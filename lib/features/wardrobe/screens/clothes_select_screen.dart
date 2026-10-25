import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/selection_tray.dart';
import 'package:all_fits/features/collections/collection_flows.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_query.dart';
import 'package:all_fits/features/wardrobe/widgets/clothing_grid.dart';
import 'package:all_fits/features/wardrobe/widgets/wardrobe_filter_sheet.dart';
import 'package:all_fits/features/wardrobe/widgets/wardrobe_toolbar.dart';

/// Fits' "Select multiple": tick pieces, then act on all of them at once.
class ClothesSelectScreen extends StatefulWidget {
  const ClothesSelectScreen({super.key, this.query = const WardrobeQuery()});

  final WardrobeQuery query;

  @override
  State<ClothesSelectScreen> createState() => _ClothesSelectScreenState();
}

class _ClothesSelectScreenState extends State<ClothesSelectScreen> {
  late WardrobeQuery _query = widget.query;
  final Set<String> _selected = {};

  Future<void> _openFilters() async {
    final wardrobe = context.read<WardrobeController>();
    final result = await showWardrobeFilterSheet(
      context,
      query: _query,
      brands: wardrobe.brands,
      materials: wardrobe.materials,
    );
    if (result != null) setState(() => _query = result);
  }

  void _toggle(String id) => setState(
    () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
  );

  Future<void> _archive() async {
    final wardrobe = context.read<WardrobeController>();
    final ids = _selected.toList();
    await ClosetFlows.guard(
      context,
      () => wardrobe.setArchivedMany(ids, archived: true),
      successMessage: '${AppFormatters.count(ids.length, 'item')} archived',
    );
    if (mounted) setState(_selected.clear);
  }

  Future<void> _delete() async {
    final items = context.read<WardrobeController>().itemsByIds(_selected);
    final deleted = await ClosetFlows.deleteItems(context, items);
    if (deleted && mounted) setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeController>();
    final counts = context.watch<OutfitController>().itemOutfitCounts;
    final results = _query.apply(wardrobe.allItems, outfitCounts: counts);
    _selected.removeWhere((id) => wardrobe.itemById(id) == null);
    final allSelected =
        results.isNotEmpty && results.every((i) => _selected.contains(i.id));
    final ids = _selected.toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: AppSpacing.xs,
        title: TextButton(
          onPressed: () => setState(
            () => allSelected
                ? _selected.clear()
                : _selected.addAll(results.map((i) => i.id)),
          ),
          child: Text(allSelected ? 'Deselect all' : 'Select all'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ClothesToolbar(
              category: _query.category,
              onCategory: (c) =>
                  setState(() => _query = _query.copyWith(category: c)),
              onFilter: _openFilters,
              filterCount: _query.sheetFilterCount,
            ),
          ),
          SliverPadding(
            padding: pageInsets(context.screenSize.width)
                .copyWith(top: AppSpacing.sm, bottom: AppSpacing.xl),
            sliver: ClothingSliverGrid(
              items: results,
              checkable: true,
              isSelected: (item) => _selected.contains(item.id),
              onTap: (item) => _toggle(item.id),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SelectionTray(
              count: ids.length,
              actions: [
                TrayAction(
                  icon: Icons.checkroom_outlined,
                  label: 'Create outfit',
                  onTap: () =>
                      AppNavigator.createOutfit(context, initialItemIds: ids),
                ),
                TrayAction(
                  icon: Icons.bookmark_border_rounded,
                  label: 'Add to collection',
                  onTap: () => CollectionFlows.addItems(context, ids),
                ),
                TrayAction(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onTap: ids.length == 1
                      ? () => AppNavigator.editClothing(context, ids.single)
                      : null,
                ),
                TrayAction(
                  icon: Icons.inventory_2_outlined,
                  label: 'Archive',
                  onTap: _archive,
                ),
                TrayAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  onTap: _delete,
                ),
              ],
            ),
    );
  }
}

/// Fits' "Reorder": drag pieces into your own order, then save it as the
/// "Custom" sort.
class ReorderClothesScreen extends StatefulWidget {
  const ReorderClothesScreen({super.key});

  @override
  State<ReorderClothesScreen> createState() => _ReorderClothesScreenState();
}

class _ReorderClothesScreenState extends State<ReorderClothesScreen> {
  late final List<String> _ids = [
    for (final item in const WardrobeQuery(
      sort: WardrobeSort.custom,
    ).apply(context.read<WardrobeController>().activeItems))
      item.id,
  ];
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final saved = await ClosetFlows.guard(
      context,
      () => context.read<WardrobeController>().setCustomOrder(_ids),
    );
    if (saved) {
      navigator.pop();
    } else if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeController>();
    final items = wardrobe.itemsByIds(_ids);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reorder'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        itemCount: items.length,
        buildDefaultDragHandles: false,
        onReorderItem: (from, to) => setState(() {
          _ids.insert(to, _ids.removeAt(from));
        }),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            key: ValueKey(item.id),
            leading: SizedBox.square(
              dimension: AppSizes.thumbMd,
              child: ClothingImage(
                item: item,
                cutout: true,
                fit: BoxFit.contain,
                decodeWidth: AppSizes.thumbMd,
              ),
            ),
            title: Text(item.name),
            subtitle: Text(item.category.singularLabel),
            trailing: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle_rounded),
            ),
          );
        },
      ),
    );
  }
}
