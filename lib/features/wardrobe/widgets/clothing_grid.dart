import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/utils/adaptive_grid.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/features/wardrobe/widgets/clothing_tile.dart';

/// Responsive sliver grid of [ClothingTile]s.
class ClothingSliverGrid extends StatelessWidget {
  const ClothingSliverGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.onFavorite,
    this.isSelected,
    this.onLongPress,
  });

  final List<ClothingItem> items;
  final ValueChanged<ClothingItem> onTap;
  final ValueChanged<ClothingItem>? onFavorite;
  final ValueChanged<ClothingItem>? onLongPress;
  final bool Function(ClothingItem item)? isSelected;

  @override
  Widget build(BuildContext context) {
    final footer = MediaQuery.textScalerOf(context)
        .scale(AppSizes.clothingTileFooterHeight);
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverGrid(
        gridDelegate: AdaptiveGrid.imageTiles(
          width: constraints.crossAxisExtent,
          imageAspect: AppSizes.clothingImageAspect,
          footerHeight: footer,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = items[index];
          return ClothingTile(
            key: ValueKey(item.id),
            item: item,
            selected: isSelected?.call(item) ?? false,
            onTap: () => onTap(item),
            onFavorite: onFavorite == null ? null : () => onFavorite!(item),
            onLongPress: onLongPress == null ? null : () => onLongPress!(item),
          );
        }, childCount: items.length),
      ),
    );
  }
}
