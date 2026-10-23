import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/core/utils/load_status.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/models/collection.dart';
import 'package:all_fits/data/repositories/collection_repository.dart';

/// Owns the user's collections and every mutation of them. Collections only
/// point at items and outfits: deleting one never deletes what is inside.
class CollectionController extends ChangeNotifier {
  CollectionController({
    required this._repository,
    required ImageStorageService imageStorage,
    IdGenerator idGenerator = const UuidIdGenerator(),
    this._clock = systemClock,
  }) : _images = imageStorage,
       _ids = idGenerator;

  final CollectionRepository _repository;
  final ImageStorageService _images;
  final IdGenerator _ids;
  final Clock _clock;

  LoadStatus _status = LoadStatus.idle;
  Object? _error;
  Map<String, Collection> _byId = const {};
  List<Collection> _collections = const [];

  LoadStatus get status => _status;
  Object? get error => _error;

  /// All collections, newest first.
  List<Collection> get collections => _collections;

  Collection? collectionById(String id) => _byId[id];

  List<Collection> collectionsWithItem(String itemId) =>
      _collections.where((c) => c.containsItem(itemId)).toList();

  List<Collection> collectionsWithOutfit(String outfitId) =>
      _collections.where((c) => c.containsOutfit(outfitId)).toList();

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _setCollections(await _repository.fetchAll());
      _status = LoadStatus.ready;
    } catch (error) {
      _status = LoadStatus.failure;
      _error = error;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// Plan limits are checked by the caller (see `PremiumFlows`).
  Future<Collection> createCollection(
    String name, {
    List<String> itemIds = const [],
    List<String> outfitIds = const [],
  }) async {
    final trimmed = _validName(name);
    final now = _clock();
    final collection = Collection(
      id: _ids.next(),
      name: trimmed,
      itemIds: itemIds.toSet().toList(),
      outfitIds: outfitIds.toSet().toList(),
      createdAt: now,
      updatedAt: now,
    );
    await _commit([collection]);
    return collection;
  }

  Future<void> rename(String id, String name) async {
    final collection = _require(id);
    final trimmed = _validName(name, except: id);
    if (trimmed == collection.name) return;
    await _commit([collection.copyWith(name: trimmed, updatedAt: _clock())]);
  }

  /// Removes the collection and its cover photo; its pieces and outfits stay.
  Future<void> deleteCollection(String id) async {
    final collection = _byId[id];
    if (collection == null) return;
    await _repository.deleteAll([id]);
    _setCollections(_collections.where((c) => c.id != id));
    notifyListeners();
    await _deleteCover(collection.coverImagePath);
  }

  /// Replaces what the collection holds. New entries go first, so the
  /// collection reads newest first.
  Future<void> setEntries(
    String id, {
    required Iterable<String> itemIds,
    required Iterable<String> outfitIds,
  }) async {
    final collection = _require(id);
    final items = _merged(collection.itemIds, itemIds);
    final outfits = _merged(collection.outfitIds, outfitIds);
    if (listEquals(items, collection.itemIds) &&
        listEquals(outfits, collection.outfitIds)) {
      return;
    }
    await _commit([
      collection.copyWith(
        itemIds: items,
        outfitIds: outfits,
        updatedAt: _clock(),
      ),
    ]);
  }

  Future<void> removeEntries(
    String id, {
    Iterable<String> itemIds = const [],
    Iterable<String> outfitIds = const [],
  }) {
    final collection = _require(id);
    final items = itemIds.toSet();
    final outfits = outfitIds.toSet();
    return setEntries(
      id,
      itemIds: collection.itemIds.where((i) => !items.contains(i)),
      outfitIds: collection.outfitIds.where((o) => !outfits.contains(o)),
    );
  }

  /// Puts [itemId] in exactly the collections in [collectionIds].
  Future<void> setItemMembership(String itemId, Set<String> collectionIds) =>
      _setMembership(
        collectionIds,
        contains: (c) => c.containsItem(itemId),
        toggle: (c, add) => c.copyWith(
          itemIds: add
              ? [itemId, ...c.itemIds]
              : c.itemIds.where((i) => i != itemId).toList(),
        ),
      );

  /// Puts [outfitId] in exactly the collections in [collectionIds].
  Future<void> setOutfitMembership(
    String outfitId,
    Set<String> collectionIds,
  ) => _setMembership(
    collectionIds,
    contains: (c) => c.containsOutfit(outfitId),
    toggle: (c, add) => c.copyWith(
      outfitIds: add
          ? [outfitId, ...c.outfitIds]
          : c.outfitIds.where((o) => o != outfitId).toList(),
    ),
  );

  /// Stores the photo at [sourcePath] as the cover, replacing any other.
  Future<void> setCover(String id, String sourcePath) async {
    final collection = _require(id);
    final reference = await _images.saveImage(sourcePath);
    try {
      await _commit([
        collection.copyWith(coverImagePath: reference, updatedAt: _clock()),
      ]);
    } catch (_) {
      await _deleteCover(reference);
      rethrow;
    }
    await _deleteCover(collection.coverImagePath);
  }

  /// Goes back to the collage cover.
  Future<void> clearCover(String id) async {
    final collection = _require(id);
    final previous = collection.coverImagePath;
    if (previous == null) return;
    await _commit([
      collection.copyWith(coverImagePath: null, updatedAt: _clock()),
    ]);
    await _deleteCover(previous);
  }

  /// Drops a permanently deleted clothing item from every collection.
  Future<void> removeItemReferences(Iterable<String> itemIds) {
    final ids = itemIds.toSet();
    return _dropReferences(
      (c) => c.itemIds.any(ids.contains),
      (c) => c.copyWith(
        itemIds: c.itemIds.where((i) => !ids.contains(i)).toList(),
      ),
    );
  }

  /// Drops a deleted outfit from every collection.
  Future<void> removeOutfitReferences(Iterable<String> outfitIds) {
    final ids = outfitIds.toSet();
    return _dropReferences(
      (c) => c.outfitIds.any(ids.contains),
      (c) => c.copyWith(
        outfitIds: c.outfitIds.where((o) => !ids.contains(o)).toList(),
      ),
    );
  }

  Future<void> clearAll() async {
    final covers = _collections.map((c) => c.coverImagePath).toList();
    await _repository.clear();
    _setCollections(const []);
    notifyListeners();
    for (final cover in covers) {
      await _deleteCover(cover);
    }
  }

  String _validName(String name, {String? except}) {
    final trimmed = name.trim();
    final error = Validators.requiredName(trimmed);
    if (error != null) throw ValidationException(error);
    final key = trimmed.toLowerCase();
    final taken = _collections.any(
      (c) => c.id != except && c.name.toLowerCase() == key,
    );
    if (taken) {
      throw ValidationException('You already have a collection “$trimmed”.');
    }
    return trimmed;
  }

  /// [next] in order, with ids that were not in [current] moved to the
  /// front.
  static List<String> _merged(List<String> current, Iterable<String> next) {
    final wanted = next.toSet();
    final existing = current.toSet();
    return [
      ...wanted.where((id) => !existing.contains(id)),
      ...current.where(wanted.contains),
    ];
  }

  Future<void> _setMembership(
    Set<String> collectionIds, {
    required bool Function(Collection) contains,
    required Collection Function(Collection, bool add) toggle,
  }) async {
    final now = _clock();
    final changed = [
      for (final collection in _collections)
        if (contains(collection) != collectionIds.contains(collection.id))
          toggle(
            collection,
            collectionIds.contains(collection.id),
          ).copyWith(updatedAt: now),
    ];
    if (changed.isNotEmpty) await _commit(changed);
  }

  Future<void> _dropReferences(
    bool Function(Collection) affected,
    Collection Function(Collection) update,
  ) async {
    final now = _clock();
    final changed = [
      for (final collection in _collections.where(affected))
        update(collection).copyWith(updatedAt: now),
    ];
    if (changed.isNotEmpty) await _commit(changed);
  }

  Future<void> _deleteCover(String? reference) async {
    if (reference == null) return;
    try {
      await _images.deleteImage(reference);
    } catch (error) {
      // An orphaned photo is harmless; never block the user on cleanup.
      developer.log('Cover not deleted', name: 'collections', error: error);
    }
  }

  Collection _require(String id) {
    final collection = _byId[id];
    if (collection == null) {
      throw const NotFoundException('This collection no longer exists.');
    }
    return collection;
  }

  Future<void> _commit(List<Collection> changed) async {
    await _repository.saveAll(changed);
    final next = Map.of(_byId);
    for (final collection in changed) {
      next[collection.id] = collection;
    }
    _setCollections(next.values);
    notifyListeners();
  }

  void _setCollections(Iterable<Collection> collections) {
    final sorted = collections.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _collections = List.unmodifiable(sorted);
    _byId = {for (final collection in sorted) collection.id: collection};
  }
}
