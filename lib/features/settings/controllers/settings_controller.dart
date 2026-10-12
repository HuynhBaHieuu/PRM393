import 'package:flutter/material.dart';

import 'package:all_fits/core/extensions/string_extensions.dart';
import 'package:all_fits/data/models/app_settings.dart';
import 'package:all_fits/data/repositories/settings_repository.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({required this._repository});

  final SettingsRepository _repository;

  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;

  String get displayName => _settings.displayName;

  String get username => _settings.username;

  String get currencySymbol => _settings.currencySymbol;

  ThemeMode get themeMode => switch (_settings.themePreference) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };

  Future<void> load() async {
    _settings = await _repository.load();
    notifyListeners();
  }

  Future<void> updateProfile({String? displayName, String? username}) {
    return _update(
      _settings.copyWith(
        displayName: displayName?.trim(),
        username: username?.trim().replaceAll('@', '').replaceAll(' ', ''),
      ),
    );
  }

  Future<void> setThemePreference(ThemePreference preference) =>
      _update(_settings.copyWith(themePreference: preference));

  Future<void> setCurrencySymbol(String symbol) {
    final value = symbol.trimmedOrNull;
    if (value == null) return Future.value();
    return _update(_settings.copyWith(currencySymbol: value));
  }

  Future<void> markSampleDataSeeded() =>
      _update(_settings.copyWith(hasSeededSampleData: true));

  Future<void> _update(AppSettings next) async {
    await _repository.save(next);
    _settings = next;
    notifyListeners();
  }
}
