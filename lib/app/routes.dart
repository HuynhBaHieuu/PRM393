import 'package:flutter/material.dart';

import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/features/insights/screens/insights_screen.dart';
import 'package:all_fits/features/outfits/screens/outfit_builder_screen.dart';
import 'package:all_fits/features/outfits/screens/outfit_detail_screen.dart';
import 'package:all_fits/features/outfits/screens/swipe_outfit_screen.dart';
import 'package:all_fits/features/premium/premium_flows.dart';
import 'package:all_fits/features/premium/screens/premium_screen.dart';
import 'package:all_fits/features/profile/screens/archived_items_screen.dart';
import 'package:all_fits/features/profile/screens/favorites_screen.dart';
import 'package:all_fits/features/profile/screens/profile_screen.dart';
import 'package:all_fits/features/settings/screens/settings_screen.dart';
import 'package:all_fits/features/stylist/screens/stylist_screen.dart';
import 'package:all_fits/features/wardrobe/controllers/clothing_draft.dart';
import 'package:all_fits/features/wardrobe/screens/clothing_detail_screen.dart';
import 'package:all_fits/features/wardrobe/screens/clothing_form_screen.dart';

abstract final class AppRoutes {
  static const String addClothing = '/clothing/new';
  static const String editClothing = '/clothing/edit';
  static const String clothingDetail = '/clothing/detail';
  static const String outfitBuilder = '/outfits/builder';
  static const String outfitDetail = '/outfits/detail';
  static const String swipeOutfit = '/outfits/swipe';
  static const String insights = '/insights';
  static const String favorites = '/favorites';
  static const String archived = '/archived';
  static const String settings = '/settings';
  static const String stylist = '/stylist';
  static const String premium = '/premium';
  static const String account = '/account';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;
    final Widget page = switch (settings.name) {
      AppRoutes.addClothing => ClothingFormScreen(
        initial: args is ClothingDraft ? args : null,
      ),
      AppRoutes.editClothing when args is String => ClothingFormScreen(
        itemId: args,
      ),
      AppRoutes.clothingDetail when args is String => ClothingDetailScreen(
        itemId: args,
      ),
      AppRoutes.outfitBuilder => OutfitBuilderScreen(
        args: args is OutfitBuilderArgs ? args : const OutfitBuilderArgs(),
      ),
      AppRoutes.outfitDetail when args is String => OutfitDetailScreen(
        outfitId: args,
      ),
      AppRoutes.swipeOutfit => const SwipeOutfitScreen(),
      AppRoutes.insights => const InsightsScreen(),
      AppRoutes.favorites => const FavoritesScreen(),
      AppRoutes.archived => const ArchivedItemsScreen(),
      AppRoutes.settings => const SettingsScreen(),
      AppRoutes.stylist => const StylistScreen(),
      AppRoutes.premium => const PremiumScreen(),
      AppRoutes.account => const ProfileScreen(),
      _ => const NotFoundView(),
    };
    final isModalForm =
        settings.name == AppRoutes.addClothing ||
        settings.name == AppRoutes.editClothing ||
        settings.name == AppRoutes.outfitBuilder ||
        settings.name == AppRoutes.swipeOutfit ||
        settings.name == AppRoutes.stylist;
    return MaterialPageRoute<dynamic>(
      settings: settings,
      fullscreenDialog: isModalForm,
      builder: (_) => page,
    );
  }
}

/// Typed navigation helpers so call sites never build route strings.
abstract final class AppNavigator {
  /// Resolves to the new item's id when an item was saved. On a full Free
  /// wardrobe it explains the limit instead and resolves to null.
  static Future<String?> addClothing(
    BuildContext context, {
    ClothingDraft? initial,
  }) async {
    if (!PremiumFlows.canAddClothing(context)) {
      await PremiumFlows.showWardrobeLimit(context);
      return null;
    }
    // Routes are built as Route<dynamic>, so push untyped and narrow after.
    final result = await Navigator.of(context)
        .pushNamed<Object?>(AppRoutes.addClothing, arguments: initial);
    return result is String ? result : null;
  }

  static Future<void> editClothing(BuildContext context, String itemId) =>
      Navigator.of(context)
          .pushNamed(AppRoutes.editClothing, arguments: itemId);

  static Future<void> clothingDetail(BuildContext context, String itemId) =>
      Navigator.of(context)
          .pushNamed(AppRoutes.clothingDetail, arguments: itemId);

  static Future<void> createOutfit(
    BuildContext context, {
    List<String> initialItemIds = const [],
  }) => Navigator.of(context).pushNamed(
    AppRoutes.outfitBuilder,
    arguments: OutfitBuilderArgs(initialItemIds: initialItemIds),
  );

  static Future<void> editOutfit(BuildContext context, String outfitId) =>
      Navigator.of(context).pushNamed(
        AppRoutes.outfitBuilder,
        arguments: OutfitBuilderArgs(outfitId: outfitId),
      );

  static Future<void> swipeOutfit(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.swipeOutfit);

  static Future<void> outfitDetail(BuildContext context, String outfitId) =>
      Navigator.of(context)
          .pushNamed(AppRoutes.outfitDetail, arguments: outfitId);

  static Future<void> insights(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.insights);

  static Future<void> favorites(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.favorites);

  static Future<void> archived(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.archived);

  static Future<void> settings(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.settings);

  static Future<void> stylist(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.stylist);

  static Future<void> premium(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.premium);

  static Future<void> account(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.account);
}
