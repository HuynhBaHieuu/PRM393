import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/social/social_flows.dart';
import 'package:all_fits/features/social/widgets/social_widgets.dart';
import 'package:all_fits/core/l10n/l10n.dart';

/// Fits' Community: Outfits, Clothes and Users tabs, with search on top.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Community')),
          actions: [
            IconButton(
              tooltip: tr('Search for clothes and users'),
              onPressed: () => AppNavigator.communitySearch(context),
              icon: const Icon(Icons.search_rounded),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: tr('Outfits')),
              Tab(text: tr('Clothes')),
              Tab(text: tr('Users')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_OutfitsTab(), _ClothesTab(), _UsersTab()],
        ),
      ),
    );
  }
}

/// Loads a Community list a page at a time, dropping pages that arrive
/// after the list was reset.
mixin CommunityPaging<T, W extends StatefulWidget> on State<W> {
  static const double _loadMoreExtent = 600;

  List<T> entries = const [];
  Object? error;
  bool loading = false;
  bool hasMore = true;
  int _generation = 0;

  Future<List<T>> fetchPage(int offset);

  Future<void> refresh() async {
    _generation++;
    setState(() {
      entries = const [];
      hasMore = true;
      error = null;
      loading = false;
    });
    await loadMore();
  }

  Future<void> loadMore() async {
    if (loading || !hasMore) return;
    final generation = _generation;
    setState(() => loading = true);
    try {
      final page = await fetchPage(entries.length);
      if (!mounted || generation != _generation) return;
      setState(() {
        entries = [...entries, ...page];
        hasMore = page.isNotEmpty;
      });
    } catch (e) {
      if (mounted && generation == _generation) setState(() => error = e);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => loading = false);
      }
    }
  }

  void replaceEntry(bool Function(T entry) matches, T replacement) {
    setState(() {
      entries = [for (final e in entries) matches(e) ? replacement : e];
    });
  }

  /// Wraps a scroll view so nearing its end loads the next page.
  Widget pagedScroll({required List<Widget> slivers}) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.vertical &&
            n.metrics.extentAfter < _loadMoreExtent) {
          loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: slivers,
        ),
      ),
    );
  }

  /// The error, loading or empty state while there is nothing to show yet;
  /// null once there is.
  Widget? placeholderSliver({
    required Widget loadingSliver,
    required Widget empty,
  }) {
    if (entries.isNotEmpty) return null;
    if (error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AppErrorView(error: error!, onRetry: refresh),
      );
    }
    if (loading || hasMore) return loadingSliver;
    return SliverFillRemaining(hasScrollBody: false, child: empty);
  }
}

/// Fits' outfit feed runs edge to edge with thin gaps.
const EdgeInsets _feedPadding = EdgeInsets.fromLTRB(
  0,
  AppSpacing.md,
  0,
  AppSpacing.xxl,
);

const EdgeInsets _gridPadding = EdgeInsets.fromLTRB(
  AppSpacing.page,
  AppSpacing.sm,
  AppSpacing.page,
  AppSpacing.xxl,
);

class _OutfitsTab extends StatefulWidget {
  const _OutfitsTab();

  @override
  State<_OutfitsTab> createState() => _OutfitsTabState();
}

class _OutfitsTabState extends State<_OutfitsTab>
    with AutomaticKeepAliveClientMixin, CommunityPaging<FeedPost, _OutfitsTab> {
  FeedFilter _filter = FeedFilter.week;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    loadMore();
  }

  @override
  Future<List<FeedPost>> fetchPage(int offset) =>
      context.read<SocialController>().repository.feed(_filter, offset: offset);

  void _select(FeedFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    refresh();
  }

  Future<void> _open(FeedPost post) async {
    final result = await AppNavigator.publicOutfit(context, post);
    if (!mounted) return;
    // Null after a block on the detail page: the owner's posts must go.
    if (result == null) {
      refresh();
      return;
    }
    replaceEntry((p) => p.isSamePost(result), result);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final placeholder = placeholderSliver(
      loadingSliver: const SliverPadding(
        padding: _feedPadding,
        sliver: LoadingTilesSliverGrid(
          aspectRatio: AppSizes.outfitImageAspect * 0.8,
          spacing: AppSpacing.xxs,
        ),
      ),
      empty: _filter == FeedFilter.following
          ? AppEmptyState(
              icon: Icons.people_outline_rounded,
              title: tr('Not following anyone yet'),
              message: tr(
                'Your following feed is empty, either you don’t follow '
                'anyone or they haven’t created any outfits yet.',
              ),
            )
          : AppEmptyState(
              icon: Icons.public_rounded,
              title: tr('No outfits yet'),
              message: tr(
                'No outfits were shared in this time. Check back later!',
              ),
            ),
    );
    return pagedScroll(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: PillBar(
              pills: [
                for (final filter in FeedFilter.values)
                  SelectablePill(
                    quiet: true,
                    label: filter.label,
                    selected: filter == _filter,
                    onTap: () => _select(filter),
                  ),
              ],
            ),
          ),
        ),
        placeholder ??
            SliverPadding(
              padding: _feedPadding,
              sliver: OutfitCardSliverGrid(
                bandHeight:
                    SocialOutfitCard.ownerBandHeight +
                    SocialOutfitCard.statsBandHeight,
                spacing: AppSpacing.xxs,
                runSpacing: AppSpacing.xxs,
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final post = entries[index];
                  return SocialOutfitCard(
                    items: post.orderedItems,
                    layout: post.outfit.layout,
                    owner: post.owner,
                    stats: PostStats(post: post),
                    onTap: () => _open(post),
                  );
                },
              ),
            ),
      ],
    );
  }
}

/// Community > Clothes: other people's pieces, newest first, by category.
class _ClothesTab extends StatefulWidget {
  const _ClothesTab();

  /// Fits' chip order, with our Dresses and Bags in it.
  static const List<ClothingCategory> categories = [
    ClothingCategory.tops,
    ClothingCategory.bottoms,
    ClothingCategory.shoes,
    ClothingCategory.outerwear,
    ClothingCategory.dresses,
    ClothingCategory.bags,
    ClothingCategory.accessories,
    ClothingCategory.other,
  ];

  @override
  State<_ClothesTab> createState() => _ClothesTabState();
}

class _ClothesTabState extends State<_ClothesTab>
    with
        AutomaticKeepAliveClientMixin,
        CommunityPaging<CommunityItem, _ClothesTab> {
  ClothingCategory? _category;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    loadMore();
  }

  @override
  Future<List<CommunityItem>> fetchPage(int offset) => context
      .read<SocialController>()
      .repository
      .communityItems(category: _category, offset: offset);

  void _select(ClothingCategory? category) {
    if (category == _category) return;
    _category = category;
    refresh();
  }

  Future<void> _open(CommunityItem entry) async {
    final result = await AppNavigator.publicPiece(context, entry);
    if (result != null && mounted) {
      replaceEntry((e) => e.isSameItem(result), result);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final placeholder = placeholderSliver(
      loadingSliver: const SliverPadding(
        padding: _gridPadding,
        sliver: LoadingTilesSliverGrid(aspectRatio: 0.8),
      ),
      empty: AppEmptyState(
        icon: Icons.checkroom_outlined,
        title: tr('No clothes yet'),
        message: tr('Pieces from public wardrobes show up here.'),
      ),
    );
    return pagedScroll(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: PillBar(
              pills: [
                SelectablePill(
                  quiet: true,
                  label: tr('All'),
                  selected: _category == null,
                  onTap: () => _select(null),
                ),
                for (final category in _ClothesTab.categories)
                  SelectablePill(
                    quiet: true,
                    label: category.label,
                    selected: category == _category,
                    onTap: () => _select(category),
                  ),
              ],
            ),
          ),
        ),
        placeholder ??
            SliverPadding(
              padding: _gridPadding,
              sliver: CommunityItemSliverGrid(entries: entries, onTap: _open),
            ),
      ],
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab>
    with
        AutomaticKeepAliveClientMixin,
        CommunityPaging<SuggestedPerson, _UsersTab> {
  /// People being followed or unfollowed right now.
  final Set<String> _busy = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    loadMore();
  }

  @override
  Future<List<SuggestedPerson>> fetchPage(int offset) => context
      .read<SocialController>()
      .repository
      .suggestedPeople(offset: offset);

  Future<void> _toggleFollow(
    SocialProfile profile,
    FollowStatus? status,
  ) async {
    final social = context.read<SocialController>();
    setState(() => _busy.add(profile.userId));
    switch (status) {
      case null:
        if (await SocialFlows.requireProfile(context) && mounted) {
          await ClosetFlows.guard(context, () => social.follow(profile.userId));
        }
      case FollowStatus.pending:
        await ClosetFlows.guard(context, () => social.unfollow(profile.userId));
      case FollowStatus.accepted:
        await SocialFlows.unfollow(context, profile);
    }
    if (mounted) setState(() => _busy.remove(profile.userId));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final social = context.watch<SocialController>();
    final statusById = {
      for (final c in social.sentRequests) c.profile.userId: c.status,
      for (final c in social.following) c.profile.userId: c.status,
    };
    final palette = context.palette;
    final placeholder = placeholderSliver(
      loadingSliver: const SliverFillRemaining(child: AppLoadingView()),
      empty: AppEmptyState(
        icon: Icons.person_search_outlined,
        title: tr('No suggestions right now'),
        message: tr('Search for people by their username to follow them.'),
        actionLabel: tr('Search'),
        onAction: () => AppNavigator.communitySearch(context),
      ),
    );
    return pagedScroll(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              0,
            ),
            child: Text(
              tr('People suggested for you'),
              style: context.textTheme.bodyLarge?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
        ),
        placeholder ??
            SliverList.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                indent: AppSpacing.page,
                endIndent: AppSpacing.page,
                color: palette.border,
              ),
              itemBuilder: (context, index) {
                final person = entries[index];
                final id = person.profile.userId;
                final status = statusById[id];
                return SuggestedPersonTile(
                  person: person,
                  status: status,
                  onTap: () => SocialFlows.openProfile(context, id),
                  onFollow: _busy.contains(id)
                      ? null
                      : () => _toggleFollow(person.profile, status),
                );
              },
            ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
      ],
    );
  }
}
