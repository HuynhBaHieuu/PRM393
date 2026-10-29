import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/subscription_plan.dart';
import 'package:all_fits/data/models/trip.dart';
import 'package:all_fits/data/repositories/trip_repository.dart';
import 'package:all_fits/features/trips/packing_list.dart';
import 'package:all_fits/features/trips/trip_controller.dart';

import '../helpers/test_harness.dart';

void main() {
  final start = DateTime(2026, 11, 12);
  DateTime day(int n) => start.add(Duration(days: n));

  ClothingItem item(String id, ClothingCategory category) => ClothingItem(
    id: id,
    name: 'Item $id',
    category: category,
    createdAt: testNow,
    updatedAt: testNow,
  );

  final items = {
    for (final i in [
      item('jeans', ClothingCategory.bottoms),
      item('tee', ClothingCategory.tops),
      item('shirt', ClothingCategory.tops),
      item('sneakers', ClothingCategory.shoes),
    ])
      i.id: i,
  };
  final outfits = {
    'casual': Outfit(
      id: 'casual',
      name: 'Casual',
      itemIds: const ['tee', 'jeans', 'sneakers'],
      createdAt: testNow,
      updatedAt: testNow,
    ),
    'smart': Outfit(
      id: 'smart',
      name: 'Smart',
      itemIds: const ['shirt', 'jeans', 'sneakers', 'gone'],
      createdAt: testNow,
      updatedAt: testNow,
    ),
  };

  Trip trip({
    Map<String, String> days = const {},
    List<String> packed = const [],
  }) => Trip(
    id: 't1',
    name: 'Đà Lạt',
    startDate: start,
    endDate: day(2),
    outfitByDay: days,
    packedItemIds: packed,
    createdAt: testNow,
    updatedAt: testNow,
  );

  PackingList listFor(Trip t) => PackingList.of(
    t,
    outfitById: (id) => outfits[id],
    itemById: (id) => items[id],
  );

  group('PackingList', () {
    test('lists each piece once with the days it is worn', () {
      final list = listFor(
        trip(
          days: {
            '2026-11-12': 'casual',
            '2026-11-13': 'smart',
            '2026-11-14': 'casual',
          },
          packed: ['jeans'],
        ),
      );
      final days = {for (final l in list.lines) l.item.id: l.days};
      expect(days, {'tee': 2, 'shirt': 1, 'jeans': 3, 'sneakers': 3});
      // Category order, then first worn: tops, bottoms, shoes.
      expect(list.lines.map((l) => l.item.id), [
        'tee',
        'shirt',
        'jeans',
        'sneakers',
      ]);
      expect(list.packedCount, 1);
      expect(list.total, 4);
    });

    test('skips deleted outfits and pieces', () {
      final list = listFor(
        trip(days: {'2026-11-12': 'deleted', '2026-11-13': 'smart'}),
      );
      expect(list.lines.map((l) => l.item.id), ['shirt', 'jeans', 'sneakers']);
      expect(list.plannedDays((id) => outfits[id]), 1);
    });

    test('copies as text with ticks and extras', () {
      final t = trip(days: {'2026-11-12': 'casual'}, packed: ['tee']).copyWith(
        extras: const [PackingExtra(id: 'e1', label: 'Charger', packed: true)],
      );
      final text = listFor(t).toText();
      expect(text, contains('Đà Lạt'));
      expect(text, contains('☑ Item tee'));
      expect(text, contains('☐ Item jeans'));
      expect(text, contains('${PackingList.extrasTitle}\n☑ Charger'));
    });
  });

  group('Trip', () {
    test('round-trips through JSON', () {
      final original = trip(days: {'2026-11-13': 'smart'}, packed: ['jeans'])
          .copyWith(
            extras: const [PackingExtra(id: 'e1', label: 'Charger')],
          );
      final copy = Trip.fromJson(
        original.copyWith(location: testCity).toJson(),
      );
      expect(copy.location, testCity);
      expect(copy.location!.name, testCity.name);
      expect(copy.startDate, start);
      expect(copy.endDate, day(2));
      expect(copy.outfitOn(day(1)), 'smart');
      expect(copy.packedItemIds, ['jeans']);
      expect(copy.extras.single.label, 'Charger');
      expect(copy.length, 3);
    });
  });

  group('TripController', () {
    late TripController controller;

    setUp(() async {
      controller = TripController(
        repository: LocalTripRepository(InMemoryStorageService()),
        idGenerator: SequentialIdGenerator(),
        clock: () => testNow,
      );
      await controller.load();
    });

    test('creates a trip and rejects bad dates', () async {
      final t = await controller.createTrip('  Beach ', start, day(4));
      expect(t.name, 'Beach');
      expect(controller.trips, [t]);
      expect(
        () => controller.createTrip('Back', day(2), day(1)),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => controller.createTrip('Long', start, day(Trip.maxDays)),
        throwsA(isA<ValidationException>()),
      );
    });

    test('sets and clears day outfits, only inside the trip', () async {
      final t = await controller.createTrip('Beach', start, day(2));
      await controller.setDayOutfit(t.id, day(1), 'casual');
      expect(controller.tripById(t.id)!.outfitOn(day(1)), 'casual');
      await controller.setDayOutfit(t.id, day(1), null);
      expect(controller.tripById(t.id)!.outfitByDay, isEmpty);
      expect(
        () => controller.setDayOutfit(t.id, day(5), 'casual'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('shorter dates drop the days outside them', () async {
      final t = await controller.createTrip('Beach', start, day(2));
      await controller.setDayOutfit(t.id, day(0), 'casual');
      await controller.setDayOutfit(t.id, day(2), 'smart');
      final updated = await controller.updateDetails(
        t.id,
        name: 'Beach',
        start: start,
        end: day(1),
      );
      expect(updated.outfitByDay.keys, ['2026-11-12']);
    });

    test('a deleted outfit leaves its days empty', () async {
      final t = await controller.createTrip('Beach', start, day(2));
      await controller.setDayOutfit(t.id, day(0), 'casual');
      await controller.setDayOutfit(t.id, day(1), 'smart');
      await controller.removeOutfitReferences(['casual']);
      expect(controller.tripById(t.id)!.outfitByDay, {'2026-11-13': 'smart'});
    });

    test('ticks pieces and extras, and unticks them all', () async {
      final t = await controller.createTrip('Beach', start, day(2));
      await controller.setItemPacked(t.id, 'tee', true);
      await controller.addExtra(t.id, 'Sunscreen');
      final extra = controller.tripById(t.id)!.extras.single;
      await controller.setExtraPacked(t.id, extra.id, true);
      expect(controller.tripById(t.id)!.packedItemIds, ['tee']);
      expect(controller.tripById(t.id)!.extras.single.packed, isTrue);

      await controller.resetPacking(t.id);
      final reset = controller.tripById(t.id)!;
      expect(reset.packedItemIds, isEmpty);
      expect(reset.extras.single.packed, isFalse);

      await controller.removeExtra(t.id, extra.id);
      expect(controller.tripById(t.id)!.extras, isEmpty);
    });

    test('keeps the city, and clears it when edited away', () async {
      final t = await controller.createTrip(
        'Beach',
        start,
        day(2),
        location: testCity,
      );
      expect(controller.tripById(t.id)!.location, testCity);
      final updated = await controller.updateDetails(
        t.id,
        name: 'Beach',
        start: start,
        end: day(2),
      );
      expect(updated.location, isNull);
    });

    test(
      'counts trips that have not ended, and finds the trip of a day',
      () async {
        final past = await controller.createTrip(
          'Last summer',
          DateTime(2026, 7, 1),
          DateTime(2026, 7, 5),
        );
        final next = await controller.createTrip('Beach', start, day(2));
        expect(controller.isActive(past), isFalse);
        expect(controller.activeCount, 1);
        expect(controller.tripOn(day(1)), next);
        expect(controller.tripOn(DateTime(2026, 7, 3)), past);
        expect(controller.tripOn(day(3)), isNull);
      },
    );

    test('Free has one trip at a time, Premium any number', () {
      expect(SubscriptionPlan.free.canAddTrip(0), isTrue);
      expect(SubscriptionPlan.free.canAddTrip(1), isFalse);
      expect(SubscriptionPlan.premium.canAddTrip(5), isTrue);
    });

    test('keeps trips after a reload', () async {
      final storage = InMemoryStorageService();
      final first = TripController(
        repository: LocalTripRepository(storage),
        clock: () => testNow,
      );
      await first.load();
      await first.createTrip('Beach', start, day(2));
      final second = TripController(
        repository: LocalTripRepository(storage),
        clock: () => testNow,
      );
      await second.load();
      expect(second.trips.single.name, 'Beach');
    });
  });
}
