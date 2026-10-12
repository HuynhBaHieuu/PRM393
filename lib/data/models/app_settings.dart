import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/utils/json_reader.dart';

enum ThemePreference {
  system('System'),
  light('Light'),
  dark('Dark');

  const ThemePreference(this.label);

  final String label;
}

class AppSettings {
  const AppSettings({
    this.displayName = '',
    this.username = '',
    this.themePreference = ThemePreference.system,
    this.currencySymbol = AppConfig.defaultCurrencySymbol,
    this.hasSeededSampleData = false,
  });

  factory AppSettings.fromJson(JsonMap json) {
    return AppSettings(
      displayName: JsonReader.nonEmptyString(json, 'displayName') ?? '',
      username: JsonReader.nonEmptyString(json, 'username') ?? '',
      themePreference:
          JsonReader.enumValue(ThemePreference.values, json['theme']) ??
          ThemePreference.system,
      currencySymbol:
          JsonReader.nonEmptyString(json, 'currencySymbol') ??
          AppConfig.defaultCurrencySymbol,
      hasSeededSampleData: JsonReader.boolean(json, 'hasSeededSampleData'),
    );
  }

  final String displayName;
  final String username;
  final ThemePreference themePreference;
  final String currencySymbol;
  final bool hasSeededSampleData;

  JsonMap toJson() => {
    'displayName': displayName,
    'username': username,
    'theme': themePreference.name,
    'currencySymbol': currencySymbol,
    'hasSeededSampleData': hasSeededSampleData,
  };

  AppSettings copyWith({
    String? displayName,
    String? username,
    ThemePreference? themePreference,
    String? currencySymbol,
    bool? hasSeededSampleData,
  }) {
    return AppSettings(
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      themePreference: themePreference ?? this.themePreference,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      hasSeededSampleData: hasSeededSampleData ?? this.hasSeededSampleData,
    );
  }
}
