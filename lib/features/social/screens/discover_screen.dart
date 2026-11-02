import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
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
    final result = await AppNavigator.publicOutfit(context, post);
    if (!mounted) return;
    // Null after a block on the detail page: the owner's posts must go.
    if (result == null) {
      _refresh();
      return;
    }
    final unsaved = _filter == FeedFilter.saved && !result.saved;
    setState(() {
      _posts = [
        for (final p in _posts)
          if (!p.isSamePost(result)) p else if (!unsaved) result,
      ];
    });
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
                    withCaption: true,
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      return SocialOutfitCard(
                        items: post.orderedItems,
                        layout: post.outfit.layout,
                        owner: post.owner,
                        footer: PostStats(post: post),
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
/// Discover posts can also be saved, liked and commented on. Pops with the
/// post as it was left, or with nothing when its owner was blocked.
class PublicOutfitScreen extends StatefulWidget {
  const PublicOutfitScreen({
    super.key,
    required this.post,
    this.fromFeed = true,
  });

  final FeedPost post;

  /// Only Discover posts can be saved, liked and commented on.
  final bool fromFeed;

  @override
  State<PublicOutfitScreen> createState() => _PublicOutfitScreenState();
}

class _PublicOutfitScreenState extends State<PublicOutfitScreen> {
  late FeedPost _post = widget.post;
  final _commentField = TextEditingController();
  bool _busy = false;
  bool _liking = false;
  bool _sending = false;

  /// Null while loading.
  List<PostComment>? _comments;
  Object? _commentsError;

  SocialController get _social => context.read<SocialController>();

  bool get _isMine => _social.me?.userId == _post.owner.userId;

  @override
  void initState() {
    super.initState();
    if (widget.fromFeed) _loadComments();
  }

  @override
  void dispose() {
    _commentField.dispose();
    super.dispose();
  }

  Future<void> _toggleSaved() async {
    if (_busy) return;
    final saved = !_post.saved;
    setState(() => _busy = true);
    try {
      await _social.repository.setSaved(_post, saved: saved);
      if (!mounted) return;
      setState(() => _post = _post.copyWith(saved: saved));
      context.showSnack(saved ? 'Saved to your ideas' : 'Removed from ideas');
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Shows the like straight away and takes it back if the server refuses.
  Future<void> _toggleLiked() async {
    if (_liking) return;
    final before = _post;
    final liked = !before.liked;
    setState(() {
      _liking = true;
      _post = before.copyWith(
        liked: liked,
        likes: math.max(0, before.likes + (liked ? 1 : -1)),
      );
    });
    try {
      await _social.repository.setLiked(before, liked: liked);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _post = _post.copyWith(liked: before.liked, likes: before.likes),
      );
      context.showErrorSnack(error);
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _loadComments() async {
    setState(() {
      _comments = null;
      _commentsError = null;
    });
    try {
      final comments = await _social.repository.comments(_post);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _post = _post.copyWith(comments: comments.length);
      });
    } catch (error) {
      if (mounted) setState(() => _commentsError = error);
    }
  }

  Future<void> _sendComment() async {
    final body = _commentField.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final comment = await _social.repository.addComment(_post, body);
      if (!mounted) return;
      _commentField.clear();
      setState(() {
        _comments = [...?_comments, comment];
        _post = _post.copyWith(comments: _post.comments + 1);
      });
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Delete for the author and the post's owner; Report for everyone else.
  Future<void> _showCommentMenu(PostComment comment) async {
    final me = _social.me?.userId;
    final mine = comment.author.userId == me;
    final canDelete = mine || _isMine;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Delete comment'),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
            if (!mine)
              ListTile(
                leading: const Icon(Icons.error_outline_rounded),
                title: const Text('Report'),
                onTap: () => Navigator.of(sheetContext).pop('report'),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'delete':
        await _deleteComment(comment);
      case 'report':
        await SocialFlows.report(
          context,
          comment.author,
          outfitId: _post.outfit.id,
        );
    }
  }

  Future<void> _deleteComment(PostComment comment) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this comment?',
      message: 'It will be removed for everyone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await _social.repository.deleteComment(comment.id);
      if (!mounted) return;
      setState(() {
        _comments = [
          for (final c in _comments ?? const <PostComment>[])
            if (c.id != comment.id) c,
        ];
        _post = _post.copyWith(comments: math.max(0, _post.comments - 1));
      });
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
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
        if (!didPop) Navigator.of(context).pop(_post);
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
                  onBlocked: () => Navigator.of(context).pop(),
                ),
                icon: const Icon(Icons.more_horiz_rounded),
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
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
                        onTap: () =>
                            SocialFlows.openProfile(context, owner.userId),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxs),
                          child: Row(
                            children: [
                              UserAvatar(
                                name: owner.name,
                                url: owner.avatarUrl,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(owner.username, style: text.titleMedium),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.fromFeed) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        IconButton(
                          tooltip: _post.liked ? 'Unlike' : 'Like',
                          onPressed: _liking ? null : _toggleLiked,
                          icon: Icon(
                            _post.liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: _post.liked ? palette.danger : null,
                          ),
                        ),
                        Text(
                          AppFormatters.count(_post.likes, 'like'),
                          style: text.bodyMedium,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: palette.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          AppFormatters.count(_post.comments, 'comment'),
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Clothes in outfit',
                    style: text.bodyMedium?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height:
                        AppSizes.recentItemWidth / AppSizes.clothingImageAspect,
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
                          onTap: () =>
                              SocialFlows.showPiece(context, items[index]),
                        ),
                      ),
                    ),
                  ),
                  if (widget.fromFeed) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Comments',
                      style: text.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ..._commentsSection(context),
                  ],
                ],
              ),
            ),
            if (widget.fromFeed) _composer(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _commentsSection(BuildContext context) {
    final comments = _comments;
    if (_commentsError != null) {
      return [
        Row(
          children: [
            const Expanded(child: Text('Couldn’t load comments.')),
            TextButton(onPressed: _loadComments, child: const Text('Retry')),
          ],
        ),
      ];
    }
    if (comments == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (comments.isEmpty) {
      return [
        Text(
          'No comments yet. Be the first to say something!',
          style: context.textTheme.bodyMedium,
        ),
      ];
    }
    return [
      for (final comment in comments)
        CommentTile(
          comment: comment,
          onAuthorTap: () =>
              SocialFlows.openProfile(context, comment.author.userId),
          onMore: () => _showCommentMenu(comment),
        ),
    ];
  }

  Widget _composer(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentField,
                  enabled: !_sending,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: PostComment.maxLength,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendComment(),
                  decoration: const InputDecoration(
                    hintText: 'Add a comment…',
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Send',
                onPressed: _sending ? null : _sendComment,
                icon: _sending
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
