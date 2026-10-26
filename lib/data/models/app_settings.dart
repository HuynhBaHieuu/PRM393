import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/utils/json_reader.dart';
import 'package:all_fits/data/models/outfit_create_mode.dart';
import 'package:all_fits/data/models/subscription_plan.dart';
import 'package:all_fits/data/models/weather.dart';

const Object _unset = Object();

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
    this.plan = SubscriptionPlan.free,
    this.premiumSince,
    this.premiumUntil,
    this.weatherLocation,
    this.outfitMode = OutfitCreateMode.collage,
    this.startsInProfile = false,
    this.dailyReminder = false,
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
      plan:
          JsonReader.enumValue(SubscriptionPlan.values, json['plan']) ??
          SubscriptionPlan.free,
      premiumSince: JsonReader.date(json, 'premiumSince'),
      premiumUntil: JsonReader.date(json, 'premiumUntil'),
      weatherLocation: WeatherLocation.tryFromJson(json['weatherLocation']),
      outfitMode:
          JsonReader.enumValue(OutfitCreateMode.values, json['outfitMode']) ??
          OutfitCreateMode.collage,
      startsInProfile: JsonReader.boolean(json, 'startsInProfile'),
      dailyReminder: JsonReader.boolean(json, 'dailyReminder'),
    );
  }

  final String displayName;
  final String username;
  final ThemePreference themePreference;
  final String currencySymbol;
  final bool hasSeededSampleData;
  final SubscriptionPlan plan;

  /// When the current Premium subscription started.
  final DateTime? premiumSince;

  /// When paid Premium ends; null for the device-only demo Premium.
  final DateTime? premiumUntil;

  /// City used for weather-based outfit picks.
  final WeatherLocation? weatherLocation;

  /// The default way "Add outfit" builds an outfit.
  final OutfitCreateMode outfitMode;

  /// "App starts in": the Profile tab instead of Home.
  final bool startsInProfile;

  /// A daily notification to log the outfit of the day.
  final bool dailyReminder;

  JsonMap toJson() => {
    'displayName': displayName,
    'username': username,
    'theme': themePreference.name,
    'currencySymbol': currencySymbol,
    'hasSeededSampleData': hasSeededSampleData,
    'plan': plan.name,
    'premiumSince': premiumSince?.toIso8601String(),
    'premiumUntil': premiumUntil?.toIso8601String(),
    'weatherLocation': weatherLocation?.toJson(),
    'outfitMode': outfitMode.name,
    'startsInProfile': startsInProfile,
    'dailyReminder': dailyReminder,
  };

  AppSettings copyWith({
    String? displayName,
    String? username,
    ThemePreference? themePreference,
    String? currencySymbol,
    bool? hasSeededSampleData,
    SubscriptionPlan? plan,
    Object? premiumSince = _unset,
    Object? premiumUntil = _unset,
    Object? weatherLocation = _unset,
    OutfitCreateMode? outfitMode,
    bool? startsInProfile,
    bool? dailyReminder,
  }) {
    return AppSettings(
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      themePreference: themePreference ?? this.themePreference,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      hasSeededSampleData: hasSeededSampleData ?? this.hasSeededSampleData,
      plan: plan ?? this.plan,
      premiumSince: identical(premiumSince, _unset)
          ? this.premiumSince
          : premiumSince as DateTime?,
      premiumUntil: identical(premiumUntil, _unset)
          ? this.premiumUntil
          : premiumUntil as DateTime?,
      weatherLocation: identical(weatherLocation, _unset)
          ? this.weatherLocation
          : weatherLocation as WeatherLocation?,
      outfitMode: outfitMode ?? this.outfitMode,
      startsInProfile: startsInProfile ?? this.startsInProfile,
      dailyReminder: dailyReminder ?? this.dailyReminder,
    );
  }
}
