import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/social/social_flows.dart';
import 'package:all_fits/features/social/widgets/social_widgets.dart';
import 'package:all_fits/features/wardrobe/widgets/clothing_grid.dart';

/// Someone else's profile, as in Fits: who they are, Follow and Style
/// buttons, then their clothes and outfits when the caller may see them.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Future<(ProfileSummary?, PublicCloset?)> _load = _fetch();
  bool _busy = false;
  bool _showOutfits = false;
  ClothingCategory? _category;

  Future<(ProfileSummary?, PublicCloset?)> _fetch() async {
    final repository = context.read<SocialController>().repository;
    final summary = await repository.summary(widget.userId);
    final closet = summary != null && summary.canViewCloset
        ? await repository.closet(widget.userId)
        : null;
    return (summary, closet);
  }

  void _reload() => setState(() => _load = _fetch());

  Future<void> _run(Future<bool> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (await action()) _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onFollowPressed(ProfileSummary summary) => _run(() async {
    final profile = summary.profile;
    if (summary.blockedByMe) return SocialFlows.unblock(context, profile);
    if (summary.myFollow == FollowStatus.accepted) {
      return SocialFlows.unfollow(context, profile);
    }
    if (!await SocialFlows.requireProfile(context) || !mounted) return false;
    final social = context.read<SocialController>();
    try {
      if (summary.myFollow == FollowStatus.pending) {
        await social.unfollow(profile.userId);
      } else {
        await social.follow(profile.userId);
      }
      return true;
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
      return false;
    }
  });

  Future<void> _onStyle(ProfileSummary summary) async {
    if (!await SocialFlows.requireProfile(context) || !mounted) return;
    await AppNavigator.styleFor(context, summary.profile);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(ProfileSummary?, PublicCloset?)>(
      future: _load,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final summary = data?.$1;
        final Widget body;
        if (snapshot.hasError) {
          body = AppErrorView(error: snapshot.error!, onRetry: _reload);
        } else if (data == null) {
          body = const AppLoadingView();
        } else if (summary == null) {
          body = const AppEmptyState(
            icon: Icons.person_off_outlined,
            title: 'Profile not available',
            message: 'This account doesn’t exist or can’t be shown.',
          );
        } else {
          body = RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _load;
            },
            child: _content(summary, data.$2),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(
              summary?.profile.username ?? '',
              style: context.textTheme.headlineSmall,
            ),
            actions: [
              if (summary != null)
                IconButton(
                  tooltip: 'More',
                  onPressed: () => SocialFlows.showProfileMenu(
                    context,
                    summary,
                    onChanged: _reload,
                  ),
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
            ],
          ),
          body: body,
        );
      },
    );
  }

  Widget _content(ProfileSummary summary, PublicCloset? closet) {
    final profile = summary.profile;
    final text = context.textTheme;
    final followLabel = summary.blockedByMe
        ? 'Unblock'
        : switch (summary.myFollow) {
            FollowStatus.accepted => 'Following',
            FollowStatus.pending => 'Requested',
            null => summary.followsMe ? 'Follow back' : 'Follow',
          };
    final followPrimary = !summary.blockedByMe && summary.myFollow == null;
    final items = closet?.items ?? const [];
    final shownItems = _category == null
        ? items
        : items.where((i) => i.category == _category).toList();
    final outfits = closet?.outfits ?? const [];

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            0,
          ),
          sliver: SliverList.list(
            children: [
              ProfileHeaderRow(
                profile: profile,
                followers: summary.followers,
                following: summary.following,
              ),
              if (profile.bio.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(profile.bio, style: text.bodyMedium),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : () => _onFollowPressed(summary),
                      style: profileButtonStyle(
                        context,
                        primary: followPrimary,
                      ),
                      child: Text(followLabel),
                    ),
                  ),
                  if (summary.canStyle) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _onStyle(summary),
                        style: profileButtonStyle(context),
                        child: Text(
                          'Style ${profile.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
        if (closet == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              compact: true,
              icon: Icons.lock_outline_rounded,
              title: summary.blockedByMe
                  ? 'You blocked this account'
                  : 'This account is private',
              message: summary.blockedByMe
                  ? 'Unblock them to see their closet again.'
                  : summary.myFollow == FollowStatus.pending
                  ? 'You’ll see their clothes and outfits once they accept '
                        'your request.'
                  : 'Follow this account to see their clothes and outfits.',
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: _TabSwitch(
              showOutfits: _showOutfits,
              onChanged: (value) => setState(() => _showOutfits = value),
            ),
          ),
          if (!_showOutfits) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: CategoryPillBar(
                  items: items,
                  selected: _category,
                  onSelected: (c) => setState(() => _category = c),
                ),
              ),
            ),
            if (shownItems.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  compact: true,
                  icon: Icons.checkroom_outlined,
                  title: 'No clothes yet',
                  message: 'Pieces they add will show up here.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  0,
                  AppSpacing.page,
                  AppSpacing.xxl,
                ),
                sliver: ClothingSliverGrid(
                  items: shownItems,
                  onTap: (item) => SocialFlows.showPiece(context, item),
                ),
              ),
          ] else if (outfits.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                compact: true,
                icon: Icons.style_outlined,
                title: 'No outfits yet',
                message: 'Outfits they create will show up here.',
                actionLabel: summary.canStyle
                    ? 'Style ${profile.username}'
                    : null,
                onAction: () => _onStyle(summary),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.md,
                AppSpacing.page,
                AppSpacing.xxl,
              ),
              sliver: OutfitCardSliverGrid(
                itemCount: outfits.length,
                itemBuilder: (context, index) {
                  final outfit = outfits[index];
                  final pieces = closet.itemsOf(outfit);
                  return SocialOutfitCard(
                    items: pieces,
                    layout: outfit.layout,
                    onTap: () => AppNavigator.publicOutfit(
                      context,
                      FeedPost(
                        owner: profile,
                        outfit: outfit,
                        items: pieces,
                        postedAt: outfit.createdAt,
                      ),
                      fromFeed: false,
                    ),
                  );
                },
              ),
            ),
        ],
        // Keeps the bottom of short pages clear of the gesture bar.
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ),
      ],
    );
  }
}

/// Clothes | Outfits, underlined like Fits' profile tabs.
class _TabSwitch extends StatelessWidget {
  const _TabSwitch({required this.showOutfits, required this.onChanged});

  final bool showOutfits;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: showOutfits ? 1 : 0,
      child: TabBar(
        onTap: (index) => onChanged(index == 1),
        tabs: const [
          Tab(text: 'Clothes'),
          Tab(text: 'Outfits'),
        ],
      ),
    );
  }
}
