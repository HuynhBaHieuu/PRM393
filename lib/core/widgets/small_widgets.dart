import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';

/// Heart toggle drawn on top of photos.
class FavoriteOverlayButton extends StatelessWidget {
  const FavoriteOverlayButton({
    super.key,
    required this.isFavorite,
    required this.onPressed,
    this.size = 32,
  });

  final bool isFavorite;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      child: Material(
        color: palette.surface.withValues(alpha: 0.9),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              isFavorite ? Icons.favorite_rounded : Icons.favorite_border,
              size: size * 0.55,
              color: isFavorite ? palette.accent : palette.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small label, e.g. "Archived" or an occasion.
class TagLabel extends StatelessWidget {
  const TagLabel(this.text, {super.key, this.inverted = false, this.icon});

  final String text;
  final bool inverted;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = inverted ? palette.onInk : palette.ink;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: inverted ? palette.ink : palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelMedium?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two side-by-side figures such as "Worn 3 times" / "Last worn Oct 1".
class StatPair extends StatelessWidget {
  const StatPair({super.key, required this.items});

  final List<(String label, String value)> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: palette.border)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) VerticalDivider(color: palette.border, width: 1),
              Expanded(
                child: Column(
                  children: [
                    Text(items[i].$2, style: text.titleLarge),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(items[i].$1.toUpperCase(), style: text.labelSmall),
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

/// Title row used at the top of bottom sheets.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.textTheme.headlineSmall)),
          ?trailing,
        ],
      ),
    );
  }
}

/// A labelled block within forms and detail pages.
class LabeledSection extends StatelessWidget {
  const LabeledSection({
    super.key,
    required this.label,
    required this.child,
    this.trailing,
  });

  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: context.textTheme.labelSmall,
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}
