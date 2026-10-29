import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/extensions/string_extensions.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/core/utils/load_status.dart';
import 'package:all_fits/data/local/background_remover.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/clothing_photo.dart';
import 'package:all_fits/data/repositories/wardrobe_repository.dart';
import 'package:all_fits/features/wardrobe/controllers/clothing_draft.dart';

/// Owns the wardrobe state and every mutation of clothing items.
class WardrobeController extends ChangeNotifier {
  WardrobeController({
    required this._repository,
    required ImageStorageService imageStorage,
    BackgroundRemover backgroundRemover = const NoBackgroundRemover(),
    IdGenerator idGenerator = const UuidIdGenerator(),
    this._clock = systemClock,
  }) : _images = imageStorage,
       _backgrounds = backgroundRemover,
       _ids = idGenerator;

  final WardrobeRepository _repository;
  final ImageStorageService _images;
  final BackgroundRemover _backgrounds;
  final IdGenerator _ids;
  final Clock _clock;

  LoadStatus _status = LoadStatus.idle;
  Object? _error;
  Map<String, ClothingItem> _byId = const {};
  List<ClothingItem> _all = const [];
  List<ClothingItem> _active = const [];
  List<ClothingItem> _archived = const [];
  final Set<String> _cutoutAttempts = {};

  LoadStatus get status => _status;
  Object? get error => _error;

  /// Every item, newest first.
  List<ClothingItem> get allItems => _all;

  /// Items shown in the wardrobe (not archived), newest first.
  List<ClothingItem> get activeItems => _active;

  List<ClothingItem> get archivedItems => _archived;

  List<ClothingItem> get favoriteItems =>
      _active.where((item) => item.isFavorite).toList();

  List<ClothingItem> recentlyAdded(int limit) => _active.take(limit).toList();

  /// Distinct brand names, sorted alphabetically.
  List<String> get brands {
    final names = <String, String>{};
    for (final item in _active) {
      final brand = item.brand;
      if (brand != null) names.putIfAbsent(brand.toLowerCase(), () => brand);
    }
    return names.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  ClothingItem? itemById(String id) => _byId[id];

  /// Resolves ids in order, skipping any that no longer exist.
  List<ClothingItem> itemsByIds(Iterable<String> ids) =>
      ids.map((id) => _byId[id]).whereType<ClothingItem>().toList();

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _setItems(await _repository.fetchAll());
      _status = LoadStatus.ready;
    } catch (error) {
      _status = LoadStatus.failure;
      _error = error;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<ClothingItem> addItem(ClothingDraft draft) async {
    draft.ensureValid(requireImage: true);
    final imageRef = await _images.saveImage(draft.newImagePath!);
    final cutoutRef = await _saveCutout(draft.newImagePath!);
    final created = [imageRef, ?cutoutRef];
    try {
      final now = _clock();
      final item = ClothingItem(
        id: _ids.next(),
        name: draft.name.trim(),
        imagePath: imageRef,
        cutoutPath: cutoutRef,
        extraPhotos: await _storeExtras(draft.extraPhotos ?? const [], created),
        category: draft.category!,
        subcategory: draft.subcategory,
        color: draft.color,
        seasons: draft.seasons,
        brand: draft.brand.trimmedOrNull,
        price: draft.price,
        notes: draft.notes.trimmedOrNull,
        isFavorite: draft.isFavorite,
        createdAt: now,
        updatedAt: now,
      );
      await _commit([item]);
      return item;
    } catch (_) {
      await _deleteAll(created);
      rethrow;
    }
  }

  Future<ClothingItem> updateItem(String id, ClothingDraft draft) async {
    final existing = _require(id);
    draft.ensureValid(requireImage: existing.imagePath == null);

    final created = <String>[];
    final ClothingItem updated;
    try {
      String? newImageRef;
      String? newCutoutRef;
      final newImagePath = draft.newImagePath;
      if (newImagePath != null) {
        newImageRef = await _images.saveImage(newImagePath);
        created.add(newImageRef);
        newCutoutRef = await _saveCutout(newImagePath);
        if (newCutoutRef != null) created.add(newCutoutRef);
      }
      final extras = draft.extraPhotos;
      updated = existing.copyWith(
        name: draft.name.trim(),
        imagePath: newImageRef ?? existing.imagePath,
        cutoutPath: newImageRef != null ? newCutoutRef : existing.cutoutPath,
        extraPhotos: extras == null
            ? existing.extraPhotos
            : await _storeExtras(extras, created),
        category: draft.category,
        subcategory: draft.subcategory,
        color: draft.color,
        seasons: draft.seasons,
        brand: draft.brand.trimmedOrNull,
        price: draft.price,
        notes: draft.notes.trimmedOrNull,
        isFavorite: draft.isFavorite,
        updatedAt: _clock(),
      );
      await _commit([updated]);
    } catch (_) {
      await _deleteAll(created);
      rethrow;
    }
    await _deleteDropped(existing, updated);
    return updated;
  }

  /// Saves one edit made on the detail screen, e.g. a new brand or season.
  Future<ClothingItem> patchItem(
    String id,
    ClothingItem Function(ClothingItem item) change,
  ) async {
    final updated = change(_require(id)).copyWith(updatedAt: _clock());
    if (updated.name.trim().isEmpty) {
      throw const ValidationException('Give this piece a name.');
    }
    await _commit([updated]);
    return updated;
  }

  /// Swaps the photo for the one at [source] and cuts it out again.
  Future<void> replacePhoto(String id, String source) async {
    final existing = _require(id);
    final imageRef = await _images.saveImage(source);
    final cutoutRef = await _saveCutout(source);
    final updated = existing.copyWith(
      imagePath: imageRef,
      cutoutPath: cutoutRef,
      updatedAt: _clock(),
    );
    try {
      await _commit([updated]);
    } catch (_) {
      await _deleteAll([imageRef, ?cutoutRef]);
      rethrow;
    }
    await _deleteDropped(existing, updated);
  }

  /// Adds the photo at [source] as an extra photo showing [kind].
  Future<void> addExtraPhoto(String id, String source, PhotoKind kind) async {
    final existing = _require(id);
    if (existing.extraPhotos.length >= AppConfig.maxExtraPhotos) {
      throw const ValidationException(
        'A piece can have up to ${AppConfig.maxExtraPhotos} extra photos.',
      );
    }
    final reference = await _images.saveImage(source);
    try {
      await _commit([
        existing.copyWith(
          extraPhotos: [
            ...existing.extraPhotos,
            ClothingPhoto(path: reference, kind: kind),
          ],
          updatedAt: _clock(),
        ),
      ]);
    } catch (_) {
      await _images.deleteImage(reference);
      rethrow;
    }
  }

  /// Changes what the extra photo at [reference] is said to show.
  Future<void> setExtraPhotoKind(
    String id,
    String reference,
    PhotoKind kind,
  ) async {
    final existing = _require(id);
    await _commit([
      existing.copyWith(
        extraPhotos: [
          for (final photo in existing.extraPhotos)
            photo.path == reference ? photo.copyWith(kind: kind) : photo,
        ],
        updatedAt: _clock(),
      ),
    ]);
  }

  Future<void> removeExtraPhoto(String id, String reference) async {
    final existing = _require(id);
    final updated = existing.copyWith(
      extraPhotos: [
        for (final photo in existing.extraPhotos)
          if (photo.path != reference) photo,
      ],
      updatedAt: _clock(),
    );
    await _commit([updated]);
    await _deleteDropped(existing, updated);
  }

  /// Makes the extra photo at [reference] the main one and cuts it out. The
  /// old main photo takes its place among the extra photos, as the front.
  Future<void> makeMainPhoto(String id, String reference) async {
    final existing = _require(id);
    final index = existing.extraPhotos.indexWhere((p) => p.path == reference);
    if (index < 0) return;
    final source = _images.resolvePath(reference);
    final cutoutRef = source == null || source.startsWith('https://')
        ? null
        : await _saveCutout(source);
    final oldMain = existing.imagePath;
    final extras = [...existing.extraPhotos]..removeAt(index);
    if (oldMain != null) {
      extras.insert(index, ClothingPhoto(path: oldMain, kind: PhotoKind.front));
    }
    final updated = existing.copyWith(
      imagePath: reference,
      cutoutPath: cutoutRef,
      extraPhotos: extras,
      updatedAt: _clock(),
    );
    try {
      await _commit([updated]);
    } catch (_) {
      if (cutoutRef != null) await _images.deleteImage(cutoutRef);
      rethrow;
    }
    // Lets the closet try again for a cut-out that failed just now.
    _cutoutAttempts.remove(id);
    await _deleteDropped(existing, updated);
  }

  /// Cuts the current photo out again, e.g. after a poor first attempt.
  Future<bool> redoCutout(String id) async {
    final existing = _require(id);
    final photo = existing.imagePath;
    final source = photo == null ? null : _images.resolvePath(photo);
    if (source == null || source.startsWith('https://')) return false;
    final cutoutRef = await _saveCutout(source);
    if (cutoutRef == null) return false;
    await _commit([
      existing.copyWith(cutoutPath: cutoutRef, updatedAt: _clock()),
    ]);
    final old = existing.cutoutPath;
    if (old != null) await _images.deleteImage(old);
    return true;
  }

  /// Saves the user's own order ("Custom" sort): [ids] first, in order.
  Future<void> setCustomOrder(List<String> ids) async {
    final updated = <ClothingItem>[];
    for (var i = 0; i < ids.length; i++) {
      final item = _byId[ids[i]];
      if (item != null && item.sortIndex != i) {
        updated.add(item.copyWith(sortIndex: i));
      }
    }
    if (updated.isNotEmpty) await _commit(updated);
  }

  Future<void> setArchivedMany(
    Iterable<String> ids, {
    required bool archived,
  }) async {
    final now = _clock();
    final updated = [
      for (final item in itemsByIds(ids))
        if (item.isArchived != archived)
          item.copyWith(isArchived: archived, updatedAt: now),
    ];
    if (updated.isNotEmpty) await _commit(updated);
  }

  /// Distinct materials, sorted alphabetically.
  List<String> get materials {
    final names = <String, String>{};
    for (final item in _active) {
      for (final material in item.materials) {
        names.putIfAbsent(material.toLowerCase(), () => material);
      }
    }
    return names.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Distinct tags on every piece, archived ones included (they still count
  /// toward the Free limit), sorted alphabetically.
  List<String> get tags {
    final names = <String, String>{};
    for (final item in _all) {
      for (final tag in item.tags) {
        names.putIfAbsent(tag.toLowerCase(), () => tag);
      }
    }
    return names.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Future<void> toggleFavorite(String id) async {
    final item = _require(id);
    await _commit([
      item.copyWith(isFavorite: !item.isFavorite, updatedAt: _clock()),
    ]);
  }

  Future<void> setArchived(String id, {required bool archived}) async {
    final item = _require(id);
    if (item.isArchived == archived) return;
    await _commit([item.copyWith(isArchived: archived, updatedAt: _clock())]);
  }

  /// Permanently removes items and their photos. Callers are responsible for
  /// removing references from outfits (see `ClosetActions`).
  Future<void> deleteItems(Iterable<String> ids) async {
    final removed = ids.map((id) => _byId[id]).whereType<ClothingItem>();
    final images = _photosOf(removed);
    final removedIds = removed.map((i) => i.id).toSet();
    if (removedIds.isEmpty) return;
    await _repository.deleteAll(removedIds);
    _setItems(_all.where((item) => !removedIds.contains(item.id)));
    notifyListeners();
    for (final image in images) {
      await _images.deleteImage(image);
    }
  }

  Future<void> deleteItem(String id) => deleteItems([id]);

  /// Adds pre-built items (e.g. sample data), keeping existing ids untouched.
  Future<void> importItems(List<ClothingItem> items) async {
    final fresh = items.where((item) => !_byId.containsKey(item.id)).toList();
    if (fresh.isNotEmpty) await _commit(fresh);
  }

  /// Increments wear counts for an outfit worn on [date].
  Future<void> recordWear(Iterable<String> itemIds, DateTime date) async {
    final day = DateHelpers.dateOnly(date);
    final updated = itemsByIds(itemIds.toSet()).map((item) {
      return item.copyWith(
        wearCount: item.wearCount + 1,
        lastWornAt: DateHelpers.latest([item.lastWornAt, day]),
      );
    }).toList();
    if (updated.isNotEmpty) await _commit(updated);
  }

  /// Reverses one wear for each item, restoring the given last-worn dates.
  Future<void> revertWear(Map<String, DateTime?> lastWornById) async {
    final updated = itemsByIds(lastWornById.keys).map((item) {
      return item.copyWith(
        wearCount: math.max(0, item.wearCount - 1),
        lastWornAt: lastWornById[item.id],
      );
    }).toList();
    if (updated.isNotEmpty) await _commit(updated);
  }

  Future<void> clearAll() async {
    final images = _photosOf(_all);
    await _repository.clear();
    _setItems(const []);
    notifyListeners();
    for (final image in images) {
      await _images.deleteImage(image);
    }
  }

  /// Makes cut-outs for pieces that have a photo but none yet. Each piece is
  /// tried once per session, so a photo that can't be cut out isn't retried
  /// on every rebuild. Never throws.
  Future<void> ensureCutouts(Iterable<String> ids) async {
    for (final item in itemsByIds(ids)) {
      final photo = item.imagePath;
      if (photo == null || item.cutoutPath != null) continue;
      if (!_cutoutAttempts.add(item.id)) continue;
      final source = _images.resolvePath(photo);
      if (source == null) continue;
      final cutout = await _saveCutout(source);
      if (cutout == null) continue;
      final current = _byId[item.id];
      try {
        // The photo may have changed or the item gone while cutting out.
        if (current == null || current.imagePath != photo) {
          throw const NotFoundException('Photo changed');
        }
        await _commit([current.copyWith(cutoutPath: cutout)]);
      } catch (error) {
        developer.log('Cut-out dropped', name: 'wardrobe', error: error);
        await _images.deleteImage(cutout);
      }
    }
  }

  /// Stores a cut-out of the photo at [source], or returns null when its
  /// background can't be removed. The piece then shows its photo instead.
  Future<String?> _saveCutout(String source) async {
    final cutout = await _backgrounds.removeBackground(source);
    if (cutout == null) return null;
    try {
      return await _images.saveImage(cutout);
    } catch (error) {
      developer.log('Cut-out not saved', name: 'wardrobe', error: error);
      return null;
    } finally {
      try {
        await File(cutout).delete();
      } on FileSystemException {
        // A leftover temp file is harmless.
      }
    }
  }

  /// Resolves the form's extra photos to stored ones, copying each newly
  /// picked photo into storage and adding its reference to [created].
  Future<List<ClothingPhoto>> _storeExtras(
    List<ExtraPhotoDraft> drafts,
    List<String> created,
  ) async {
    final photos = <ClothingPhoto>[];
    for (final draft in drafts) {
      var reference = draft.reference;
      if (reference == null) {
        reference = await _images.saveImage(draft.newPath!);
        created.add(reference);
      }
      photos.add(ClothingPhoto(path: reference, kind: draft.kind));
    }
    return photos;
  }

  /// Deletes the photos [before] had that [after] no longer uses.
  Future<void> _deleteDropped(ClothingItem before, ClothingItem after) async {
    final kept = _photosOf([after]).toSet();
    await _deleteAll(_photosOf([before]).where((p) => !kept.contains(p)));
  }

  Future<void> _deleteAll(Iterable<String> references) async {
    for (final reference in references) {
      await _images.deleteImage(reference);
    }
  }

  static List<String> _photosOf(Iterable<ClothingItem> items) => [
    for (final item in items) ...[
      ?item.imagePath,
      ?item.cutoutPath,
      for (final photo in item.extraPhotos) photo.path,
    ],
  ];

  ClothingItem _require(String id) {
    final item = _byId[id];
    if (item == null) {
      developer.log('Missing clothing item $id', name: 'wardrobe');
      throw const NotFoundException('This item is no longer in your wardrobe.');
    }
    return item;
  }

  Future<void> _commit(List<ClothingItem> changed) async {
    await _repository.saveAll(changed);
    final next = Map.of(_byId);
    for (final item in changed) {
      next[item.id] = item;
    }
    _setItems(next.values);
    notifyListeners();
  }

  void _setItems(Iterable<ClothingItem> items) {
    final sorted = items.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _all = List.unmodifiable(sorted);
    _byId = {for (final item in sorted) item.id: item};
    _active = List.unmodifiable(sorted.where((item) => !item.isArchived));
    _archived = List.unmodifiable(sorted.where((item) => item.isArchived));
  }
}
