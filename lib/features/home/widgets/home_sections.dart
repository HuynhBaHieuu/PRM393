import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/section_header.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cards.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/wardrobe/widgets/clothing_tile.dart';
import 'package:all_fits/navigation/app_navigation.dart';

/// Three shortcuts to the most common tasks.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.add_a_photo_outlined,
            label: 'Add Clothing',
            onTap: () => AppNavigator.addClothing(context),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _QuickAction(
            icon: Icons.style_outlined,
            label: 'Create Outfit',
            onTap: () => AppNavigator.createOutfit(context),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _QuickAction(
            icon: Icons.event_outlined,
            label: 'Plan Outfit',
            onTap: () => context.read<ShellController>().openCloset(ClosetTab.planner),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: AppSizes.icon),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip of the newest wardrobe items.
class RecentlyAddedSection extends StatelessWidget {
  const RecentlyAddedSection({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<WardrobeController>().recentlyAdded(
      AppConfig.recentItemsLimit,
    );
    final shell = context.read<ShellController>();
    final footer = MediaQuery.textScalerOf(context)
        .scale(AppSizes.clothingTileFooterHeight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Recently added',
          actionLabel: items.isEmpty ? null : 'See all',
          onAction: () => shell.openCloset(ClosetTab.clothes),
        ),
        const SizedBox(height: AppSpacing.md),
        if (items.isEmpty)
          _InlineEmpty(
            message: 'Your wardrobe is empty. Add your first piece.',
            actionLabel: 'Add Clothing',
            onAction: () => AppNavigator.addClothing(context),
          )
        else
          SizedBox(
            height:
                AppSizes.recentItemWidth / AppSizes.clothingImageAspect +
                footer,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) => SizedBox(
                width: AppSizes.recentItemWidth,
                child: ClothingTile(
                  item: items[index],
                  decodeWidth: AppSizes.recentItemWidth,
                  onTap: () =>
                      AppNavigator.clothingDetail(context, items[index].id),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Outfits ordered by most recent wear.
class RecentlyWornSection extends StatelessWidget {
  const RecentlyWornSection({super.key});

  @override
  Widget build(BuildContext context) {
    final outfits = context.watch<OutfitController>().recentlyWorn(
      AppConfig.recentOutfitsLimit,
    );
    final footer = MediaQuery.textScalerOf(context)
        .scale(AppSizes.outfitTileFooterHeight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Recently worn'),
        const SizedBox(height: AppSpacing.md),
        if (outfits.isEmpty)
          const _InlineEmpty(
            message: 'Outfits you mark as worn will show up here.',
          )
        else
          SizedBox(
            height:
                AppSizes.recentOutfitWidth / AppSizes.outfitImageAspect +
                footer,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              itemCount: outfits.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final outfit = outfits[index];
                return SizedBox(
                  width: AppSizes.recentOutfitWidth,
                  child: OutfitCard(
                    outfit: outfit,
                    subtitle:
                        'Worn ${AppFormatters.relativeDay(outfit.lastWornAt!).toLowerCase()}',
                    onTap: () => AppNavigator.outfitDetail(context, outfit.id),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}
