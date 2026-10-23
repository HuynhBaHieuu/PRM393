import 'dart:io';

import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/adaptive_grid.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit_placement.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';

/// Round profile photo, or initials when there is none.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.url,
    this.size = 40,
    this.photoPath,
  });

  final String name;
  final String? url;
  final double size;

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
        color: palette.surfaceMuted,
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
                    label: 'Followers',
                    onTap: onFollowers,
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  CountLabel(
                    count: following,
                    label: 'Following',
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

/// An outfit flat-lay with its owner pinned to the top-left corner, as on
/// Fits' Community grid.
class SocialOutfitCard extends StatelessWidget {
  const SocialOutfitCard({
    super.key,
    required this.items,
    required this.layout,
    required this.onTap,
    this.owner,
    this.caption,
  });

  final List<ClothingItem> items;
  final List<OutfitPlacement> layout;
  final VoidCallback onTap;
  final SocialProfile? owner;

  /// Small line under the card, e.g. "For you · 2 days ago".
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(AppRadius.lg);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
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
                    OutfitCanvas(items: items, layout: layout),
                    if (owner != null)
                      Positioned(
                        top: AppSpacing.xs,
                        left: AppSpacing.xs,
                        right: AppSpacing.xs,
                        child: Row(
                          children: [
                            UserAvatar(
                              name: owner!.name,
                              url: owner!.avatarUrl,
                              size: 24,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                owner!.username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textTheme.labelLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
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

/// [SocialOutfitCard]s, two across on a phone.
class OutfitCardSliverGrid extends StatelessWidget {
  const OutfitCardSliverGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.withCaption = false,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;

  /// Leaves room for each card's caption line.
  final bool withCaption;

  static const double _captionHeight = 28;

  @override
  Widget build(BuildContext context) {
    final footer = withCaption
        ? MediaQuery.textScalerOf(context).scale(_captionHeight)
        : 0.0;
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverGrid.builder(
        gridDelegate: AdaptiveGrid.imageTiles(
          width: constraints.crossAxisExtent,
          imageAspect: AppSizes.outfitImageAspect,
          footerHeight: footer,
          spacing: AppSpacing.sm,
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
          label: 'All',
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
      tooltip: count == 0 ? 'Notifications' : 'Notifications, $count new',
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
