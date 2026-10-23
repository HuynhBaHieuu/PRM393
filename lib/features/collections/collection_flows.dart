import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/local/image_picker_service.dart';
import 'package:all_fits/data/models/collection.dart';
import 'package:all_fits/features/collections/controllers/collection_controller.dart';
import 'package:all_fits/features/collections/widgets/collection_cards.dart';
import 'package:all_fits/features/premium/premium_flows.dart';
import 'package:all_fits/features/shared/closet_flows.dart';

/// Dialogs and sheets for collections. Each reports its own errors.
abstract final class CollectionFlows {
  /// Asks for a name and creates a collection holding [itemIds] and
  /// [outfitIds]. On a full Free plan explains the limit instead. Resolves
  /// to the new collection, or null.
  static Future<Collection?> create(
    BuildContext context, {
    List<String> itemIds = const [],
    List<String> outfitIds = const [],
  }) async {
    if (!PremiumFlows.canAddCollection(context)) {
      await PremiumFlows.showCollectionLimit(context);
      return null;
    }
    final name = await showTextInputDialog(
      context,
      title: 'New collection',
      hint: 'e.g. Beach trip, Work, Wishlist',
      maxLength: Validators.maxNameLength,
      confirmLabel: 'Create',
    );
    if (name == null || !context.mounted) return null;
    try {
      return await context.read<CollectionController>().createCollection(
        name,
        itemIds: itemIds,
        outfitIds: outfitIds,
      );
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
      return null;
    }
  }

  static Future<void> rename(
    BuildContext context,
    Collection collection,
  ) async {
    final name = await showTextInputDialog(
      context,
      title: 'Rename collection',
      initialValue: collection.name,
      maxLength: Validators.maxNameLength,
    );
    if (name == null || !context.mounted) return;
    await ClosetFlows.guard(
      context,
      () => context.read<CollectionController>().rename(collection.id, name),
    );
  }

  /// Confirms, then deletes [collection]. Its contents stay in the closet.
  static Future<bool> delete(
    BuildContext context,
    Collection collection,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete collection?',
      message:
          '“${collection.name}” will be removed. The clothes and outfits in '
          'it stay in your closet.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return false;
    try {
      await context.read<CollectionController>().deleteCollection(
        collection.id,
      );
      if (context.mounted) context.showSnack('Collection deleted');
      return true;
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
      return false;
    }
  }

  /// Lets the user pick a cover photo, or go back to the collage.
  static Future<void> changeCover(
    BuildContext context,
    Collection collection,
  ) async {
    final picker = context.read<ImagePickerService>();
    final choice = await showModalBottomSheet<_CoverChoice>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHeader(title: 'Cover'),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(_CoverChoice.gallery),
            ),
            if (picker.supportsCamera)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_CoverChoice.camera),
              ),
            if (collection.coverImagePath != null)
              ListTile(
                leading: const Icon(Icons.grid_view_rounded),
                title: const Text('Use collage of pieces'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_CoverChoice.collage),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final collections = context.read<CollectionController>();
    if (choice == _CoverChoice.collage) {
      await ClosetFlows.guard(
        context,
        () => collections.clearCover(collection.id),
      );
      return;
    }
    await ClosetFlows.guard(context, () async {
      final path = await picker.pickImage(
        choice == _CoverChoice.camera
            ? ImagePickSource.camera
            : ImagePickSource.gallery,
      );
      if (path != null) await collections.setCover(collection.id, path);
    });
  }

  /// Rename, cover and delete. [onDeleted] runs after a delete.
  static Future<void> showActions(
    BuildContext context,
    Collection collection, {
    VoidCallback? onDeleted,
  }) {
    final palette = context.palette;
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        void run(Future<void> Function() action) {
          Navigator.of(sheetContext).pop();
          action();
        }

        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(title: collection.name),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename'),
                onTap: () => run(() => rename(context, collection)),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Change cover'),
                onTap: () => run(() => changeCover(context, collection)),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: palette.danger,
                ),
                title: Text('Delete', style: TextStyle(color: palette.danger)),
                onTap: () => run(() async {
                  if (await delete(context, collection)) onDeleted?.call();
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  /// Ticks which collections hold one clothing item.
  static Future<void> addItem(BuildContext context, String itemId) =>
      _addTo(context, _Entry.item(itemId));

  /// Ticks which collections hold one outfit.
  static Future<void> addOutfit(BuildContext context, String outfitId) =>
      _addTo(context, _Entry.outfit(outfitId));

  static Future<void> _addTo(BuildContext context, _Entry entry) async {
    final selection = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddToCollectionSheet(entry: entry),
    );
    if (selection == null || !context.mounted) return;
    final collections = context.read<CollectionController>();
    await ClosetFlows.guard(
      context,
      () => entry.isItem
          ? collections.setItemMembership(entry.id, selection)
          : collections.setOutfitMembership(entry.id, selection),
      successMessage: selection.isEmpty
          ? 'Not in any collection'
          : 'In ${AppFormatters.count(selection.length, 'collection')}',
    );
  }
}

enum _CoverChoice { gallery, camera, collage }

/// The item or outfit being sorted into collections.
class _Entry {
  const _Entry.item(this.id) : isItem = true;

  const _Entry.outfit(this.id) : isItem = false;

  final String id;
  final bool isItem;

  bool isIn(Collection collection) =>
      isItem ? collection.containsItem(id) : collection.containsOutfit(id);
}

class _AddToCollectionSheet extends StatefulWidget {
  const _AddToCollectionSheet({required this.entry});

  final _Entry entry;

  @override
  State<_AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends State<_AddToCollectionSheet> {
  late final Set<String> _selected = {
    for (final collection in context.read<CollectionController>().collections)
      if (widget.entry.isIn(collection)) collection.id,
  };

  Future<void> _createCollection() async {
    final entry = widget.entry;
    // The new collection already holds the entry, so it stays even if the
    // sheet is dismissed.
    final created = await CollectionFlows.create(
      context,
      itemIds: entry.isItem ? [entry.id] : const [],
      outfitIds: entry.isItem ? const [] : [entry.id],
    );
    if (created != null && mounted) {
      setState(() => _selected.add(created.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final collections = context.watch<CollectionController>().collections;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Column(
        children: [
          const SheetHeader(title: 'Add to collection'),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                ListTile(
                  leading: const SizedBox.square(
                    dimension: AppSizes.thumbSm,
                    child: Icon(Icons.add_rounded),
                  ),
                  title: const Text('New collection'),
                  onTap: _createCollection,
                ),
                for (final collection in collections)
                  _CollectionCheckTile(
                    collection: collection,
                    selected: _selected.contains(collection.id),
                    onChanged: (selected) => setState(
                      () => selected
                          ? _selected.add(collection.id)
                          : _selected.remove(collection.id),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.md,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop({
                    // Drop ids of collections deleted while the sheet was open.
                    for (final collection in collections)
                      if (_selected.contains(collection.id)) collection.id,
                  }),
                  child: const Text('Done'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionCheckTile extends StatelessWidget {
  const _CollectionCheckTile({
    required this.collection,
    required this.selected,
    required this.onChanged,
  });

  final Collection collection;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final contents = watchCollectionContents(context, collection);
    return CheckboxListTile(
      value: selected,
      onChanged: (value) => onChanged(value ?? false),
      secondary: SizedBox.square(
        dimension: AppSizes.thumbSm,
        child: CollectionCover(collection: collection, contents: contents),
      ),
      title: Text(
        collection.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(collectionCountLine(contents)),
    );
  }
}
