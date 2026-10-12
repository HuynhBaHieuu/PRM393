import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/outfit_calendar_entry.dart';
import 'package:all_fits/data/models/season.dart';

/// A label/count pair in a breakdown. A null [key] means "unspecified".
class StatBucket<T> {
  const StatBucket(this.key, this.count);

  final T? key;
  final int count;
}

/// Wardrobe statistics derived purely from local data.
/// Archived items are excluded from every item-based figure.
class WardrobeStats {
  const WardrobeStats({
    required this.totalItems,
    required this.archivedItems,
    required this.totalOutfits,
    required this.totalValue,
    required this.timesWorn,
    required this.mostWorn,
    required this.leastWorn,
    required this.byCategory,
    required this.byColor,
    required this.bySeason,
  });

  factory WardrobeStats.compute({
    required List<ClothingItem> items,
    required List<Outfit> outfits,
    required List<OutfitCalendarEntry> entries,
  }) {
    final active = items.where((item) => !item.isArchived).toList();

    final totalValue = active.fold<double>(
      0,
      (sum, item) => sum + (item.price ?? 0),
    );

    ClothingItem? mostWorn;
    ClothingItem? leastWorn;
    for (final item in active) {
      if (item.wearCount > 0 &&
          (mostWorn == null || item.wearCount > mostWorn.wearCount)) {
        mostWorn = item;
      }
      // Ties go to the oldest item: it has had the most chances to be worn.
      if (leastWorn == null ||
          item.wearCount < leastWorn.wearCount ||
          (item.wearCount == leastWorn.wearCount &&
              item.createdAt.isBefore(leastWorn.createdAt))) {
        leastWorn = item;
      }
    }
    if (leastWorn != null && leastWorn.id == mostWorn?.id) leastWorn = null;

    final categoryCounts = <ClothingCategory, int>{};
    final colorCounts = <ClothingColor?, int>{};
    final seasonCounts = <Season?, int>{};
    for (final item in active) {
      categoryCounts.update(item.category, (c) => c + 1, ifAbsent: () => 1);
      colorCounts.update(item.color, (c) => c + 1, ifAbsent: () => 1);
      if (item.seasons.isEmpty) {
        seasonCounts.update(null, (c) => c + 1, ifAbsent: () => 1);
      }
      for (final season in item.seasons) {
        seasonCounts.update(season, (c) => c + 1, ifAbsent: () => 1);
      }
    }

    return WardrobeStats(
      totalItems: active.length,
      archivedItems: items.length - active.length,
      totalOutfits: outfits.length,
      totalValue: totalValue,
      timesWorn: entries.where((e) => e.isWorn).length,
      mostWorn: mostWorn,
      leastWorn: leastWorn,
      byCategory: _sorted(categoryCounts),
      byColor: _sorted(colorCounts),
      bySeason: _sorted(seasonCounts),
    );
  }

  static const WardrobeStats empty = WardrobeStats(
    totalItems: 0,
    archivedItems: 0,
    totalOutfits: 0,
    totalValue: 0,
    timesWorn: 0,
    mostWorn: null,
    leastWorn: null,
    byCategory: [],
    byColor: [],
    bySeason: [],
  );

  final int totalItems;
  final int archivedItems;
  final int totalOutfits;
  final double totalValue;

  /// Number of worn calendar entries.
  final int timesWorn;
  final ClothingItem? mostWorn;
  final ClothingItem? leastWorn;
  final List<StatBucket<ClothingCategory>> byCategory;
  final List<StatBucket<ClothingColor>> byColor;
  final List<StatBucket<Season>> bySeason;

  bool get isEmpty => totalItems == 0 && totalOutfits == 0;

  /// Sorts by count descending; unspecified buckets always go last.
  static List<StatBucket<T>> _sorted<T>(Map<T?, int> counts) {
    final buckets = counts.entries
        .map((e) => StatBucket<T>(e.key, e.value))
        .toList();
    buckets.sort((a, b) {
      if (a.key == null) return 1;
      if (b.key == null) return -1;
      return b.count.compareTo(a.count);
    });
    return buckets;
  }
}
