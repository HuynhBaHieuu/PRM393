import 'dart:convert';
import 'dart:developer' as developer;

import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/app_settings.dart';

abstract interface class SettingsRepository {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}

class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository(this._storage);

  final LocalStorageService _storage;

  @override
  Future<AppSettings> load() async {
    try {
      final raw = await _storage.read(StorageKeys.settings);
      if (raw == null || raw.isEmpty) return const AppSettings();
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AppSettings.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (error) {
      // Corrupt settings fall back to defaults rather than blocking startup.
      developer.log('Settings unreadable', name: 'storage', error: error);
    }
    return const AppSettings();
  }

  @override
  Future<void> save(AppSettings settings) async {
    try {
      await _storage.write(StorageKeys.settings, jsonEncode(settings.toJson()));
    } catch (error) {
      developer.log('Failed to save settings', name: 'storage', error: error);
      throw const StorageException();
    }
  }
}
