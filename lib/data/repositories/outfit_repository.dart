import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/data/local/json_collection_store.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/outfit.dart';

abstract interface class OutfitRepository {
  Future<List<Outfit>> fetchAll();

  /// Inserts or replaces outfits by id.
  Future<void> saveAll(Iterable<Outfit> outfits);

  Future<void> deleteAll(Iterable<String> ids);

  Future<void> clear();
}

class LocalOutfitRepository implements OutfitRepository {
  LocalOutfitRepository(LocalStorageService storage)
    : _store = JsonCollectionStore<Outfit>(
        storage: storage,
        key: StorageKeys.outfits,
        fromJson: Outfit.fromJson,
        toJson: (outfit) => outfit.toJson(),
        idOf: (outfit) => outfit.id,
      );

  final JsonCollectionStore<Outfit> _store;

  @override
  Future<List<Outfit>> fetchAll() => _store.readAll();

  @override
  Future<void> saveAll(Iterable<Outfit> outfits) => _store.upsertAll(outfits);

  @override
  Future<void> deleteAll(Iterable<String> ids) => _store.removeIds(ids);

  @override
  Future<void> clear() => _store.clear();
}
