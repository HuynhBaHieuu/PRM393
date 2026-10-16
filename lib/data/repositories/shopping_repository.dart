import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/data/local/json_collection_store.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/shopping_item.dart';

abstract interface class ShoppingRepository {
  Future<List<ShoppingItem>> fetchAll();

  /// Inserts or replaces items by id.
  Future<void> saveAll(Iterable<ShoppingItem> items);

  Future<void> deleteAll(Iterable<String> ids);

  Future<void> clear();
}

class LocalShoppingRepository implements ShoppingRepository {
  LocalShoppingRepository(LocalStorageService storage)
    : this.fromStore(
        JsonCollectionStore<ShoppingItem>(
          storage: storage,
          key: StorageKeys.shoppingItems,
          fromJson: ShoppingItem.fromJson,
          toJson: (item) => item.toJson(),
          idOf: (item) => item.id,
        ),
      );

  /// Uses any [CollectionStore], e.g. `SupabaseCollectionStore` for the server.
  LocalShoppingRepository.fromStore(this._store);

  final CollectionStore<ShoppingItem> _store;

  @override
  Future<List<ShoppingItem>> fetchAll() => _store.readAll();

  @override
  Future<void> saveAll(Iterable<ShoppingItem> items) => _store.upsertAll(items);

  @override
  Future<void> deleteAll(Iterable<String> ids) => _store.removeIds(ids);

  @override
  Future<void> clear() => _store.clear();
}
