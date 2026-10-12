import 'dart:developer' as developer;

import 'package:flutter/services.dart' show rootBundle;

import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/data/local/image_picker_service.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/local/password_hasher.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';
import 'package:all_fits/data/repositories/auth_repository.dart';
import 'package:all_fits/data/repositories/calendar_repository.dart';
import 'package:all_fits/data/repositories/outfit_repository.dart';
import 'package:all_fits/data/repositories/settings_repository.dart';
import 'package:all_fits/data/repositories/wardrobe_repository.dart';

/// Composition root for services and repositories. Swap implementations
/// here to move to a remote backend (Firebase, Supabase, ...) later.
class AppDependencies {
  AppDependencies({
    required this.storage,
    required this.imageStorage,
    required this.imagePicker,
    this.idGenerator = const UuidIdGenerator(),
    this.clock = systemClock,
    this.seedSampleData = AppConfig.seedSampleDataOnFirstLaunch,
    this.aiStylist = const AiStylistService(apiKey: ''),
    PasswordHasher passwordHasher = const Pbkdf2PasswordHasher(),
  }) : authRepository = LocalAuthRepository(
         storage,
         hasher: passwordHasher,
         idGenerator: idGenerator,
         clock: clock,
       );

  static Future<AppDependencies> production() async {
    final imageStorage = LocalImageStorageService();
    await imageStorage.init();
    return AppDependencies(
      storage: SharedPreferencesStorageService(),
      imageStorage: imageStorage,
      imagePicker: DeviceImagePickerService(),
      aiStylist: await _loadAiStylist(),
    );
  }

  static Future<AiStylistService> _loadAiStylist() async {
    try {
      return AiStylistService.fromConfig(
        await rootBundle.loadString(AiStylistService.configAsset),
      );
    } catch (_) {
      // No config file in this build: the stylist stays switched off.
      return const AiStylistService(apiKey: '');
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
  final AuthRepository authRepository;

  /// Repositories whose data belongs to [userId] only.
  UserRepositories repositoriesFor(String userId) {
    final scoped = ScopedStorageService(storage, StorageKeys.userScope(userId));
    return UserRepositories(
      wardrobe: LocalWardrobeRepository(scoped),
      outfits: LocalOutfitRepository(scoped),
      calendar: LocalCalendarRepository(scoped),
      settings: LocalSettingsRepository(scoped),
    );
  }

  /// Gives data created before accounts existed to [userId]. Runs at most
  /// once per device, so only the first account ever registered gets it.
  Future<void> adoptLegacyData(String userId) async {
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
  });

  final WardrobeRepository wardrobe;
  final OutfitRepository outfits;
  final CalendarRepository calendar;
  final SettingsRepository settings;
}
