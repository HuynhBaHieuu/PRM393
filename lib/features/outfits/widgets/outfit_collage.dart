import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit_slot.dart';

/// Compact preview of an outfit as a photo collage, for cards and thumbnails.
///
/// 1 item fills the frame, 2 sit side by side, 3 use one large and two small
/// tiles, and 4+ use a 2×2 grid with a "+N" overlay.
class OutfitCollage extends StatelessWidget {
  const OutfitCollage({
    super.key,
    required this.items,
    this.borderRadius = AppRadius.lg,
    this.gap = 2,
    this.decodeWidth = 200,
  });

  final List<ClothingItem> items;
  final double borderRadius;
  final double gap;
  final double decodeWidth;

  static const int _maxTiles = 4;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ColoredBox(
        color: palette.surface,
        child: items.isEmpty
            ? ColoredBox(
                color: palette.surfaceMuted,
                child: Center(
                  child: Icon(
                    Icons.style_outlined,
                    color: palette.textTertiary,
                  ),
                ),
              )
            : _layout(context),
      ),
    );
  }

  Widget _tile(ClothingItem item, {double? width}) =>
      ClothingImage(item: item, decodeWidth: width ?? decodeWidth);

  Widget _layout(BuildContext context) {
    final gapBox = SizedBox(width: gap, height: gap);
    switch (items.length) {
      case 1:
        return SizedBox.expand(child: _tile(items[0]));
      case 2:
        return Row(
          children: [
            Expanded(child: _tile(items[0])),
            gapBox,
            Expanded(child: _tile(items[1])),
          ],
        );
      case 3:
        return Row(
          children: [
            Expanded(child: _tile(items[0])),
            gapBox,
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _tile(items[1], width: decodeWidth / 2)),
                  gapBox,
                  Expanded(child: _tile(items[2], width: decodeWidth / 2)),
                ],
              ),
            ),
          ],
        );
      default:
        final shown = items.take(_maxTiles).toList();
        final hidden = items.length - _maxTiles;
        Widget cell(int index) {
          final tile = _tile(shown[index], width: decodeWidth / 2);
          if (index != _maxTiles - 1 || hidden <= 0) return tile;
          return Stack(
            fit: StackFit.expand,
            children: [
              tile,
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Text(
                    '+$hidden',
                    style: context.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: cell(0)),
                  gapBox,
                  Expanded(child: cell(1)),
                ],
              ),
            ),
            gapBox,
            Expanded(
              child: Row(
                children: [
                  Expanded(child: cell(2)),
                  gapBox,
                  Expanded(child: cell(3)),
                ],
              ),
            ),
          ],
        );
    }
  }
}

/// Larger "outfit board": main pieces stacked top to bottom, with
/// accessories in a narrow side column.
class OutfitComposition extends StatelessWidget {
  const OutfitComposition({
    super.key,
    required this.items,
    this.borderRadius = AppRadius.xl,
  });

  final List<ClothingItem> items;
  final double borderRadius;

  static const double _gap = AppSpacing.xs;
  static const int _mainFlex = 3;
  static const int _sideFlex = 1;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final main = <ClothingItem>[];
    final side = <ClothingItem>[];
    for (final item in items) {
      final slot = OutfitSlot.forCategory(item.category);
      (slot == OutfitSlot.accessories ? side : main).add(item);
    }
    // Avoid an empty main column when an outfit is only accessories.
    if (main.isEmpty) {
      main.addAll(side);
      side.clear();
    }

    Widget column(List<ClothingItem> pieces) => Column(
      children: [
        for (var i = 0; i < pieces.length; i++) ...[
          if (i > 0) const SizedBox(height: _gap),
          Expanded(
            child: ClothingImage(
              item: pieces[i],
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(AppRadius.md),
              decodeWidth: 360,
            ),
          ),
        ],
      ],
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: _mainFlex, child: column(main)),
          if (side.isNotEmpty) ...[
            const SizedBox(width: _gap),
            Expanded(flex: _sideFlex, child: column(side)),
          ],
        ],
      ),
    );
  }
}
