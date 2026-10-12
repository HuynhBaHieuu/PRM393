import 'dart:developer' as developer;

import 'package:all_fits/data/models/user_account.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// Loads the signed-in user's data before the main UI is shown.
class AppBootstrap {
  AppBootstrap({
    required this.user,
    required this.settings,
    required this.wardrobe,
    required this.outfits,
    required this.planner,
    required this.closet,
    required this.seedSampleData,
  });

  final AppUser user;
  final SettingsController settings;
  final WardrobeController wardrobe;
  final OutfitController outfits;
  final PlannerController planner;
  final ClosetActions closet;
  final bool seedSampleData;

  Future<void> run() async {
    await Future.wait([
      settings.load(),
      wardrobe.load(),
      outfits.load(),
      planner.load(),
    ]);
    if (settings.displayName.isEmpty && settings.username.isEmpty) {
      // A new account starts with the name and handle given at sign-up.
      await settings.updateProfile(
        displayName: user.displayName,
        username: user.email.split('@').first,
      );
    }
    if (seedSampleData && !settings.settings.hasSeededSampleData) {
      try {
        await closet.loadSampleData();
        await settings.markSampleDataSeeded();
      } catch (error) {
        // Sample data is optional; never block startup on it.
        developer.log('Sample data skipped', name: 'bootstrap', error: error);
      }
    }
  }
}
