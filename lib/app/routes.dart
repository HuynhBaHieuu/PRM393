import 'package:flutter/material.dart';

import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/features/collections/screens/collection_detail_screen.dart';
import 'package:all_fits/features/insights/screens/insights_screen.dart';
import 'package:all_fits/features/outfits/screens/outfit_builder_screen.dart';
import 'package:all_fits/features/outfits/screens/outfit_detail_screen.dart';
import 'package:all_fits/features/outfits/controllers/outfit_query.dart';
import 'package:all_fits/features/outfits/screens/outfit_pick_screen.dart';
import 'package:all_fits/features/outfits/screens/outfits_select_screen.dart';
import 'package:all_fits/features/outfits/screens/swipe_outfit_screen.dart';
import 'package:all_fits/features/planner/screens/planner_screen.dart';
import 'package:all_fits/features/premium/premium_flows.dart';
import 'package:all_fits/features/premium/screens/premium_screen.dart';
import 'package:all_fits/features/profile/screens/archived_items_screen.dart';
import 'package:all_fits/features/profile/screens/favorites_screen.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/features/settings/screens/settings_screen.dart';
import 'package:all_fits/features/social/screens/discover_screen.dart';
import 'package:all_fits/features/social/screens/edit_profile_screen.dart';
import 'package:all_fits/features/social/screens/people_screens.dart';
import 'package:all_fits/features/social/screens/style_outfit_screen.dart';
import 'package:all_fits/features/social/screens/styled_together_screen.dart';
import 'package:all_fits/features/social/screens/user_profile_screen.dart';
import 'package:all_fits/features/stylist/screens/stylist_screen.dart';
import 'package:all_fits/features/trips/screens/trip_detail_screen.dart';
import 'package:all_fits/features/trips/screens/trips_screen.dart';
import 'package:all_fits/data/models/try_on.dart';
import 'package:all_fits/features/try_on/screens/try_on_clothes_screen.dart';
import 'package:all_fits/features/try_on/screens/try_on_profile_screen.dart';
import 'package:all_fits/features/try_on/screens/try_on_screen.dart';
import 'package:all_fits/features/try_on/try_on_flows.dart';
import 'package:all_fits/features/wardrobe/controllers/clothing_draft.dart';
import 'package:all_fits/features/wardrobe/screens/clothing_detail_screen.dart';
import 'package:all_fits/features/wardrobe/screens/clothing_photos_screen.dart';
import 'package:all_fits/features/wardrobe/screens/clothing_form_screen.dart';
import 'package:all_fits/features/wardrobe/screens/clothes_select_screen.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_query.dart';

abstract final class AppRoutes {
  static const String addClothing = '/clothing/new';
  static const String addClothingFromLink = '/clothing/new/link';
  static const String editClothing = '/clothing/edit';
  static const String clothingDetail = '/clothing/detail';
  static const String clothingPhotos = '/clothing/photos';
  static const String outfitBuilder = '/outfits/builder';
  static const String outfitPick = '/outfits/new';
  static const String planner = '/planner';
  static const String selectClothes = '/clothing/select';
  static const String reorderClothes = '/clothing/reorder';
  static const String selectOutfits = '/outfits/select';
  static const String reorderOutfits = '/outfits/reorder';
  static const String outfitDetail = '/outfits/detail';
  static const String swipeOutfit = '/outfits/swipe';
  static const String collectionDetail = '/collections/detail';
  static const String trips = '/trips';
  static const String tripDetail = '/trips/detail';
  static const String insights = '/insights';
  static const String favorites = '/favorites';
  static const String archived = '/archived';
  static const String settings = '/settings';
  static const String stylist = '/stylist';
  static const String premium = '/premium';
  static const String dailyReminders = '/settings/reminders';
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
      AppRoutes.addClothingFromLink => const ClothingFormScreen(fromLink: true),
      AppRoutes.editClothing when args is String => ClothingFormScreen(
        itemId: args,
      ),
      AppRoutes.clothingDetail when args is String => ClothingDetailScreen(
        itemId: args,
      ),
      AppRoutes.clothingDetail when args is ClothingDetailArgs =>
        ClothingDetailScreen(itemId: args.itemId, siblings: args.siblings),
      AppRoutes.clothingPhotos when args is ClothingPhotosArgs =>
        ClothingPhotosScreen(
          itemId: args.itemId,
          initialIndex: args.initialIndex,
        ),
      AppRoutes.selectClothes => ClothesSelectScreen(
        query: args is WardrobeQuery ? args : const WardrobeQuery(),
      ),
      AppRoutes.reorderClothes => const ReorderClothesScreen(),
      AppRoutes.selectOutfits => OutfitsSelectScreen(
        query: args is OutfitQuery ? args : const OutfitQuery(),
      ),
      AppRoutes.reorderOutfits => const ReorderOutfitsScreen(),
      AppRoutes.outfitPick => OutfitPickScreen(
        initialItemIds: args is (List<String>, DateTime?) ? args.$1 : const [],
        planDate: args is (List<String>, DateTime?) ? args.$2 : null,
      ),
      AppRoutes.planner => const PlannerScreen(),
      AppRoutes.outfitBuilder => OutfitBuilderScreen(
        args: args is OutfitBuilderArgs ? args : const OutfitBuilderArgs(),
      ),
      AppRoutes.outfitDetail when args is String => OutfitDetailScreen(
        outfitId: args,
      ),
      AppRoutes.swipeOutfit => SwipeOutfitScreen(
        initialItemIds: args is (List<String>, DateTime?) ? args.$1 : const [],
        planDate: args is (List<String>, DateTime?) ? args.$2 : null,
      ),
      AppRoutes.collectionDetail when args is String => CollectionDetailScreen(
        collectionId: args,
      ),
      AppRoutes.trips => const TripsScreen(),
      AppRoutes.tripDetail when args is String => TripDetailScreen(
        tripId: args,
      ),
      AppRoutes.insights => const InsightsScreen(),
      AppRoutes.favorites => const FavoritesScreen(),
      AppRoutes.archived => const ArchivedItemsScreen(),
      AppRoutes.settings => const SettingsScreen(),
      AppRoutes.stylist => StylistScreen(
        launch: args is StylistLaunch ? args : null,
      ),
      AppRoutes.premium => const PremiumScreen(),
      AppRoutes.dailyReminders => const DailyRemindersScreen(),
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
        settings.name == AppRoutes.addClothingFromLink ||
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
    bool fromLink = false,
  }) async {
    if (!PremiumFlows.canAddClothing(context)) {
      await PremiumFlows.showWardrobeLimit(context);
      return null;
    }
    // Routes are built as Route<dynamic>, so push untyped and narrow after.
    final result = await Navigator.of(context).pushNamed<Object?>(
      fromLink ? AppRoutes.addClothingFromLink : AppRoutes.addClothing,
      arguments: initial,
    );
    return result is String ? result : null;
  }

  static Future<void> editClothing(BuildContext context, String itemId) =>
      Navigator.of(context)
          .pushNamed(AppRoutes.editClothing, arguments: itemId);

  /// With [siblings] (the list the piece was tapped in), the page offers
  /// ‹ › to step through them.
  static Future<void> clothingDetail(
    BuildContext context,
    String itemId, {
    List<String> siblings = const [],
  }) => Navigator.of(context).pushNamed(
    AppRoutes.clothingDetail,
    arguments: ClothingDetailArgs(itemId, siblings: siblings),
  );

  static Future<void> clothingPhotos(
    BuildContext context,
    String itemId, {
    int initialIndex = 0,
  }) => Navigator.of(context).pushNamed(
    AppRoutes.clothingPhotos,
    arguments: ClothingPhotosArgs(itemId, initialIndex: initialIndex),
  );

  static Future<void> selectClothes(
    BuildContext context, {
    WardrobeQuery query = const WardrobeQuery(),
  }) =>
      Navigator.of(context)
          .pushNamed(AppRoutes.selectClothes, arguments: query);

  static Future<void> reorderClothes(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.reorderClothes);

  static Future<void> selectOutfits(
    BuildContext context, {
    OutfitQuery query = const OutfitQuery(),
  }) =>
      Navigator.of(context)
          .pushNamed(AppRoutes.selectOutfits, arguments: query);

  static Future<void> reorderOutfits(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.reorderOutfits);

  static Future<void> planner(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.planner);

  /// Fits' "Add outfit": choose pieces first (starting with
  /// [initialItemIds]), then how to put them together. With [planDate], the
  /// new outfit is planned on that day.
  static Future<void> createOutfit(
    BuildContext context, {
    List<String> initialItemIds = const [],
    DateTime? planDate,
  }) => Navigator.of(context)
      .pushNamed(AppRoutes.outfitPick, arguments: (initialItemIds, planDate));

  /// The collage builder for a new outfit; resolves to true once saved.
  static Future<bool> composeOutfit(
    BuildContext context, {
    List<String> itemIds = const [],
    String? photoFile,
    DateTime? planDate,
  }) async {
    final result = await Navigator.of(context).pushNamed<Object?>(
      AppRoutes.outfitBuilder,
      arguments: OutfitBuilderArgs(
        initialItemIds: itemIds,
        photoFile: photoFile,
        planDate: planDate,
      ),
    );
    return result == true;
  }

  static Future<void> editOutfit(BuildContext context, String outfitId) =>
      Navigator.of(context).pushNamed(
        AppRoutes.outfitBuilder,
        arguments: OutfitBuilderArgs(outfitId: outfitId),
      );

  /// Fits' Dressing Room; resolves to true once an outfit was saved. With
  /// [planDate], the new outfit is planned on that day.
  static Future<bool> swipeOutfit(
    BuildContext context, {
    List<String> initialItemIds = const [],
    DateTime? planDate,
  }) async {
    final result = await Navigator.of(context).pushNamed<Object?>(
      AppRoutes.swipeOutfit,
      arguments: (initialItemIds, planDate),
    );
    return result == true;
  }

  static Future<void> outfitDetail(BuildContext context, String outfitId) =>
      Navigator.of(context)
          .pushNamed(AppRoutes.outfitDetail, arguments: outfitId);

  static Future<void> collectionDetail(
    BuildContext context,
    String collectionId,
  ) =>
      Navigator.of(context)
          .pushNamed(AppRoutes.collectionDetail, arguments: collectionId);

  static Future<void> trips(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.trips);

  static Future<void> tripDetail(BuildContext context, String tripId) =>
      Navigator.of(context).pushNamed(AppRoutes.tripDetail, arguments: tripId);

  static Future<void> insights(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.insights);

  static Future<void> favorites(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.favorites);

  static Future<void> archived(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.archived);

  static Future<void> settings(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.settings);

  static Future<void> stylist(BuildContext context, {StylistLaunch? launch}) =>
      Navigator.of(context).pushNamed(AppRoutes.stylist, arguments: launch);

  static Future<void> premium(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.premium);

  static Future<void> dailyReminders(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.dailyReminders);

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
