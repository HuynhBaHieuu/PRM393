import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/extensions/model_presentation.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/section_header.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/wardrobe/widgets/clothing_tile.dart';

enum _OutfitMenuAction { edit, delete }

class OutfitDetailScreen extends StatelessWidget {
  const OutfitDetailScreen({super.key, required this.outfitId});

  final String outfitId;

  Future<void> _onMenu(
    BuildContext context,
    Outfit outfit,
    _OutfitMenuAction action,
  ) async {
    switch (action) {
      case _OutfitMenuAction.edit:
        await AppNavigator.editOutfit(context, outfit.id);
      case _OutfitMenuAction.delete:
        final navigator = Navigator.of(context);
        final deleted = await ClosetFlows.deleteOutfit(context, outfit);
        if (deleted) navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final outfits = context.watch<OutfitController>();
    final outfit = outfits.outfitById(outfitId);
    if (outfit == null) {
      return const NotFoundView(
        title: 'Outfit not found',
        message: 'This outfit no longer exists.',
      );
    }
    final wardrobe = context.watch<WardrobeController>();
    final items = wardrobe.itemsByIds(outfit.itemIds);
    final missing = outfit.itemIds.length - items.length;
    final closet = context.read<ClosetActions>();
    final wornToday =
        context
            .watch<PlannerController>()
            .dayPlan(closet.today)
            .worn
            ?.outfitId ==
        outfit.id;
    final palette = context.palette;
    final text = context.textTheme;
    final lastWorn = outfit.lastWornAt;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: outfit.isFavorite ? 'Unfavorite' : 'Favorite',
            onPressed: () => ClosetFlows.guard(
              context,
              () => outfits.toggleFavorite(outfit.id),
            ),
            icon: Icon(
              outfit.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: outfit.isFavorite ? palette.accent : palette.ink,
            ),
          ),
          PopupMenuButton<_OutfitMenuAction>(
            tooltip: 'More',
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (action) => _onMenu(context, outfit, action),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _OutfitMenuAction.edit,
                child: Text('Edit'),
              ),
              PopupMenuItem(
                value: _OutfitMenuAction.delete,
                child: Text('Delete', style: TextStyle(color: palette.danger)),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        children: [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSizes.maxPreviewWidth,
                    ),
                    child: AspectRatio(
                      aspectRatio: AppSizes.outfitImageAspect,
                      child: DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          border: Border.all(color: palette.border),
                        ),
                        child: OutfitCanvas(
                          items: items,
                          layout: outfit.layout,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(outfit.name, style: text.headlineMedium),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    TagLabel(AppFormatters.count(items.length, 'piece')),
                    if (outfit.occasion != null)
                      TagLabel(
                        outfit.occasion!.label,
                        icon: outfit.occasion!.icon,
                      ),
                    for (final season in outfit.seasons) TagLabel(season.label),
                    if (wornToday)
                      const TagLabel(
                        'Worn today',
                        inverted: true,
                        icon: Icons.check_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                StatPair(
                  items: [
                    (
                      outfit.wearCount == 1 ? 'Time worn' : 'Times worn',
                      '${outfit.wearCount}',
                    ),
                    (
                      'Last worn',
                      lastWorn == null
                          ? '—'
                          : AppFormatters.relativeDay(lastWorn),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  lastWorn == null
                      ? AppFormatters.wearCount(outfit.wearCount)
                      : '${AppFormatters.wearCount(outfit.wearCount)} · '
                            'last worn ${AppFormatters.shortDate(lastWorn)}',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: wornToday || items.isEmpty
                            ? null
                            : () => ClosetFlows.markWorn(
                                context,
                                outfit.id,
                                date: DateHelpers.dateOnly(closet.today),
                              ),
                        icon: const Icon(Icons.check_rounded),
                        label: Text(wornToday ? 'Worn today' : 'Wear Today'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            ClosetFlows.planOutfit(context, outfit.id),
                        icon: const Icon(Icons.event_outlined),
                        label: const Text('Plan Outfit'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'Pieces',
                  padding: EdgeInsets.zero,
                  subtitle: missing > 0
                      ? '${AppFormatters.count(missing, 'piece')} no longer '
                            'in your wardrobe'
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: Text(
                      'This outfit has no pieces left. Edit it to add some.',
                      style: text.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                for (final item in items) _PieceRow(item: item),
                if (outfit.notes != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  LabeledSection(
                    label: 'Notes',
                    child: Text(outfit.notes!, style: text.bodyMedium),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PieceRow extends StatelessWidget {
  const _PieceRow({required this.item});

  final ClothingItem item;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return InkWell(
      onTap: () => AppNavigator.clothingDetail(context, item.id),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            SizedBox.square(
              dimension: AppSizes.thumbLg,
              child: ClothingImage(
                item: item,
                borderRadius: BorderRadius.circular(AppRadius.md),
                decodeWidth: AppSizes.thumbLg,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(ClothingTile.metaLine(item), style: text.bodySmall),
                ],
              ),
            ),
            if (item.isArchived) const TagLabel('Archived'),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
