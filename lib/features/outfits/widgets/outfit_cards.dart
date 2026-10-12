import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/adaptive_grid.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/features/outfits/widgets/outfit_collage.dart';
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
  });

  final Outfit outfit;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onLongPress;

  /// Overrides the default meta line.
  final String? subtitle;

  static const double _overlayInset = 8;

  @override
  Widget build(BuildContext context) {
    final items = watchOutfitItems(context, outfit);
    final text = context.textTheme;
    return Semantics(
      button: true,
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
                  OutfitCollage(items: items),
                  if (onFavorite != null)
                    Positioned(
                      top: _overlayInset,
                      right: _overlayInset,
                      child: FavoriteOverlayButton(
                        isFavorite: outfit.isFavorite,
                        onPressed: onFavorite!,
                      ),
                    ),
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
  });

  final List<Outfit> outfits;
  final ValueChanged<Outfit> onTap;
  final ValueChanged<Outfit>? onFavorite;
  final ValueChanged<Outfit>? onLongPress;

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
                child: OutfitCollage(
                  items: items,
                  borderRadius: AppRadius.sm,
                  decodeWidth: _thumbWidth,
                ),
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
