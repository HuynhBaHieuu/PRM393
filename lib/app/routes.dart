import 'package:flutter/material.dart';

import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/features/collections/screens/collection_detail_screen.dart';
import 'package:all_fits/features/insights/screens/insights_screen.dart';
import 'package:all_fits/features/outfits/screens/outfit_builder_screen.dart';
import 'package:all_fits/features/outfits/screens/outfit_detail_screen.dart';
import 'package:all_fits/features/outfits/screens/swipe_outfit_screen.dart';
import 'package:all_fits/features/premium/premium_flows.dart';
import 'package:all_fits/features/premium/screens/premium_screen.dart';
import 'package:all_fits/features/profile/screens/archived_items_screen.dart';
import 'package:all_fits/features/profile/screens/favorites_screen.dart';
import 'package:all_fits/features/profile/screens/profile_screen.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/features/settings/screens/settings_screen.dart';
import 'package:all_fits/features/social/screens/discover_screen.dart';
import 'package:all_fits/features/social/screens/edit_profile_screen.dart';
import 'package:all_fits/features/social/screens/people_screens.dart';
import 'package:all_fits/features/social/screens/style_outfit_screen.dart';
import 'package:all_fits/features/social/screens/styled_together_screen.dart';
import 'package:all_fits/features/social/screens/user_profile_screen.dart';
import 'package:all_fits/features/stylist/screens/stylist_screen.dart';
import 'package:all_fits/data/models/try_on.dart';
import 'package:all_fits/features/try_on/screens/try_on_clothes_screen.dart';
import 'package:all_fits/features/try_on/screens/try_on_profile_screen.dart';
import 'package:all_fits/features/try_on/screens/try_on_screen.dart';
import 'package:all_fits/features/try_on/try_on_flows.dart';
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
  static const String collectionDetail = '/collections/detail';
  static const String insights = '/insights';
  static const String favorites = '/favorites';
  static const String archived = '/archived';
  static const String settings = '/settings';
  static const String stylist = '/stylist';
  static const String premium = '/premium';
  static const String account = '/account';
  static const String editProfile = '/profile/edit';
  static const String connections = '/profile/connections';
  static const String blockedUsers = '/profile/blocked';
  static const String notifications = '/notifications';
  static const String userSearch = '/users/search';
  static const String userProfile = '/users/profile';
  static const String styleFor = '/users/style';
  static const String styledTogether = '/styled';
  static const String styledOutfit = '/styled/detail';
  static const String discover = '/discover';
  static const String publicOutfit = '/discover/outfit';
  static const String tryOn = '/try-on';
  static const String tryOnProfile = '/try-on/profile';
  static const String tryOnClothes = '/try-on/clothes';

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
      AppRoutes.collectionDetail when args is String => CollectionDetailScreen(
        collectionId: args,
      ),
      AppRoutes.insights => const InsightsScreen(),
      AppRoutes.favorites => const FavoritesScreen(),
      AppRoutes.archived => const ArchivedItemsScreen(),
      AppRoutes.settings => const SettingsScreen(),
      AppRoutes.stylist => const StylistScreen(),
      AppRoutes.premium => const PremiumScreen(),
      AppRoutes.account => const ProfileScreen(),
      AppRoutes.editProfile => const EditProfileScreen(),
      AppRoutes.connections => ConnectionsScreen(
        initialTab: args is ConnectionsTab ? args : ConnectionsTab.followers,
      ),
      AppRoutes.blockedUsers => const BlockedUsersScreen(),
      AppRoutes.notifications => const NotificationsScreen(),
      AppRoutes.userSearch => const UserSearchScreen(),
      AppRoutes.userProfile when args is String => UserProfileScreen(
        userId: args,
      ),
      AppRoutes.styleFor when args is SocialProfile => StyleOutfitScreen(
        recipient: args,
      ),
      AppRoutes.styledTogether => StyledTogetherScreen(showByYou: args == true),
      AppRoutes.styledOutfit when args is String => StyledOutfitScreen(
        styledId: args,
      ),
      AppRoutes.discover => const DiscoverScreen(),
      AppRoutes.publicOutfit when args is (FeedPost, bool) =>
        PublicOutfitScreen(post: args.$1, fromFeed: args.$2),
      AppRoutes.tryOn when args is TryOnArgs => TryOnScreen(args: args),
      AppRoutes.tryOnClothes when args is TryOnArgs => TryOnClothesScreen(
        args: args,
      ),
      AppRoutes.tryOnProfile => TryOnProfileScreen(onboarding: args == true),
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

  static Future<void> collectionDetail(
    BuildContext context,
    String collectionId,
  ) =>
      Navigator.of(context)
          .pushNamed(AppRoutes.collectionDetail, arguments: collectionId);

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

  static Future<void> editProfile(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.editProfile);

  static Future<void> connections(
    BuildContext context, [
    ConnectionsTab tab = ConnectionsTab.followers,
  ]) => Navigator.of(context).pushNamed(AppRoutes.connections, arguments: tab);

  static Future<void> blockedUsers(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.blockedUsers);

  static Future<void> notifications(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.notifications);

  static Future<void> userSearch(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.userSearch);

  static Future<void> userProfile(BuildContext context, String userId) =>
      Navigator.of(context).pushNamed(AppRoutes.userProfile, arguments: userId);

  static Future<void> styleFor(BuildContext context, SocialProfile recipient) =>
      Navigator.of(context).pushNamed(AppRoutes.styleFor, arguments: recipient);

  static Future<void> styledTogether(
    BuildContext context, {
    bool showByYou = false,
  }) =>
      Navigator.of(context)
          .pushNamed(AppRoutes.styledTogether, arguments: showByYou);

  static Future<void> styledOutfit(BuildContext context, String id) =>
      Navigator.of(context).pushNamed(AppRoutes.styledOutfit, arguments: id);

  static Future<void> discover(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.discover);

  /// Prefer [TryOnFlows.start], which asks for consent first.
  static Future<void> tryOn(BuildContext context, TryOnArgs args) =>
      Navigator.of(context).pushNamed(AppRoutes.tryOn, arguments: args);

  /// Prefer [TryOnFlows.start], which asks for consent first.
  static Future<void> tryOnClothes(BuildContext context, TryOnArgs args) =>
      Navigator.of(context).pushNamed(AppRoutes.tryOnClothes, arguments: args);

  /// During [onboarding], resolves to who wears the outfit once the user
  /// agrees, or null.
  static Future<TryOnWearer?> tryOnProfile(
    BuildContext context, {
    bool onboarding = false,
  }) async {
    final result = await Navigator.of(context)
        .pushNamed<Object?>(AppRoutes.tryOnProfile, arguments: onboarding);
    return result is TryOnWearer ? result : null;
  }

  /// Resolves to true when the post changed (saved, unsaved, owner blocked).
  static Future<bool> publicOutfit(
    BuildContext context,
    FeedPost post, {
    bool fromFeed = true,
  }) async {
    final result = await Navigator.of(
      context,
    ).pushNamed<Object?>(AppRoutes.publicOutfit, arguments: (post, fromFeed));
    return result == true;
  }
}
