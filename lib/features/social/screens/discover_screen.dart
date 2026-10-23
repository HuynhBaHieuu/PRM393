import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/social/social_flows.dart';
import 'package:all_fits/features/social/widgets/social_widgets.dart';
import 'package:all_fits/features/wardrobe/widgets/clothing_tile.dart';

/// Public outfits from the community, newest first (Fits' Community tab).
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  static const double _loadMoreExtent = 600;

  FeedFilter _filter = FeedFilter.latest;
  List<FeedPost> _posts = const [];
  Object? _error;
  bool _loading = false;
  bool _hasMore = true;

  /// Bumped on every filter change so late pages of the old one are dropped.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    _generation++;
    setState(() {
      _posts = const [];
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final generation = _generation;
    setState(() => _loading = true);
    try {
      final page = await context.read<SocialController>().repository.feed(
        _filter,
        before: _posts.isEmpty ? null : _posts.last.postedAt,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _posts = [..._posts, ...page];
        _hasMore = page.isNotEmpty;
      });
    } catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _select(FeedFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    _refresh();
  }

  Future<void> _open(FeedPost post) async {
    final changed = await AppNavigator.publicOutfit(context, post);
    // A save toggle or a block on the detail page changes this list.
    if (changed == true && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            tooltip: 'Search people',
            onPressed: () => AppNavigator.userSearch(context),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < _loadMoreExtent) _loadMore();
          return false;
        },
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: PillBar(
                    pills: [
                      for (final filter in FeedFilter.values)
                        SelectablePill(
                          label: filter.label,
                          selected: filter == _filter,
                          onTap: () => _select(filter),
                        ),
                    ],
                  ),
                ),
              ),
              if (_posts.isEmpty && _error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppErrorView(error: _error!, onRetry: _refresh),
                )
              else if (_posts.isEmpty && _loading)
                const SliverFillRemaining(child: AppLoadingView())
              else if (_posts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    icon: Icons.public_rounded,
                    title: 'No outfits yet',
                    message: switch (_filter) {
                      FeedFilter.latest =>
                        'No outfits were shared yet. Check back later!',
                      FeedFilter.following =>
                        'Follow people to see their outfits here.',
                      FeedFilter.saved =>
                        'Save outfit inspiration from others to find it '
                            'here.',
                    },
                    actionLabel: _filter == FeedFilter.following
                        ? 'Find friends'
                        : null,
                    onAction: () => AppNavigator.userSearch(context),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.xs,
                    AppSpacing.page,
                    AppSpacing.xxl,
                  ),
                  sliver: OutfitCardSliverGrid(
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      return SocialOutfitCard(
                        items: post.orderedItems,
                        layout: post.outfit.layout,
                        owner: post.owner,
                        onTap: () => _open(post),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A shared outfit, as on Fits: the flat-lay, who made it, and its pieces.
/// Pops with true when the post was saved, unsaved or its owner blocked.
class PublicOutfitScreen extends StatefulWidget {
  const PublicOutfitScreen({
    super.key,
    required this.post,
    this.fromFeed = true,
  });

  final FeedPost post;

  /// Only Discover posts can be saved as ideas.
  final bool fromFeed;

  @override
  State<PublicOutfitScreen> createState() => _PublicOutfitScreenState();
}

class _PublicOutfitScreenState extends State<PublicOutfitScreen> {
  late FeedPost _post = widget.post;
  bool _changed = false;
  bool _busy = false;

  bool get _isMine =>
      context.read<SocialController>().me?.userId == _post.owner.userId;

  Future<void> _toggleSaved() async {
    if (_busy) return;
    final saved = !_post.saved;
    setState(() => _busy = true);
    try {
      await context.read<SocialController>().repository.setSaved(
        _post,
        saved: saved,
      );
      if (!mounted) return;
      setState(() {
        _post = _post.copyWith(saved: saved);
        _changed = true;
      });
      context.showSnack(saved ? 'Saved to your ideas' : 'Removed from ideas');
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final items = _post.orderedItems;
    final owner = _post.owner;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            if (widget.fromFeed && !_isMine)
              IconButton(
                tooltip: _post.saved ? 'Remove from ideas' : 'Save idea',
                onPressed: _busy ? null : _toggleSaved,
                icon: Icon(
                  _post.saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                ),
              ),
            if (!_isMine)
              IconButton(
                tooltip: 'More',
                onPressed: () => SocialFlows.showPostMenu(
                  context,
                  _post,
                  onBlocked: () => Navigator.of(context).pop(true),
                ),
                icon: const Icon(Icons.more_horiz_rounded),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSizes.maxPreviewWidth,
                ),
                child: AspectRatio(
                  aspectRatio: AppSizes.outfitImageAspect,
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: palette.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      child: OutfitCanvas(
                        items: items,
                        layout: _post.outfit.layout,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _post.outfit.name,
                    style: text.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                InkWell(
                  onTap: () => SocialFlows.openProfile(context, owner.userId),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxs),
                    child: Row(
                      children: [
                        UserAvatar(name: owner.name, url: owner.avatarUrl),
                        const SizedBox(width: AppSpacing.xs),
                        Text(owner.username, style: text.titleMedium),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Clothes in outfit',
              style: text.bodyMedium?.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: AppSizes.recentItemWidth / AppSizes.clothingImageAspect,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) => SizedBox(
                  width: AppSizes.recentItemWidth,
                  child: ClothingTile(
                    item: items[index],
                    decodeWidth: AppSizes.recentItemWidth,
                    onTap: () => SocialFlows.showPiece(context, items[index]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
