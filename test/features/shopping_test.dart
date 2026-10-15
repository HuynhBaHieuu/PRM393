import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/app/app.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/shopping_item.dart';
import 'package:all_fits/data/repositories/shopping_repository.dart';
import 'package:all_fits/features/shopping/controllers/shopping_controller.dart';
import 'package:all_fits/features/shopping/controllers/shopping_draft.dart';

import '../helpers/test_harness.dart';

void main() {
  late InMemoryStorageService storage;
  late ShoppingController shopping;
  late DateTime now;

  ShoppingController newController() => ShoppingController(
    repository: LocalShoppingRepository(storage),
    idGenerator: SequentialIdGenerator(),
    clock: () => now,
  );

  setUp(() async {
    storage = InMemoryStorageService();
    now = testNow;
    shopping = newController();
    await shopping.load();
  });

  group('adding to the list', () {
    test('trims text fields and starts unbought', () async {
      final item = await shopping.addItem(
        const ShoppingDraft(
          name: '  Leather boots ',
          category: ClothingCategory.shoes,
          color: ClothingColor.black,
          brand: '  ',
          price: 120,
          link: ' shop.com/boots ',
          priority: ShoppingPriority.high,
        ),
      );
      expect(item.name, 'Leather boots');
      expect(item.brand, isNull);
      expect(item.link, 'shop.com/boots');
      expect(item.isPurchased, isFalse);
      expect(shopping.toBuy.single.id, item.id);
      expect(shopping.toBuyTotal, 120);
    });

    test('requires a name, a category and a valid link', () async {
      await expectLater(
        shopping.addItem(
          const ShoppingDraft(name: ' ', category: ClothingCategory.tops),
        ),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        shopping.addItem(const ShoppingDraft(name: 'Tee', category: null)),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        shopping.addItem(
          const ShoppingDraft(
            name: 'Tee',
            category: ClothingCategory.tops,
            link: 'not a link',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(shopping.toBuy, isEmpty);
    });

    test('sorts must-haves first, then newest', () async {
      await shopping.addItem(
        const ShoppingDraft(name: 'Old', category: ClothingCategory.tops),
      );
      now = testNow.add(const Duration(hours: 1));
      await shopping.addItem(
        const ShoppingDraft(name: 'New', category: ClothingCategory.tops),
      );
      await shopping.addItem(
        const ShoppingDraft(
          name: 'Wanted',
          category: ClothingCategory.tops,
          priority: ShoppingPriority.high,
        ),
      );
      expect(shopping.toBuy.map((i) => i.name), ['Wanted', 'New', 'Old']);
    });
  });

  group('buying', () {
    test('moves items between lists and totals', () async {
      final item = await shopping.addItem(
        const ShoppingDraft(
          name: 'Coat',
          category: ClothingCategory.outerwear,
          price: 200,
        ),
      );
      await shopping.setPurchased(item.id, purchased: true);
      expect(shopping.toBuy, isEmpty);
      expect(shopping.purchased.single.purchasedAt, testNow);
      expect(shopping.spentTotal, 200);
      expect(shopping.toBuyTotal, 0);

      await shopping.setPurchased(item.id, purchased: false);
      expect(shopping.purchased, isEmpty);
      expect(shopping.toBuy.single.id, item.id);
    });

    test('linking to the wardrobe marks the item bought', () async {
      final item = await shopping.addItem(
        const ShoppingDraft(
          name: 'Cap',
          category: ClothingCategory.accessories,
        ),
      );
      await shopping.linkToWardrobe(item.id, 'wardrobe-1');
      final linked = shopping.itemById(item.id)!;
      expect(linked.wardrobeItemId, 'wardrobe-1');
      expect(linked.isPurchased, isTrue);
    });

    test('clearing bought items keeps the rest', () async {
      final keep = await shopping.addItem(
        const ShoppingDraft(name: 'Keep', category: ClothingCategory.tops),
      );
      final done = await shopping.addItem(
        const ShoppingDraft(name: 'Done', category: ClothingCategory.tops),
      );
      await shopping.setPurchased(done.id, purchased: true);
      await shopping.clearPurchased();
      expect(shopping.purchased, isEmpty);
      expect(shopping.toBuy.single.id, keep.id);
    });
  });

  test('the list survives a reload', () async {
    final item = await shopping.addItem(
      const ShoppingDraft(
        name: 'Scarf',
        category: ClothingCategory.accessories,
        color: ClothingColor.red,
        price: 35.5,
        notes: 'wool',
      ),
    );
    await shopping.setPurchased(item.id, purchased: true);

    final reloaded = newController();
    await reloaded.load();
    final restored = reloaded.itemById(item.id)!;
    expect(restored.name, 'Scarf');
    expect(restored.color, ClothingColor.red);
    expect(restored.price, 35.5);
    expect(restored.notes, 'wool');
    expect(restored.purchasedAt, testNow);
  });

  test('malformed records fall back to safe defaults', () {
    final item = ShoppingItem.fromJson({
      'id': 'a',
      'name': 'Bag',
      'category': 'unknown',
      'priority': 'urgent',
      'price': -5,
    });
    expect(item.category, ClothingCategory.other);
    expect(item.priority, ShoppingPriority.medium);
    expect(item.price, isNull);
    expect(() => ShoppingItem.fromJson({'id': 'b'}), throwsFormatException);
  });

  test('link validation', () {
    expect(Validators.optionalLink(''), isNull);
    expect(Validators.optionalLink('shop.com/item'), isNull);
    expect(Validators.optionalLink('https://shop.com/item?id=1'), isNull);
    expect(Validators.optionalLink('shop'), isNotNull);
    expect(Validators.optionalLink('two words.com'), isNotNull);
  });

  testWidgets('add a wish, tick it off and add it to the wardrobe', (
    tester,
  ) async {
    final deps = testDependencies();
    await registerTestUser(deps);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AllFitsApp(dependencies: deps));
    await tester.pumpAndSettle();

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profile'),
      ),
    );
    await tap(find.text('Shopping List'));
    expect(find.text('Nothing on your list'), findsOneWidget);

    await tap(find.byType(FloatingActionButton));
    expect(find.text('Add to shopping list'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Chelsea Boots',
    );
    await tap(find.text('Shoes'));
    await tap(find.text('Save'));

    expect(find.text('Chelsea Boots'), findsOneWidget);
    expect(find.text('To buy (1)'), findsOneWidget);

    await tap(find.byType(Checkbox));
    expect(find.text('Bought (1)'), findsOneWidget);
    await tap(find.text('Add to wardrobe'));

    expect(find.text('Add clothing'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Chelsea Boots'), findsOneWidget);
    await tap(find.text('Gallery'));
    await tap(find.text('Save'));

    expect(find.text('Shopping List'), findsOneWidget);
    await tap(find.text('Bought (1)'));
    expect(find.textContaining('In your wardrobe'), findsOneWidget);
  });
}
