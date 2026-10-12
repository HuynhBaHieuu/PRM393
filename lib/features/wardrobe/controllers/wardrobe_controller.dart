import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/extensions/string_extensions.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/core/utils/load_status.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/repositories/wardrobe_repository.dart';
import 'package:all_fits/features/wardrobe/controllers/clothing_draft.dart';

/// Owns the wardrobe state and every mutation of clothing items.
class WardrobeController extends ChangeNotifier {
  WardrobeController({
    required this._repository,
    required ImageStorageService imageStorage,
    IdGenerator idGenerator = const UuidIdGenerator(),
    this._clock = systemClock,
  }) : _images = imageStorage,
       _ids = idGenerator;

  final WardrobeRepository _repository;
  final ImageStorageService _images;
  final IdGenerator _ids;
  final Clock _clock;

  LoadStatus _status = LoadStatus.idle;
  Object? _error;
  Map<String, ClothingItem> _byId = const {};
  List<ClothingItem> _all = const [];
  List<ClothingItem> _active = const [];
  List<ClothingItem> _archived = const [];

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
    final now = _clock();
    final item = ClothingItem(
      id: _ids.next(),
      name: draft.name.trim(),
      imagePath: imageRef,
      category: draft.category!,
      color: draft.color,
      seasons: draft.seasons,
      brand: draft.brand.trimmedOrNull,
      price: draft.price,
      notes: draft.notes.trimmedOrNull,
      isFavorite: draft.isFavorite,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _commit([item]);
    } catch (_) {
      await _images.deleteImage(imageRef);
      rethrow;
    }
    return item;
  }

  Future<ClothingItem> updateItem(String id, ClothingDraft draft) async {
    final existing = _require(id);
    draft.ensureValid(requireImage: existing.imagePath == null);

    String? newImageRef;
    final newImagePath = draft.newImagePath;
    if (newImagePath != null) {
      newImageRef = await _images.saveImage(newImagePath);
    }
    final updated = existing.copyWith(
      name: draft.name.trim(),
      imagePath: newImageRef ?? existing.imagePath,
      category: draft.category,
      color: draft.color,
      seasons: draft.seasons,
      brand: draft.brand.trimmedOrNull,
      price: draft.price,
      notes: draft.notes.trimmedOrNull,
      isFavorite: draft.isFavorite,
      updatedAt: _clock(),
    );
    try {
      await _commit([updated]);
    } catch (_) {
      if (newImageRef != null) await _images.deleteImage(newImageRef);
      rethrow;
    }
    final oldImage = existing.imagePath;
    if (newImageRef != null && oldImage != null) {
      await _images.deleteImage(oldImage);
    }
    return updated;
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
    final images = removed.map((i) => i.imagePath).whereType<String>().toList();
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
    final images = _all.map((i) => i.imagePath).whereType<String>().toList();
    await _repository.clear();
    _setItems(const []);
    notifyListeners();
    for (final image in images) {
      await _images.deleteImage(image);
    }
  }

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
