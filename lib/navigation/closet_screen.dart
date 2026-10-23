import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/features/collections/screens/collections_screen.dart';
import 'package:all_fits/features/outfits/screens/outfits_screen.dart';
import 'package:all_fits/features/planner/screens/planner_screen.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/social/screens/people_screens.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/social/social_flows.dart';
import 'package:all_fits/features/social/widgets/social_widgets.dart';
import 'package:all_fits/features/wardrobe/screens/wardrobe_screen.dart';
import 'package:all_fits/navigation/app_navigation.dart';

/// The Profile tab: the user's name, a menu to the account page, their
/// community profile when online, and the closet split into Clothes,
/// Outfits, Collections and Planner tabs.
class ClosetScreen extends StatefulWidget {
  const ClosetScreen({super.key});

  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen>
    with SingleTickerProviderStateMixin {
  late final ShellController _shell = context.read<ShellController>();
  late final TabController _tabs = TabController(
    length: ClosetTab.values.length,
    initialIndex: _shell.closetTab.index,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabChanged);
    _shell.addListener(_onShellChanged);
  }

  @override
  void dispose() {
    _shell.removeListener(_onShellChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChanged() => _shell.syncClosetTab(ClosetTab.values[_tabs.index]);

  // Another screen asked for a specific closet tab.
  void _onShellChanged() {
    final index = _shell.closetTab.index;
    if (index != _tabs.index) _tabs.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final social = context.watch<SocialController?>();
    final title = settings.username.isNotEmpty
        ? settings.username
        : settings.displayName.isNotEmpty
        ? settings.displayName
        : 'My closet';

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: context.textTheme.headlineMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Account',
                  onPressed: () => AppNavigator.account(context),
                  icon: const Icon(Icons.menu_rounded),
                ),
              ],
            ),
          ),
          if (social != null)
            _CommunityHeader(social: social, settings: settings),
          TabBar(
            controller: _tabs,
            // Four tabs share a phone's width: shrink a label that would
            // otherwise be clipped ("Collections" on small screens or with
            // large text).
            labelPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxs,
            ),
            tabs: [
              for (final tab in ClosetTab.values)
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(tab.label, maxLines: 1),
                  ),
                ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                WardrobeScreen(),
                OutfitsScreen(),
                CollectionsScreen(),
                PlannerScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fits' profile header: photo, name, follower counts, and Edit / Share
/// profile. Before a profile exists it offers to create one.
class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader({required this.social, required this.settings});

  final SocialController social;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final me = social.me;
    final style = profileButtonStyle(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          ProfileHeaderRow(
            profile:
                me ??
                SocialProfile(
                  userId: '',
                  username: settings.username,
                  displayName: settings.displayName,
                ),
            followers: social.followers.length,
            following: social.following.length,
            onFollowers: () => AppNavigator.connections(context),
            onFollowing: () =>
                AppNavigator.connections(context, ConnectionsTab.following),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => AppNavigator.editProfile(context),
                  style: style,
                  child: Text(me == null ? 'Create profile' : 'Edit profile'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: me == null
                      ? () => AppNavigator.userSearch(context)
                      : () => SocialFlows.shareProfile(context, me.username),
                  style: style,
                  child: Text(me == null ? 'Find friends' : 'Share profile'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
