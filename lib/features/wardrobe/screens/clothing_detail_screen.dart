import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/color_swatch.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/section_header.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cards.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

enum _ItemMenuAction { edit, archive, delete }

class ClothingDetailScreen extends StatelessWidget {
  const ClothingDetailScreen({super.key, required this.itemId});

  final String itemId;

  static const double _imageHeightFactor = 0.62;
  static const double _usedInCardWidth = 132;

  Future<void> _onMenu(
    BuildContext context,
    ClothingItem item,
    _ItemMenuAction action,
  ) async {
    final wardrobe = context.read<WardrobeController>();
    switch (action) {
      case _ItemMenuAction.edit:
        await AppNavigator.editClothing(context, item.id);
      case _ItemMenuAction.archive:
        await _setArchived(context, wardrobe, item, archived: !item.isArchived);
      case _ItemMenuAction.delete:
        final navigator = Navigator.of(context);
        final deleted = await ClosetFlows.deleteItem(context, item);
        if (deleted) navigator.pop();
    }
  }

  Future<void> _setArchived(
    BuildContext context,
    WardrobeController wardrobe,
    ClothingItem item, {
    required bool archived,
  }) async {
    try {
      await wardrobe.setArchived(item.id, archived: archived);
      if (!context.mounted) return;
      context.showSnack(
        archived ? 'Moved to archive' : 'Restored to your wardrobe',
        actionLabel: 'Undo',
        onAction: () => ClosetFlows.guard(
          context,
          () => wardrobe.setArchived(item.id, archived: !archived),
        ),
      );
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeController>();
    final item = wardrobe.itemById(itemId);
    if (item == null) {
      return const NotFoundView(
        title: 'Item not found',
        message: 'This item is no longer in your wardrobe.',
      );
    }
    final usedIn = context.watch<OutfitController>().outfitsUsingItem(itemId);
    final currency = context.select<SettingsController, String>(
      (s) => s.currencySymbol,
    );
    final palette = context.palette;
    final text = context.textTheme;
    final size = context.screenSize;
    final imageHeight = math.min(
      size.width / AppSizes.clothingImageAspect,
      size.height * _imageHeightFactor,
    );
    final lastWorn = item.lastWornAt;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: imageHeight,
            backgroundColor: palette.background,
            leading: const _OverlayBackButton(),
            actions: [
              _OverlayAction(
                child: IconButton(
                  tooltip: item.isFavorite ? 'Unfavorite' : 'Favorite',
                  onPressed: () => ClosetFlows.guard(
                    context,
                    () => wardrobe.toggleFavorite(item.id),
                  ),
                  icon: Icon(
                    item.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: item.isFavorite ? palette.accent : palette.ink,
                  ),
                ),
              ),
              _OverlayAction(
                child: PopupMenuButton<_ItemMenuAction>(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (action) => _onMenu(context, item, action),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _ItemMenuAction.edit,
                      child: Text('Edit'),
                    ),
                    PopupMenuItem(
                      value: _ItemMenuAction.archive,
                      child: Text(item.isArchived ? 'Restore' : 'Archive'),
                    ),
                    PopupMenuItem(
                      value: _ItemMenuAction.delete,
                      child: Text(
                        'Delete',
                        style: TextStyle(color: palette.danger),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: ClothingImage(item: item, decodeWidth: size.width),
            ),
          ),
          SliverToBoxAdapter(
            child: ResponsiveCenter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.lg,
                  AppSpacing.page,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(item.category.singularLabel),
                    const SizedBox(height: AppSpacing.xs),
                    Text(item.name, style: text.headlineMedium),
                    if (item.brand != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        item.brand!,
                        style: text.bodyLarge?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                    if (item.isArchived) ...[
                      const SizedBox(height: AppSpacing.md),
                      _ArchivedBanner(
                        onRestore: () => _setArchived(
                          context,
                          wardrobe,
                          item,
                          archived: false,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    StatPair(
                      items: [
                        (
                          item.wearCount == 1 ? 'Time worn' : 'Times worn',
                          '${item.wearCount}',
                        ),
                        (
                          'Last worn',
                          lastWorn == null
                              ? '—'
                              : AppFormatters.relativeDay(lastWorn),
                        ),
                        ('In outfits', '${usedIn.length}'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      lastWorn == null
                          ? AppFormatters.wearCount(item.wearCount)
                          : '${AppFormatters.wearCount(item.wearCount)} · '
                                'last worn ${AppFormatters.shortDate(lastWorn)}',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _AttributeRow(
                      label: 'Category',
                      value: item.category.singularLabel,
                    ),
                    _AttributeRow(
                      label: 'Color',
                      value: item.color?.label,
                      leading: item.color == null
                          ? null
                          : ColorSwatchDot(color: item.color!),
                    ),
                    _AttributeRow(
                      label: 'Season',
                      value: item.seasons.isEmpty
                          ? null
                          : item.seasons.map((s) => s.label).join(', '),
                    ),
                    _AttributeRow(label: 'Brand', value: item.brand),
                    _AttributeRow(
                      label: 'Price',
                      value: item.price == null
                          ? null
                          : AppFormatters.price(item.price!, currency),
                    ),
                    _AttributeRow(
                      label: 'Added',
                      value: AppFormatters.shortDate(item.createdAt),
                    ),
                    if (item.notes != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      LabeledSection(
                        label: 'Notes',
                        child: Text(item.notes!, style: text.bodyMedium),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton.icon(
                      onPressed: item.isArchived
                          ? null
                          : () => AppNavigator.createOutfit(
                              context,
                              initialItemIds: [item.id],
                            ),
                      icon: const Icon(Icons.style_outlined),
                      label: const Text('Create outfit with this item'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(
                          AppSizes.buttonHeight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (usedIn.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'Worn in these outfits'),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            SliverToBoxAdapter(
              child: SizedBox(
                height:
                    _usedInCardWidth / AppSizes.outfitImageAspect +
                    MediaQuery.textScalerOf(context)
                        .scale(AppSizes.outfitTileFooterHeight),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  itemCount: usedIn.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) => SizedBox(
                    width: _usedInCardWidth,
                    child: OutfitCard(
                      outfit: usedIn[index],
                      onTap: () =>
                          AppNavigator.outfitDetail(context, usedIn[index].id),
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ],
      ),
    );
  }
}

class _AttributeRow extends StatelessWidget {
  const _AttributeRow({required this.label, this.value, this.leading});

  final String label;
  final String? value;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(color: palette.textSecondary),
            ),
          ),
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              value ?? '—',
              textAlign: TextAlign.end,
              style: value == null
                  ? text.bodyMedium?.copyWith(color: palette.textTertiary)
                  : text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedBanner extends StatelessWidget {
  const _ArchivedBanner({required this.onRestore});

  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, size: AppSizes.iconSm),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Text('This item is archived')),
          TextButton(onPressed: onRestore, child: const Text('Restore')),
        ],
      ),
    );
  }
}

/// Keeps app bar icons legible on top of photos.
class _OverlayAction extends StatelessWidget {
  const _OverlayAction({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.palette.surface.withValues(alpha: 0.88),
        ),
        child: child,
      ),
    );
  }
}

class _OverlayBackButton extends StatelessWidget {
  const _OverlayBackButton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _OverlayAction(
        child: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}
