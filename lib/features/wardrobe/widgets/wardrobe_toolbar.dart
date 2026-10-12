import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/widgets/page_header.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/data/models/clothing_category.dart';

/// Search field with filter and sort buttons.
class WardrobeToolbar extends StatelessWidget {
  const WardrobeToolbar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilter,
    required this.onSort,
    required this.filterCount,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilter;
  final VoidCallback onSort;
  final int filterCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Row(
        children: [
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: searchController,
              builder: (context, value, _) => TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search name, brand, color…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          HeaderIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Filter',
            badgeCount: filterCount,
            onPressed: onFilter,
          ),
          const SizedBox(width: AppSpacing.xs),
          HeaderIconButton(
            icon: Icons.swap_vert_rounded,
            tooltip: 'Sort',
            onPressed: onSort,
          ),
        ],
      ),
    );
  }
}

/// Horizontally scrolling category pills with an "All" option.
class CategoryFilterBar extends StatelessWidget {
  const CategoryFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.categories = ClothingCategory.values,
  });

  final ClothingCategory? selected;
  final ValueChanged<ClothingCategory?> onChanged;
  final List<ClothingCategory> categories;

  static const double _height = 36;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          if (index == 0) {
            return SelectablePill(
              label: 'All',
              selected: selected == null,
              onTap: () => onChanged(null),
            );
          }
          final category = categories[index - 1];
          return SelectablePill(
            label: category.label,
            selected: selected == category,
            onTap: () => onChanged(selected == category ? null : category),
          );
        },
      ),
    );
  }
}
