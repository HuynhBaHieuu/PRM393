import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/features/wardrobe/controllers/clothing_draft.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_query.dart';

import '../helpers/test_harness.dart';

void main() {
  late TestCloset closet;

  setUp(() async {
    closet = TestCloset();
    await closet.load();
  });

  group('adding clothing', () {
    test('stores the photo reference and trims text fields', () async {
      final item = await closet.wardrobe.addItem(
        const ClothingDraft(
          name: '  White Tee ',
          category: ClothingCategory.tops,
          color: ClothingColor.white,
          seasons: [Season.summer],
          brand: '   ',
          price: 18,
          notes: ' soft cotton ',
          newImagePath: '/tmp/tee.jpg',
        ),
      );
      expect(item.name, 'White Tee');
      expect(item.brand, isNull);
      expect(item.notes, 'soft cotton');
      expect(item.imagePath, closet.images.saved.single);
      expect(item.createdAt, testNow);
      expect(closet.wardrobe.activeItems.single.id, item.id);
    });

    test('requires a photo, a name and a category', () async {
      Future<ClothingItem> add(ClothingDraft draft) =>
          closet.wardrobe.addItem(draft);

      await expectLater(
        add(const ClothingDraft(name: 'Tee', category: ClothingCategory.tops)),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        add(
          const ClothingDraft(
            name: ' ',
            category: ClothingCategory.tops,
            newImagePath: '/tmp/a.jpg',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        add(
          const ClothingDraft(name: 'Tee', category: null, newImagePath: 'x'),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(closet.wardrobe.allItems, isEmpty);
    });

    test('an invalid image leaves the wardrobe unchanged', () async {
      closet.images.failNextSave = true;
      await expectLater(
        closet.addItem('Tee', ClothingCategory.tops),
        throwsA(isA<InvalidImageException>()),
      );
      expect(closet.wardrobe.allItems, isEmpty);
    });

    test('a failed save removes the copied photo', () async {
      closet.storage.failWrites = true;
      await expectLater(
        closet.addItem('Tee', ClothingCategory.tops),
        throwsA(isA<StorageException>()),
      );
      expect(closet.images.deleted, closet.images.saved);
    });
  });

  test('editing with a new photo replaces and deletes the old one', () async {
    final id = await closet.addItem('Tee', ClothingCategory.tops);
    final oldImage = closet.wardrobe.itemById(id)!.imagePath;
    await closet.wardrobe.updateItem(
      id,
      const ClothingDraft(
        name: 'Tee v2',
        category: ClothingCategory.tops,
        newImagePath: '/tmp/new.jpg',
      ),
    );
    final updated = closet.wardrobe.itemById(id)!;
    expect(updated.name, 'Tee v2');
    expect(updated.imagePath, isNot(oldImage));
    expect(closet.images.deleted, [oldImage]);
  });

  group('deleting clothing', () {
    test('removes the item and its photo', () async {
      final id = await closet.addItem('Tee', ClothingCategory.tops);
      final image = closet.wardrobe.itemById(id)!.imagePath;
      await closet.closet.deleteItemPermanently(id);
      expect(closet.wardrobe.itemById(id), isNull);
      expect(closet.images.deleted, [image]);
    });

    test('removes the item from outfits that used it', () async {
      final tee = await closet.addItem('Tee', ClothingCategory.tops);
      final jeans = await closet.addItem('Jeans', ClothingCategory.bottoms);
      final outfitId = await closet.addOutfit('Casual', [tee, jeans]);

      await closet.closet.deleteItemPermanently(tee);
      expect(closet.outfits.outfitById(outfitId)!.itemIds, [jeans]);
    });
  });

  test('favorites toggle on and off', () async {
    final id = await closet.addItem('Tee', ClothingCategory.tops);
    await closet.wardrobe.toggleFavorite(id);
    expect(closet.wardrobe.favoriteItems.map((i) => i.id), [id]);
    await closet.wardrobe.toggleFavorite(id);
    expect(closet.wardrobe.favoriteItems, isEmpty);
  });

  test(
    'archive hides an item from the wardrobe and restore brings it back',
    () async {
      final id = await closet.addItem('Tee', ClothingCategory.tops);
      await closet.wardrobe.setArchived(id, archived: true);
      expect(closet.wardrobe.activeItems, isEmpty);
      expect(closet.wardrobe.archivedItems.single.id, id);
      // Archived items stay in storage.
      expect(closet.wardrobe.itemById(id), isNotNull);

      await closet.wardrobe.setArchived(id, archived: false);
      expect(closet.wardrobe.activeItems.single.id, id);
      expect(closet.wardrobe.archivedItems, isEmpty);
    },
  );

  group('WardrobeQuery', () {
    ClothingItem item(
      String name, {
      ClothingCategory category = ClothingCategory.tops,
      ClothingColor? color,
      String? brand,
      List<Season> seasons = const [],
      bool favorite = false,
      bool archived = false,
      int wears = 0,
      double? price,
      int ageDays = 0,
    }) {
      final created = testNow.subtract(Duration(days: ageDays));
      return ClothingItem(
        id: name,
        name: name,
        category: category,
        color: color,
        brand: brand,
        seasons: seasons,
        isFavorite: favorite,
        isArchived: archived,
        wearCount: wears,
        price: price,
        createdAt: created,
        updatedAt: created,
      );
    }

    final items = [
      item(
        'White Tee',
        color: ClothingColor.white,
        brand: 'Everyday',
        seasons: [Season.summer],
        wears: 5,
        price: 20,
        ageDays: 3,
      ),
      item(
        'Blue Jeans',
        category: ClothingCategory.bottoms,
        color: ClothingColor.blue,
        brand: 'North',
        favorite: true,
        wears: 1,
        price: 70,
        ageDays: 1,
      ),
      item('Old Coat', category: ClothingCategory.outerwear, archived: true),
      item('Sneakers', category: ClothingCategory.shoes, ageDays: 2),
    ];

    List<String> names(WardrobeQuery q) =>
        q.apply(items).map((i) => i.name).toList();

    test('hides archived items unless requested', () {
      expect(names(const WardrobeQuery()), isNot(contains('Old Coat')));
      expect(names(const WardrobeQuery(showArchived: true)), ['Old Coat']);
    });

    test('searches name, brand, category and color', () {
      expect(names(const WardrobeQuery(searchText: 'jeans')), ['Blue Jeans']);
      expect(names(const WardrobeQuery(searchText: 'everyday')), ['White Tee']);
      expect(names(const WardrobeQuery(searchText: 'shoe')), ['Sneakers']);
      expect(names(const WardrobeQuery(searchText: 'BLUE')), ['Blue Jeans']);
    });

    test('filters by category, color, season, brand and favorites', () {
      expect(names(const WardrobeQuery(category: ClothingCategory.bottoms)), [
        'Blue Jeans',
      ]);
      expect(names(const WardrobeQuery(colors: {ClothingColor.white})), [
        'White Tee',
      ]);
      expect(names(const WardrobeQuery(seasons: {Season.summer})), [
        'White Tee',
      ]);
      expect(names(const WardrobeQuery(brands: {'north'})), ['Blue Jeans']);
      expect(names(const WardrobeQuery(favoritesOnly: true)), ['Blue Jeans']);
    });

    test('sorts by date, category, color, outfits and custom order', () {
      expect(names(const WardrobeQuery()), [
        'Blue Jeans',
        'Sneakers',
        'White Tee',
      ]);
      expect(names(const WardrobeQuery(sort: WardrobeSort.categories)), [
        'White Tee',
        'Blue Jeans',
        'Sneakers',
      ]);
      // Pieces without a color go last.
      expect(
        names(const WardrobeQuery(sort: WardrobeSort.colors)).last,
        'Sneakers',
      );
      final counts = {'Sneakers': 2, 'White Tee': 1};
      expect(
        const WardrobeQuery(sort: WardrobeSort.mostOutfits)
            .apply(items, outfitCounts: counts)
            .map((i) => i.name),
        ['Sneakers', 'White Tee', 'Blue Jeans'],
      );
      final reordered = [
        items[0].copyWith(sortIndex: 1),
        items[3].copyWith(sortIndex: 0),
        items[1],
      ];
      expect(
        const WardrobeQuery(sort: WardrobeSort.custom)
            .apply(reordered)
            .map((i) => i.name),
        ['Sneakers', 'White Tee', 'Blue Jeans'],
      );
    });

    test('filters by usage, categories and materials', () {
      final counts = {'White Tee': 1};
      List<String> used(ItemUsage usage) =>
          WardrobeQuery(usage: usage)
              .apply(items, outfitCounts: counts)
              .map((i) => i.name)
              .toList();
      expect(used(ItemUsage.used), ['White Tee']);
      expect(used(ItemUsage.unused), ['Blue Jeans', 'Sneakers']);
      expect(
        names(
          const WardrobeQuery(
            categories: {ClothingCategory.shoes, ClothingCategory.bottoms},
          ),
        ),
        ['Blue Jeans', 'Sneakers'],
      );
      final denim = [
        items[1].copyWith(materials: ['Denim']),
        items[0],
      ];
      expect(
        const WardrobeQuery(materials: {'denim'}).apply(denim).single.name,
        'Blue Jeans',
      );
    });

    test('groups by season and color', () {
      const bySeason = WardrobeQuery(groupBy: WardrobeGroup.season);
      final groups = bySeason.group(bySeason.apply(items));
      expect(groups.map((g) => g.$1), ['☀️ Summer', 'No season']);
      expect(groups.first.$2.single.name, 'White Tee');
      const byColor = WardrobeQuery(groupBy: WardrobeGroup.colors);
      expect(byColor.group(byColor.apply(items)).map((g) => g.$1), [
        'White',
        'Blue',
        'No color',
      ]);
    });
  });
}
