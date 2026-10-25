import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/features/outfits/outfit_ideas.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_query.dart';

import '../helpers/test_harness.dart';

ClothingItem _item(
  String id,
  ClothingCategory category, {
  List<Season> seasons = const [],
  ClothingColor color = ClothingColor.black,
}) => ClothingItem(
  id: id,
  name: id,
  category: category,
  color: color,
  seasons: seasons,
  createdAt: testNow,
  updatedAt: testNow,
);

WeatherReport _weather(double temperature, {bool rain = false}) =>
    WeatherReport(
      location: testCity,
      temperature: temperature,
      high: temperature,
      low: temperature - 5,
      condition: rain ? WeatherCondition.rain : WeatherCondition.clear,
      rainChance: rain ? 90 : 0,
      fetchedAt: testNow,
    );

void main() {
  final wardrobe = [
    _item('tee', ClothingCategory.tops, seasons: [Season.summer]),
    _item('knit', ClothingCategory.tops, seasons: [Season.winter]),
    _item('shirt', ClothingCategory.tops, color: ClothingColor.white),
    _item('hoodie', ClothingCategory.tops, color: ClothingColor.grey),
    _item('jeans', ClothingCategory.bottoms, color: ClothingColor.blue),
    _item('cargo', ClothingCategory.bottoms, color: ClothingColor.green),
    _item('shorts', ClothingCategory.bottoms, seasons: [Season.summer]),
    _item('sneakers', ClothingCategory.shoes, color: ClothingColor.white),
    _item('coat', ClothingCategory.outerwear, seasons: [Season.winter]),
    _item('dress', ClothingCategory.dresses, seasons: [Season.summer]),
  ];
  final day = DateTime(2026, 10, 25);

  test('ideas are complete, distinct and the same all day', () {
    final ideas = OutfitIdeas.generate(wardrobe, day: day);
    expect(ideas, hasLength(3));
    for (final idea in ideas) {
      final categories = idea.items.map((i) => i.category).toSet();
      expect(
        categories.contains(ClothingCategory.dresses) ||
            categories.containsAll([
              ClothingCategory.tops,
              ClothingCategory.bottoms,
            ]),
        isTrue,
      );
      expect(idea.title, isNotEmpty);
    }
    expect({for (final idea in ideas) idea.itemIds.join()}, hasLength(3));
    expect(
      OutfitIdeas.generate(wardrobe, day: day).map((i) => i.itemIds),
      ideas.map((i) => i.itemIds),
    );
  });

  test('cold rain adds outerwear; heat skips winter pieces', () {
    final cold = OutfitIdeas.generate(
      wardrobe,
      day: day,
      weather: _weather(4, rain: true),
    );
    expect(cold.every((i) => i.itemIds.contains('coat')), isTrue);
    expect(cold.first.title, contains('layers'));

    final hot = OutfitIdeas.generate(wardrobe, day: day, weather: _weather(32));
    for (final idea in hot) {
      expect(idea.itemIds, isNot(contains('coat')));
      expect(idea.itemIds, isNot(contains('knit')));
    }
  });

  test('an anchor piece is in every idea', () {
    final jeans = wardrobe.firstWhere((i) => i.id == 'jeans');
    final ideas = OutfitIdeas.generate(
      wardrobe,
      day: day,
      anchor: jeans,
      count: 2,
    );
    expect(ideas, isNotEmpty);
    expect(ideas.every((i) => i.itemIds.contains('jeans')), isTrue);
  });

  test('too few pieces make no ideas', () {
    expect(
      OutfitIdeas.generate(
        wardrobe.where((i) => i.category == ClothingCategory.shoes).toList(),
        day: day,
      ),
      isEmpty,
    );
  });

  test('the filter sheet counts name search and usage', () {
    const query = WardrobeQuery(searchText: 'tee', usage: ItemUsage.used);
    expect(query.sheetFilterCount, 2);
    expect(query.clearedSheetFilters().sheetFilterCount, 0);
  });
}
