import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/season.dart';

/// Fits' "Sort items by" options.
enum WardrobeSort {
  custom('Custom'),
  dateAdded('Date added'),
  categories('Categories'),
  colors('Colors'),
  mostOutfits('Most outfits');

  const WardrobeSort(this.label);

  final String label;
}

/// Fits' "Group items by" options.
enum WardrobeGroup {
  none('None'),
  categories('Categories'),
  season('Season'),
  colors('Colors'),
  tags('Tags');

  const WardrobeGroup(this.label);

  final String label;
}

/// Fits' "Usage" filter: whether a piece is in any saved outfit.
enum ItemUsage {
  all('All'),
  unused('Not used in outfits'),
  used('Used in outfits');

  const ItemUsage(this.label);

  final String label;
}

const Object _unset = Object();

/// Search, filter, sort and grouping settings for the wardrobe grid. Pure
/// and immutable, so the same logic can back other views or a remote query.
class WardrobeQuery {
  const WardrobeQuery({
    this.searchText = '',
    this.category,
    this.categories = const {},
    this.colors = const {},
    this.seasons = const {},
    this.brands = const {},
    this.materials = const {},
    this.tags = const {},
    this.usage = ItemUsage.all,
    this.favoritesOnly = false,
    this.showArchived = false,
    this.sort = WardrobeSort.dateAdded,
    this.groupBy = WardrobeGroup.none,
  });

  /// Matched against the name (and brand, category, color).
  final String searchText;

  /// The category chip above the grid.
  final ClothingCategory? category;

  /// Categories picked in the filter sheet.
  final Set<ClothingCategory> categories;
  final Set<ClothingColor> colors;
  final Set<Season> seasons;

  /// Lower-cased brand names.
  final Set<String> brands;

  /// Lower-cased material names.
  final Set<String> materials;

  /// Lower-cased tags; a piece matches when it has any of them.
  final Set<String> tags;
  final ItemUsage usage;
  final bool favoritesOnly;

  /// When true, shows archived items instead of the active wardrobe.
  final bool showArchived;
  final WardrobeSort sort;
  final WardrobeGroup groupBy;

  /// Number of refinements set in the filter sheet.
  int get sheetFilterCount =>
      categories.length +
      colors.length +
      seasons.length +
      brands.length +
      materials.length +
      tags.length +
      (searchText.trim().isEmpty ? 0 : 1) +
      (usage == ItemUsage.all ? 0 : 1) +
      (favoritesOnly ? 1 : 0) +
      (showArchived ? 1 : 0);

  bool get hasRefinements => sheetFilterCount > 0 || category != null;

  WardrobeQuery copyWith({
    String? searchText,
    Object? category = _unset,
    Set<ClothingCategory>? categories,
    Set<ClothingColor>? colors,
    Set<Season>? seasons,
    Set<String>? brands,
    Set<String>? materials,
    Set<String>? tags,
    ItemUsage? usage,
    bool? favoritesOnly,
    bool? showArchived,
    WardrobeSort? sort,
    WardrobeGroup? groupBy,
  }) {
    return WardrobeQuery(
      searchText: searchText ?? this.searchText,
      category: identical(category, _unset)
          ? this.category
          : category as ClothingCategory?,
      categories: categories ?? this.categories,
      colors: colors ?? this.colors,
      seasons: seasons ?? this.seasons,
      brands: brands ?? this.brands,
      materials: materials ?? this.materials,
      tags: tags ?? this.tags,
      usage: usage ?? this.usage,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      showArchived: showArchived ?? this.showArchived,
      sort: sort ?? this.sort,
      groupBy: groupBy ?? this.groupBy,
    );
  }

  /// Clears everything except the sort order and grouping.
  WardrobeQuery cleared() => WardrobeQuery(sort: sort, groupBy: groupBy);

  /// "Clear filters" in the sheet: keeps the category chip.
  WardrobeQuery clearedSheetFilters() => WardrobeQuery(category: category);

  /// [outfitCounts] maps an item id to the number of outfits using it; the
  /// Usage filter and "Most outfits" sort read it.
  List<ClothingItem> apply(
    Iterable<ClothingItem> items, {
    Map<String, int> outfitCounts = const {},
  }) {
    final query = searchText.trim().toLowerCase();
    int outfitsOf(ClothingItem item) => outfitCounts[item.id] ?? 0;
    final result = items.where((item) {
      if (item.isArchived != showArchived) return false;
      if (category != null && item.category != category) return false;
      if (categories.isNotEmpty && !categories.contains(item.category)) {
        return false;
      }
      if (favoritesOnly && !item.isFavorite) return false;
      if (colors.isNotEmpty && !colors.contains(item.color)) return false;
      if (seasons.isNotEmpty && !item.seasons.any(seasons.contains)) {
        return false;
      }
      if (brands.isNotEmpty &&
          !brands.contains(item.brand?.trim().toLowerCase())) {
        return false;
      }
      if (materials.isNotEmpty &&
          !item.materials.any((m) => materials.contains(m.toLowerCase()))) {
        return false;
      }
      if (tags.isNotEmpty &&
          !item.tags.any((t) => tags.contains(t.toLowerCase()))) {
        return false;
      }
      switch (usage) {
        case ItemUsage.all:
          break;
        case ItemUsage.unused:
          if (outfitsOf(item) > 0) return false;
        case ItemUsage.used:
          if (outfitsOf(item) == 0) return false;
      }
      return query.isEmpty || matchesSearch(item, query);
    }).toList();
    result.sort((a, b) {
      final order = _compare(a, b, outfitsOf);
      // Newest first breaks ties, so equal pieces keep a stable order.
      return order != 0 ? order : b.createdAt.compareTo(a.createdAt);
    });
    return result;
  }

  /// Splits sorted [items] into labeled groups for [groupBy]; a single
  /// unlabeled group when not grouping. A piece in several seasons shows
  /// in each of them.
  List<(String, List<ClothingItem>)> group(List<ClothingItem> items) {
    switch (groupBy) {
      case WardrobeGroup.none:
        return [('', items)];
      case WardrobeGroup.categories:
        return _groups(
          items,
          ClothingCategory.values,
          (item) => [item.category],
          (c) => c.label,
        );
      case WardrobeGroup.colors:
        return _groups(
          items,
          ClothingColor.values,
          (item) => [?item.color],
          (c) => c.label,
          other: 'No color',
        );
      case WardrobeGroup.season:
        return _groups(
          items,
          Season.values,
          (item) => item.seasons,
          (s) => '${s.emoji} ${s.label}',
          other: 'No season',
        );
      case WardrobeGroup.tags:
        // Tags are free text: group by their lower-cased form, labelled with
        // the first spelling seen, alphabetically.
        final labels = <String, String>{};
        for (final item in items) {
          for (final tag in item.tags) {
            labels.putIfAbsent(tag.toLowerCase(), () => tag);
          }
        }
        final keys = labels.keys.toList()..sort();
        return _groups(
          items,
          keys,
          (item) => [for (final t in item.tags) t.toLowerCase()],
          (key) => '#${labels[key]}',
          other: 'No tags',
        );
    }
  }

  static List<(String, List<ClothingItem>)> _groups<T>(
    List<ClothingItem> items,
    List<T> keys,
    List<T> Function(ClothingItem item) keysOf,
    String Function(T key) labelOf, {
    String? other,
  }) {
    final byKey = {for (final key in keys) key: <ClothingItem>[]};
    final rest = <ClothingItem>[];
    for (final item in items) {
      final itemKeys = keysOf(item);
      if (itemKeys.isEmpty) rest.add(item);
      for (final key in itemKeys) {
        byKey[key]?.add(item);
      }
    }
    return [
      for (final MapEntry(:key, :value) in byKey.entries)
        if (value.isNotEmpty) (labelOf(key), value),
      if (rest.isNotEmpty && other != null) (other, rest),
    ];
  }

  /// Matches name, brand, category, subcategory, color and tags. [query]
  /// must be lower-case.
  static bool matchesSearch(ClothingItem item, String query) {
    final fields = [
      ...item.tags,
      item.name,
      item.brand ?? '',
      item.category.label,
      item.category.singularLabel,
      item.subcategory?.label ?? '',
      item.color?.label ?? '',
    ];
    return fields.any((field) => field.toLowerCase().contains(query));
  }

  int _compare(
    ClothingItem a,
    ClothingItem b,
    int Function(ClothingItem item) outfitsOf,
  ) {
    switch (sort) {
      case WardrobeSort.custom:
        // Reordered pieces first, in the user's order; the rest newest first.
        final ia = a.sortIndex, ib = b.sortIndex;
        if (ia == null || ib == null) {
          return ia == null && ib == null ? 0 : (ia == null ? 1 : -1);
        }
        return ia.compareTo(ib);
      case WardrobeSort.dateAdded:
        return b.createdAt.compareTo(a.createdAt);
      case WardrobeSort.categories:
        return a.category.index.compareTo(b.category.index);
      case WardrobeSort.colors:
        // Pieces without a color go last.
        return (a.color?.index ?? ClothingColor.values.length).compareTo(
          b.color?.index ?? ClothingColor.values.length,
        );
      case WardrobeSort.mostOutfits:
        return outfitsOf(b).compareTo(outfitsOf(a));
    }
  }
}
