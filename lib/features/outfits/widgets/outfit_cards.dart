import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/adaptive_grid.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/option_sheets.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cover.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

String outfitMetaLine(Outfit outfit, int pieceCount) => [
  AppFormatters.count(pieceCount, 'piece'),
  ?outfit.occasion?.label,
  if (outfit.seasons.length == 1) outfit.seasons.first.label,
].join(' · ');

/// Resolves an outfit's items from the wardrobe and rebuilds on changes.
List<ClothingItem> watchOutfitItems(BuildContext context, Outfit outfit) =>
    context.watch<WardrobeController>().itemsByIds(outfit.itemIds);

/// Grid tile for an outfit: collage, name and meta line.
class OutfitCard extends StatelessWidget {
  const OutfitCard({
    super.key,
    required this.outfit,
    required this.onTap,
    this.onFavorite,
    this.onLongPress,
    this.subtitle,
    this.selected = false,
  });

  final Outfit outfit;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onLongPress;

  /// Overrides the default meta line.
  final String? subtitle;

  /// Shows a selection ring and check mark (used by pickers).
  final bool selected;

  static const double _overlayInset = 8;

  @override
  Widget build(BuildContext context) {
    final items = watchOutfitItems(context, outfit);
    final text = context.textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: outfit.name,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: AppSizes.outfitImageAspect,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  OutfitCover(outfit: outfit, items: items),
                  if (onFavorite != null)
                    Positioned(
                      top: _overlayInset,
                      right: _overlayInset,
                      child: FavoriteOverlayButton(
                        isFavorite: outfit.isFavorite,
                        onPressed: onFavorite!,
                      ),
                    ),
                  if (selected) ...[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: context.palette.ink,
                          width: 2,
                        ),
                      ),
                    ),
                    const Positioned(
                      top: _overlayInset,
                      left: _overlayInset,
                      child: SelectionBadge(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              outfit.name,
              style: text.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle ?? outfitMetaLine(outfit, items.length),
              style: text.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class OutfitSliverGrid extends StatelessWidget {
  const OutfitSliverGrid({
    super.key,
    required this.outfits,
    required this.onTap,
    this.onFavorite,
    this.onLongPress,
    this.isSelected,
  });

  final List<Outfit> outfits;
  final ValueChanged<Outfit> onTap;
  final ValueChanged<Outfit>? onFavorite;
  final ValueChanged<Outfit>? onLongPress;
  final bool Function(Outfit outfit)? isSelected;

  @override
  Widget build(BuildContext context) {
    final footer = MediaQuery.textScalerOf(context)
        .scale(AppSizes.outfitTileFooterHeight);
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverGrid(
        gridDelegate: AdaptiveGrid.imageTiles(
          width: constraints.crossAxisExtent,
          imageAspect: AppSizes.outfitImageAspect,
          footerHeight: footer,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final outfit = outfits[index];
          return OutfitCard(
            key: ValueKey(outfit.id),
            outfit: outfit,
            selected: isSelected?.call(outfit) ?? false,
            onTap: () => onTap(outfit),
            onFavorite: onFavorite == null ? null : () => onFavorite!(outfit),
            onLongPress: onLongPress == null
                ? null
                : () => onLongPress!(outfit),
          );
        }, childCount: outfits.length),
      ),
    );
  }
}

/// Fits' Outfits tab grid: three image-only white cards across, with a
/// round check in [checkable] mode.
class OutfitTileGrid extends StatelessWidget {
  const OutfitTileGrid({
    super.key,
    required this.outfits,
    required this.onTap,
    this.onLongPress,
    this.isSelected,
    this.checkable = false,
  });

  final List<Outfit> outfits;
  final ValueChanged<Outfit> onTap;
  final ValueChanged<Outfit>? onLongPress;
  final bool Function(Outfit outfit)? isSelected;
  final bool checkable;

  static const double _aspect = 0.62;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: _aspect,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final outfit = outfits[index];
        final items = watchOutfitItems(context, outfit);
        final selected = isSelected?.call(outfit) ?? false;
        return Semantics(
          key: ValueKey(outfit.id),
          button: true,
          selected: selected,
          label: outfit.name,
          child: GestureDetector(
            onTap: () => onTap(outfit),
            onLongPress: onLongPress == null
                ? null
                : () => onLongPress!(outfit),
            child: Container(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: checkable && selected ? 0.45 : 1,
                    child: Padding(
                      padding: EdgeInsets.all(
                        outfit.photoPath == null ? AppSpacing.xs : 0,
                      ),
                      child: OutfitCover(
                        outfit: outfit,
                        items: items,
                        worn: true,
                      ),
                    ),
                  ),
                  if (checkable)
                    Positioned(
                      top: AppSpacing.xxs,
                      right: AppSpacing.xxs,
                      child: RoundCheck(checked: selected, size: 26),
                    ),
                ],
              ),
            ),
          ),
        );
      }, childCount: outfits.length),
    );
  }
}

/// Horizontal list row: small collage thumbnail, name and meta.
class OutfitListRow extends StatelessWidget {
  const OutfitListRow({
    super.key,
    required this.outfit,
    this.onTap,
    this.trailing,
    this.subtitle,
  });

  final Outfit outfit;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? subtitle;

  static const double _thumbWidth = 60;

  @override
  Widget build(BuildContext context) {
    final items = watchOutfitItems(context, outfit);
    final text = context.textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            SizedBox(
              width: _thumbWidth,
              child: AspectRatio(
                aspectRatio: AppSizes.outfitImageAspect,
                child: OutfitCover(outfit: outfit, items: items),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outfit.name,
                    style: text.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle ?? outfitMetaLine(outfit, items.length),
                    style: text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing outfits; resolves to the chosen outfit id.
Future<String?> showOutfitPickerSheet(
  BuildContext context, {
  required List<Outfit> outfits,
  String title = 'Choose an outfit',
  VoidCallback? onCreateOutfit,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Column(
        children: [
          SheetHeader(title: title),
          Expanded(
            child: outfits.isEmpty
                ? _NoOutfits(onCreateOutfit: onCreateOutfit)
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      0,
                      AppSpacing.page,
                      AppSpacing.xl,
                    ),
                    itemCount: outfits.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final outfit = outfits[index];
                      return OutfitListRow(
                        outfit: outfit,
                        onTap: () => Navigator.of(context).pop(outfit.id),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

class _NoOutfits extends StatelessWidget {
  const _NoOutfits({this.onCreateOutfit});

  final VoidCallback? onCreateOutfit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          Icon(
            Icons.style_outlined,
            size: AppSizes.iconXl,
            color: context.palette.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('No outfits yet', style: context.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('Create your first look.', style: context.textTheme.bodySmall),
          if (onCreateOutfit != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                onCreateOutfit!();
              },
              child: const Text('Create Outfit'),
            ),
          ],
        ],
      ),
    );
  }
}
