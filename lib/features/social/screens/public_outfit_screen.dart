import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/social/social_flows.dart';
import 'package:all_fits/features/social/widgets/comments_sheet.dart';
import 'package:all_fits/features/social/widgets/social_widgets.dart';
import 'package:all_fits/core/l10n/l10n.dart';

/// A shared outfit, as on Fits: the flat-lay with a round back button on
/// it, likes and comments, who made it, and its pieces. Community posts can
/// be liked and commented on. Pops with the post as it was left, or with
/// nothing when its owner was blocked.
class PublicOutfitScreen extends StatefulWidget {
  const PublicOutfitScreen({
    super.key,
    required this.post,
    this.fromFeed = true,
  });

  final FeedPost post;

  /// Only Community posts can be liked and commented on.
  final bool fromFeed;

  @override
  State<PublicOutfitScreen> createState() => _PublicOutfitScreenState();
}

class _PublicOutfitScreenState extends State<PublicOutfitScreen> {
  late FeedPost _post = widget.post;
  bool _liking = false;

  static const double _pieceSize = 72;

  SocialController get _social => context.read<SocialController>();

  bool get _isMine => _social.me?.userId == _post.owner.userId;

  /// Shows the like straight away and takes it back if the server refuses.
  Future<void> _toggleLiked() async {
    if (_liking) return;
    if (!await SocialFlows.requireProfile(context) || !mounted) return;
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

  Future<void> _openComments() async {
    final repository = _social.repository;
    final count = await CommentsSheet.show(
      context,
      ownerId: _post.owner.userId,
      outfitId: _post.outfit.id,
      load: () => repository.comments(_post),
      add: (body) => repository.addComment(_post, body),
      delete: repository.deleteComment,
    );
    if (count != null && mounted) {
      setState(() => _post = _post.copyWith(comments: count));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final items = _post.orderedItems;
    final owner = _post.owner;
    final radius = BorderRadius.circular(AppRadius.xl);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_post);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.xs,
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
                        borderRadius: radius,
                        border: Border.all(color: palette.border),
                      ),
                      child: ClipRRect(
                        borderRadius: radius,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            OutfitCanvas(
                              items: items,
                              layout: _post.outfit.layout,
                            ),
                            Positioned(
                              top: AppSpacing.sm,
                              left: AppSpacing.sm,
                              child: _RoundButton(
                                tooltip: MaterialLocalizations.of(context)
                                    .backButtonTooltip,
                                icon: Icons.chevron_left_rounded,
                                onPressed: () => Navigator.maybePop(context),
                              ),
                            ),
                            if (!_isMine)
                              Positioned(
                                top: AppSpacing.sm,
                                right: AppSpacing.sm,
                                child: _RoundButton(
                                  tooltip: tr('More'),
                                  icon: Icons.more_horiz_rounded,
                                  onPressed: () => SocialFlows.showPostMenu(
                                    context,
                                    _post,
                                    onBlocked: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  if (widget.fromFeed) ...[
                    CountButton(
                      tooltip: _post.liked ? tr('Unlike') : tr('Like'),
                      icon: _post.liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _post.liked ? palette.danger : null,
                      count: _post.likes,
                      onPressed: _liking ? null : _toggleLiked,
                    ),
                    CountButton(
                      tooltip: tr('Comments'),
                      icon: Icons.chat_bubble_outline_rounded,
                      count: _post.comments,
                      onPressed: _openComments,
                    ),
                  ],
                  const Spacer(),
                  InkWell(
                    onTap: () => SocialFlows.openProfile(context, owner.userId),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxs),
                      child: Row(
                        children: [
                          UserAvatar(name: owner.name, url: owner.avatarUrl),
                          const SizedBox(width: AppSpacing.sm),
                          Text(owner.username, style: text.titleMedium),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                tr('Clothes in outfit'),
                style: text.bodyMedium?.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: _pieceSize,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Semantics(
                      button: true,
                      label: item.name,
                      child: Material(
                        color: palette.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () =>
                              SocialFlows.openPiece(context, owner, item),
                          child: SizedBox.square(
                            dimension: _pieceSize,
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              child: ClothingImage(
                                item: item,
                                cutout: true,
                                fit: BoxFit.contain,
                                decodeWidth: _pieceSize,
                              ),
                            ),
                          ),
                        ),
                      ),
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

/// Fits' grey see-through circle over a photo.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.4),
        foregroundColor: Colors.white,
      ),
      icon: Icon(icon, size: AppSizes.iconLg),
    );
  }
}
