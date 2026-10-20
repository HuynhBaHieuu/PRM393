import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/season.dart';

enum WardrobeSort {
  newest('Newest first'),
  oldest('Oldest first'),
  name('Name A–Z'),
  mostWorn('Most worn'),
  leastWorn('Least worn'),
  priceHigh('Price: high to low'),
  priceLow('Price: low to high');

  const WardrobeSort(this.label);

  final String label;
}

const Object _unset = Object();

/// Search, filter and sort settings for the wardrobe grid. Pure and
/// immutable, so the same logic can back other views or a remote query.
class WardrobeQuery {
  const WardrobeQuery({
    this.searchText = '',
    this.category,
    this.colors = const {},
    this.seasons = const {},
    this.brands = const {},
    this.favoritesOnly = false,
    this.showArchived = false,
    this.sort = WardrobeSort.newest,
  });

  final String searchText;
  final ClothingCategory? category;
  final Set<ClothingColor> colors;
  final Set<Season> seasons;

  /// Lower-cased brand names.
  final Set<String> brands;
  final bool favoritesOnly;

  /// When true, shows archived items instead of the active wardrobe.
  final bool showArchived;
  final WardrobeSort sort;

  /// Number of refinements set in the filter sheet.
  int get sheetFilterCount =>
      colors.length +
      seasons.length +
      brands.length +
      (favoritesOnly ? 1 : 0) +
      (showArchived ? 1 : 0);

  bool get hasRefinements =>
      sheetFilterCount > 0 || category != null || searchText.trim().isNotEmpty;

  WardrobeQuery copyWith({
    String? searchText,
    Object? category = _unset,
    Set<ClothingColor>? colors,
    Set<Season>? seasons,
    Set<String>? brands,
    bool? favoritesOnly,
    bool? showArchived,
    WardrobeSort? sort,
  }) {
    return WardrobeQuery(
      searchText: searchText ?? this.searchText,
      category: identical(category, _unset)
          ? this.category
          : category as ClothingCategory?,
      colors: colors ?? this.colors,
      seasons: seasons ?? this.seasons,
      brands: brands ?? this.brands,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      showArchived: showArchived ?? this.showArchived,
      sort: sort ?? this.sort,
    );
  }

  /// Clears everything except the sort order.
  WardrobeQuery cleared() => WardrobeQuery(sort: sort);

  WardrobeQuery clearedSheetFilters() =>
      WardrobeQuery(searchText: searchText, category: category, sort: sort);

  List<ClothingItem> apply(Iterable<ClothingItem> items) {
    final query = searchText.trim().toLowerCase();
    final result = items.where((item) {
      if (item.isArchived != showArchived) return false;
      if (category != null && item.category != category) return false;
      if (favoritesOnly && !item.isFavorite) return false;
      if (colors.isNotEmpty && !colors.contains(item.color)) return false;
      if (seasons.isNotEmpty && !item.seasons.any(seasons.contains)) {
        return false;
      }
      if (brands.isNotEmpty &&
          !brands.contains(item.brand?.trim().toLowerCase())) {
        return false;
      }
      return query.isEmpty || matchesSearch(item, query);
    }).toList();
    result.sort(_comparator);
    return result;
  }

  /// Matches name, brand, category, subcategory and color. [query] must be lower-case.
  static bool matchesSearch(ClothingItem item, String query) {
    final fields = [
      item.name,
      item.brand ?? '',
      item.category.label,
      item.category.singularLabel,
      item.subcategory?.label ?? '',
      item.color?.label ?? '',
    ];
    return fields.any((field) => field.toLowerCase().contains(query));
  }

  int _comparator(ClothingItem a, ClothingItem b) {
    switch (sort) {
      case WardrobeSort.newest:
        return b.createdAt.compareTo(a.createdAt);
      case WardrobeSort.oldest:
        return a.createdAt.compareTo(b.createdAt);
      case WardrobeSort.name:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case WardrobeSort.mostWorn:
        return b.wearCount.compareTo(a.wearCount);
      case WardrobeSort.leastWorn:
        return a.wearCount.compareTo(b.wearCount);
      case WardrobeSort.priceHigh:
        return (b.price ?? -1).compareTo(a.price ?? -1);
      case WardrobeSort.priceLow:
        // Items without a price sort last.
        return (a.price ?? double.infinity).compareTo(
          b.price ?? double.infinity,
        );
    }
  }
}
