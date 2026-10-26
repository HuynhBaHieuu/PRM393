import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/data/models/clothing_item.dart';

/// The validated 8-slot categorical palette (dataviz reference), in fixed
/// order. A slice keeps its slot by rank in the current breakdown.
const List<Color> insightSeriesLight = [
  Color(0xFF2A78D6),
  Color(0xFFEB6834),
  Color(0xFF1BAF7A),
  Color(0xFFEDA100),
  Color(0xFFE87BA4),
  Color(0xFF008300),
  Color(0xFF6250D6),
  Color(0xFFE34948),
];

const List<Color> insightSeriesDark = [
  Color(0xFF3987E5),
  Color(0xFFD95926),
  Color(0xFF199E70),
  Color(0xFFC98500),
  Color(0xFFD55181),
  Color(0xFF008300),
  Color(0xFF9085E9),
  Color(0xFFE66767),
];

/// One slice of a [DonutChart].
class DonutSlice {
  const DonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

/// A donut with a 2px surface gap between slices and a caption inside.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    required this.title,
    required this.subtitle,
    this.size = 260,
  });

  final List<DonutSlice> slices;
  final String title;
  final String subtitle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    return Semantics(
      label: '$title $subtitle',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _DonutPainter(
            slices: slices,
            gap: palette.surface,
            empty: palette.surfaceMuted,
            outline: palette.border,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: text.titleLarge),
                Text(
                  subtitle,
                  style: text.bodyLarge?.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.gap,
    required this.empty,
    required this.outline,
  });

  final List<DonutSlice> slices;
  final Color gap;
  final Color empty;
  final Color outline;

  static const double _thickness = 0.2;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * _thickness;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.width - stroke) / 2,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final total = slices.fold<int>(0, (sum, s) => sum + s.value);
    if (total == 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, base..color = empty);
      return;
    }
    var start = -math.pi / 2;
    final separators = <double>[];
    for (final slice in slices) {
      final sweep = slice.value / total * math.pi * 2;
      canvas.drawArc(rect, start, sweep, false, base..color = slice.color);
      // Very light slices (white clothes) get a thin outline.
      if (slice.color.computeLuminance() > 0.85) {
        final edge = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = outline;
        canvas
          ..drawArc(rect.inflate(stroke / 2), start, sweep, false, edge)
          ..drawArc(rect.deflate(stroke / 2), start, sweep, false, edge);
      }
      separators.add(start);
      start += sweep;
    }
    if (slices.length < 2) return;
    // 2px surface gaps between slices.
    final line = Paint()
      ..color = gap
      ..strokeWidth = 2;
    final center = rect.center;
    final inner = rect.width / 2 - stroke / 2 - 1;
    final outer = rect.width / 2 + stroke / 2 + 1;
    for (final angle in separators) {
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(center + dir * inner, center + dir * outer, line);
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.slices != slices || old.gap != gap;
}

/// Two-column legend: dot, label, count and share.
class DonutLegend extends StatelessWidget {
  const DonutLegend({super.key, required this.slices});

  final List<DonutSlice> slices;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final total = slices.fold<int>(0, (sum, s) => sum + s.value);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            for (final slice in slices)
              SizedBox(
                width: width,
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: slice.color,
                        shape: BoxShape.circle,
                        border: slice.color.computeLuminance() > 0.85
                            ? Border.all(color: palette.border)
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        slice.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyLarge,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${slice.value}',
                      style: text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${(slice.value / total * 100).round()}%',
                      style: text.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Grey box with two figures side by side, as in Fits' value card.
class FigurePair extends StatelessWidget {
  const FigurePair({super.key, required this.figures});

  final List<(IconData icon, String value, String label)> figures;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < figures.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, color: palette.border),
              Expanded(
                child: Column(
                  children: [
                    Icon(
                      figures[i].$1,
                      size: AppSizes.iconXl,
                      color: palette.textSecondary,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        figures[i].$2,
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      figures[i].$3,
                      textAlign: TextAlign.center,
                      style: text.bodyLarge?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
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

/// A titled insight with an optional Premium star on the right.
class InsightSection extends StatelessWidget {
  const InsightSection({
    super.key,
    required this.title,
    required this.child,
    this.premiumBadge = false,
  });

  final String title;
  final Widget child;
  final bool premiumBadge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (premiumBadge)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: palette.ink,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_border_rounded,
                        size: AppSizes.iconSm,
                        color: palette.onInk,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        'Premium',
                        style: text.labelMedium?.copyWith(color: palette.onInk),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Fits' "Upgrade to Pro 🔒" placeholder for locked insights.
class LockedInsight extends StatelessWidget {
  const LockedInsight({super.key, required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surfaceMuted.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Text('Upgrade to Premium 🔒', style: text.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Unlock all insights with All Fits Premium',
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: onUpgrade, child: const Text('Upgrade')),
        ],
      ),
    );
  }
}

/// A row of pieces on grey tiles, each with an optional caption.
class InsightItemStrip extends StatelessWidget {
  const InsightItemStrip({
    super.key,
    required this.items,
    required this.onTap,
    this.captionOf,
    this.emptyText = 'Nothing here yet.',
  });

  final List<ClothingItem> items;
  final ValueChanged<ClothingItem> onTap;
  final String Function(ClothingItem item)? captionOf;
  final String emptyText;

  static const double _size = 150;
  static const int _limit = 12;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (items.isEmpty) {
      return Text(
        emptyText,
        style: context.textTheme.bodyLarge?.copyWith(
          color: palette.textSecondary,
        ),
      );
    }
    final caption = captionOf;
    final shown = items.take(_limit).toList();
    return SizedBox(
      height: _size + (caption == null ? 0 : 30),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: shown.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final item = shown[index];
          return Semantics(
            button: true,
            label: item.name,
            child: GestureDetector(
              onTap: () => onTap(item),
              child: SizedBox(
                width: _size,
                child: Column(
                  children: [
                    Container(
                      width: _size,
                      height: _size,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: palette.surfaceMuted.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: ClothingImage(
                        item: item,
                        cutout: true,
                        fit: BoxFit.contain,
                        decodeWidth: _size,
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(caption(item), style: context.textTheme.titleSmall),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A black progress bar on grey, as in Fits' "Wardrobe usage".
class UsageBar extends StatelessWidget {
  const UsageBar({super.key, required this.value});

  /// 0–1.
  final double value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 14,
        color: palette.ink,
        backgroundColor: palette.border,
      ),
    );
  }
}
