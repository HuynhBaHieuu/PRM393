import 'dart:convert';
import 'dart:developer' as developer;

import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/json_reader.dart';
import 'package:all_fits/data/local/local_storage_service.dart';

/// A keyed collection of records, stored on the device or on a server.
abstract interface class CollectionStore<T> {
  Future<List<T>> readAll();

  Future<void> upsertAll(Iterable<T> values);

  Future<void> removeIds(Iterable<String> ids);

  Future<void> clear();
}

/// Persists a collection of records as a JSON array under a single key.
///
/// Malformed records are skipped instead of failing the whole load, and an
/// unreadable payload is backed up before it can be overwritten.
/// The in-memory cache is only updated after a write succeeds.
class JsonCollectionStore<T> implements CollectionStore<T> {
  JsonCollectionStore({
    required this._storage,
    required this._key,
    required this._fromJson,
    required this._toJson,
    required this._idOf,
  });

  final LocalStorageService _storage;
  final String _key;
  final T Function(JsonMap json) _fromJson;
  final JsonMap Function(T value) _toJson;
  final String Function(T value) _idOf;

  Map<String, T>? _cache;

  @override
  Future<List<T>> readAll() async => List.of((await _load()).values);

  @override
  Future<void> upsertAll(Iterable<T> values) async {
    final next = Map.of(await _load());
    for (final value in values) {
      next[_idOf(value)] = value;
    }
    await _persist(next);
  }

  @override
  Future<void> removeIds(Iterable<String> ids) async {
    final next = Map.of(await _load());
    var changed = false;
    for (final id in ids) {
      changed = next.remove(id) != null || changed;
    }
    if (changed) await _persist(next);
  }

  @override
  Future<void> clear() => _persist({});

  Future<Map<String, T>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final String? raw;
    try {
      raw = await _storage.read(_key);
    } catch (error) {
      _log('Failed to read', error);
      throw const StorageException('Your saved data could not be loaded.');
    }

    final records = <String, T>{};
    if (raw != null && raw.isNotEmpty) {
      Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } on FormatException catch (error) {
        _log('Stored JSON is unreadable', error);
        await _backup(raw);
      }
      if (decoded is List) {
        for (final element in decoded) {
          try {
            final value = _fromJson(Map<String, dynamic>.from(element as Map));
            records[_idOf(value)] = value;
          } catch (error) {
            _log('Skipping malformed record', error);
          }
        }
      } else if (decoded != null) {
        _log('Unexpected payload type ${decoded.runtimeType}', null);
        await _backup(raw);
      }
    }
    return _cache = records;
  }

  Future<void> _persist(Map<String, T> next) async {
    try {
      final encoded = jsonEncode(next.values.map(_toJson).toList());
      await _storage.write(_key, encoded);
    } catch (error) {
      _log('Failed to write', error);
      throw const StorageException();
    }
    _cache = next;
  }

  Future<void> _backup(String raw) async {
    try {
      await _storage.write(StorageKeys.corruptBackup(_key), raw);
    } catch (error) {
      _log('Failed to back up corrupt data', error);
    }
  }

  void _log(String message, Object? error) =>
      developer.log('$message ($_key)', name: 'storage', error: error);
}
