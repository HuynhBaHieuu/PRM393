import 'package:all_fits/core/utils/json_reader.dart';

/// A place the user gets weather for, chosen by city name.
class WeatherLocation {
  const WeatherLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.country,
  });

  /// Returns null when the coordinates are missing.
  static WeatherLocation? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final name = JsonReader.nonEmptyString(json, 'name');
    final latitude = JsonReader.decimal(json, 'latitude');
    final longitude = JsonReader.decimal(json, 'longitude');
    if (name == null || latitude == null || longitude == null) return null;
    return WeatherLocation(
      name: name,
      latitude: latitude,
      longitude: longitude,
      country: JsonReader.nonEmptyString(json, 'country'),
    );
  }

  final String name;
  final double latitude;
  final double longitude;
  final String? country;

  /// "Hanoi, Vietnam"
  String get label => country == null ? name : '$name, $country';

  JsonMap toJson() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'country': country,
  };

  @override
  bool operator ==(Object other) =>
      other is WeatherLocation &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

enum WeatherCondition {
  clear('Clear'),
  cloudy('Cloudy'),
  fog('Foggy'),
  rain('Rain'),
  snow('Snow'),
  storm('Storm');

  const WeatherCondition(this.label);

  final String label;

  /// Maps a WMO weather code, as used by Open-Meteo.
  static WeatherCondition fromCode(int code) => switch (code) {
    0 || 1 => WeatherCondition.clear,
    2 || 3 => WeatherCondition.cloudy,
    45 || 48 => WeatherCondition.fog,
    >= 71 && <= 77 || 85 || 86 => WeatherCondition.snow,
    >= 95 => WeatherCondition.storm,
    _ => WeatherCondition.rain,
  };

  bool get isWet =>
      this == WeatherCondition.rain ||
      this == WeatherCondition.snow ||
      this == WeatherCondition.storm;
}

/// The forecast for one day. Temperatures are in °C.
class DayForecast {
  const DayForecast({
    required this.date,
    required this.high,
    required this.low,
    required this.condition,
    required this.rainChance,
  });

  /// The day, without a time.
  final DateTime date;
  final double high;
  final double low;
  final WeatherCondition condition;

  /// Highest chance of precipitation that day, 0-100.
  final int rainChance;
}

/// Today's weather for one location. Temperatures are in °C.
class WeatherReport {
  const WeatherReport({
    required this.location,
    required this.temperature,
    required this.high,
    required this.low,
    required this.condition,
    required this.rainChance,
    required this.fetchedAt,
  });

  final WeatherLocation location;
  final double temperature;
  final double high;
  final double low;
  final WeatherCondition condition;

  /// Highest chance of precipitation today, 0-100.
  final int rainChance;
  final DateTime fetchedAt;
}
