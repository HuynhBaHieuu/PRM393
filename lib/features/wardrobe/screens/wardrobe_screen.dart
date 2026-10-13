import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/page_header.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_query.dart';
import 'package:all_fits/features/wardrobe/widgets/clothing_grid.dart';
import 'package:all_fits/features/wardrobe/widgets/wardrobe_filter_sheet.dart';
import 'package:all_fits/features/wardrobe/widgets/wardrobe_toolbar.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  final TextEditingController _search = TextEditingController();
  WardrobeQuery _query = const WardrobeQuery();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setQuery(WardrobeQuery query) => setState(() => _query = query);

  Future<void> _openFilters() async {
    final result = await showWardrobeFilterSheet(
      context,
      query: _query,
      brands: context.read<WardrobeController>().brands,
    );
    if (result != null) _setQuery(result);
  }

  Future<void> _openSort() async {
    final sort = await showWardrobeSortSheet(context, current: _query.sort);
    if (sort != null) _setQuery(_query.copyWith(sort: sort));
  }

  void _clearAll() {
    _search.clear();
    _setQuery(_query.cleared());
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeController>();
    final results = _query.apply(wardrobe.allItems);
    final insets = pageInsets(context.screenSize.width);
    final activeCount = wardrobe.activeItems.length;
    final brands = wardrobe.brands;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Your Wardrobe',
              subtitle: AppFormatters.count(activeCount, 'piece'),
              actions: [
                HeaderIconButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Add clothing',
                  filled: true,
                  onPressed: () => AppNavigator.addClothing(context),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: WardrobeToolbar(
              searchController: _search,
              onSearchChanged: (text) =>
                  _setQuery(_query.copyWith(searchText: text)),
              onFilter: _openFilters,
              onSort: _openSort,
              filterCount: _query.sheetFilterCount,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          SliverToBoxAdapter(
            child: CategoryFilterBar(
              selected: _query.category,
              onChanged: (category) =>
                  _setQuery(_query.copyWith(category: category)),
            ),
          ),
          if (brands.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xs)),
            SliverToBoxAdapter(
              child: BrandFilterBar(
                brands: brands,
                selected: _query.brands,
                onChanged: (brands) =>
                    _setQuery(_query.copyWith(brands: brands)),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: _ResultsBar(
              count: results.length,
              query: _query,
              onClear: _query.hasRefinements ? _clearAll : null,
            ),
          ),
          if (activeCount == 0 && !_query.showArchived)
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
                icon: _query.showArchived
                    ? Icons.inventory_2_outlined
                    : Icons.search_off_rounded,
                title: _query.showArchived ? 'No archived items' : 'No matches',
                message: _query.showArchived
                    ? 'Items you archive will appear here.'
                    : 'Try a different search or clear your filters.',
                actionLabel: 'Clear filters',
                onAction: _clearAll,
              ),
            )
          else
            SliverPadding(
              padding: insets.copyWith(bottom: AppSpacing.xl),
              sliver: ClothingSliverGrid(
                items: results,
                onTap: (item) => AppNavigator.clothingDetail(context, item.id),
                onFavorite: (item) => ClosetFlows.guard(
                  context,
                  () => wardrobe.toggleFavorite(item.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultsBar extends StatelessWidget {
  const _ResultsBar({required this.count, required this.query, this.onClear});

  final int count;
  final WardrobeQuery query;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final label = [
      AppFormatters.count(count, 'item'),
      if (query.showArchived) 'archived',
      if (query.sort != WardrobeSort.newest) query.sort.label.toLowerCase(),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.bodySmall)),
          if (onClear != null)
            TextButton(onPressed: onClear, child: const Text('Clear all'))
          else
            TextButton.icon(
              onPressed: () => AppNavigator.insights(context),
              icon: const Icon(Icons.insights_outlined, size: AppSizes.iconSm),
              label: const Text('Insights'),
            ),
        ],
      ),
    );
  }
}
