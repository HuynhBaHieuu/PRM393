import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/data/local/json_collection_store.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/outfit_calendar_entry.dart';

abstract interface class CalendarRepository {
  Future<List<OutfitCalendarEntry>> fetchAll();

  /// Inserts or replaces entries by id.
  Future<void> saveAll(Iterable<OutfitCalendarEntry> entries);

  Future<void> deleteAll(Iterable<String> ids);

  Future<void> clear();
}

class LocalCalendarRepository implements CalendarRepository {
  LocalCalendarRepository(LocalStorageService storage)
    : this.fromStore(
        JsonCollectionStore<OutfitCalendarEntry>(
          storage: storage,
          key: StorageKeys.calendarEntries,
          fromJson: OutfitCalendarEntry.fromJson,
          toJson: (entry) => entry.toJson(),
          idOf: (entry) => entry.id,
        ),
      );

  /// Uses any [CollectionStore], e.g. `SupabaseCollectionStore` for the server.
  LocalCalendarRepository.fromStore(this._store);

  final CollectionStore<OutfitCalendarEntry> _store;

  @override
  Future<List<OutfitCalendarEntry>> fetchAll() => _store.readAll();

  @override
  Future<void> saveAll(Iterable<OutfitCalendarEntry> entries) =>
      _store.upsertAll(entries);

  @override
  Future<void> deleteAll(Iterable<String> ids) => _store.removeIds(ids);

  @override
  Future<void> clear() => _store.clear();
}
