import 'package:shared_preferences/shared_preferences.dart';

/// Minimal key-value persistence contract. Swap the implementation to move
/// storage to a database or a remote backend without touching repositories.
abstract interface class LocalStorageService {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> remove(String key);
}

class SharedPreferencesStorageService implements LocalStorageService {
  SharedPreferencesStorageService([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

/// Volatile storage for tests and previews.
class InMemoryStorageService implements LocalStorageService {
  InMemoryStorageService([Map<String, String>? initialValues])
    : _values = {...?initialValues};

  final Map<String, String> _values;

  /// When true, writes throw to simulate a storage failure.
  bool failWrites = false;

  Map<String, String> get values => Map.unmodifiable(_values);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('Simulated storage failure');
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async => _values.remove(key);
}

/// Prefixes every key so each user's data is stored separately.
class ScopedStorageService implements LocalStorageService {
  ScopedStorageService(this._inner, this._prefix);

  final LocalStorageService _inner;
  final String _prefix;

  @override
  Future<String?> read(String key) => _inner.read('$_prefix$key');

  @override
  Future<void> write(String key, String value) =>
      _inner.write('$_prefix$key', value);

  @override
  Future<void> remove(String key) => _inner.remove('$_prefix$key');
}
