import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// Today's worn or planned outfit, or an invitation to create/plan one.
class TodayOutfitSection extends StatelessWidget {
  const TodayOutfitSection({super.key});

  @override
  Widget build(BuildContext context) {
    final closet = context.read<ClosetActions>();
    final plan = context.watch<PlannerController>().dayPlan(closet.today);
    final outfits = context.watch<OutfitController>();
    final entry = plan.primary;
    final outfit = entry == null ? null : outfits.outfitById(entry.outfitId);

    if (outfit == null) {
      return _EmptyToday(hasOutfits: outfits.outfits.isNotEmpty);
    }
    final items = context.watch<WardrobeController>().itemsByIds(
      outfit.itemIds,
    );
    return _TodayCard(outfit: outfit, items: items, isWorn: plan.worn != null);
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.outfit,
    required this.items,
    required this.isWorn,
  });

  final Outfit outfit;
  final List<ClothingItem> items;
  final bool isWorn;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: () => AppNavigator.outfitDetail(context, outfit.id),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ThumbnailStrip(items: items),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TagLabel(
                          isWorn ? 'Worn today' : 'Planned for today',
                          inverted: isWorn,
                          icon: isWorn
                              ? Icons.check_rounded
                              : Icons.event_outlined,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(outfit.name, style: text.headlineSmall),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatters.count(items.length, 'piece'),
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (!isWorn)
                    FilledButton(
                      onPressed: () => ClosetFlows.markWorn(context, outfit.id),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(
                          0,
                          AppSizes.compactButtonHeight,
                        ),
                      ),
                      child: const Text('Mark as Worn'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Up to [_maxShown] clothing thumbnails in a row; extra pieces become "+N".
class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip({required this.items});

  final List<ClothingItem> items;

  static const int _maxShown = 4;
  static const double _gap = AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (items.isEmpty) {
      return SizedBox(
        height: AppSizes.thumbLg,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      );
    }
    final shown = items.take(_maxShown).toList();
    final hidden = items.length - shown.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - _gap * (_maxShown - 1)) / _maxShown;
        final height = (width / AppSizes.clothingImageAspect).clamp(
          0.0,
          AppSizes.todayOutfitPreviewHeight,
        );
        return SizedBox(
          height: height,
          child: Row(
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                SizedBox(
                  width: width,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClothingImage(
                        item: shown[i],
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        decodeWidth: width,
                      ),
                      if (hidden > 0 && i == shown.length - 1)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: ColoredBox(
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
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday({required this.hasOutfits});

  final bool hasOutfits;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final today = context.read<ClosetActions>().today;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.wb_sunny_outlined, color: palette.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text('No outfit for today', style: text.headlineSmall),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            hasOutfits
                ? 'Pick one of your looks for today, or put together '
                      'something new.'
                : 'Put together your first look from your wardrobe.',
            style: text.bodyMedium?.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              FilledButton(
                onPressed: () => AppNavigator.createOutfit(context),
                child: const Text('Create Outfit'),
              ),
              if (hasOutfits)
                OutlinedButton(
                  onPressed: () => ClosetFlows.pickAndPlan(context, today),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: palette.surface,
                  ),
                  child: const Text('Plan for today'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
