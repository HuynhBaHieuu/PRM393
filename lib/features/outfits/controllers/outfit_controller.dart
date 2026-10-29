import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/extensions/string_extensions.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/core/utils/load_status.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/repositories/outfit_repository.dart';
import 'package:all_fits/features/outfits/controllers/outfit_draft.dart';

/// Owns saved outfits and every mutation of them.
class OutfitController extends ChangeNotifier {
  OutfitController({
    required this._repository,
    ImageStorageService? imageStorage,
    IdGenerator idGenerator = const UuidIdGenerator(),
    this._clock = systemClock,
  }) : _images = imageStorage,
       _ids = idGenerator;

  final OutfitRepository _repository;

  /// Stores outfit selfies; without it, outfits can't have a photo.
  final ImageStorageService? _images;
  final IdGenerator _ids;
  final Clock _clock;

  LoadStatus _status = LoadStatus.idle;
  Object? _error;
  Map<String, Outfit> _byId = const {};
  List<Outfit> _outfits = const [];

  LoadStatus get status => _status;
  Object? get error => _error;

  /// All outfits, newest first.
  List<Outfit> get outfits => _outfits;

  List<Outfit> get favorites =>
      _outfits.where((outfit) => outfit.isFavorite).toList();

  Outfit? outfitById(String id) => _byId[id];

  /// How many outfits use each clothing item.
  Map<String, int> get itemOutfitCounts {
    final counts = <String, int>{};
    for (final outfit in _outfits) {
      for (final id in outfit.itemIds) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<Outfit> outfitsUsingItem(String itemId) =>
      _outfits.where((outfit) => outfit.itemIds.contains(itemId)).toList();

  /// Outfits ordered by most recent wear.
  List<Outfit> recentlyWorn(int limit) {
    final worn = _outfits.where((o) => o.lastWornAt != null).toList()
      ..sort((a, b) => b.lastWornAt!.compareTo(a.lastWornAt!));
    return worn.take(limit).toList();
  }

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _setOutfits(await _repository.fetchAll());
      _status = LoadStatus.ready;
    } catch (error) {
      _status = LoadStatus.failure;
      _error = error;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<Outfit> createOutfit(OutfitDraft draft) async {
    draft.ensureValid();
    final photoRef = await _savePhoto(draft.newPhotoPath);
    final now = _clock();
    final outfit = Outfit(
      id: _ids.next(),
      name: draft.name.trim(),
      itemIds: draft.itemIds.toSet().toList(),
      occasion: draft.occasion,
      seasons: draft.seasons,
      notes: draft.notes.trimmedOrNull,
      isFavorite: draft.isFavorite,
      layout: draft.layout,
      background: draft.background,
      stickers: draft.stickers,
      photoPath: photoRef,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _commit([outfit]);
    } catch (_) {
      if (photoRef != null) await _images?.deleteImage(photoRef);
      rethrow;
    }
    return outfit;
  }

  Future<Outfit> updateOutfit(String id, OutfitDraft draft) async {
    final existing = _require(id);
    draft.ensureValid();
    final photoRef = await _savePhoto(draft.newPhotoPath);
    final updated = existing.copyWith(
      name: draft.name.trim(),
      itemIds: draft.itemIds.toSet().toList(),
      occasion: draft.occasion,
      seasons: draft.seasons,
      notes: draft.notes.trimmedOrNull,
      isFavorite: draft.isFavorite,
      layout: draft.layout,
      background: draft.background,
      stickers: draft.stickers,
      photoPath: photoRef ?? (draft.keepsPhoto ? existing.photoPath : null),
      updatedAt: _clock(),
    );
    try {
      await _commit([updated]);
    } catch (_) {
      if (photoRef != null) await _images?.deleteImage(photoRef);
      rethrow;
    }
    final old = existing.photoPath;
    if (old != null && old != updated.photoPath) {
      await _images?.deleteImage(old);
    }
    return updated;
  }

  /// Saves one edit made on the detail screen, e.g. a new occasion.
  Future<Outfit> patchOutfit(String id, Outfit Function(Outfit o) change) async {
    final updated = change(_require(id)).copyWith(updatedAt: _clock());
    if (updated.name.trim().isEmpty) {
      throw const ValidationException('Give this outfit a name.');
    }
    await _commit([updated]);
    return updated;
  }

  /// Fits' "Duplicate": a copy with the same pieces and layout, unworn.
  Future<Outfit> duplicateOutfit(String id) async {
    final source = _require(id);
    final now = _clock();
    final photo = source.photoPath;
    final copy = Outfit(
      id: _ids.next(),
      name: '${source.name} (copy)',
      itemIds: source.itemIds,
      occasion: source.occasion,
      seasons: source.seasons,
      notes: source.notes,
      layout: source.layout,
      background: source.background,
      stickers: source.stickers,
      // The copy needs its own stored file, so deleting one keeps the other.
      photoPath: photo == null ? null : await _copyPhoto(photo),
      createdAt: now,
      updatedAt: now,
    );
    await _commit([copy]);
    return copy;
  }

  /// Sets or replaces the outfit's photo from the file at [source]; null
  /// removes it.
  Future<void> setPhoto(String id, String? source) async {
    final existing = _require(id);
    final photoRef = await _savePhoto(source);
    try {
      await _commit([
        existing.copyWith(photoPath: photoRef, updatedAt: _clock()),
      ]);
    } catch (_) {
      if (photoRef != null) await _images?.deleteImage(photoRef);
      rethrow;
    }
    final old = existing.photoPath;
    if (old != null) await _images?.deleteImage(old);
  }

  Future<String?> _copyPhoto(String reference) async {
    final path = _images?.resolvePath(reference);
    if (path == null || path.startsWith('https://')) return null;
    return _savePhoto(path);
  }

  /// Saves the user's own order ("Custom" sort): [ids] first, in order.
  Future<void> setCustomOrder(List<String> ids) async {
    final updated = <Outfit>[];
    for (var i = 0; i < ids.length; i++) {
      final outfit = _byId[ids[i]];
      if (outfit != null && outfit.sortIndex != i) {
        updated.add(outfit.copyWith(sortIndex: i));
      }
    }
    if (updated.isNotEmpty) await _commit(updated);
  }

  Future<void> toggleFavorite(String id) async {
    final outfit = _require(id);
    await _commit([
      outfit.copyWith(isFavorite: !outfit.isFavorite, updatedAt: _clock()),
    ]);
  }

  /// Removes outfits. Callers clear calendar entries (see `ClosetActions`).
  Future<void> deleteOutfits(Iterable<String> ids) async {
    final existing = ids.where(_byId.containsKey).toSet();
    if (existing.isEmpty) return;
    final photos = [for (final id in existing) ?_byId[id]!.photoPath];
    await _repository.deleteAll(existing);
    _setOutfits(_outfits.where((o) => !existing.contains(o.id)));
    notifyListeners();
    for (final photo in photos) {
      await _images?.deleteImage(photo);
    }
  }

  Future<String?> _savePhoto(String? source) async {
    if (source == null) return null;
    final images = _images;
    if (images == null) {
      throw const ValidationException('Outfit photos aren’t available here.');
    }
    return images.saveImage(source);
  }

  Future<void> deleteOutfit(String id) => deleteOutfits([id]);

  /// Drops a deleted clothing item from every outfit that used it.
  Future<void> removeItemReferences(String itemId) async {
    final now = _clock();
    final updated = outfitsUsingItem(itemId)
        .map(
          (outfit) => outfit.copyWith(
            itemIds: outfit.itemIds.where((id) => id != itemId).toList(),
            layout: outfit.layout.where((p) => p.itemId != itemId).toList(),
            updatedAt: now,
          ),
        )
        .toList();
    if (updated.isNotEmpty) await _commit(updated);
  }

  Future<void> importOutfits(List<Outfit> outfits) async {
    final fresh = outfits.where((o) => !_byId.containsKey(o.id)).toList();
    if (fresh.isNotEmpty) await _commit(fresh);
  }

  Future<void> recordWear(String id, DateTime date) async {
    final outfit = _require(id);
    await _commit([
      outfit.copyWith(
        wearCount: outfit.wearCount + 1,
        lastWornAt: DateHelpers.latest([
          outfit.lastWornAt,
          DateHelpers.dateOnly(date),
        ]),
      ),
    ]);
  }

  Future<void> revertWear(String id, {required DateTime? lastWornAt}) async {
    final outfit = _byId[id];
    if (outfit == null) return;
    await _commit([
      outfit.copyWith(
        wearCount: math.max(0, outfit.wearCount - 1),
        lastWornAt: lastWornAt,
      ),
    ]);
  }

  Future<void> clearAll() async {
    final photos = [for (final o in _outfits) ?o.photoPath];
    await _repository.clear();
    _setOutfits(const []);
    notifyListeners();
    for (final photo in photos) {
      await _images?.deleteImage(photo);
    }
  }

  Outfit _require(String id) {
    final outfit = _byId[id];
    if (outfit == null) {
      throw const NotFoundException('This outfit no longer exists.');
    }
    return outfit;
  }

  Future<void> _commit(List<Outfit> changed) async {
    await _repository.saveAll(changed);
    final next = Map.of(_byId);
    for (final outfit in changed) {
      next[outfit.id] = outfit;
    }
    _setOutfits(next.values);
    notifyListeners();
  }

  void _setOutfits(Iterable<Outfit> outfits) {
    final sorted = outfits.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _outfits = List.unmodifiable(sorted);
    _byId = {for (final outfit in sorted) outfit.id: outfit};
  }
}
