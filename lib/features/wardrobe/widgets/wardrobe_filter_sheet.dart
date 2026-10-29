import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/constants/app_durations.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/color_swatch.dart';
import 'package:all_fits/core/widgets/option_sheets.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_query.dart';

/// Opens Fits' "Filters" sheet; resolves to the updated query, or null if
/// dismissed.
Future<WardrobeQuery?> showWardrobeFilterSheet(
  BuildContext context, {
  required WardrobeQuery query,
  required List<String> brands,
  required List<String> materials,
  required List<String> tags,
}) {
  return showModalBottomSheet<WardrobeQuery>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => WardrobeFilterSheet(
      query: query,
      brands: brands,
      materials: materials,
      tags: tags,
    ),
  );
}

class WardrobeFilterSheet extends StatefulWidget {
  const WardrobeFilterSheet({
    super.key,
    required this.query,
    required this.brands,
    required this.materials,
    required this.tags,
  });

  final WardrobeQuery query;
  final List<String> brands;
  final List<String> materials;
  final List<String> tags;

  @override
  State<WardrobeFilterSheet> createState() => _WardrobeFilterSheetState();
}

class _WardrobeFilterSheetState extends State<WardrobeFilterSheet> {
  late WardrobeQuery _query = widget.query;
  late final TextEditingController _name = TextEditingController(
    text: widget.query.searchText,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Set<T> _toggled<T>(Set<T> set, T value) =>
      set.contains(value) ? ({...set}..remove(value)) : {...set, value};

  static String? _summary(Iterable<String> names) =>
      names.isEmpty ? null : names.join(', ');

  Future<void> _pickCategories() async {
    final result = await showMultiSelectSheet<ClothingCategory>(
      context,
      options: ClothingCategory.values,
      selected: _query.categories,
      labelOf: (c) => c.label,
    );
    if (result != null) {
      setState(() => _query = _query.copyWith(categories: result));
    }
  }

  /// Brands, materials and tags are stored lower-cased; [names] keeps their casing.
  Future<Set<String>?> _pickNames(List<String> names, Set<String> keys) async {
    final result = await showMultiSelectSheet<String>(
      context,
      options: names,
      selected: names.where((n) => keys.contains(n.toLowerCase())).toSet(),
      labelOf: (n) => n,
    );
    return result?.map((n) => n.toLowerCase()).toSet();
  }

  Future<void> _pickBrands() async {
    if (widget.brands.isEmpty) {
      context.showSnack('Add a brand to a piece to filter by it.');
      return;
    }
    final result = await _pickNames(widget.brands, _query.brands);
    if (result != null) {
      setState(() => _query = _query.copyWith(brands: result));
    }
  }

  Future<void> _pickMaterials() async {
    if (widget.materials.isEmpty) {
      context.showSnack('Add materials to a piece to filter by them.');
      return;
    }
    final result = await _pickNames(widget.materials, _query.materials);
    if (result != null) {
      setState(() => _query = _query.copyWith(materials: result));
    }
  }

  Future<void> _pickTags() async {
    if (widget.tags.isEmpty) {
      context.showSnack('Add tags to a piece to filter by them.');
      return;
    }
    final result = await _pickNames(widget.tags, _query.tags);
    if (result != null) {
      setState(() => _query = _query.copyWith(tags: result));
    }
  }

  void _clear() {
    _name.clear();
    setState(() => _query = _query.clearedSheetFilters());
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return OptionSheetFrame(
      title: 'Filters',
      secondaryLabel: 'Clear filters',
      onSecondary: _clear,
      onDone: () =>
          Navigator.of(context)
              .pop(_query.copyWith(searchText: _name.text.trim())),
      children: [
        const OptionSheetLabel('Colors'),
        SizedBox(
          height: _ColorDot.size + 8,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final color in ClothingColor.values)
                _ColorDot(
                  color: color,
                  selected: _query.colors.contains(color),
                  onTap: () => setState(
                    () => _query = _query.copyWith(
                      colors: _toggled(_query.colors, color),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const OptionSheetLabel('Categories'),
        SelectFieldButton(
          placeholder: 'Select categories',
          value: _summary(_query.categories.map((c) => c.label)),
          onTap: _pickCategories,
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
                onTap: () => setState(
                  () => _query = _query.copyWith(
                    seasons: _toggled(_query.seasons, season),
                  ),
                ),
              ),
          ],
        ),
        const OptionSheetLabel('Brands'),
        SelectFieldButton(
          placeholder: 'Select brands',
          value: _summary(
            widget.brands.where((b) => _query.brands.contains(b.toLowerCase())),
          ),
          onTap: _pickBrands,
        ),
        const OptionSheetLabel('Materials'),
        SelectFieldButton(
          placeholder: 'Select materials',
          value: _summary(
            widget.materials.where(
              (m) => _query.materials.contains(m.toLowerCase()),
            ),
          ),
          onTap: _pickMaterials,
        ),
        const OptionSheetLabel('Tags'),
        SelectFieldButton(
          placeholder: 'Select tags',
          value: _summary(
            widget.tags
                .where((t) => _query.tags.contains(t.toLowerCase()))
                .map((t) => '#$t'),
          ),
          onTap: _pickTags,
        ),
        const OptionSheetLabel('Name'),
        TextField(
          controller: _name,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search for name',
            filled: false,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              borderSide: BorderSide(color: palette.border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              borderSide: BorderSide(color: palette.border, width: 1.5),
            ),
          ),
        ),
        const OptionSheetLabel('Usage'),
        _ChoiceRow<ItemUsage>(
          options: ItemUsage.values,
          selected: _query.usage,
          labelOf: (u) => u.label,
          onSelect: (u) => setState(() => _query = _query.copyWith(usage: u)),
        ),
        const OptionSheetLabel('Sort items by'),
        _ChoiceRow<WardrobeSort>(
          options: WardrobeSort.values,
          selected: _query.sort,
          labelOf: (s) => s.label,
          onSelect: (s) => setState(() => _query = _query.copyWith(sort: s)),
        ),
        const OptionSheetLabel('Group items by'),
        _ChoiceRow<WardrobeGroup>(
          options: WardrobeGroup.values,
          selected: _query.groupBy,
          labelOf: (g) => g.label,
          onSelect: (g) => setState(() => _query = _query.copyWith(groupBy: g)),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

/// One choice out of several, as a scrolling row of pills.
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  final List<T> options;
  final T selected;
  final String Function(T option) labelOf;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return PillBar(
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
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final ClothingColor color;
  final bool selected;
  final VoidCallback onTap;

  static const double size = 40;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final light = color.swatch.computeLuminance() > 0.5 || color.isMulti;
    return Semantics(
      button: true,
      selected: selected,
      label: color.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          margin: const EdgeInsets.only(right: AppSpacing.sm),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? palette.ink : Colors.transparent,
              width: 2,
            ),
          ),
          child: ColorSwatchDot(
            color: color,
            size: size,
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: light ? Colors.black : Colors.white,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Fits' season chip: an outlined box with the season's emoji.
class SeasonChip extends StatelessWidget {
  const SeasonChip({
    super.key,
    required this.season,
    required this.selected,
    required this.onTap,
  });

  final Season season;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.ink : palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(
            color: selected ? palette.ink : palette.border,
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                EmojiIcon(season.emoji, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  season.label,
                  style: context.textTheme.titleSmall?.copyWith(
                    color: selected ? palette.onInk : palette.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
