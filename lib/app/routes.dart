import 'package:flutter/material.dart';

import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/features/insights/screens/insights_screen.dart';
import 'package:all_fits/features/outfits/screens/outfit_builder_screen.dart';
import 'package:all_fits/features/outfits/screens/outfit_detail_screen.dart';
import 'package:all_fits/features/profile/screens/archived_items_screen.dart';
import 'package:all_fits/features/profile/screens/favorites_screen.dart';
import 'package:all_fits/features/settings/screens/settings_screen.dart';
import 'package:all_fits/features/stylist/screens/stylist_screen.dart';
import 'package:all_fits/features/wardrobe/screens/clothing_detail_screen.dart';
import 'package:all_fits/features/wardrobe/screens/clothing_form_screen.dart';

abstract final class AppRoutes {
  static const String addClothing = '/clothing/new';
  static const String editClothing = '/clothing/edit';
  static const String clothingDetail = '/clothing/detail';
  static const String outfitBuilder = '/outfits/builder';
  static const String outfitDetail = '/outfits/detail';
  static const String insights = '/insights';
  static const String favorites = '/favorites';
  static const String archived = '/archived';
  static const String settings = '/settings';
  static const String stylist = '/stylist';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;
    final Widget page = switch (settings.name) {
      AppRoutes.addClothing => const ClothingFormScreen(),
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
      AppRoutes.insights => const InsightsScreen(),
      AppRoutes.favorites => const FavoritesScreen(),
      AppRoutes.archived => const ArchivedItemsScreen(),
      AppRoutes.settings => const SettingsScreen(),
      AppRoutes.stylist => const StylistScreen(),
      _ => const NotFoundView(),
    };
    final isModalForm =
        settings.name == AppRoutes.addClothing ||
        settings.name == AppRoutes.editClothing ||
        settings.name == AppRoutes.outfitBuilder ||
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
  /// Resolves to the new item's id when an item was saved.
  static Future<String?> addClothing(BuildContext context) async {
    // Routes are built as Route<dynamic>, so push untyped and narrow after.
    final result = await Navigator.of(context)
        .pushNamed<Object?>(AppRoutes.addClothing);
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
}
