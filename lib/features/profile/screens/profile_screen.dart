import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/data/models/user_account.dart';
import 'package:all_fits/features/auth/auth_flows.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/premium/widgets/premium_widgets.dart';
import 'package:all_fits/features/profile/widgets/profile_widgets.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final user = context.read<AppUser>();
    final wardrobe = context.watch<WardrobeController>();
    final outfits = context.watch<OutfitController>();
    final wornCount = context.select<PlannerController, int>(
      (p) => p.entries.where((e) => e.isWorn).length,
    );
    final favoriteCount =
        wardrobe.favoriteItems.length + outfits.favorites.length;
    final archivedCount = wardrobe.archivedItems.length;
    final social = context.watch<SocialController?>();

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProfileHeader(
                  name: settings.displayName,
                  username: settings.username,
                  email: user.email,
                  badge: settings.isPremium ? const PremiumBadge() : null,
                  onEdit: () => AppNavigator.settings(context),
                ),
                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: ProfileStatsRow(
                    stats: [
                      (wardrobe.activeItems.length, 'Items'),
                      (outfits.outfits.length, 'Outfits'),
                      (wornCount, 'Worn'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ProfileMenuTile(
                  icon: Icons.workspace_premium_outlined,
                  title: 'All Fits Premium',
                  subtitle: settings.isPremium
                      ? 'Unlimited wardrobe and AI Stylist'
                      : 'Unlimited AI Stylist chat and space',
                  trailingText: settings.plan.label,
                  onTap: () => AppNavigator.premium(context),
                ),
                if (social != null) ...[
                  ProfileMenuTile(
                    icon: Icons.account_circle_outlined,
                    title: 'My profile',
                    subtitle: social.me == null
                        ? 'Pick a username so friends can find you'
                        : '@${social.me!.username} · '
                              '${social.me!.isPrivate ? 'Private' : 'Public'}',
                    onTap: () => AppNavigator.editProfile(context),
                  ),
                  ProfileMenuTile(
                    icon: Icons.people_outline_rounded,
                    title: 'Followers & following',
                    trailingText: social.incomingRequests.isEmpty
                        ? null
                        : '${social.incomingRequests.length} requests',
                    onTap: () => AppNavigator.connections(context),
                  ),
                  ProfileMenuTile(
                    icon: Icons.style_outlined,
                    title: 'Styled together',
                    subtitle: 'Outfits made for you and by you',
                    trailingText: social.unansweredStyledCount == 0
                        ? null
                        : '${social.unansweredStyledCount} new',
                    onTap: () => AppNavigator.styledTogether(context),
                  ),
                  ProfileMenuTile(
                    icon: Icons.block_rounded,
                    title: 'Blocked users',
                    onTap: () => AppNavigator.blockedUsers(context),
                  ),
                ],
                ProfileMenuTile(
                  icon: Icons.insights_outlined,
                  title: 'Wardrobe Insights',
                  subtitle: 'Value, wear and breakdowns',
                  onTap: () => AppNavigator.insights(context),
                ),
                ProfileMenuTile(
                  icon: Icons.favorite_border_rounded,
                  title: 'Favorites',
                  trailingText: favoriteCount == 0 ? null : '$favoriteCount',
                  onTap: () => AppNavigator.favorites(context),
                ),
                ProfileMenuTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Archived Items',
                  trailingText: archivedCount == 0 ? null : '$archivedCount',
                  onTap: () => AppNavigator.archived(context),
                ),
                ProfileMenuTile(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () => AppNavigator.settings(context),
                ),
                ProfileMenuTile(
                  icon: Icons.logout_rounded,
                  title: 'Log out',
                  onTap: () => AuthFlows.signOut(context),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Member since ${AppFormatters.monthYear(user.createdAt)}',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
