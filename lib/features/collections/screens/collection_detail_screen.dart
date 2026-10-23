import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/section_header.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/collection.dart';
import 'package:all_fits/features/collections/collection_flows.dart';
import 'package:all_fits/features/collections/controllers/collection_controller.dart';
import 'package:all_fits/features/collections/widgets/collection_cards.dart';
import 'package:all_fits/features/collections/widgets/collection_entry_picker.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cards.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/wardrobe/widgets/clothing_grid.dart';

enum _CollectionMenuAction { rename, cover, delete }

/// One collection: its pieces, then its outfits.
class CollectionDetailScreen extends StatelessWidget {
  const CollectionDetailScreen({super.key, required this.collectionId});

  final String collectionId;

  Future<void> _add(BuildContext context, Collection collection) async {
    final collections = context.read<CollectionController>();
    final selection = await showCollectionEntryPicker(
      context,
      collection: collection,
    );
    if (selection == null || !context.mounted) return;
    await ClosetFlows.guard(
      context,
      () => collections.setEntries(
        collection.id,
        itemIds: selection.itemIds,
        outfitIds: selection.outfitIds,
      ),
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    Collection collection,
    _CollectionMenuAction action,
  ) async {
    switch (action) {
      case _CollectionMenuAction.rename:
        await CollectionFlows.rename(context, collection);
      case _CollectionMenuAction.cover:
        await CollectionFlows.changeCover(context, collection);
      case _CollectionMenuAction.delete:
        final navigator = Navigator.of(context);
        final deleted = await CollectionFlows.delete(context, collection);
        if (deleted) navigator.pop();
    }
  }

  /// Long-press on an entry: open it or take it out of the collection.
  Future<void> _showEntryActions(
    BuildContext context, {
    required String title,
    required VoidCallback onOpen,
    required Future<void> Function() onRemove,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(title: title),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Open'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onOpen();
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline_rounded),
              title: const Text('Remove from collection'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ClosetFlows.guard(
                  context,
                  onRemove,
                  successMessage: 'Removed from collection',
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CollectionController>();
    final collection = controller.collectionById(collectionId);
    if (collection == null) {
      return const NotFoundView(
        title: 'Collection not found',
        message: 'This collection no longer exists.',
      );
    }
    final contents = watchCollectionContents(context, collection);
    final insets = pageInsets(context.screenSize.width);
    final palette = context.palette;
    final archivedCount = contents.items.where((i) => i.isArchived).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(collection.name),
        actions: [
          IconButton(
            tooltip: 'Add',
            onPressed: () => _add(context, collection),
            icon: const Icon(Icons.add_rounded),
          ),
          PopupMenuButton<_CollectionMenuAction>(
            tooltip: 'More',
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (action) => _onMenu(context, collection, action),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _CollectionMenuAction.rename,
                child: Text('Rename'),
              ),
              const PopupMenuItem(
                value: _CollectionMenuAction.cover,
                child: Text('Change cover'),
              ),
              PopupMenuItem(
                value: _CollectionMenuAction.delete,
                child: Text('Delete', style: TextStyle(color: palette.danger)),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: contents.items.isEmpty && contents.outfits.isEmpty
          ? AppEmptyState(
              icon: Icons.collections_bookmark_outlined,
              title: 'Nothing here yet',
              message: 'Add pieces and outfits to keep them together.',
              actionLabel: 'Add',
              onAction: () => _add(context, collection),
            )
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: insets.copyWith(top: AppSpacing.sm),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      collectionCountLine(contents),
                      style: context.textTheme.bodySmall,
                    ),
                  ),
                ),
                if (contents.items.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.lg),
                  ),
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Clothes',
                      subtitle: archivedCount == 0
                          ? null
                          : 'Archived pieces are faded',
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.md),
                  ),
                  SliverPadding(
                    padding: insets,
                    sliver: ClothingSliverGrid(
                      items: contents.items,
                      isDimmed: (item) => item.isArchived,
                      onTap: (item) =>
                          AppNavigator.clothingDetail(context, item.id),
                      onLongPress: (item) => _showEntryActions(
                        context,
                        title: item.name,
                        onOpen: () =>
                            AppNavigator.clothingDetail(context, item.id),
                        onRemove: () => controller.removeEntries(
                          collection.id,
                          itemIds: [item.id],
                        ),
                      ),
                    ),
                  ),
                ],
                if (contents.outfits.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xl),
                  ),
                  const SliverToBoxAdapter(
                    child: SectionHeader(title: 'Outfits'),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.md),
                  ),
                  SliverPadding(
                    padding: insets,
                    sliver: OutfitSliverGrid(
                      outfits: contents.outfits,
                      onTap: (outfit) =>
                          AppNavigator.outfitDetail(context, outfit.id),
                      onLongPress: (outfit) => _showEntryActions(
                        context,
                        title: outfit.name,
                        onOpen: () =>
                            AppNavigator.outfitDetail(context, outfit.id),
                        onRemove: () => controller.removeEntries(
                          collection.id,
                          outfitIds: [outfit.id],
                        ),
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxl),
                ),
              ],
            ),
    );
  }
}
