import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/repositories/wardrobe_repository.dart';

import '../helpers/test_harness.dart';

void main() {
  test('data survives an app restart', () async {
    final storage = InMemoryStorageService();
    final first = TestCloset(storage: storage);
    await first.load();
    final itemId = await first.addItem('Linen Shirt', ClothingCategory.tops);
    final outfitId = await first.addOutfit('Linen day', [itemId]);
    await first.wardrobe.toggleFavorite(itemId);
    await first.closet.planOutfit(outfitId, testNow);

    // A new set of controllers over the same storage simulates a restart.
    final second = TestCloset(storage: storage);
    await second.load();
    final item = second.wardrobe.itemById(itemId)!;
    expect(item.name, 'Linen Shirt');
    expect(item.isFavorite, isTrue);
    expect(second.outfits.outfitById(outfitId)?.itemIds, [itemId]);
    expect(second.planner.dayPlan(testNow).planned?.outfitId, outfitId);
  });

  test('malformed records are skipped instead of failing the load', () async {
    final storage = InMemoryStorageService({
      StorageKeys.clothingItems: jsonEncode([
        {'id': 'ok', 'name': 'Good item', 'category': 'tops'},
        {'name': 'missing id'},
        'not even a map',
        42,
      ]),
    });
    final items = await LocalWardrobeRepository(storage).fetchAll();
    expect(items.map((i) => i.id), ['ok']);
  });

  test('unreadable JSON is backed up and treated as empty', () async {
    const corrupt = '{not json';
    final storage = InMemoryStorageService({
      StorageKeys.clothingItems: corrupt,
    });
    final items = await LocalWardrobeRepository(storage).fetchAll();
    expect(items, isEmpty);
    expect(
      storage.values[StorageKeys.corruptBackup(StorageKeys.clothingItems)],
      corrupt,
    );
  });

  test('a failed write surfaces a StorageException and keeps state', () async {
    final closet = TestCloset();
    await closet.load();
    final itemId = await closet.addItem('Coat', ClothingCategory.outerwear);

    closet.storage.failWrites = true;
    await expectLater(
      closet.wardrobe.toggleFavorite(itemId),
      throwsA(isA<StorageException>()),
    );
    expect(closet.wardrobe.itemById(itemId)!.isFavorite, isFalse);
  });
}
