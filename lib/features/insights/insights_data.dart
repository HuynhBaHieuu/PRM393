import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/outfit_calendar_entry.dart';

/// What the donut chart splits the wardrobe by, as in Fits.
enum InsightDimension {
  categories('Categories'),
  colors('Colors'),
  brands('Brands'),
  season('Season');

  const InsightDimension(this.label);

  final String label;
}

/// One slice: its label, how many pieces, and the clothing color it stands
/// for (colors only).
class InsightSlice {
  const InsightSlice(this.label, this.count, {this.color});

  final String label;
  final int count;
  final ClothingColor? color;
}

/// A piece with the figure shown under it, e.g. "$12 / wear".
typedef RankedItem = (ClothingItem item, double value);

/// Fits' Insights figures, computed from local data. Archived pieces are
/// left out.
class InsightsData {
  InsightsData({
    required List<ClothingItem> items,
    required this.outfits,
    required this.entries,
    required this.today,
  }) : active = items.where((i) => !i.isArchived).toList();

  final List<ClothingItem> active;
  final List<Outfit> outfits;
  final List<OutfitCalendarEntry> entries;
  final DateTime today;

  /// More slices than this fold into "Other".
  static const int maxSlices = 8;
  static const String other = 'Other';

  /// Slices for [dimension], biggest first. Categories split into types
  /// (Sneakers, Jeans…), limited to [category] when given.
  List<InsightSlice> slices(
    InsightDimension dimension, {
    ClothingCategory? category,
  }) {
    final pool = category == null
        ? active
        : active.where((i) => i.category == category).toList();
    final counts = <String, int>{};
    final colors = <String, ClothingColor>{};
    void add(String key, {ClothingColor? color}) {
      counts.update(key, (c) => c + 1, ifAbsent: () => 1);
      if (color != null) colors[key] = color;
    }

    for (final item in pool) {
      switch (dimension) {
        case InsightDimension.categories:
          add(item.subcategory?.label ?? item.category.label);
        case InsightDimension.colors:
          final color = item.color;
          if (color == null) {
            add('No color');
          } else {
            add(color.label, color: color);
          }
        case InsightDimension.brands:
          add(item.brand?.trim() ?? 'No brand');
        case InsightDimension.season:
          if (item.seasons.isEmpty) add('No season');
          for (final season in item.seasons) {
            add(season.label);
          }
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final slices = [
      for (final e in sorted)
        InsightSlice(e.key, e.value, color: colors[e.key]),
    ];
    if (slices.length <= maxSlices) return slices;
    final kept = slices.take(maxSlices - 1).toList();
    final rest = slices.skip(maxSlices - 1).fold(0, (sum, s) => sum + s.count);
    return [...kept, InsightSlice(other, rest)];
  }

  /// The groups the donut's middle counts, e.g. "in 8 categories".
  static String groupNoun(InsightDimension dimension) => switch (dimension) {
    InsightDimension.categories => 'categories',
    InsightDimension.colors => 'colors',
    InsightDimension.brands => 'brands',
    InsightDimension.season => 'seasons',
  };

  double get wardrobeValue =>
      active.fold<double>(0, (sum, item) => sum + (item.price ?? 0));

  /// Average over the pieces that have a price.
  double get averagePrice {
    final priced = active.where((i) => i.price != null).toList();
    if (priced.isEmpty) return 0;
    return priced.fold<double>(0, (sum, i) => sum + i.price!) / priced.length;
  }

  /// Most expensive pieces first.
  List<RankedItem> get highestPrice {
    final priced = [
      for (final item in active)
        if (item.price != null && item.price! > 0) (item, item.price!),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return priced;
  }

  /// Price divided by times worn, cheapest per wear first. Unworn pieces
  /// count as one wear, so they don't look free.
  List<RankedItem> get costPerWear {
    final ranked = [
      for (final item in active)
        if (item.price != null && item.price! > 0)
          (item, item.price! / (item.wearCount < 1 ? 1 : item.wearCount)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return ranked;
  }

  /// Share of pieces worn at least once, 0–1.
  double usage({ClothingCategory? category}) {
    final pool = category == null
        ? active
        : active.where((i) => i.category == category).toList();
    if (pool.isEmpty) return 0;
    return pool.where((i) => i.wearCount > 0).length / pool.length;
  }

  /// Pieces in outfits worn during the last 30 days, with how often.
  List<RankedItem> get wornLastMonth {
    final from = DateHelpers.addDays(today, -30);
    final byId = {for (final o in outfits) o.id: o};
    final counts = <String, int>{};
    for (final entry in entries) {
      if (!entry.isWorn ||
          entry.date.isBefore(from) ||
          entry.date.isAfter(today)) {
        continue;
      }
      for (final id in byId[entry.outfitId]?.itemIds ?? const <String>[]) {
        counts.update(id, (c) => c + 1, ifAbsent: () => 1);
      }
    }
    final ranked = [
      for (final item in active)
        if (counts[item.id] != null) (item, counts[item.id]!.toDouble()),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return ranked;
  }

  /// Most worn pieces of all time.
  List<RankedItem> get wornOverall {
    final ranked = [
      for (final item in active)
        if (item.wearCount > 0) (item, item.wearCount.toDouble()),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return ranked;
  }

  /// Pieces never worn, oldest first: they have waited longest.
  List<ClothingItem> get neverWorn =>
      active.where((i) => i.wearCount == 0).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<ClothingItem> get recentlyAdded =>
      [...active]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}
