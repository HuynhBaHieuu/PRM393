import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/occasion.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/outfit_calendar_entry.dart';
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/features/insights/insights_data.dart';
import 'package:all_fits/features/outfits/controllers/outfit_query.dart';

import '../helpers/test_harness.dart';

ClothingItem _item(
  String id, {
  ClothingCategory category = ClothingCategory.tops,
  ClothingColor? color,
  String? brand,
  double? price,
  int wears = 0,
  int ageDays = 0,
  bool archived = false,
}) {
  final created = testNow.subtract(Duration(days: ageDays));
  return ClothingItem(
    id: id,
    name: id,
    category: category,
    color: color,
    brand: brand,
    price: price,
    wearCount: wears,
    isArchived: archived,
    createdAt: created,
    updatedAt: created,
  );
}

Outfit _outfit(
  String id, {
  List<String> items = const [],
  Occasion? occasion,
  List<Season> seasons = const [],
  int wears = 0,
  int ageDays = 0,
  String? photo,
}) {
  final created = testNow.subtract(Duration(days: ageDays));
  return Outfit(
    id: id,
    name: id,
    itemIds: items,
    occasion: occasion,
    seasons: seasons,
    wearCount: wears,
    photoPath: photo,
    createdAt: created,
    updatedAt: created,
  );
}

void main() {
  group('InsightsData', () {
    final items = [
      _item(
        'tee',
        color: ClothingColor.white,
        brand: 'Nike',
        price: 20,
        wears: 4,
      ),
      _item(
        'hoodie',
        color: ClothingColor.black,
        brand: 'Nike',
        price: 80,
        wears: 1,
      ),
      _item(
        'jeans',
        category: ClothingCategory.bottoms,
        color: ClothingColor.blue,
        price: 60,
        ageDays: 5,
      ),
      _item('old', archived: true, price: 999),
    ];
    final outfits = [
      _outfit('look', items: ['tee', 'jeans']),
    ];
    final data = InsightsData(
      items: items,
      outfits: outfits,
      entries: [
        OutfitCalendarEntry(
          id: 'e1',
          date: testNow.subtract(const Duration(days: 3)),
          outfitId: 'look',
          status: CalendarEntryStatus.worn,
        ),
        OutfitCalendarEntry(
          id: 'e2',
          date: testNow.subtract(const Duration(days: 60)),
          outfitId: 'look',
          status: CalendarEntryStatus.worn,
        ),
      ],
      today: testNow,
    );

    test('leaves archived pieces out of value and prices', () {
      expect(data.wardrobeValue, 160);
      expect(data.averagePrice, closeTo(53.3, 0.1));
      expect(data.highestPrice.first.$1.id, 'hoodie');
    });

    test('splits by category, color and brand', () {
      final byCategory = data.slices(InsightDimension.categories);
      expect(byCategory.first.label, 'Tops');
      expect(byCategory.first.count, 2);
      final colors = data.slices(InsightDimension.colors);
      expect(colors.map((s) => s.color), contains(ClothingColor.white));
      final brands = data.slices(InsightDimension.brands);
      expect(brands.first.label, 'Nike');
      expect(brands.last.label, 'No brand');
    });

    test('ranks cost per wear and usage', () {
      expect(data.costPerWear.first.$1.id, 'tee');
      expect(data.costPerWear.first.$2, 5);
      expect(data.usage(), closeTo(2 / 3, 0.001));
      expect(data.usage(category: ClothingCategory.bottoms), 0);
      expect(data.neverWorn.single.id, 'jeans');
    });

    test('counts pieces worn in the last 30 days only', () {
      final worn = {for (final (item, n) in data.wornLastMonth) item.id: n};
      expect(worn, {'tee': 1, 'jeans': 1});
    });

    test('folds more than eight groups into Other', () {
      final many = InsightsData(
        items: [for (var i = 0; i < 10; i++) _item('p$i', brand: 'Brand $i')],
        outfits: const [],
        entries: const [],
        today: testNow,
      );
      final slices = many.slices(InsightDimension.brands);
      expect(slices, hasLength(InsightsData.maxSlices));
      expect(slices.last.label, InsightsData.other);
      expect(slices.last.count, 3);
    });
  });

  group('OutfitQuery', () {
    final outfits = [
      _outfit('work', occasion: Occasion.work, wears: 3, ageDays: 2),
      _outfit('date', occasion: Occasion.date, seasons: [Season.summer]),
      _outfit('selfie', photo: 'images/1.jpg', wears: 1, ageDays: 1),
    ];
    List<String> ids(OutfitQuery q) =>
        q.apply(outfits).map((o) => o.id).toList();

    test('filters by occasion, season, image type and name', () {
      expect(ids(const OutfitQuery(occasion: Occasion.work)), ['work']);
      expect(ids(const OutfitQuery(seasons: {Season.summer})), ['date']);
      expect(ids(const OutfitQuery(imageType: OutfitImageType.photos)), [
        'selfie',
      ]);
      expect(ids(const OutfitQuery(imageType: OutfitImageType.collages)), [
        'date',
        'work',
      ]);
      expect(ids(const OutfitQuery(searchText: 'SEL')), ['selfie']);
    });

    test('sorts by wear and keeps the custom order', () {
      expect(ids(const OutfitQuery(sort: OutfitSort.mostWorn)).first, 'work');
      expect(ids(const OutfitQuery(sort: OutfitSort.leastWorn)).first, 'date');
      final ordered = [
        outfits[0].copyWith(sortIndex: 1),
        outfits[2].copyWith(sortIndex: 0),
        outfits[1],
      ];
      expect(
        const OutfitQuery(sort: OutfitSort.custom)
            .apply(ordered)
            .map((o) => o.id),
        ['selfie', 'work', 'date'],
      );
    });

    test('groups by occasion', () {
      const query = OutfitQuery(groupBy: OutfitGroup.categories);
      expect(query.group(query.apply(outfits)).map((g) => g.$1), [
        'Work',
        'Date',
        'No occasion',
      ]);
    });
  });
}
