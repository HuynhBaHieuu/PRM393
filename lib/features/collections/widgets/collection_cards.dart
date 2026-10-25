import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/adaptive_grid.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/collection.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// The pieces and outfits a collection points at that still exist.
typedef CollectionContents = ({List<ClothingItem> items, List<Outfit> outfits});

/// Resolves [collection]'s entries and rebuilds when they change.
CollectionContents watchCollectionContents(
  BuildContext context,
  Collection collection,
) {
  final wardrobe = context.watch<WardrobeController>();
  final outfits = context.watch<OutfitController>();
  return (
    items: wardrobe.itemsByIds(collection.itemIds),
    outfits: [for (final id in collection.outfitIds) ?outfits.outfitById(id)],
  );
}

/// "3 pieces · 2 outfits".
String collectionCountLine(CollectionContents contents) {
  if (contents.items.isEmpty && contents.outfits.isEmpty) return 'Empty';
  return [
    if (contents.items.isNotEmpty)
      AppFormatters.count(contents.items.length, 'piece'),
    if (contents.outfits.isNotEmpty)
      AppFormatters.count(contents.outfits.length, 'outfit'),
  ].join(' · ');
}

/// Square cover: the chosen photo, else a 2×2 collage of the first pieces
/// and outfits inside, else an icon.
class CollectionCover extends StatelessWidget {
  const CollectionCover({
    super.key,
    required this.collection,
    required this.contents,
  });

  final Collection collection;
  final CollectionContents contents;

  static const int _collageSize = 4;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final photo = _coverPhoto(context);
    final Widget child;
    if (photo != null) {
      child = Image(
        image: photo,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, _, _) => _collage(context),
      );
    } else {
      child = _collage(context);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: ColoredBox(color: palette.surfaceMuted, child: child),
    );
  }

  ImageProvider? _coverPhoto(BuildContext context) {
    final reference = collection.coverImagePath;
    if (reference == null) return null;
    final path = context.read<ImageStorageService>().resolvePath(reference);
    if (path == null) return null;
    return path.startsWith('https://')
        ? NetworkImage(path)
        : FileImage(File(path));
  }

  Widget _collage(BuildContext context) {
    // Pieces still in use come first; archived ones only fill gaps.
    final items = [
      ...contents.items.where((i) => !i.isArchived),
      ...contents.items.where((i) => i.isArchived),
    ].take(_collageSize).toList();
    final cells = <Widget>[
      for (final item in items)
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xxs),
          child: ClothingImage(
            item: item,
            cutout: true,
            fit: BoxFit.contain,
            decodeWidth: 120,
          ),
        ),
      for (final outfit in contents.outfits.take(_collageSize - items.length))
        _OutfitCell(outfit: outfit),
    ];
    if (cells.isEmpty) {
      return Center(
        child: Icon(
          Icons.collections_bookmark_outlined,
          size: AppSizes.iconXl,
          color: context.palette.textTertiary,
        ),
      );
    }
    if (cells.length == 1) return cells.single;
    final divider = context.palette.background;
    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 1,
      crossAxisSpacing: 1,
      children: [
        for (var i = 0; i < _collageSize; i++)
          ColoredBox(
            color: i < cells.length ? context.palette.surfaceMuted : divider,
            child: i < cells.length ? cells[i] : null,
          ),
      ],
    );
  }
}

class _OutfitCell extends StatelessWidget {
  const _OutfitCell({required this.outfit});

  final Outfit outfit;

  @override
  Widget build(BuildContext context) {
    final items = context.watch<WardrobeController>().itemsByIds(
      outfit.itemIds,
    );
    return Center(
      child: AspectRatio(
        aspectRatio: AppSizes.outfitImageAspect,
        child: OutfitCanvas(items: items, layout: outfit.layout),
      ),
    );
  }
}

/// Grid tile for a collection: cover, name and counts.
class CollectionCard extends StatelessWidget {
  const CollectionCard({
    super.key,
    required this.collection,
    required this.onTap,
    this.onLongPress,
  });

  final Collection collection;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final contents = watchCollectionContents(context, collection);
    final text = context.textTheme;
    return Semantics(
      button: true,
      label: collection.name,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: CollectionCover(
                collection: collection,
                contents: contents,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              collection.name,
              style: text.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              collectionCountLine(contents),
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

class CollectionSliverGrid extends StatelessWidget {
  const CollectionSliverGrid({
    super.key,
    required this.collections,
    required this.onTap,
    this.onLongPress,
  });

  final List<Collection> collections;
  final ValueChanged<Collection> onTap;
  final ValueChanged<Collection>? onLongPress;

  @override
  Widget build(BuildContext context) {
    final footer = MediaQuery.textScalerOf(context)
        .scale(AppSizes.outfitTileFooterHeight);
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverGrid(
        gridDelegate: AdaptiveGrid.imageTiles(
          width: constraints.crossAxisExtent,
          imageAspect: 1,
          footerHeight: footer,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final collection = collections[index];
          return CollectionCard(
            key: ValueKey(collection.id),
            collection: collection,
            onTap: () => onTap(collection),
            onLongPress: onLongPress == null
                ? null
                : () => onLongPress!(collection),
          );
        }, childCount: collections.length),
      ),
    );
  }
}
