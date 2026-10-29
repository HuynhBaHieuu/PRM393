import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/string_extensions.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/core/widgets/section_header.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/social/social_flows.dart';
import 'package:all_fits/features/social/widgets/social_widgets.dart';

/// Everyone with a profile; typing narrows it by username or name.
class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _query = TextEditingController();
  List<SocialProfile>? _people;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final people = await context.read<SocialController>().repository.people();
      if (mounted) {
        setState(() {
          _people = people;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = _people;
    final term = _query.text.replaceAll('@', '').trim().folded;
    final results = people == null || term.isEmpty
        ? people
        : [
            for (final p in people)
              if (p.username.contains(term) ||
                  p.displayName.folded.contains(term))
                p,
          ];
    final Widget body;
    if (_error != null && people == null) {
      body = AppErrorView(error: _error!, onRetry: _load);
    } else if (results == null) {
      body = const AppLoadingView();
    } else if (people!.isEmpty) {
      body = const AppEmptyState(
        icon: Icons.person_search_outlined,
        title: 'No one here yet',
        message: 'People appear here once they set up their profile.',
      );
    } else if (results.isEmpty) {
      body = const AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No users found',
        message: 'Check the spelling, or ask them for their username.',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: results.length,
          itemBuilder: (context, index) => ProfileRow(
            profile: results[index],
            onTap: () =>
                SocialFlows.openProfile(context, results[index].userId),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _query,
          autofocus: true,
          autocorrect: false,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Search people',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        actions: const [SizedBox(width: AppSpacing.md)],
      ),
      body: body,
    );
  }
}

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
          title: Text(social.me?.username ?? 'Followers'),
          bottom: TabBar(
            tabs: [
              Tab(text: '${social.followers.length} Followers'),
              Tab(text: '${social.following.length} Following'),
              Tab(text: requests == 0 ? 'Requests' : 'Requests ($requests)'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ConnectionList(
              connections: social.followers,
              emptyTitle: 'No followers yet',
              emptyMessage: 'Followers will appear here.',
              trailing: (c) => TextButton(
                onPressed: () => SocialFlows.removeFollower(context, c.profile),
                child: const Text('Remove'),
              ),
            ),
            _ConnectionList(
              connections: social.following,
              emptyTitle: 'Not following anyone yet',
              emptyMessage: 'Find friends to see their outfits on Discover.',
              trailing: (c) => FilledButton(
                onPressed: () => SocialFlows.unfollow(context, c.profile),
                style: profileButtonStyle(context),
                child: const Text('Following'),
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
                  actionLabel: 'Find friends',
                  onAction: () => AppNavigator.userSearch(context),
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
          children: const [
            AppEmptyState(
              icon: Icons.person_add_alt_outlined,
              title: 'No follow requests',
              message: 'People that request to follow you will appear here.',
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
            const SectionHeader(title: 'Sent'),
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
                  child: const Text('Requested'),
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
            child: const Text('Accept'),
          ),
          IconButton(
            tooltip: 'Decline',
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
      appBar: AppBar(title: const Text('Blocked users')),
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
            return const AppEmptyState(
              icon: Icons.block_rounded,
              title: 'No blocked users',
              message: 'If you block users, they will appear here.',
            );
          }
          return ListView.builder(
            itemCount: blocked.length,
            itemBuilder: (context, index) => ProfileRow(
              profile: blocked[index],
              trailing: FilledButton(
                onPressed: () => _unblock(blocked[index]),
                style: profileButtonStyle(context),
                child: const Text('Unblock'),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Fits' bell: follow requests and outfits made for the user.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialController>();
    final requests = social.incomingRequests;
    final styled = social.styledForMe.where((s) => s.isPending).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: social.load,
        child: ListView(
          children: [
            if (requests.isEmpty && styled.isEmpty)
              const AppEmptyState(
                icon: Icons.notifications_off_outlined,
                title: 'No notifications yet',
                message:
                    'You’ll get notified for activities, for example when '
                    'someone wants to follow you or creates an outfit for '
                    'you.',
              ),
            if (requests.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              const SectionHeader(title: 'Follow requests'),
              for (final request in requests)
                FollowRequestRow(request: request),
            ],
            if (styled.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              SectionHeader(
                title: 'Outfits for you',
                actionLabel: 'See all',
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
                    '${outfit.other.username} created an outfit for you.',
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
          ],
        ),
      ),
    );
  }
}
