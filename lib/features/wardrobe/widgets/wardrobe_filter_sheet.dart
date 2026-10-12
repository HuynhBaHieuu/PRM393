import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/widgets/color_swatch.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_query.dart';

/// Opens the filter sheet; resolves to the updated query, or null if closed.
Future<WardrobeQuery?> showWardrobeFilterSheet(
  BuildContext context, {
  required WardrobeQuery query,
  required List<String> brands,
}) {
  return showModalBottomSheet<WardrobeQuery>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => WardrobeFilterSheet(query: query, brands: brands),
  );
}

class WardrobeFilterSheet extends StatefulWidget {
  const WardrobeFilterSheet({
    super.key,
    required this.query,
    required this.brands,
  });

  final WardrobeQuery query;
  final List<String> brands;

  @override
  State<WardrobeFilterSheet> createState() => _WardrobeFilterSheetState();
}

class _WardrobeFilterSheetState extends State<WardrobeFilterSheet> {
  late WardrobeQuery _query = widget.query;

  static const double _maxHeightFraction = 0.85;

  Set<T> _toggled<T>(Set<T> set, T value) =>
      set.contains(value) ? ({...set}..remove(value)) : {...set, value};

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * _maxHeightFraction;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(title: 'Filter'),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              children: [
                LabeledSection(
                  label: 'Color',
                  child: ColorSwatchPicker(
                    selected: null,
                    multiSelected: _query.colors,
                    onChanged: (color) => setState(
                      () => _query = _query.copyWith(
                        colors: _toggled(_query.colors, color),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                LabeledSection(
                  label: 'Season',
                  child: PillGroup<Season>(
                    options: Season.values,
                    selected: _query.seasons,
                    labelOf: (s) => s.label,
                    onToggle: (season) => setState(
                      () => _query = _query.copyWith(
                        seasons: _toggled(_query.seasons, season),
                      ),
                    ),
                  ),
                ),
                if (widget.brands.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  LabeledSection(
                    label: 'Brand',
                    child: PillGroup<String>(
                      options: widget.brands,
                      selected: widget.brands
                          .where((b) => _query.brands.contains(b.toLowerCase()))
                          .toSet(),
                      labelOf: (b) => b,
                      onToggle: (brand) => setState(
                        () => _query = _query.copyWith(
                          brands: _toggled(_query.brands, brand.toLowerCase()),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Favorites only'),
                  value: _query.favoritesOnly,
                  onChanged: (value) => setState(
                    () => _query = _query.copyWith(favoritesOnly: value),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show archived items'),
                  subtitle: const Text('Browse items you have put away'),
                  value: _query.showArchived,
                  onChanged: (value) => setState(
                    () => _query = _query.copyWith(showArchived: value),
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
                AppSpacing.md,
                AppSpacing.page,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          setState(() => _query = _query.clearedSheetFilters()),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_query),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the sort options; resolves to the chosen sort, or null.
Future<WardrobeSort?> showWardrobeSortSheet(
  BuildContext context, {
  required WardrobeSort current,
}) {
  return showModalBottomSheet<WardrobeSort>(
    context: context,
    useSafeArea: true,
    builder: (context) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(title: 'Sort by'),
          for (final sort in WardrobeSort.values)
            ListTile(
              title: Text(sort.label),
              trailing: sort == current
                  ? const Icon(Icons.check_rounded)
                  : null,
              selected: sort == current,
              onTap: () => Navigator.of(context).pop(sort),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}
