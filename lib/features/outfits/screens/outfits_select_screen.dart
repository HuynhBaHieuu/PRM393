import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/selection_tray.dart';
import 'package:all_fits/features/collections/collection_flows.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/controllers/outfit_query.dart';
import 'package:all_fits/features/outfits/screens/outfits_screen.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cards.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cover.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/shared/closet_flows.dart';

/// Fits' "Select multiple" for outfits.
class OutfitsSelectScreen extends StatefulWidget {
  const OutfitsSelectScreen({super.key, this.query = const OutfitQuery()});

  final OutfitQuery query;

  @override
  State<OutfitsSelectScreen> createState() => _OutfitsSelectScreenState();
}

class _OutfitsSelectScreenState extends State<OutfitsSelectScreen> {
  late OutfitQuery _query = widget.query;
  final Set<String> _selected = {};

  Future<void> _openFilters() async {
    final result = await showOutfitFilterSheet(context, query: _query);
    if (result != null) setState(() => _query = result);
  }

  void _toggle(String id) => setState(
    () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
  );

  Future<void> _addToCollection() async {
    final ids = _selected.toList();
    if (ids.length == 1) {
      await CollectionFlows.addOutfit(context, ids.single);
    } else {
      for (final id in ids) {
        if (!mounted) return;
        await CollectionFlows.addOutfit(context, id);
      }
    }
  }

  Future<void> _delete() async {
    final count = _selected.length;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${AppFormatters.count(count, 'outfit')}?',
      message:
          'They will be removed along with their plans. Your clothes stay '
          'in your wardrobe.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final closet = context.read<ClosetActions>();
    final ids = _selected.toList();
    final done = await ClosetFlows.guard(context, () async {
      for (final id in ids) {
        await closet.deleteOutfit(id);
      }
    }, successMessage: '${AppFormatters.count(count, 'outfit')} deleted');
    if (done && mounted) setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OutfitController>();
    final results = _query.apply(controller.outfits);
    _selected.removeWhere((id) => controller.outfitById(id) == null);
    final allSelected =
        results.isNotEmpty && results.every((o) => _selected.contains(o.id));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: AppSpacing.xs,
        title: TextButton(
          onPressed: () => setState(
            () => allSelected
                ? _selected.clear()
                : _selected.addAll(results.map((o) => o.id)),
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
            child: OccasionToolbar(
              occasion: _query.occasion,
              onOccasion: (o) =>
                  setState(() => _query = _query.copyWith(occasion: o)),
              onFilter: _openFilters,
              filterCount: _query.sheetFilterCount,
            ),
          ),
          SliverPadding(
            padding: pageInsets(context.screenSize.width)
                .copyWith(top: AppSpacing.sm, bottom: AppSpacing.xl),
            sliver: OutfitTileGrid(
              outfits: results,
              checkable: true,
              isSelected: (o) => _selected.contains(o.id),
              onTap: (o) => _toggle(o.id),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SelectionTray(
              count: _selected.length,
              actions: [
                TrayAction(
                  icon: Icons.bookmark_border_rounded,
                  label: 'Add to collection',
                  onTap: _addToCollection,
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

/// Fits' "Reorder" for outfits: drag into the "Custom" sort order.
class ReorderOutfitsScreen extends StatefulWidget {
  const ReorderOutfitsScreen({super.key});

  @override
  State<ReorderOutfitsScreen> createState() => _ReorderOutfitsScreenState();
}

class _ReorderOutfitsScreenState extends State<ReorderOutfitsScreen> {
  late final List<String> _ids = [
    for (final o in const OutfitQuery(
      sort: OutfitSort.custom,
    ).apply(context.read<OutfitController>().outfits))
      o.id,
  ];
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final saved = await ClosetFlows.guard(
      context,
      () => context.read<OutfitController>().setCustomOrder(_ids),
    );
    if (saved) {
      navigator.pop();
    } else if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OutfitController>();
    final outfits = [for (final id in _ids) ?controller.outfitById(id)];
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
        buildDefaultDragHandles: false,
        itemCount: outfits.length,
        onReorderItem: (from, to) => setState(() {
          _ids.insert(to, _ids.removeAt(from));
        }),
        itemBuilder: (context, index) {
          final outfit = outfits[index];
          return ListTile(
            key: ValueKey(outfit.id),
            leading: SizedBox(
              width: AppSizes.thumbMd,
              height: AppSizes.thumbMd / 0.62,
              child: OutfitCover(
                outfit: outfit,
                items: watchOutfitItems(context, outfit),
                worn: true,
              ),
            ),
            title: Text(outfit.name),
            subtitle: outfit.occasion == null
                ? null
                : Text(outfit.occasion!.label),
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
