import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/outfit_calendar_entry.dart';
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/data/models/wardrobe_stats.dart';

void main() {
  final now = DateTime(2026, 10, 1);

  ClothingItem item(
    String id, {
    ClothingCategory category = ClothingCategory.tops,
    ClothingColor? color,
    List<Season> seasons = const [],
    double? price,
    int wears = 0,
    bool archived = false,
    int ageDays = 0,
  }) {
    final created = now.subtract(Duration(days: ageDays));
    return ClothingItem(
      id: id,
      name: id,
      category: category,
      color: color,
      seasons: seasons,
      price: price,
      wearCount: wears,
      isArchived: archived,
      createdAt: created,
      updatedAt: created,
    );
  }

  test('computes totals, wear highlights and breakdowns', () {
    final items = [
      item(
        'tee',
        color: ClothingColor.white,
        seasons: [Season.summer, Season.spring],
        price: 20,
        wears: 6,
      ),
      item(
        'jeans',
        category: ClothingCategory.bottoms,
        color: ClothingColor.blue,
        price: 80,
        wears: 2,
        ageDays: 10,
      ),
      item('shirt', color: ClothingColor.white, price: 40.5, ageDays: 5),
      item('old', price: 500, wears: 9, archived: true),
    ];
    final outfits = [
      Outfit(
        id: 'o',
        name: 'o',
        itemIds: const ['tee', 'jeans'],
        createdAt: now,
        updatedAt: now,
      ),
    ];
    final entries = [
      OutfitCalendarEntry(
        id: 'w1',
        date: now,
        outfitId: 'o',
        status: CalendarEntryStatus.worn,
      ),
      OutfitCalendarEntry(
        id: 'p1',
        date: now,
        outfitId: 'o',
        status: CalendarEntryStatus.planned,
      ),
    ];

    final stats = WardrobeStats.compute(
      items: items,
      outfits: outfits,
      entries: entries,
    );

    expect(stats.totalItems, 3);
    expect(stats.archivedItems, 1);
    expect(stats.totalOutfits, 1);
    expect(stats.totalValue, closeTo(140.5, 0.001));
    expect(stats.timesWorn, 1);
    expect(stats.mostWorn?.id, 'tee');
    expect(stats.leastWorn?.id, 'shirt');

    expect(stats.byCategory.first.key, ClothingCategory.tops);
    expect(stats.byCategory.first.count, 2);
    expect(stats.byColor.first.key, ClothingColor.white);
    expect(stats.byColor.first.count, 2);
    // Items without seasons are counted as unspecified, listed last.
    expect(stats.bySeason.last.key, isNull);
    expect(stats.bySeason.last.count, 2);
  });

  test('handles an empty wardrobe', () {
    final stats = WardrobeStats.compute(
      items: const [],
      outfits: const [],
      entries: const [],
    );
    expect(stats.isEmpty, isTrue);
    expect(stats.mostWorn, isNull);
    expect(stats.leastWorn, isNull);
    expect(stats.totalValue, 0);
  });

  test('least worn ties go to the oldest item', () {
    final stats = WardrobeStats.compute(
      items: [item('new', ageDays: 1), item('older', ageDays: 30)],
      outfits: const [],
      entries: const [],
    );
    expect(stats.mostWorn, isNull);
    expect(stats.leastWorn?.id, 'older');
  });
}
