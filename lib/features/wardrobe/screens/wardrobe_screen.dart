import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/option_sheets.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_query.dart';
import 'package:all_fits/features/wardrobe/widgets/clothing_grid.dart';
import 'package:all_fits/features/wardrobe/widgets/wardrobe_filter_sheet.dart';
import 'package:all_fits/features/wardrobe/widgets/wardrobe_toolbar.dart';

/// The Clothes tab: Fits' chip toolbar over a grid of cut-outs.
class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

enum _MoreAction { select, reorder }

class _WardrobeScreenState extends State<WardrobeScreen> {
  WardrobeQuery _query = const WardrobeQuery();

  void _setQuery(WardrobeQuery query) => setState(() => _query = query);

  Future<void> _openFilters() async {
    final wardrobe = context.read<WardrobeController>();
    final result = await showWardrobeFilterSheet(
      context,
      query: _query,
      brands: wardrobe.brands,
      materials: wardrobe.materials,
    );
    if (result != null) _setQuery(result);
  }

  Future<void> _openMore() async {
    final action = await showModalBottomSheet<_MoreAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetActionTile(
                icon: Icons.check_circle_outline_rounded,
                label: 'Select multiple',
                onTap: () => Navigator.of(sheetContext).pop(_MoreAction.select),
              ),
              SheetActionTile(
                icon: Icons.swap_vert_rounded,
                label: 'Reorder',
                onTap: () =>
                    Navigator.of(sheetContext).pop(_MoreAction.reorder),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _MoreAction.select:
        await AppNavigator.selectClothes(context, query: _query);
      case _MoreAction.reorder:
        await AppNavigator.reorderClothes(context);
        // Show the new order straight away.
        if (mounted) _setQuery(_query.copyWith(sort: WardrobeSort.custom));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeController>();
    final counts = context.watch<OutfitController>().itemOutfitCounts;
    final results = _query.apply(wardrobe.allItems, outfitCounts: counts);
    final insets = pageInsets(context.screenSize.width);
    final ids = [for (final item in results) item.id];

    void open(ClothingItem item) =>
        AppNavigator.clothingDetail(context, item.id, siblings: ids);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
          SliverToBoxAdapter(
            child: ClothesToolbar(
              category: _query.category,
              onCategory: (c) => _setQuery(_query.copyWith(category: c)),
              onFilter: _openFilters,
              filterCount: _query.sheetFilterCount,
              onMore: wardrobe.activeItems.isEmpty ? null : _openMore,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
          if (wardrobe.activeItems.isEmpty && !_query.showArchived)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.checkroom_outlined,
                title: 'Your wardrobe is empty',
                message: 'Add your first clothing item to get started.',
                actionLabel: 'Add Clothing',
                onAction: () => AppNavigator.addClothing(context),
              ),
            )
          else if (results.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No clothes match your filters',
                message: 'Change your filters and try again',
                actionLabel: 'Clear filters',
                onAction: () => _setQuery(_query.cleared()),
              ),
            )
          else
            for (final (label, items) in _query.group(results)) ...[
              if (label.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.md,
                      AppSpacing.page,
                      AppSpacing.xs,
                    ),
                    child: Text(
                      '$label  ${items.length}',
                      style: context.textTheme.titleMedium,
                    ),
                  ),
                ),
              SliverPadding(
                padding: insets.copyWith(bottom: AppSpacing.md),
                sliver: ClothingSliverGrid(items: items, onTap: open),
              ),
            ],
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }
}
