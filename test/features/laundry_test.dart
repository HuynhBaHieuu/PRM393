import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/laundry_status.dart';
import 'package:all_fits/features/outfits/outfit_ideas.dart';

import '../helpers/test_harness.dart';

void main() {
  late TestCloset closet;
  late String tee;
  late String jeans;
  late String sneakers;

  final today = DateHelpers.dateOnly(testNow);
  DateTime day(int offset) => DateHelpers.addDays(today, offset);
  ClothingItem item(String id) => closet.wardrobe.itemById(id)!;

  setUp(() async {
    closet = TestCloset();
    await closet.load();
    sneakers = await closet.addItem('Sneakers', ClothingCategory.shoes);
    jeans = await closet.addItem('Jeans', ClothingCategory.bottoms);
    tee = await closet.addItem('Tee', ClothingCategory.tops);
  });

  group('wearing', () {
    test('a top goes in the hamper after one wear', () async {
      final outfit = await closet.addOutfit('Casual', [tee, jeans, sneakers]);
      await closet.closet.markWorn(outfit);

      expect(item(tee).laundry, LaundryStatus.dirty);
      expect(item(tee).wearsSinceWash, 1);
      // Bottoms take three wears; shoes never need washing.
      expect(item(jeans).laundry, LaundryStatus.clean);
      expect(item(sneakers).laundry, LaundryStatus.clean);
      expect(closet.wardrobe.laundryItems.map((i) => i.id), [tee]);
      expect(
        closet.wardrobe.availableItems.map((i) => i.id),
        isNot(contains(tee)),
      );
    });

    test('bottoms go in the hamper on the third wear', () async {
      final outfit = await closet.addOutfit('Jeans day', [jeans]);
      for (final offset in [-2, -1, 0]) {
        await closet.closet.markWorn(outfit, date: day(offset));
      }
      expect(item(jeans).wearsSinceWash, 3);
      expect(item(jeans).laundry, LaundryStatus.dirty);
    });

    test('undoing the wear that filled the hamper takes it back out', () async {
      final outfit = await closet.addOutfit('Casual', [tee]);
      await closet.closet.markWorn(outfit);
      await closet.closet.unmarkWorn(closet.planner.dayPlan(today).worn!);

      expect(item(tee).laundry, LaundryStatus.clean);
      expect(item(tee).wearsSinceWash, 0);
    });

    test('undoing a wear leaves a piece the user put in the wash', () async {
      final outfit = await closet.addOutfit('Jeans day', [jeans]);
      await closet.closet.markWorn(outfit);
      await closet.wardrobe.setLaundry([jeans], LaundryStatus.dirty);
      await closet.closet.unmarkWorn(closet.planner.dayPlan(today).worn!);

      expect(item(jeans).laundry, LaundryStatus.dirty);
    });
  });

  group('laundry actions', () {
    test('marking clean starts the wear count over', () async {
      final outfit = await closet.addOutfit('Casual', [tee]);
      await closet.closet.markWorn(outfit);
      await closet.wardrobe.setLaundry([tee], LaundryStatus.washing);
      expect(item(tee).laundry, LaundryStatus.washing);
      expect(item(tee).wearsSinceWash, 1);

      await closet.wardrobe.setLaundry([tee], LaundryStatus.clean);
      expect(item(tee).laundry, LaundryStatus.clean);
      expect(item(tee).wearsSinceWash, 0);
      expect(closet.wardrobe.laundryItems, isEmpty);
    });

    test('restore puts pieces back the way they were', () async {
      final outfit = await closet.addOutfit('Casual', [tee]);
      await closet.closet.markWorn(outfit);
      final previous = await closet.wardrobe.setLaundry([
        tee,
        jeans,
      ], LaundryStatus.clean);
      // Jeans were clean and unworn already, so only the tee changed.
      expect(previous.map((i) => i.id), [tee]);

      await closet.wardrobe.restoreLaundry(previous);
      expect(item(tee).laundry, LaundryStatus.dirty);
      expect(item(tee).wearsSinceWash, 1);
    });

    test('the status survives a reload', () async {
      await closet.wardrobe.setLaundry([jeans], LaundryStatus.washing);
      final reloaded = TestCloset(storage: closet.storage);
      await reloaded.load();
      expect(reloaded.wardrobe.itemById(jeans)!.laundry, LaundryStatus.washing);
    });
  });

  test('older saves without laundry fields read as clean', () {
    final item = ClothingItem.fromJson({
      'id': 'a',
      'name': 'Tee',
      'category': 'tops',
      'laundry': 'not-a-status',
    });
    expect(item.laundry, LaundryStatus.clean);
    expect(item.wearsSinceWash, 0);
  });

  test('outfit ideas leave out pieces in the laundry', () async {
    final otherTee = await closet.addItem('Shirt', ClothingCategory.tops);
    await closet.wardrobe.setLaundry([tee], LaundryStatus.dirty);
    final ideas = OutfitIdeas.generate(
      closet.wardrobe.activeItems,
      day: today,
      count: 6,
    );
    expect(ideas, isNotEmpty);
    final used = {for (final idea in ideas) ...idea.itemIds};
    expect(used, isNot(contains(tee)));
    expect(used, contains(otherTee));
  });
}
