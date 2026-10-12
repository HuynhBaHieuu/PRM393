import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/data/local/json_collection_store.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/clothing_item.dart';

abstract interface class WardrobeRepository {
  Future<List<ClothingItem>> fetchAll();

  /// Inserts or replaces items by id.
  Future<void> saveAll(Iterable<ClothingItem> items);

  Future<void> deleteAll(Iterable<String> ids);

  Future<void> clear();
}

class LocalWardrobeRepository implements WardrobeRepository {
  LocalWardrobeRepository(LocalStorageService storage)
    : _store = JsonCollectionStore<ClothingItem>(
        storage: storage,
        key: StorageKeys.clothingItems,
        fromJson: ClothingItem.fromJson,
        toJson: (item) => item.toJson(),
        idOf: (item) => item.id,
      );

  final JsonCollectionStore<ClothingItem> _store;

  @override
  Future<List<ClothingItem>> fetchAll() => _store.readAll();

  @override
  Future<void> saveAll(Iterable<ClothingItem> items) => _store.upsertAll(items);

  @override
  Future<void> deleteAll(Iterable<String> ids) => _store.removeIds(ids);

  @override
  Future<void> clear() => _store.clear();
}
