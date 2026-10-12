import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/constants/app_durations.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/color_swatch.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/clothing_item.dart';

/// Image-first wardrobe tile: photo, name and a short meta line.
class ClothingTile extends StatelessWidget {
  const ClothingTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onFavorite,
    this.onLongPress,
    this.selected = false,
    this.decodeWidth = 260,
  });

  final ClothingItem item;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onLongPress;

  /// Shows a selection ring and check mark (used by pickers).
  final bool selected;
  final double decodeWidth;

  static const double _overlayInset = 8;

  static String metaLine(ClothingItem item) =>
      [item.category.singularLabel, ?item.brand].join(' · ');

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final radius = BorderRadius.circular(AppRadius.lg);

    return Semantics(
      button: true,
      selected: selected,
      label: item.name,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: AppSizes.clothingImageAspect,
              child: AnimatedContainer(
                duration: AppDurations.fast,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: selected ? palette.ink : Colors.transparent,
                    width: 2,
                  ),
                ),
                padding: EdgeInsets.all(selected ? 3 : 0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClothingImage(
                      item: item,
                      borderRadius: radius,
                      decodeWidth: decodeWidth,
                    ),
                    if (onFavorite != null)
                      Positioned(
                        top: _overlayInset,
                        right: _overlayInset,
                        child: FavoriteOverlayButton(
                          isFavorite: item.isFavorite,
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
                      Positioned(
                        top: _overlayInset,
                        left: _overlayInset,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: palette.ink,
                          child: Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: palette.onInk,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.name,
              style: text.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                if (item.color != null) ...[
                  ColorSwatchDot(color: item.color!, size: 10),
                  const SizedBox(width: AppSpacing.xxs + 2),
                ],
                Expanded(
                  child: Text(
                    metaLine(item),
                    style: text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
