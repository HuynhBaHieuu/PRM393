import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/json_reader.dart';
import 'package:all_fits/data/models/weather.dart';

abstract interface class WeatherService {
  /// Best match for a city name, or null when nothing matches.
  Future<WeatherLocation?> findCity(String name);

  Future<WeatherReport> today(WeatherLocation location);

  /// The city the device seems to be in, from its internet address; null
  /// when it can't be told.
  Future<WeatherLocation?> locate();
}

/// Weather from Open-Meteo (open-meteo.com): free and needs no API key.
/// Only the chosen city's coordinates are sent. Until the user picks a city,
/// [locate] asks ipwho.is (free, no key) for the city of the device's
/// internet address, so no location permission is needed.
class OpenMeteoWeatherService implements WeatherService {
  const OpenMeteoWeatherService({this._clock = DateTime.now});

  final DateTime Function() _clock;

  static const Duration _timeout = Duration(seconds: 15);
  static const String _unavailable =
      'Weather is unavailable right now. Check your connection.';

  @override
  Future<WeatherLocation?> findCity(String name) async {
    final query = name.trim();
    if (query.isEmpty) return null;
    final json = await _getJson(
      Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': query,
        'count': '1',
      }),
    );
    final results = json['results'];
    if (results is! List || results.isEmpty) return null;
    return WeatherLocation.tryFromJson(results.first);
  }

  @override
  Future<WeatherLocation?> locate() async {
    final json = await _getJson(Uri.https('ipwho.is', '/'));
    if (json['success'] != true) return null;
    return WeatherLocation.tryFromJson({
      'name': json['city'],
      'latitude': json['latitude'],
      'longitude': json['longitude'],
      'country': json['country'],
    });
  }

  @override
  Future<WeatherReport> today(WeatherLocation location) async {
    final json = await _getJson(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '${location.latitude}',
        'longitude': '${location.longitude}',
        'current': 'temperature_2m,weather_code',
        'daily':
            'temperature_2m_max,temperature_2m_min,'
            'precipitation_probability_max',
        'timezone': 'auto',
        'forecast_days': '1',
      }),
    );
    try {
      final current = Map<String, dynamic>.from(json['current'] as Map);
      final daily = Map<String, dynamic>.from(json['daily'] as Map);
      double first(String key) =>
          ((daily[key] as List).first as num).toDouble();
      final temperature = JsonReader.decimal(current, 'temperature_2m')!;
      final rain = (daily['precipitation_probability_max'] as List).first;
      return WeatherReport(
        location: location,
        temperature: temperature,
        high: first('temperature_2m_max'),
        low: first('temperature_2m_min'),
        condition: WeatherCondition.fromCode(
          JsonReader.integer(current, 'weather_code'),
        ),
        rainChance: rain is num ? rain.round().clamp(0, 100) : 0,
        fetchedAt: _clock(),
      );
    } catch (_) {
      throw const WeatherException(_unavailable);
    }
  }

  Future<JsonMap> _getJson(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(_timeout);
      final response = await request.close().timeout(_timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw const WeatherException(_unavailable);
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) throw const WeatherException(_unavailable);
      return Map<String, dynamic>.from(decoded);
    } on WeatherException {
      rethrow;
    } catch (_) {
      // Offline, timeouts and unreadable replies all read the same to users.
      throw const WeatherException(_unavailable);
    } finally {
      client.close(force: true);
    }
  }
}
