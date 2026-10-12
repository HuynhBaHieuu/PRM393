import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/occasion.dart';
import 'package:all_fits/data/models/outfit_calendar_entry.dart';
import 'package:all_fits/data/models/outfit_slot.dart';
import 'package:all_fits/features/outfits/controllers/outfit_builder_controller.dart';
import 'package:all_fits/features/shared/closet_actions.dart';

import '../helpers/test_harness.dart';

void main() {
  late TestCloset closet;
  late String jacket;
  late String tee;
  late String jeans;
  late String sneakers;
  late String cap;

  final today = DateHelpers.dateOnly(testNow);
  DateTime day(int offset) => DateHelpers.addDays(today, offset);

  setUp(() async {
    closet = TestCloset();
    await closet.load();
    cap = await closet.addItem('Cap', ClothingCategory.accessories);
    sneakers = await closet.addItem('Sneakers', ClothingCategory.shoes);
    jeans = await closet.addItem('Jeans', ClothingCategory.bottoms);
    tee = await closet.addItem('Tee', ClothingCategory.tops);
    jacket = await closet.addItem('Jacket', ClothingCategory.outerwear);
  });

  group('outfit builder', () {
    OutfitBuilderController builder({List<String> initial = const []}) =>
        OutfitBuilderController(
          lookup: closet.wardrobe.itemById,
          initialItemIds: initial,
        );

    test('orders pieces by slot as they are added', () {
      final b = builder()
        ..addItem(sneakers)
        ..addItem(cap)
        ..addItem(tee)
        ..addItem(jacket)
        ..addItem(jeans);
      expect(b.itemIds, [jacket, tee, jeans, sneakers, cap]);
      expect(b.idsInSlot(OutfitSlot.top), [tee]);
    });

    test('supports remove, replace and manual reorder', () async {
      final shirt = await closet.addItem('Shirt', ClothingCategory.tops);
      final b = builder(initial: [tee, jeans, sneakers]);

      b.replaceItem(tee, shirt);
      expect(b.itemIds, [shirt, jeans, sneakers]);

      b.reorder(2, 0);
      expect(b.itemIds, [sneakers, shirt, jeans]);

      b.removeItem(shirt);
      expect(b.itemIds, [sneakers, jeans]);
    });

    test('slot selection replaces only that slot', () async {
      final shirt = await closet.addItem('Shirt', ClothingCategory.tops);
      final b = builder(initial: [tee, jeans])
        ..setSlotSelection(OutfitSlot.top, [shirt]);
      expect(b.itemIds, [shirt, jeans]);
    });

    test('ignores unknown item ids', () {
      final b = builder(initial: ['missing', tee]);
      expect(b.itemIds, [tee]);
    });
  });

  group('creating outfits', () {
    test('saves the builder draft with a fallback name', () async {
      final b = OutfitBuilderController(lookup: closet.wardrobe.itemById)
        ..addItem(tee)
        ..addItem(jeans)
        ..setOccasion(Occasion.work);
      final outfit = await closet.outfits.createOutfit(
        b.buildDraft(name: '  ', fallbackName: 'Outfit 1'),
      );
      expect(outfit.name, 'Outfit 1');
      expect(outfit.itemIds, [tee, jeans]);
      expect(outfit.occasion, Occasion.work);
      expect(closet.outfits.outfits.single.id, outfit.id);
    });

    test('rejects an empty outfit', () async {
      await expectLater(
        closet.addOutfit('Empty', const []),
        throwsA(isA<ValidationException>()),
      );
    });

    test('deleting an outfit removes its calendar entries', () async {
      final id = await closet.addOutfit('Casual', [tee, jeans]);
      await closet.closet.planOutfit(id, day(2));
      await closet.closet.markWorn(id, date: day(-1));

      await closet.closet.deleteOutfit(id);
      expect(closet.outfits.outfitById(id), isNull);
      expect(closet.planner.entries, isEmpty);
    });
  });

  group('calendar planning', () {
    test('plans an outfit and replaces an existing plan', () async {
      final a = await closet.addOutfit('A', [tee]);
      final b = await closet.addOutfit('B', [jeans]);

      await closet.closet.planOutfit(a, day(3));
      await closet.closet.planOutfit(b, day(3));

      final plan = closet.planner.dayPlan(day(3));
      expect(plan.planned?.outfitId, b);
      expect(closet.planner.entries, hasLength(1));
    });

    test('removing a plan clears the day', () async {
      final a = await closet.addOutfit('A', [tee]);
      final entry = await closet.closet.planOutfit(a, day(1));
      await closet.planner.removeEntry(entry.id);
      expect(closet.planner.dayPlan(day(1)).isEmpty, isTrue);
    });
  });

  group('marking outfits as worn', () {
    test('updates the calendar and wear statistics', () async {
      final id = await closet.addOutfit('Casual', [tee, jeans]);
      await closet.closet.planOutfit(id, today);

      final result = await closet.closet.markWorn(id);
      expect(result, WearResult.marked);

      // The planned entry becomes the worn entry.
      final plan = closet.planner.dayPlan(today);
      expect(plan.planned, isNull);
      expect(plan.worn?.status, CalendarEntryStatus.worn);
      expect(closet.planner.entries, hasLength(1));

      final outfit = closet.outfits.outfitById(id)!;
      expect(outfit.wearCount, 1);
      expect(outfit.lastWornAt, today);
      expect(closet.wardrobe.itemById(tee)!.wearCount, 1);
      expect(closet.wardrobe.itemById(jeans)!.lastWornAt, today);
      expect(closet.wardrobe.itemById(jacket)!.wearCount, 0);
    });

    test('marking the same outfit twice on one day counts once', () async {
      final id = await closet.addOutfit('Casual', [tee]);
      await closet.closet.markWorn(id);
      expect(await closet.closet.markWorn(id), WearResult.alreadyWorn);
      expect(closet.outfits.outfitById(id)!.wearCount, 1);
      expect(closet.wardrobe.itemById(tee)!.wearCount, 1);
    });

    test('cannot be marked worn in the future', () async {
      final id = await closet.addOutfit('Casual', [tee]);
      await expectLater(
        closet.closet.markWorn(id, date: day(1)),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      'undo reverses counts and restores the previous last-worn date',
      () async {
        final id = await closet.addOutfit('Casual', [tee, jeans]);
        await closet.closet.markWorn(id, date: day(-3));
        await closet.closet.markWorn(id, date: day(-1));
        expect(closet.wardrobe.itemById(tee)!.wearCount, 2);

        final latest = closet.planner.dayPlan(day(-1)).worn!;
        await closet.closet.unmarkWorn(latest);

        final outfit = closet.outfits.outfitById(id)!;
        expect(outfit.wearCount, 1);
        expect(outfit.lastWornAt, day(-3));
        expect(closet.wardrobe.itemById(tee)!.wearCount, 1);
        expect(closet.wardrobe.itemById(tee)!.lastWornAt, day(-3));
      },
    );

    test('wearing another outfit the same day replaces the first', () async {
      final a = await closet.addOutfit('A', [tee]);
      final b = await closet.addOutfit('B', [jeans]);
      await closet.closet.markWorn(a);
      await closet.closet.markWorn(b);

      expect(closet.planner.dayPlan(today).worn?.outfitId, b);
      expect(closet.outfits.outfitById(a)!.wearCount, 0);
      expect(closet.wardrobe.itemById(tee)!.wearCount, 0);
      expect(closet.wardrobe.itemById(jeans)!.wearCount, 1);
    });
  });
}
