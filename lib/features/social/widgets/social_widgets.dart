import 'dart:io';

import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/adaptive_grid.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit_placement.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';
import 'package:all_fits/core/l10n/l10n.dart';

/// Round profile photo, or initials when there is none.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.url,
    this.size = 40,
    this.photoPath,
    this.color,
  });

  final String name;
  final String? url;
  final double size;

  /// Fill behind the initials; a soft grey by default.
  final Color? color;

  /// A just-picked photo on the device, shown before it is uploaded.
  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final initials = AppFormatters.initials(name);
    final ImageProvider? source = photoPath != null
        ? FileImage(File(photoPath!))
        : url != null
        ? NetworkImage(url!)
        : null;
    final image = source == null
        ? null
        : ResizeImage.resizeIfNeeded(
            (size * MediaQuery.devicePixelRatioOf(context)).round(),
            null,
            source,
          );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? palette.surfaceMuted,
        shape: BoxShape.circle,
        image: image == null
            ? null
            : DecorationImage(image: image, fit: BoxFit.cover),
      ),
      child: image != null
          ? null
          : initials.isEmpty
          ? Icon(
              Icons.person_outline_rounded,
              size: size * 0.5,
              color: palette.textSecondary,
            )
          : Text(
              initials,
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w600,
                color: palette.ink,
              ),
            ),
    );
  }
}

/// Username in bold over the display name, as in Fits' people lists.
class ProfileRow extends StatelessWidget {
  const ProfileRow({
    super.key,
    required this.profile,
    this.onTap,
    this.trailing,
  });

  final SocialProfile profile;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      leading: UserAvatar(name: profile.name, url: profile.avatarUrl),
      title: Row(
        children: [
          Flexible(
            child: Text(
              profile.username,
              style: text.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (profile.isPrivate) ...[
            const SizedBox(width: AppSpacing.xxs),
            Icon(
              Icons.lock_outline_rounded,
              size: 14,
              color: context.palette.textSecondary,
            ),
          ],
        ],
      ),
      subtitle: profile.displayName.isEmpty
          ? null
          : Text(
              profile.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: trailing,
    );
  }
}

/// A "1570 / Followers" pair in a profile header.
class CountLabel extends StatelessWidget {
  const CountLabel({
    super.key,
    required this.count,
    required this.label,
    this.onTap,
  });

  final int count;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$count', style: text.titleLarge),
            Text(
              label,
              style: text.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar, name and follower counts at the top of a profile.
class ProfileHeaderRow extends StatelessWidget {
  const ProfileHeaderRow({
    super.key,
    required this.profile,
    required this.followers,
    required this.following,
    this.onFollowers,
    this.onFollowing,
    this.avatarBadge,
  });

  final SocialProfile profile;
  final int followers;
  final int following;
  final VoidCallback? onFollowers;
  final VoidCallback? onFollowing;

  /// Drawn on the avatar's corner, e.g. a "+" on your own profile.
  final Widget? avatarBadge;

  static const double _avatarSize = 88;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return Row(
      children: [
        Stack(
          children: [
            UserAvatar(
              name: profile.name,
              url: profile.avatarUrl,
              size: _avatarSize,
            ),
            if (avatarBadge != null)
              Positioned(right: 0, bottom: 0, child: avatarBadge!),
          ],
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.name,
                style: text.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  CountLabel(
                    count: followers,
                    label: tr('Followers'),
                    onTap: onFollowers,
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  CountLabel(
                    count: following,
                    label: tr('Following'),
                    onTap: onFollowing,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Fits' grey and black profile buttons share this shape.
ButtonStyle profileButtonStyle(BuildContext context, {bool primary = false}) {
  final palette = context.palette;
  return FilledButton.styleFrom(
    minimumSize: const Size(0, AppSizes.compactButtonHeight + 4),
    backgroundColor: primary ? palette.ink : palette.surfaceMuted,
    foregroundColor: primary ? palette.onInk : palette.ink,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  );
}

/// An outfit flat-lay in a card, as on Fits' Community grid: its owner in a
/// band above the pieces and its likes and comments in a band below, so
/// neither covers the clothes.
class SocialOutfitCard extends StatelessWidget {
  const SocialOutfitCard({
    super.key,
    required this.items,
    required this.layout,
    required this.onTap,
    this.owner,
    this.caption,
    this.stats,
  });

  final List<ClothingItem> items;
  final List<OutfitPlacement> layout;
  final VoidCallback onTap;
  final SocialProfile? owner;

  /// Small line under the card, e.g. "For you · 2 days ago".
  final String? caption;

  /// The band under the flat-lay, e.g. [PostStats].
  final Widget? stats;

  static const double _avatarSize = 32;

  /// Height of the owner band; give it to [OutfitCardSliverGrid].
  static const double ownerBandHeight =
      _avatarSize + AppSpacing.sm + AppSpacing.xxs;

  /// Height of the stats band; give it to [OutfitCardSliverGrid].
  static const double statsBandHeight = 24 + AppSpacing.xxs + AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(AppRadius.md);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: palette.border),
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: ColoredBox(
                  color: palette.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (owner != null)
                        SizedBox(
                          height: ownerBandHeight,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.sm,
                              AppSpacing.sm,
                              AppSpacing.sm,
                              AppSpacing.xxs,
                            ),
                            child: Row(
                              children: [
                                UserAvatar(
                                  name: owner!.name,
                                  url: owner!.avatarUrl,
                                  size: _avatarSize,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    owner!.username,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textTheme.titleSmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: OutfitCanvas(items: items, layout: layout),
                      ),
                      if (stats != null)
                        SizedBox(
                          height: statsBandHeight,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.sm,
                              AppSpacing.xxs,
                              AppSpacing.sm,
                              AppSpacing.sm,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: stats,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// A Community post's likes and comments, e.g. "♥ 12  💬 3".
class PostStats extends StatelessWidget {
  const PostStats({super.key, required this.post});

  final FeedPost post;

  static const double _iconSize = 22;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.textTheme.titleSmall;
    return Semantics(
      label: tr('{0}, {1}', [
        AppFormatters.count(post.likes, 'like'),
        AppFormatters.count(post.comments, 'comment'),
      ]),
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(
            post.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: _iconSize,
            color: post.liked ? palette.danger : palette.ink,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text('${post.likes}', style: style),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: _iconSize,
            color: palette.ink,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text('${post.comments}', style: style),
        ],
      ),
    );
  }
}

/// One comment: who wrote it, when, and what. Long press opens Delete or
/// Report, as in Fits.
class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    this.onAuthorTap,
    this.onMore,
  });

  final PostComment comment;
  final VoidCallback? onAuthorTap;

  /// Opens Delete / Report on long press.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final author = comment.author;
    return InkWell(
      onLongPress: onMore,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onAuthorTap,
              child: UserAvatar(
                name: author.name,
                url: author.avatarUrl,
                size: AppSizes.thumbSm,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: author.username, style: text.titleSmall),
                        TextSpan(
                          text: ' ${AppFormatters.timeAgo(comment.createdAt)}',
                          style: text.bodySmall?.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(comment.body, style: text.bodyLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A piece in Community > Clothes: a soft grey card with its owner on top,
/// the cut-out photo, and its name.
class CommunityItemCard extends StatelessWidget {
  const CommunityItemCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final CommunityItem entry;
  final VoidCallback onTap;

  /// Leaves room for the owner row and the name under the photo.
  static const double footerHeight = 84;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final owner = entry.owner;
    return Material(
      color: palette.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  UserAvatar(
                    name: owner.name,
                    url: owner.avatarUrl,
                    size: 28,
                    // Stands out from the card's own grey.
                    color: palette.surface,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      owner.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: ClothingImage(
                  item: entry.item,
                  cutout: true,
                  fit: BoxFit.contain,
                  decodeWidth: 220,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                entry.item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [CommunityItemCard]s, two across on a phone.
class CommunityItemSliverGrid extends StatelessWidget {
  const CommunityItemSliverGrid({
    super.key,
    required this.entries,
    required this.onTap,
  });

  final List<CommunityItem> entries;
  final ValueChanged<CommunityItem> onTap;

  @override
  Widget build(BuildContext context) {
    final footer = MediaQuery.textScalerOf(context)
        .scale(CommunityItemCard.footerHeight);
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverGrid.builder(
        gridDelegate: AdaptiveGrid.imageTiles(
          width: constraints.crossAxisExtent,
          imageAspect: 1,
          footerHeight: footer,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) => CommunityItemCard(
          entry: entries[index],
          onTap: () => onTap(entries[index]),
        ),
      ),
    );
  }
}

/// Grey rounded boxes shown while a Community grid loads, as in Fits.
class LoadingTilesSliverGrid extends StatelessWidget {
  const LoadingTilesSliverGrid({
    super.key,
    required this.aspectRatio,
    this.spacing = AppSpacing.sm,
  });

  final double aspectRatio;
  final double spacing;

  static const int _count = 6;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverGrid.builder(
        gridDelegate: AdaptiveGrid.imageTiles(
          width: constraints.crossAxisExtent,
          imageAspect: aspectRatio,
          footerHeight: 0,
          spacing: spacing,
          runSpacing: spacing,
        ),
        itemCount: _count,
        itemBuilder: (_, _) => DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        ),
      ),
    );
  }
}

/// Follow, Requested or Following, as on Fits' people lists.
class FollowButton extends StatelessWidget {
  const FollowButton({
    super.key,
    required this.status,
    required this.onPressed,
  });

  /// Null when the user doesn't follow them yet.
  final FollowStatus? status;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final following = status != null;
    return FilledButton(
      onPressed: onPressed,
      style: profileButtonStyle(context, primary: !following).copyWith(
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
      ),
      child: Text(switch (status) {
        null => tr('Follow'),
        FollowStatus.pending => tr('Requested'),
        FollowStatus.accepted => tr('Following'),
      }),
    );
  }
}

/// Someone in Community > Users: avatar, username and name, Follow, then a
/// row of their newest pieces.
class SuggestedPersonTile extends StatelessWidget {
  const SuggestedPersonTile({
    super.key,
    required this.person,
    required this.status,
    required this.onTap,
    required this.onFollow,
  });

  final SuggestedPerson person;
  final FollowStatus? status;
  final VoidCallback onTap;
  final VoidCallback? onFollow;

  static const double _avatarSize = 56;
  static const double _pieceHeight = 96;
  static const int _pieces = 5;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final palette = context.palette;
    final profile = person.profile;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.md,
          AppSpacing.page,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                UserAvatar(
                  name: profile.name,
                  url: profile.avatarUrl,
                  size: _avatarSize,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium,
                            ),
                          ),
                          if (profile.isPrivate) ...[
                            const SizedBox(width: AppSpacing.xxs),
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 14,
                              color: palette.textSecondary,
                            ),
                          ],
                        ],
                      ),
                      if (profile.displayName.isNotEmpty)
                        Text(
                          profile.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FollowButton(status: status, onPressed: onFollow),
              ],
            ),
            if (person.items.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: _pieceHeight,
                child: Row(
                  children: [
                    for (final item in person.items.take(_pieces))
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xxs,
                          ),
                          child: ClothingImage(
                            item: item,
                            cutout: true,
                            fit: BoxFit.contain,
                            decodeWidth: _pieceHeight,
                          ),
                        ),
                      ),
                    for (var i = person.items.length; i < _pieces; i++)
                      const Spacer(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// [SocialOutfitCard]s, two across on a phone.
class OutfitCardSliverGrid extends StatelessWidget {
  const OutfitCardSliverGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.withCaption = false,
    this.bandHeight = 0,
    this.spacing = AppSpacing.sm,
    this.runSpacing = AppSpacing.lg,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;

  /// Leaves room for each card's caption line.
  final bool withCaption;

  /// Height of the cards' owner and stats bands, e.g.
  /// [SocialOutfitCard.ownerBandHeight].
  final double bandHeight;
  final double spacing;
  final double runSpacing;

  static const double _captionHeight = 28;

  @override
  Widget build(BuildContext context) {
    final footer =
        bandHeight +
        (withCaption
            ? MediaQuery.textScalerOf(context).scale(_captionHeight)
            : 0.0);
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverGrid.builder(
        gridDelegate: AdaptiveGrid.imageTiles(
          width: constraints.crossAxisExtent,
          imageAspect: AppSizes.outfitImageAspect,
          footerHeight: footer,
          spacing: spacing,
          runSpacing: runSpacing,
        ),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// All / Tops / Bottoms… for the categories present in [items].
class CategoryPillBar extends StatelessWidget {
  const CategoryPillBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<ClothingItem> items;
  final ClothingCategory? selected;
  final ValueChanged<ClothingCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final present = {for (final item in items) item.category};
    return PillBar(
      pills: [
        SelectablePill(
          label: tr('All'),
          selected: selected == null,
          onTap: () => onSelected(null),
        ),
        for (final category in ClothingCategory.values)
          if (present.contains(category))
            SelectablePill(
              label: category.label,
              selected: selected == category,
              onTap: () => onSelected(category),
            ),
      ],
    );
  }
}

/// Bell with Fits' red count badge.
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    required this.count,
    required this.onPressed,
  });

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: count == 0
          ? tr('Notifications')
          : tr('Notifications, {0} new', [count]),
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: context.palette.danger,
        label: Text(count > 9 ? '9+' : '$count'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}

/// An icon with its count, e.g. ♡ 118, as under a Fits outfit or piece.
/// The count is left out at zero.
class CountButton extends StatelessWidget {
  const CountButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.count,
    required this.onPressed,
    this.color,
  });

  final String tooltip;
  final IconData icon;
  final int count;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: AppSizes.iconLg, color: color),
              if (count > 0) ...[
                const SizedBox(width: AppSpacing.xs),
                Text('$count', style: context.textTheme.titleMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
