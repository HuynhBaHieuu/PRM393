import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/option_sheets.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/data/models/occasion.dart';
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/controllers/outfit_query.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cards.dart';
import 'package:all_fits/features/wardrobe/widgets/wardrobe_filter_sheet.dart';
import 'package:all_fits/features/wardrobe/widgets/wardrobe_toolbar.dart';

enum _MoreAction { select, reorder }

/// The Outfits tab: Fits' occasion chips, filter and "⋯" buttons over a
/// three-column grid of outfit cards.
class OutfitsScreen extends StatefulWidget {
  const OutfitsScreen({super.key});

  @override
  State<OutfitsScreen> createState() => _OutfitsScreenState();
}

class _OutfitsScreenState extends State<OutfitsScreen> {
  OutfitQuery _query = const OutfitQuery();

  Future<void> _openFilters() async {
    final result = await showOutfitFilterSheet(context, query: _query);
    if (result != null) setState(() => _query = result);
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
        await AppNavigator.selectOutfits(context, query: _query);
      case _MoreAction.reorder:
        await AppNavigator.reorderOutfits(context);
        if (mounted) {
          setState(() => _query = _query.copyWith(sort: OutfitSort.custom));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<OutfitController>().outfits;
    final visible = _query.apply(all);
    final insets = pageInsets(context.screenSize.width);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
          SliverToBoxAdapter(
            child: OccasionToolbar(
              occasion: _query.occasion,
              onOccasion: (o) =>
                  setState(() => _query = _query.copyWith(occasion: o)),
              onFilter: _openFilters,
              filterCount: _query.sheetFilterCount,
              onMore: all.isEmpty ? null : _openMore,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
          if (all.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.style_outlined,
                title: 'No outfits yet',
                message:
                    'Your outfits will appear here. Create collages '
                    'or add outfit selfies.',
                actionLabel: 'Create Outfit',
                onAction: () => AppNavigator.createOutfit(context),
              ),
            )
          else if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No outfits match your filters',
                message: 'Change your filters and try again',
                actionLabel: 'Clear filters',
                onAction: () => setState(() => _query = const OutfitQuery()),
              ),
            )
          else
            for (final (label, outfits) in _query.group(visible)) ...[
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
                      '$label  ${outfits.length}',
                      style: context.textTheme.titleMedium,
                    ),
                  ),
                ),
              SliverPadding(
                padding: insets.copyWith(bottom: AppSpacing.md),
                sliver: OutfitTileGrid(
                  outfits: outfits,
                  onTap: (o) => AppNavigator.outfitDetail(context, o.id),
                ),
              ),
            ],
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }
}

/// Occasion chips with the round filter and "⋯" buttons.
class OccasionToolbar extends StatelessWidget {
  const OccasionToolbar({
    super.key,
    required this.occasion,
    required this.onOccasion,
    required this.onFilter,
    this.filterCount = 0,
    this.onMore,
  });

  final Occasion? occasion;
  final ValueChanged<Occasion?> onOccasion;
  final VoidCallback onFilter;
  final int filterCount;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: AppSpacing.page),
              children: [
                CategoryChip(
                  label: 'All',
                  selected: occasion == null,
                  onTap: () => onOccasion(null),
                ),
                for (final o in Occasion.values)
                  CategoryChip(
                    label: o.label,
                    selected: occasion == o,
                    onTap: () => onOccasion(occasion == o ? null : o),
                  ),
              ],
            ),
          ),
          RoundToolButton(
            icon: Icons.filter_list_rounded,
            tooltip: 'Filter',
            badgeCount: filterCount,
            onPressed: onFilter,
          ),
          if (onMore != null) ...[
            const SizedBox(width: AppSpacing.xs),
            RoundToolButton(
              icon: Icons.more_horiz_rounded,
              tooltip: 'More',
              onPressed: onMore!,
            ),
          ],
          const SizedBox(width: AppSpacing.page),
        ],
      ),
    );
  }
}

/// Fits' outfit "Filters" sheet; resolves to the new query, or null.
Future<OutfitQuery?> showOutfitFilterSheet(
  BuildContext context, {
  required OutfitQuery query,
}) {
  return showModalBottomSheet<OutfitQuery>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _OutfitFilterSheet(query: query),
  );
}

class _OutfitFilterSheet extends StatefulWidget {
  const _OutfitFilterSheet({required this.query});

  final OutfitQuery query;

  @override
  State<_OutfitFilterSheet> createState() => _OutfitFilterSheetState();
}

class _OutfitFilterSheetState extends State<_OutfitFilterSheet> {
  late OutfitQuery _query = widget.query;
  late final TextEditingController _name = TextEditingController(
    text: widget.query.searchText,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickOccasions() async {
    final result = await showMultiSelectSheet<Occasion>(
      context,
      options: Occasion.values,
      selected: _query.occasions,
      labelOf: (o) => o.label,
    );
    if (result != null) {
      setState(() => _query = _query.copyWith(occasions: result));
    }
  }

  Widget _choices<T>(
    List<T> options,
    T selected,
    String Function(T) labelOf,
    ValueChanged<T> onSelect,
  ) => PillBar(
    padding: EdgeInsets.zero,
    pills: [
      for (final option in options)
        SelectablePill(
          label: labelOf(option),
          selected: option == selected,
          onTap: () => onSelect(option),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      borderSide: BorderSide(color: palette.border, width: 1.5),
    );
    return OptionSheetFrame(
      title: 'Filters',
      secondaryLabel: 'Clear filters',
      onSecondary: () {
        _name.clear();
        setState(() => _query = _query.clearedSheetFilters());
      },
      onDone: () =>
          Navigator.of(context)
              .pop(_query.copyWith(searchText: _name.text.trim())),
      children: [
        const OptionSheetLabel('Categories'),
        SelectFieldButton(
          placeholder: 'Select categories',
          value: _query.occasions.isEmpty
              ? null
              : _query.occasions.map((o) => o.label).join(', '),
          onTap: _pickOccasions,
        ),
        const OptionSheetLabel('Season'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final season in Season.values)
              SeasonChip(
                season: season,
                selected: _query.seasons.contains(season),
                onTap: () => setState(() {
                  final seasons = {..._query.seasons};
                  if (!seasons.remove(season)) seasons.add(season);
                  _query = _query.copyWith(seasons: seasons);
                }),
              ),
          ],
        ),
        const OptionSheetLabel('Name'),
        TextField(
          controller: _name,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'Search for name',
            filled: false,
            border: border,
            enabledBorder: border,
          ),
        ),
        const OptionSheetLabel('Image type'),
        _choices<OutfitImageType>(
          OutfitImageType.values,
          _query.imageType,
          (t) => t.label,
          (t) => setState(() => _query = _query.copyWith(imageType: t)),
        ),
        const OptionSheetLabel('Sort items by'),
        _choices<OutfitSort>(
          OutfitSort.values,
          _query.sort,
          (s) => s.label,
          (s) => setState(() => _query = _query.copyWith(sort: s)),
        ),
        const OptionSheetLabel('Group items by'),
        _choices<OutfitGroup>(
          OutfitGroup.values,
          _query.groupBy,
          (g) => g.label,
          (g) => setState(() => _query = _query.copyWith(groupBy: g)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Favorites only'),
          value: _query.favoritesOnly,
          onChanged: (on) =>
              setState(() => _query = _query.copyWith(favoritesOnly: on)),
        ),
      ],
    );
  }
}
