import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/constants/app_durations.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/data/models/clothing_item.dart';

/// A headline figure such as "Total items".
class OverviewStatTile extends StatelessWidget {
  const OverviewStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSizes.iconSm, color: palette.textSecondary),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: text.headlineMedium),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(label, style: text.bodySmall),
        ],
      ),
    );
  }
}

/// Most / least worn item highlight.
class WearHighlightRow extends StatelessWidget {
  const WearHighlightRow({
    super.key,
    required this.label,
    required this.item,
    required this.onTap,
  });

  final String label;
  final ClothingItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final lastWorn = item.lastWornAt;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            SizedBox(
              width: AppSizes.thumbLg,
              child: AspectRatio(
                aspectRatio: AppSizes.clothingImageAspect,
                child: ClothingImage(
                  item: item,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  decodeWidth: AppSizes.thumbLg,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(), style: text.labelSmall),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(item.name, style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    lastWorn == null
                        ? '${AppFormatters.wearCount(item.wearCount)} · added '
                              '${AppFormatters.shortDate(item.createdAt)}'
                        : '${AppFormatters.wearCount(item.wearCount)} · last '
                              '${AppFormatters.shortDate(lastWorn)}',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

/// One labelled horizontal bar in a breakdown.
class BreakdownBar extends StatelessWidget {
  const BreakdownBar({
    super.key,
    required this.label,
    required this.count,
    required this.total,
    this.leading,
  });

  final String label;
  final int count;
  final int total;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final fraction = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(child: Text(label, style: text.bodyMedium)),
              Text(
                '$count · ${(fraction * 100).round()}%',
                style: text.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: AppDurations.slow,
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: AppSizes.barHeight,
                color: palette.ink,
                backgroundColor: palette.surfaceMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
