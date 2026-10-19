import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/constants/app_durations.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/data/models/clothing_color.dart';

/// Round color chip. "Multicolor" is drawn as four flat blocks.
class ColorSwatchDot extends StatelessWidget {
  const ColorSwatchDot({
    super.key,
    required this.color,
    this.size = AppSizes.swatchDot,
    this.child,
  });

  final ClothingColor color;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    const blocks = ClothingColor.multiBlocks;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.isMulti ? null : color.swatch,
        shape: BoxShape.circle,
      ),
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.palette.border),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (color.isMulti)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var row = 0; row < blocks.length; row += 2)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final block in blocks.skip(row).take(2))
                          Expanded(child: ColoredBox(color: block)),
                      ],
                    ),
                  ),
              ],
            ),
          ?child,
        ],
      ),
    );
  }
}

/// Row of tappable color swatches. Tapping the selected swatch clears it.
class ColorSwatchPicker extends StatelessWidget {
  const ColorSwatchPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.multiSelected,
  });

  /// Single selection mode.
  final ClothingColor? selected;

  /// Multi selection mode, used by filters. Overrides [selected] when set.
  final Set<ClothingColor>? multiSelected;
  final ValueChanged<ClothingColor> onChanged;

  static const double _ringGap = 3;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final color in ClothingColor.values)
          Builder(
            builder: (context) {
              final isSelected =
                  multiSelected?.contains(color) ?? color == selected;
              return Tooltip(
                message: color.label,
                child: Semantics(
                  label: color.label,
                  selected: isSelected,
                  button: true,
                  child: GestureDetector(
                    onTap: () => onChanged(color),
                    child: AnimatedContainer(
                      duration: AppDurations.fast,
                      padding: const EdgeInsets.all(_ringGap),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? palette.ink : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ColorSwatchDot(
                        color: color,
                        size: AppSizes.swatch,
                        child: isSelected
                            ? Icon(
                                Icons.check_rounded,
                                size: AppSizes.iconSm,
                                color: _checkColor(color),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  static Color _checkColor(ClothingColor color) =>
      color.swatch.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}
