import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/data/local/json_collection_store.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/trip.dart';

abstract interface class TripRepository {
  Future<List<Trip>> fetchAll();

  /// Inserts or replaces trips by id.
  Future<void> saveAll(Iterable<Trip> trips);

  Future<void> deleteAll(Iterable<String> ids);

  Future<void> clear();
}

class LocalTripRepository implements TripRepository {
  LocalTripRepository(LocalStorageService storage)
    : this.fromStore(
        JsonCollectionStore<Trip>(
          storage: storage,
          key: StorageKeys.trips,
          fromJson: Trip.fromJson,
          toJson: (trip) => trip.toJson(),
          idOf: (trip) => trip.id,
        ),
      );

  /// Uses any [CollectionStore], e.g. `SupabaseCollectionStore` for the server.
  LocalTripRepository.fromStore(this._store);

  final CollectionStore<Trip> _store;

  @override
  Future<List<Trip>> fetchAll() => _store.readAll();

  @override
  Future<void> saveAll(Iterable<Trip> trips) => _store.upsertAll(trips);

  @override
  Future<void> deleteAll(Iterable<String> ids) => _store.removeIds(ids);

  @override
  Future<void> clear() => _store.clear();
}
