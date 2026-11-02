import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/core/widgets/section_header.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/social/social_flows.dart';
import 'package:all_fits/features/social/widgets/social_widgets.dart';
import 'package:all_fits/core/l10n/l10n.dart';

enum ConnectionsTab { followers, following, requests }

/// The user's followers, who they follow, and requests both ways.
class ConnectionsScreen extends StatelessWidget {
  const ConnectionsScreen({
    super.key,
    this.initialTab = ConnectionsTab.followers,
  });

  final ConnectionsTab initialTab;

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialController>();
    final requests = social.incomingRequests.length;
    return DefaultTabController(
      length: ConnectionsTab.values.length,
      initialIndex: initialTab.index,
      child: Scaffold(
        appBar: AppBar(
          title: Text(social.me?.username ?? tr('Followers')),
          bottom: TabBar(
            tabs: [
              Tab(text: tr('{0} Followers', [social.followers.length])),
              Tab(text: tr('{0} Following', [social.following.length])),
              Tab(
                text: requests == 0
                    ? tr('Requests')
                    : tr('Requests ({0})', [requests]),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ConnectionList(
              connections: social.followers,
              emptyTitle: tr('No followers yet'),
              emptyMessage: tr('Followers will appear here.'),
              trailing: (c) => TextButton(
                onPressed: () => SocialFlows.removeFollower(context, c.profile),
                child: Text(tr('Remove')),
              ),
            ),
            _ConnectionList(
              connections: social.following,
              emptyTitle: tr('Not following anyone yet'),
              emptyMessage: tr(
                'Find friends to see their outfits in Community.',
              ),
              trailing: (c) => FilledButton(
                onPressed: () => SocialFlows.unfollow(context, c.profile),
                style: profileButtonStyle(context),
                child: Text(tr('Following')),
              ),
            ),
            _RequestsList(social: social),
          ],
        ),
      ),
    );
  }
}

class _ConnectionList extends StatelessWidget {
  const _ConnectionList({
    required this.connections,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.trailing,
  });

  final List<Connection> connections;
  final String emptyTitle;
  final String emptyMessage;
  final Widget Function(Connection connection) trailing;

  @override
  Widget build(BuildContext context) {
    final social = context.read<SocialController>();
    return RefreshIndicator(
      onRefresh: social.load,
      child: connections.isEmpty
          ? ListView(
              children: [
                AppEmptyState(
                  icon: Icons.people_outline_rounded,
                  title: emptyTitle,
                  message: emptyMessage,
                  actionLabel: tr('Find friends'),
                  onAction: () => AppNavigator.communitySearch(context),
                ),
              ],
            )
          : ListView.builder(
              itemCount: connections.length,
              itemBuilder: (context, index) {
                final connection = connections[index];
                return ProfileRow(
                  profile: connection.profile,
                  onTap: () => SocialFlows.openProfile(
                    context,
                    connection.profile.userId,
                  ),
                  trailing: trailing(connection),
                );
              },
            ),
    );
  }
}

class _RequestsList extends StatelessWidget {
  const _RequestsList({required this.social});

  final SocialController social;

  @override
  Widget build(BuildContext context) {
    final incoming = social.incomingRequests;
    final sent = social.sentRequests;
    if (incoming.isEmpty && sent.isEmpty) {
      return RefreshIndicator(
        onRefresh: social.load,
        child: ListView(
          children: [
            AppEmptyState(
              icon: Icons.person_add_alt_outlined,
              title: tr('No follow requests'),
              message: tr(
                'People that request to follow you will appear here.',
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: social.load,
      child: ListView(
        children: [
          for (final request in incoming) FollowRequestRow(request: request),
          if (sent.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            SectionHeader(title: tr('Sent')),
            for (final request in sent)
              ProfileRow(
                profile: request.profile,
                onTap: () =>
                    SocialFlows.openProfile(context, request.profile.userId),
                trailing: FilledButton(
                  onPressed: () => ClosetFlows.guard(
                    context,
                    () => social.unfollow(request.profile.userId),
                  ),
                  style: profileButtonStyle(context),
                  child: Text(tr('Requested')),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Someone asking to follow the user, with Accept and Decline.
class FollowRequestRow extends StatelessWidget {
  const FollowRequestRow({super.key, required this.request});

  final Connection request;

  @override
  Widget build(BuildContext context) {
    final social = context.read<SocialController>();
    final profile = request.profile;
    return ProfileRow(
      profile: profile,
      onTap: () => SocialFlows.openProfile(context, profile.userId),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: () => ClosetFlows.guard(
              context,
              () => social.acceptFollower(profile.userId),
            ),
            style: profileButtonStyle(context, primary: true),
            child: Text(tr('Accept')),
          ),
          IconButton(
            tooltip: tr('Decline'),
            onPressed: () => ClosetFlows.guard(
              context,
              () => social.removeFollower(profile.userId),
            ),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late Future<List<SocialProfile>> _blocked = _fetch();

  Future<List<SocialProfile>> _fetch() =>
      context.read<SocialController>().repository.blockedUsers();

  Future<void> _unblock(SocialProfile profile) async {
    if (await SocialFlows.unblock(context, profile) && mounted) {
      setState(() => _blocked = _fetch());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Blocked users'))),
      body: FutureBuilder<List<SocialProfile>>(
        future: _blocked,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AppErrorView(
              error: snapshot.error!,
              onRetry: () => setState(() => _blocked = _fetch()),
            );
          }
          final blocked = snapshot.data;
          if (blocked == null) return const AppLoadingView();
          if (blocked.isEmpty) {
            return AppEmptyState(
              icon: Icons.block_rounded,
              title: tr('No blocked users'),
              message: tr('If you block users, they will appear here.'),
            );
          }
          return ListView.builder(
            itemCount: blocked.length,
            itemBuilder: (context, index) => ProfileRow(
              profile: blocked[index],
              trailing: FilledButton(
                onPressed: () => _unblock(blocked[index]),
                style: profileButtonStyle(context),
                child: Text(tr('Unblock')),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Fits' bell: follow requests, outfits made for the user, and likes and
/// comments on their Community posts. Opening it clears the likes and
/// comments from the bell; the ones that were new keep a dot until it closes.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// When the user last looked, before this visit.
  late final PostActivityFeed _before;

  @override
  void initState() {
    super.initState();
    _before = context.read<SocialController>().activity;
    _markSeen();
  }

  Future<void> _markSeen() async {
    final social = context.read<SocialController>();
    await social.loadActivity();
    await social.markActivitySeen();
  }

  Future<void> _refresh() async {
    final social = context.read<SocialController>();
    await social.load();
    await social.markActivitySeen();
  }

  bool _isNew(PostActivity activity) =>
      _before.seenAt == null || activity.createdAt.isAfter(_before.seenAt!);

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialController>();
    final requests = social.incomingRequests;
    final styled = social.styledForMe.where((s) => s.isPending).toList();
    final activity = social.activity.items;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Notifications'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: [
            if (requests.isEmpty && styled.isEmpty && activity.isEmpty)
              AppEmptyState(
                icon: Icons.notifications_off_outlined,
                title: tr('No notifications yet'),
                message: tr(
                  'You’ll get notified for activities, for example when '
                  'someone wants to follow you, creates an outfit for '
                  'you, or likes or comments on your outfits.',
                ),
              ),
            if (requests.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              SectionHeader(title: tr('Follow requests')),
              for (final request in requests)
                FollowRequestRow(request: request),
            ],
            if (styled.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              SectionHeader(
                title: tr('Outfits for you'),
                actionLabel: tr('See all'),
                onAction: () => AppNavigator.styledTogether(context),
              ),
              for (final outfit in styled)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  onTap: () => AppNavigator.styledOutfit(context, outfit.id),
                  leading: UserAvatar(
                    name: outfit.other.name,
                    url: outfit.other.avatarUrl,
                  ),
                  title: Text(
                    tr('{0} created an outfit for you.', [
                      outfit.other.username,
                    ]),
                  ),
                  subtitle: outfit.message == null
                      ? null
                      : Text(
                          outfit.message!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: SizedBox(
                    width: AppSizes.thumbMd,
                    child: AspectRatio(
                      aspectRatio: AppSizes.outfitImageAspect,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: OutfitCanvas(
                          items: outfit.orderedItems,
                          layout: outfit.layout,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            if (activity.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              SectionHeader(title: tr('Likes & comments')),
              for (final item in activity)
                _ActivityRow(activity: item, isNew: _isNew(item)),
            ],
          ],
        ),
      ),
    );
  }
}

/// "mia liked your outfit." or "mia commented: Love it", with the outfit.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, required this.isNew});

  final PostActivity activity;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final actor = activity.actor;
    final post = activity.post;
    final what = switch (activity.kind) {
      PostActivityKind.like => tr('{0} liked your outfit.', [actor.username]),
      PostActivityKind.comment => tr('{0} commented: {1}', [
        actor.username,
        activity.body ?? '',
      ]),
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      onTap: () => AppNavigator.publicOutfit(context, post),
      leading: Badge(
        isLabelVisible: isNew,
        smallSize: 10,
        backgroundColor: palette.danger,
        child: GestureDetector(
          onTap: () => SocialFlows.openProfile(context, actor.userId),
          child: UserAvatar(name: actor.name, url: actor.avatarUrl),
        ),
      ),
      title: Text(what, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(AppFormatters.timeAgo(activity.createdAt)),
      trailing: SizedBox(
        width: AppSizes.thumbMd,
        child: AspectRatio(
          aspectRatio: AppSizes.outfitImageAspect,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: OutfitCanvas(
              items: post.orderedItems,
              layout: post.outfit.layout,
            ),
          ),
        ),
      ),
    );
  }
}
