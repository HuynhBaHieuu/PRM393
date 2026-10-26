import 'package:all_fits/data/models/occasion.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/season.dart';

/// Fits' outfit "Sort items by" options.
enum OutfitSort {
  custom('Custom'),
  dateAdded('Date added'),
  mostWorn('Most worn'),
  leastWorn('Least worn');

  const OutfitSort(this.label);

  final String label;
}

/// Fits' outfit "Group items by" options; occasions are its categories.
enum OutfitGroup {
  none('None'),
  categories('Categories'),
  season('Season');

  const OutfitGroup(this.label);

  final String label;
}

/// Fits' "Image type": collages, outfit photos (selfies), or both.
enum OutfitImageType {
  all('All'),
  collages('Collages'),
  photos('Photos');

  const OutfitImageType(this.label);

  final String label;
}

const Object _unset = Object();

/// Filter, sort and grouping for the Outfits tab. Pure and immutable.
class OutfitQuery {
  const OutfitQuery({
    this.occasion,
    this.occasions = const {},
    this.seasons = const {},
    this.searchText = '',
    this.imageType = OutfitImageType.all,
    this.favoritesOnly = false,
    this.sort = OutfitSort.dateAdded,
    this.groupBy = OutfitGroup.none,
  });

  /// The occasion chip above the grid.
  final Occasion? occasion;

  /// Occasions picked in the filter sheet ("Categories").
  final Set<Occasion> occasions;
  final Set<Season> seasons;
  final String searchText;
  final OutfitImageType imageType;
  final bool favoritesOnly;
  final OutfitSort sort;
  final OutfitGroup groupBy;

  int get sheetFilterCount =>
      occasions.length +
      seasons.length +
      (searchText.trim().isEmpty ? 0 : 1) +
      (imageType == OutfitImageType.all ? 0 : 1) +
      (favoritesOnly ? 1 : 0);

  OutfitQuery copyWith({
    Object? occasion = _unset,
    Set<Occasion>? occasions,
    Set<Season>? seasons,
    String? searchText,
    OutfitImageType? imageType,
    bool? favoritesOnly,
    OutfitSort? sort,
    OutfitGroup? groupBy,
  }) {
    return OutfitQuery(
      occasion: identical(occasion, _unset)
          ? this.occasion
          : occasion as Occasion?,
      occasions: occasions ?? this.occasions,
      seasons: seasons ?? this.seasons,
      searchText: searchText ?? this.searchText,
      imageType: imageType ?? this.imageType,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      sort: sort ?? this.sort,
      groupBy: groupBy ?? this.groupBy,
    );
  }

  /// "Clear filters" keeps the occasion chip.
  OutfitQuery clearedSheetFilters() => OutfitQuery(occasion: occasion);

  List<Outfit> apply(Iterable<Outfit> outfits) {
    final query = searchText.trim().toLowerCase();
    final result = outfits.where((o) {
      if (occasion != null && o.occasion != occasion) return false;
      if (occasions.isNotEmpty && !occasions.contains(o.occasion)) {
        return false;
      }
      if (seasons.isNotEmpty && !o.seasons.any(seasons.contains)) return false;
      if (favoritesOnly && !o.isFavorite) return false;
      switch (imageType) {
        case OutfitImageType.all:
          break;
        case OutfitImageType.collages:
          if (o.photoPath != null) return false;
        case OutfitImageType.photos:
          if (o.photoPath == null) return false;
      }
      return query.isEmpty || o.name.toLowerCase().contains(query);
    }).toList();
    result.sort((a, b) {
      final order = _compare(a, b);
      return order != 0 ? order : b.createdAt.compareTo(a.createdAt);
    });
    return result;
  }

  int _compare(Outfit a, Outfit b) {
    switch (sort) {
      case OutfitSort.custom:
        final ia = a.sortIndex, ib = b.sortIndex;
        if (ia == null || ib == null) {
          return ia == null && ib == null ? 0 : (ia == null ? 1 : -1);
        }
        return ia.compareTo(ib);
      case OutfitSort.dateAdded:
        return b.createdAt.compareTo(a.createdAt);
      case OutfitSort.mostWorn:
        return b.wearCount.compareTo(a.wearCount);
      case OutfitSort.leastWorn:
        return a.wearCount.compareTo(b.wearCount);
    }
  }

  /// Labeled groups of sorted [outfits]; one unlabeled group when not
  /// grouping.
  List<(String, List<Outfit>)> group(List<Outfit> outfits) {
    switch (groupBy) {
      case OutfitGroup.none:
        return [('', outfits)];
      case OutfitGroup.categories:
        return [
          for (final o in Occasion.values)
            if (outfits.any((x) => x.occasion == o))
              (o.label, outfits.where((x) => x.occasion == o).toList()),
          if (outfits.any((x) => x.occasion == null))
            ('No occasion', outfits.where((x) => x.occasion == null).toList()),
        ];
      case OutfitGroup.season:
        return [
          for (final s in Season.values)
            if (outfits.any((x) => x.seasons.contains(s)))
              (
                '${s.emoji} ${s.label}',
                outfits.where((x) => x.seasons.contains(s)).toList(),
              ),
          if (outfits.any((x) => x.seasons.isEmpty))
            ('No season', outfits.where((x) => x.seasons.isEmpty).toList()),
        ];
    }
  }
}
