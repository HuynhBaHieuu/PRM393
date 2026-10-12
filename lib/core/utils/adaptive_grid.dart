import 'package:flutter/rendering.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';

/// Computes grid layouts that adapt to the available width instead of
/// hard-coding a column count.
abstract final class AdaptiveGrid {
  static const int minColumns = 2;
  static const int maxColumns = 6;

  static int columnsFor(
    double width, {
    double minTileWidth = AppSizes.gridMinTileWidth,
    double spacing = AppSpacing.md,
  }) {
    final columns = ((width + spacing) / (minTileWidth + spacing)).floor();
    return columns.clamp(minColumns, maxColumns);
  }

  /// A delegate for tiles made of an image of [imageAspect] (width / height)
  /// plus a text footer of [footerHeight].
  static SliverGridDelegate imageTiles({
    required double width,
    required double imageAspect,
    required double footerHeight,
    double minTileWidth = AppSizes.gridMinTileWidth,
    double spacing = AppSpacing.md,
  }) {
    final columns = columnsFor(
      width,
      minTileWidth: minTileWidth,
      spacing: spacing,
    );
    final tileWidth = (width - spacing * (columns - 1)) / columns;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: spacing,
      mainAxisSpacing: AppSpacing.lg,
      mainAxisExtent: tileWidth / imageAspect + footerHeight,
    );
  }
}
