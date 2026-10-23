import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/constants/app_durations.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/clothing_item.dart';

/// Image-only wardrobe tile: the piece cut out of its background.
class ClothingTile extends StatelessWidget {
  const ClothingTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onFavorite,
    this.onLongPress,
    this.selected = false,
    this.dimmed = false,
    this.decodeWidth = 260,
  });

  final ClothingItem item;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onLongPress;

  /// Shows a selection ring and check mark (used by pickers).
  final bool selected;

  /// Fades the photo, e.g. for archived pieces inside a collection.
  final bool dimmed;
  final double decodeWidth;

  static const double _overlayInset = 6;
  static const double _dimmedOpacity = 0.4;

  static String metaLine(ClothingItem item) =>
      [item.category.singularLabel, ?item.brand].join(' · ');

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(AppRadius.md);

    return Semantics(
      button: true,
      selected: selected,
      label: item.name,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? palette.ink : Colors.transparent,
              width: 2,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: dimmed ? _dimmedOpacity : 1,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxs),
                  child: ClothingImage(
                    item: item,
                    cutout: true,
                    fit: BoxFit.contain,
                    borderRadius: radius,
                    decodeWidth: decodeWidth,
                  ),
                ),
              ),
              if (onFavorite != null && item.isFavorite)
                Positioned(
                  top: _overlayInset,
                  right: _overlayInset,
                  child: FavoriteOverlayButton(
                    isFavorite: true,
                    onPressed: onFavorite!,
                  ),
                ),
              if (item.isArchived)
                const Positioned(
                  left: _overlayInset,
                  bottom: _overlayInset,
                  child: TagLabel('Archived', inverted: true),
                ),
              if (selected)
                const Positioned(
                  top: _overlayInset,
                  left: _overlayInset,
                  child: SelectionBadge(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
