import 'dart:developer' as developer;

import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, SupabaseClient;

import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/data/local/image_picker_service.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/local/password_hasher.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';
import 'package:all_fits/data/remote/supabase_backend.dart';
import 'package:all_fits/data/remote/weather_service.dart';
import 'package:all_fits/data/repositories/auth_repository.dart';
import 'package:all_fits/data/repositories/calendar_repository.dart';
import 'package:all_fits/data/repositories/outfit_repository.dart';
import 'package:all_fits/data/repositories/settings_repository.dart';
import 'package:all_fits/data/repositories/shopping_repository.dart';
import 'package:all_fits/data/repositories/wardrobe_repository.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/outfit_calendar_entry.dart';
import 'package:all_fits/data/models/shopping_item.dart';

/// Composition root for services and repositories. With [supabase] set,
/// accounts and per-user data live on the server; otherwise on the device.
class AppDependencies {
  AppDependencies({
    required this.storage,
    required this.imageStorage,
    required this.imagePicker,
    this.idGenerator = const UuidIdGenerator(),
    this.clock = systemClock,
    this.seedSampleData = AppConfig.seedSampleDataOnFirstLaunch,
    this.aiStylist = const AiStylistService(apiKey: ''),
    this.weather = const OpenMeteoWeatherService(),
    this.supabase,
    PasswordHasher passwordHasher = const Pbkdf2PasswordHasher(),
  }) : authRepository = supabase != null
           ? SupabaseAuthRepository(supabase.auth, storage)
           : LocalAuthRepository(
               storage,
               hasher: passwordHasher,
               idGenerator: idGenerator,
               clock: clock,
             );

  static Future<AppDependencies> production() async {
    final env = await _loadEnv();
    final config = supabaseConfigFrom(env);
    final SupabaseClient? supabase;
    final ImageStorageService imageStorage;
    if (config != null) {
      supabase = (await Supabase.initialize(
        url: config.url,
        publishableKey: config.key,
      )).client;
      imageStorage = SupabaseImageStorageService(supabase);
    } else {
      supabase = null;
      final local = LocalImageStorageService();
      await local.init();
      imageStorage = local;
    }
    return AppDependencies(
      storage: SharedPreferencesStorageService(),
      imageStorage: imageStorage,
      imagePicker: DeviceImagePickerService(),
      aiStylist: AiStylistService.fromConfig(env),
      supabase: supabase,
    );
  }

  /// Contents of `assets/env.json`, or `{}` when this build has none: the AI
  /// stylist stays switched off and data stays on the device.
  static Future<String> _loadEnv() async {
    try {
      return await rootBundle.loadString(AiStylistService.configAsset);
    } catch (_) {
      return '{}';
    }
  }

  /// Device-wide storage; per-user data goes through [repositoriesFor].
  final LocalStorageService storage;
  final ImageStorageService imageStorage;
  final ImagePickerService imagePicker;
  final IdGenerator idGenerator;
  final Clock clock;
  final bool seedSampleData;
  final AiStylistService aiStylist;
  final WeatherService weather;
  final SupabaseClient? supabase;
  final AuthRepository authRepository;

  /// Repositories whose data belongs to [userId] only.
  UserRepositories repositoriesFor(String userId) {
    final client = supabase;
    if (client != null) {
      SupabaseCollectionStore<T> store<T>(
        String table,
        T Function(Map<String, dynamic>) fromJson,
        Map<String, dynamic> Function(T) toJson,
        String Function(T) idOf,
      ) => SupabaseCollectionStore<T>(
        client: client,
        table: table,
        userId: userId,
        fromJson: fromJson,
        toJson: toJson,
        idOf: idOf,
      );
      return UserRepositories(
        wardrobe: LocalWardrobeRepository.fromStore(
          store(
            'clothing_items',
            ClothingItem.fromJson,
            (i) => i.toJson(),
            (i) => i.id,
          ),
        ),
        outfits: LocalOutfitRepository.fromStore(
          store('outfits', Outfit.fromJson, (o) => o.toJson(), (o) => o.id),
        ),
        calendar: LocalCalendarRepository.fromStore(
          store(
            'calendar_entries',
            OutfitCalendarEntry.fromJson,
            (e) => e.toJson(),
            (e) => e.id,
          ),
        ),
        settings: SupabaseSettingsRepository(client, userId),
        shopping: LocalShoppingRepository.fromStore(
          store(
            'shopping_items',
            ShoppingItem.fromJson,
            (i) => i.toJson(),
            (i) => i.id,
          ),
        ),
      );
    }
    final scoped = ScopedStorageService(storage, StorageKeys.userScope(userId));
    return UserRepositories(
      wardrobe: LocalWardrobeRepository(scoped),
      outfits: LocalOutfitRepository(scoped),
      calendar: LocalCalendarRepository(scoped),
      settings: LocalSettingsRepository(scoped),
      shopping: LocalShoppingRepository(scoped),
    );
  }

  /// Gives data created before accounts existed to [userId]. Runs at most
  /// once per device, so only the first account ever registered gets it.
  Future<void> adoptLegacyData(String userId) async {
    if (supabase != null) return;
    try {
      if (await storage.read(StorageKeys.legacyDataAdopted) != null) return;
      final prefix = StorageKeys.userScope(userId);
      for (final key in StorageKeys.userDataKeys) {
        final value = await storage.read(key);
        if (value == null) continue;
        await storage.write('$prefix$key', value);
        await storage.remove(key);
      }
      await storage.write(StorageKeys.legacyDataAdopted, userId);
    } catch (error) {
      // Losing old demo data must never block registration.
      developer.log('Legacy data not adopted', name: 'auth', error: error);
    }
  }
}

class UserRepositories {
  const UserRepositories({
    required this.wardrobe,
    required this.outfits,
    required this.calendar,
    required this.settings,
    required this.shopping,
  });

  final WardrobeRepository wardrobe;
  final OutfitRepository outfits;
  final CalendarRepository calendar;
  final SettingsRepository settings;
  final ShoppingRepository shopping;
}
