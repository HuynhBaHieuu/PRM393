import 'package:flutter/foundation.dart';

import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/core/utils/load_status.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/data/remote/weather_service.dart';

/// Today's weather for the user's chosen city.
class WeatherController extends ChangeNotifier {
  WeatherController({required this._service, this._clock = systemClock});

  final WeatherService _service;
  final Clock _clock;

  LoadStatus _status = LoadStatus.idle;
  Object? _error;
  WeatherReport? _report;
  WeatherLocation? _requested;

  LoadStatus get status => _status;
  Object? get error => _error;
  WeatherReport? get report => _report;

  /// True when [location]'s weather hasn't been loaded or has gone stale.
  /// A failed load is not retried automatically; see [refresh].
  bool needsRefresh(WeatherLocation location) {
    if (location != _requested) return true;
    if (_status != LoadStatus.ready) return false;
    final fetched = _report?.fetchedAt;
    return fetched == null ||
        _clock().difference(fetched) > AppConfig.weatherMaxAge;
  }

  Future<void> refresh(WeatherLocation location) async {
    _requested = location;
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final report = await _service.today(location);
      if (_requested != location) return; // The city changed meanwhile.
      _report = report;
      _status = LoadStatus.ready;
    } catch (error) {
      if (_requested != location) return;
      _error = error;
      _status = LoadStatus.failure;
    }
    notifyListeners();
  }

  Future<WeatherLocation?> findCity(String name) => _service.findCity(name);

  bool _locateTried = false;

  /// The device's city from its internet address, looked up once per
  /// session; null when unknown or already tried. Never throws.
  Future<WeatherLocation?> locateOnce() async {
    if (_locateTried) return null;
    _locateTried = true;
    try {
      return await _service.locate();
    } catch (_) {
      return null;
    }
  }
}
