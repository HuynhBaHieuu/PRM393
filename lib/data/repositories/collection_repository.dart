import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/data/local/json_collection_store.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/collection.dart';

abstract interface class CollectionRepository {
  Future<List<Collection>> fetchAll();

  /// Inserts or replaces collections by id.
  Future<void> saveAll(Iterable<Collection> collections);

  Future<void> deleteAll(Iterable<String> ids);

  Future<void> clear();
}

class LocalCollectionRepository implements CollectionRepository {
  LocalCollectionRepository(LocalStorageService storage)
    : this.fromStore(
        JsonCollectionStore<Collection>(
          storage: storage,
          key: StorageKeys.collections,
          fromJson: Collection.fromJson,
          toJson: (collection) => collection.toJson(),
          idOf: (collection) => collection.id,
        ),
      );

  /// Uses any [CollectionStore], e.g. `SupabaseCollectionStore` for the server.
  LocalCollectionRepository.fromStore(this._store);

  final CollectionStore<Collection> _store;

  @override
  Future<List<Collection>> fetchAll() => _store.readAll();

  @override
  Future<void> saveAll(Iterable<Collection> collections) =>
      _store.upsertAll(collections);

  @override
  Future<void> deleteAll(Iterable<String> ids) => _store.removeIds(ids);

  @override
  Future<void> clear() => _store.clear();
}
