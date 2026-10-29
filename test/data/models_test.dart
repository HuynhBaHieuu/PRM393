import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/data/models/app_settings.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/clothing_photo.dart';
import 'package:all_fits/data/models/clothing_subcategory.dart';
import 'package:all_fits/data/models/occasion.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/outfit_calendar_entry.dart';
import 'package:all_fits/data/models/season.dart';

void main() {
  final created = DateTime(2026, 9, 1, 10, 30);

  group('ClothingItem serialization', () {
    final item = ClothingItem(
      id: 'item-1',
      name: 'Denim Jacket',
      imagePath: 'wardrobe_images/abc.jpg',
      extraPhotos: const [
        ClothingPhoto(path: 'wardrobe_images/back.jpg', kind: PhotoKind.back),
        ClothingPhoto(path: 'wardrobe_images/tag.jpg', kind: PhotoKind.tag),
      ],
      category: ClothingCategory.outerwear,
      subcategory: ClothingSubcategory.jackets,
      color: ClothingColor.blue,
      seasons: const [Season.spring, Season.autumn],
      brand: 'North Thread',
      price: 98.5,
      notes: 'Roll the sleeves.',
      sourceUrl: 'https://yame.vn/products/denim-jacket',
      isFavorite: true,
      isArchived: false,
      wearCount: 3,
      lastWornAt: DateTime(2026, 9, 20),
      createdAt: created,
      updatedAt: created.add(const Duration(days: 1)),
    );

    test('round-trips through JSON', () {
      final decoded = ClothingItem.fromJson(
        jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.id, item.id);
      expect(decoded.name, item.name);
      expect(decoded.imagePath, item.imagePath);
      expect(decoded.extraPhotos, item.extraPhotos);
      expect(decoded.category, item.category);
      expect(decoded.subcategory, ClothingSubcategory.jackets);
      expect(decoded.color, item.color);
      expect(decoded.seasons, item.seasons);
      expect(decoded.brand, item.brand);
      expect(decoded.price, item.price);
      expect(decoded.notes, item.notes);
      expect(decoded.sourceUrl, item.sourceUrl);
      expect(decoded.isFavorite, isTrue);
      expect(decoded.isArchived, isFalse);
      expect(decoded.wearCount, 3);
      expect(decoded.lastWornAt, item.lastWornAt);
      expect(decoded.createdAt, item.createdAt);
      expect(decoded.updatedAt, item.updatedAt);
    });

    test('drops malformed and repeated extra photos', () {
      final decoded = ClothingItem.fromJson({
        'id': 'x',
        'name': 'Tee',
        'extraPhotos': [
          {'path': 'a.jpg', 'kind': 'detail'},
          {'path': 'a.jpg', 'kind': 'back'},
          {'path': '  '},
          {'path': 'b.jpg', 'kind': 'sideways'},
          'c.jpg',
        ],
      });
      expect(decoded.extraPhotos, const [
        ClothingPhoto(path: 'a.jpg', kind: PhotoKind.detail),
        ClothingPhoto(path: 'b.jpg'),
      ]);
      expect(
        ClothingItem.fromJson({'id': 'y', 'name': 'Old'}).extraPhotos,
        isEmpty,
      );
    });

    test('tolerates malformed optional fields', () {
      final decoded = ClothingItem.fromJson({
        'id': 'x',
        'name': '  Tee  ',
        'category': 'not-a-category',
        'color': 42,
        'seasons': ['summer', 'monsoon', 7, 'summer'],
        'price': -5,
        'wearCount': 'many',
        'isFavorite': 'yes',
        'createdAt': 'yesterday',
      });
      expect(decoded.name, 'Tee');
      expect(decoded.category, ClothingCategory.other);
      expect(decoded.color, isNull);
      expect(decoded.seasons, [Season.summer]);
      expect(decoded.price, isNull);
      expect(decoded.wearCount, 0);
      expect(decoded.isFavorite, isFalse);
    });

    test('drops a subcategory of another category', () {
      final decoded = ClothingItem.fromJson({
        'id': 'x',
        'name': 'Tee',
        'category': 'tops',
        'subcategory': 'jeans',
      });
      expect(decoded.subcategory, isNull);
    });

    test('rejects records without an id or name', () {
      expect(
        () => ClothingItem.fromJson({'name': 'No id'}),
        throwsFormatException,
      );
      expect(
        () => ClothingItem.fromJson({'id': 'x', 'name': '   '}),
        throwsFormatException,
      );
    });

    test('copyWith can clear nullable fields', () {
      final cleared = item.copyWith(brand: null, price: null);
      expect(cleared.brand, isNull);
      expect(cleared.price, isNull);
      expect(cleared.color, ClothingColor.blue);
    });
  });

  group('Outfit serialization', () {
    final outfit = Outfit(
      id: 'outfit-1',
      name: 'Weekend',
      itemIds: const ['a', 'b', 'c'],
      occasion: Occasion.casual,
      seasons: const [Season.summer],
      notes: 'Sunny days',
      isFavorite: true,
      wearCount: 2,
      lastWornAt: DateTime(2026, 9, 28),
      createdAt: created,
      updatedAt: created,
    );

    test('round-trips through JSON', () {
      final decoded = Outfit.fromJson(
        jsonDecode(jsonEncode(outfit.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.id, outfit.id);
      expect(decoded.name, outfit.name);
      expect(decoded.itemIds, outfit.itemIds);
      expect(decoded.occasion, Occasion.casual);
      expect(decoded.seasons, [Season.summer]);
      expect(decoded.notes, outfit.notes);
      expect(decoded.isFavorite, isTrue);
      expect(decoded.wearCount, 2);
      expect(decoded.lastWornAt, outfit.lastWornAt);
    });

    test('drops duplicate and invalid item ids, keeping order', () {
      final decoded = Outfit.fromJson({
        'id': 'o',
        'itemIds': ['b', 'a', 'b', 3, '', 'c'],
      });
      expect(decoded.itemIds, ['b', 'a', 'c']);
      expect(decoded.name, isNotEmpty);
    });
  });

  group('OutfitCalendarEntry serialization', () {
    test('stores dates without time or time zone', () {
      final entry = OutfitCalendarEntry(
        id: 'e',
        date: DateTime(2026, 10, 3, 22, 45),
        outfitId: 'o',
        status: CalendarEntryStatus.planned,
      );
      final json = entry.toJson();
      expect(json['date'], '2026-10-03');
      final decoded = OutfitCalendarEntry.fromJson(json);
      expect(decoded.date, DateTime(2026, 10, 3));
      expect(decoded.status, CalendarEntryStatus.planned);
    });

    test('rejects incomplete entries', () {
      expect(
        () => OutfitCalendarEntry.fromJson({'id': 'e', 'date': 'bad'}),
        throwsFormatException,
      );
    });
  });

  test('AppSettings falls back to defaults for bad values', () {
    final settings = AppSettings.fromJson({'theme': 'neon', 'username': 3});
    expect(settings.themePreference, ThemePreference.system);
    expect(settings.username, isEmpty);
    expect(settings.currencySymbol, isNotEmpty);
  });
}
