import 'package:flutter/material.dart';

import 'package:all_fits/core/extensions/string_extensions.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/data/models/app_settings.dart';
import 'package:all_fits/data/models/subscription_plan.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/data/repositories/settings_repository.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({required this._repository, this._clock = systemClock});

  final SettingsRepository _repository;
  final Clock _clock;

  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;

  String get displayName => _settings.displayName;

  String get username => _settings.username;

  String get currencySymbol => _settings.currencySymbol;

  SubscriptionPlan get plan => _settings.plan;

  bool get isPremium => _settings.plan.isPremium;

  WeatherLocation? get weatherLocation => _settings.weatherLocation;

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

  /// Simulated checkout: switches to Premium without taking a payment.
  Future<void> startPremium() {
    if (isPremium) return Future.value();
    return _update(
      _settings.copyWith(
        plan: SubscriptionPlan.premium,
        premiumSince: _clock(),
      ),
    );
  }

  Future<void> cancelPremium() => _update(
    _settings.copyWith(plan: SubscriptionPlan.free, premiumSince: null),
  );

  Future<void> setWeatherLocation(WeatherLocation? location) =>
      _update(_settings.copyWith(weatherLocation: location));

  Future<void> markSampleDataSeeded() =>
      _update(_settings.copyWith(hasSeededSampleData: true));

  Future<void> _update(AppSettings next) async {
    await _repository.save(next);
    _settings = next;
    notifyListeners();
  }
}
