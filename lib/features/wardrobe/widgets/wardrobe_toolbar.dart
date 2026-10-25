import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/constants/app_durations.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/data/models/clothing_category.dart';

/// Fits' closet toolbar: small category chips (the chosen one a black pill),
/// then a round filter button and, optionally, a round "⋯" button.
class ClothesToolbar extends StatelessWidget {
  const ClothesToolbar({
    super.key,
    required this.category,
    required this.onCategory,
    required this.onFilter,
    this.filterCount = 0,
    this.onMore,
  });

  final ClothingCategory? category;
  final ValueChanged<ClothingCategory?> onCategory;
  final VoidCallback onFilter;
  final int filterCount;
  final VoidCallback? onMore;

  static const double _height = 48;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: Row(
        children: [
          Expanded(
            child: ShaderMask(
              // Fades chips out under the buttons, as in Fits.
              shaderCallback: (rect) => const LinearGradient(
                colors: [Colors.black, Colors.black, Colors.transparent],
                stops: [0, 0.88, 1],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: AppSpacing.page),
                children: [
                  CategoryChip(
                    label: 'All',
                    selected: category == null,
                    onTap: () => onCategory(null),
                  ),
                  for (final c in ClothingCategory.values)
                    CategoryChip(
                      label: c.label,
                      selected: category == c,
                      onTap: () => onCategory(category == c ? null : c),
                    ),
                ],
              ),
            ),
          ),
          RoundToolButton(
            icon: Icons.filter_list_rounded,
            tooltip: 'Filter',
            badgeCount: filterCount,
            onPressed: onFilter,
          ),
          if (onMore != null) ...[
            const SizedBox(width: AppSpacing.xs),
            RoundToolButton(
              icon: Icons.more_horiz_rounded,
              tooltip: 'More',
              onPressed: onMore!,
            ),
          ],
          const SizedBox(width: AppSpacing.page),
        ],
      ),
    );
  }
}

/// A small category chip: grey text, or white text on a black pill.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: selected ? palette.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            ),
            child: Text(
              label,
              style: context.textTheme.titleSmall?.copyWith(
                color: selected ? palette.onInk : palette.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grey round icon button with an optional count badge.
class RoundToolButton extends StatelessWidget {
  const RoundToolButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final button = IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(AppSizes.headerActionSize + 4),
        backgroundColor: palette.surfaceMuted,
        foregroundColor: palette.ink,
      ),
    );
    if (badgeCount == 0) return button;
    return Badge(
      label: Text('$badgeCount'),
      backgroundColor: palette.ink,
      textColor: palette.onInk,
      child: button,
    );
  }
}
