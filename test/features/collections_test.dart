import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/collection.dart';
import 'package:all_fits/data/models/subscription_plan.dart';

import '../helpers/test_harness.dart';

void main() {
  late TestCloset closet;
  late String tee;
  late String jeans;
  late String sneakers;
  late String look;

  setUp(() async {
    closet = TestCloset();
    await closet.load();
    tee = await closet.addItem('Tee', ClothingCategory.tops);
    jeans = await closet.addItem('Jeans', ClothingCategory.bottoms);
    sneakers = await closet.addItem('Sneakers', ClothingCategory.shoes);
    look = await closet.addOutfit('Weekend', [tee, jeans, sneakers]);
  });

  group('naming', () {
    test('trims the name and rejects blanks', () async {
      final beach = await closet.collections.createCollection('  Beach  ');
      expect(beach.name, 'Beach');
      expect(beach.isEmpty, isTrue);
      await expectLater(
        closet.collections.createCollection('   '),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects a name already used, ignoring case', () async {
      final beach = await closet.collections.createCollection('Beach');
      final work = await closet.collections.createCollection('Work');
      await expectLater(
        closet.collections.createCollection('beach'),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        closet.collections.rename(work.id, 'BEACH'),
        throwsA(isA<ValidationException>()),
      );
      // Changing only the case of its own name is fine.
      await closet.collections.rename(beach.id, 'BEACH');
      expect(closet.collections.collectionById(beach.id)!.name, 'BEACH');
    });
  });

  group('entries', () {
    test('adds many at once, newest first, and removes them', () async {
      final c = await closet.collections.createCollection('Work');
      await closet.collections.setEntries(
        c.id,
        itemIds: [tee],
        outfitIds: const [],
      );
      await closet.collections.setEntries(
        c.id,
        itemIds: [tee, jeans, sneakers],
        outfitIds: [look],
      );
      var saved = closet.collections.collectionById(c.id)!;
      expect(saved.itemIds, [jeans, sneakers, tee]);
      expect(saved.outfitIds, [look]);

      await closet.collections.removeEntries(c.id, itemIds: [sneakers]);
      saved = closet.collections.collectionById(c.id)!;
      expect(saved.itemIds, [jeans, tee]);
      expect(saved.outfitIds, [look]);
    });

    test('puts one item in exactly the ticked collections', () async {
      final beach = await closet.collections.createCollection('Beach');
      final work = await closet.collections.createCollection('Work');
      final wishlist = await closet.collections.createCollection(
        'Wishlist',
        itemIds: [tee],
      );

      await closet.collections.setItemMembership(tee, {beach.id, work.id});
      expect(
        closet.collections.collectionsWithItem(tee).map((c) => c.id),
        unorderedEquals([beach.id, work.id]),
      );
      expect(
        closet.collections.collectionById(wishlist.id)!.containsItem(tee),
        isFalse,
      );

      await closet.collections.setOutfitMembership(look, {wishlist.id});
      expect(
        closet.collections.collectionsWithOutfit(look).single.id,
        wishlist.id,
      );
    });
  });

  group('keeping the closet consistent', () {
    test('deleting a collection keeps its clothes and outfits', () async {
      final c = await closet.collections.createCollection(
        'Work',
        itemIds: [tee],
        outfitIds: [look],
      );
      await closet.collections.deleteCollection(c.id);
      expect(closet.collections.collections, isEmpty);
      expect(closet.wardrobe.itemById(tee), isNotNull);
      expect(closet.outfits.outfitById(look), isNotNull);
    });

    test('a deleted item or outfit leaves every collection', () async {
      final a = await closet.collections.createCollection(
        'A',
        itemIds: [tee, jeans],
        outfitIds: [look],
      );
      final b = await closet.collections.createCollection(
        'B',
        itemIds: [tee],
      );

      await closet.closet.deleteItemPermanently(tee);
      expect(closet.collections.collectionById(a.id)!.itemIds, [jeans]);
      expect(closet.collections.collectionById(b.id)!.itemIds, isEmpty);

      await closet.closet.deleteOutfit(look);
      expect(closet.collections.collectionById(a.id)!.outfitIds, isEmpty);
    });

    test('an archived item stays in its collections', () async {
      final c = await closet.collections.createCollection(
        'Work',
        itemIds: [tee],
      );
      await closet.wardrobe.setArchived(tee, archived: true);
      expect(closet.collections.collectionById(c.id)!.itemIds, [tee]);
    });

    test('erasing all data removes collections and their covers', () async {
      final c = await closet.collections.createCollection('Work');
      await closet.collections.setCover(c.id, '/tmp/cover.jpg');
      final cover = closet.collections.collectionById(c.id)!.coverImagePath;
      await closet.closet.eraseAllData();
      expect(closet.collections.collections, isEmpty);
      expect(closet.images.deleted, contains(cover));
    });
  });

  group('cover', () {
    test('a new cover photo replaces and deletes the old one', () async {
      final c = await closet.collections.createCollection('Work');
      await closet.collections.setCover(c.id, '/tmp/one.jpg');
      final first = closet.collections.collectionById(c.id)!.coverImagePath;
      expect(first, isNotNull);

      await closet.collections.setCover(c.id, '/tmp/two.jpg');
      final second = closet.collections.collectionById(c.id)!.coverImagePath;
      expect(second, isNot(first));
      expect(closet.images.deleted, [first]);

      await closet.collections.clearCover(c.id);
      expect(closet.collections.collectionById(c.id)!.coverImagePath, isNull);
      expect(closet.images.deleted, [first, second]);
    });

    test('deleting a collection deletes its cover photo', () async {
      final c = await closet.collections.createCollection('Work');
      await closet.collections.setCover(c.id, '/tmp/one.jpg');
      final cover = closet.collections.collectionById(c.id)!.coverImagePath;
      await closet.collections.deleteCollection(c.id);
      expect(closet.images.deleted, [cover]);
    });
  });

  test('collections are saved on the device', () async {
    final c = await closet.collections.createCollection(
      'Beach',
      itemIds: [tee],
      outfitIds: [look],
    );
    final reopened = TestCloset(storage: closet.storage);
    await reopened.load();
    final saved = reopened.collections.collectionById(c.id)!;
    expect(saved.name, 'Beach');
    expect(saved.itemIds, [tee]);
    expect(saved.outfitIds, [look]);
  });

  test('reads stored JSON leniently', () {
    final collection = Collection.fromJson({
      'id': 'c1',
      'itemIds': ['a', 'a', 'b'],
    });
    expect(collection.name, 'Untitled collection');
    expect(collection.itemIds, ['a', 'b']);
    expect(collection.outfitIds, isEmpty);
    expect(() => Collection.fromJson({'name': 'x'}), throwsFormatException);
  });

  test('Free holds a few collections, Premium any number', () {
    const limit = AppConfig.freeCollectionLimit;
    expect(SubscriptionPlan.free.canAddCollection(limit - 1), isTrue);
    expect(SubscriptionPlan.free.canAddCollection(limit), isFalse);
    expect(SubscriptionPlan.premium.canAddCollection(limit * 10), isTrue);
  });
}
