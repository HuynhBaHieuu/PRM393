import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/collection.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cards.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/wardrobe/widgets/clothing_grid.dart';

/// What the user ticked in [showCollectionEntryPicker].
typedef CollectionSelection = ({Set<String> itemIds, Set<String> outfitIds});

/// Lets the user tick many pieces and outfits at once, starting from what
/// [collection] already holds. Resolves to the full selection, or null when
/// dismissed.
Future<CollectionSelection?> showCollectionEntryPicker(
  BuildContext context, {
  required Collection collection,
}) {
  return showModalBottomSheet<CollectionSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _EntryPickerSheet(collection: collection),
  );
}

class _EntryPickerSheet extends StatefulWidget {
  const _EntryPickerSheet({required this.collection});

  final Collection collection;

  @override
  State<_EntryPickerSheet> createState() => _EntryPickerSheetState();
}

class _EntryPickerSheetState extends State<_EntryPickerSheet> {
  late final Set<String> _items = {...widget.collection.itemIds};
  late final Set<String> _outfits = {...widget.collection.outfitIds};

  void _toggle(Set<String> set, String id) =>
      setState(() => set.contains(id) ? set.remove(id) : set.add(id));

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeController>();
    // Archived pieces already inside stay listed so they can be taken out.
    final items = [
      ...wardrobe.activeItems,
      ...wardrobe.archivedItems.where(
        (item) => widget.collection.containsItem(item.id),
      ),
    ];
    final outfits = context.watch<OutfitController>().outfits;
    final itemIds = {for (final item in items) item.id};
    final outfitIds = {for (final outfit in outfits) outfit.id};
    final selectedItems = _items.where(itemIds.contains).length;
    final selectedOutfits = _outfits.where(outfitIds.contains).length;

    return DefaultTabController(
      length: 2,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        // Each tab scrolls on its own, so the sheet's controller goes unused.
        builder: (context, _) => Column(
          children: [
            SheetHeader(title: 'Add to ${widget.collection.name}'),
            TabBar(
              tabs: [
                Tab(text: 'Clothes ($selectedItems)'),
                Tab(text: 'Outfits ($selectedOutfits)'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  items.isEmpty
                      ? const AppEmptyState(
                          compact: true,
                          icon: Icons.checkroom_outlined,
                          title: 'No clothes yet',
                          message: 'Add pieces to your wardrobe first.',
                        )
                      : CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.all(AppSpacing.page),
                              sliver: ClothingSliverGrid(
                                items: items,
                                isSelected: (item) => _items.contains(item.id),
                                onTap: (item) => _toggle(_items, item.id),
                              ),
                            ),
                          ],
                        ),
                  outfits.isEmpty
                      ? const AppEmptyState(
                          compact: true,
                          icon: Icons.style_outlined,
                          title: 'No outfits yet',
                          message: 'Create an outfit first.',
                        )
                      : CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.all(AppSpacing.page),
                              sliver: OutfitSliverGrid(
                                outfits: outfits,
                                isSelected: (outfit) =>
                                    _outfits.contains(outfit.id),
                                onTap: (outfit) => _toggle(_outfits, outfit.id),
                              ),
                            ),
                          ],
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
                    onPressed: () => Navigator.of(context).pop((
                      // Ids of things deleted meanwhile are dropped here.
                      itemIds: _items.where(itemIds.contains).toSet(),
                      outfitIds: _outfits.where(outfitIds.contains).toSet(),
                    )),
                    child: Text(
                      selectedItems + selectedOutfits == 0
                          ? 'Done'
                          : 'Done · ${selectedItems + selectedOutfits} selected',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
