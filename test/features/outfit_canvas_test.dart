import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/app/theme/app_theme.dart';
import 'package:all_fits/data/local/background_remover.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/outfit_placement.dart';
import 'package:all_fits/features/outfits/outfit_layout.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';

import '../helpers/test_harness.dart';

ClothingItem _item(String id, ClothingCategory category) => ClothingItem(
  id: id,
  name: id,
  category: category,
  createdAt: testNow,
  updatedAt: testNow,
);

void main() {
  final tee = _item('tee', ClothingCategory.tops);
  final jeans = _item('jeans', ClothingCategory.bottoms);
  final bag = _item('bag', ClothingCategory.bags);
  final ring = _item('ring', ClothingCategory.accessories);

  group('layout', () {
    test('default spots go by category, bottoms behind tops', () {
      final layout = OutfitLayout.resolve([tee, bag, jeans, ring], const []);
      expect(layout.map((p) => p.itemId), ['jeans', 'tee', 'bag', 'ring']);
      // Two accessories don't share a spot.
      expect(layout[2].x, isNot(layout[3].x));
    });

    test('saved spots are kept; deleted pieces drop out', () {
      const moved = OutfitPlacement(
        itemId: 'tee',
        x: 0.1,
        y: 0.1,
        width: 0.3,
        height: 0.3,
      );
      const gone = OutfitPlacement(
        itemId: 'deleted',
        x: 0.5,
        y: 0.5,
        width: 0.3,
        height: 0.3,
      );
      final layout = OutfitLayout.resolve([tee, jeans], [gone, moved]);
      expect(layout.map((p) => p.itemId), ['tee', 'jeans']);
      expect(layout.first.x, 0.1);
    });

    test('layout survives JSON and skips broken entries', () {
      final outfit = Outfit(
        id: 'o',
        name: 'Look',
        itemIds: const ['tee'],
        createdAt: testNow,
        updatedAt: testNow,
        layout: const [
          OutfitPlacement(
            itemId: 'tee',
            x: 0.4,
            y: 0.3,
            width: 0.5,
            height: 0.4,
            rotation: 0.2,
          ),
        ],
      );
      final json = outfit.toJson();
      (json['layout'] as List).add({'itemId': 'x', 'width': 0});
      final restored = Outfit.fromJson(json).layout.single;
      expect(restored.itemId, 'tee');
      expect(restored.rotation, 0.2);
    });
  });

  test('opaqueBounds finds the visible pixels', () {
    // 4×3 image, visible pixels at (1,1) and (2,2).
    final rgba = Uint8List(4 * 3 * 4);
    rgba[(1 * 4 + 1) * 4 + 3] = 255;
    rgba[(2 * 4 + 2) * 4 + 3] = 255;
    final bounds = opaqueBounds(rgba, 4, 3)!;
    expect(
      [bounds.left, bounds.top, bounds.right, bounds.bottom],
      [1, 1, 3, 3],
    );
    expect(opaqueBounds(Uint8List(16), 2, 2), isNull);
  });

  testWidgets('dragging a piece moves it; the empty board does nothing', (
    tester,
  ) async {
    var layout = <OutfitPlacement>[];
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        // Like the outfit builder: the canvas heads a scrolling form.
        home: ListView(
          controller: scroll,
          padding: EdgeInsets.zero,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                height: 500,
                child: StatefulBuilder(
                  builder: (context, setState) => OutfitCanvas(
                    items: [tee],
                    layout: layout,
                    onChanged: (next) => setState(() => layout = next),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );

    final start = OutfitLayout.resolve([tee], const []).single;
    final center = Offset(start.x * 400, start.y * 500);

    await tester.dragFrom(const Offset(20, 480), const Offset(50, 0));
    expect(layout, isEmpty);

    final gesture = await tester.startGesture(center);
    // Mostly vertical, which the page would take as a scroll.
    await gesture.moveBy(const Offset(-20, 100));
    await gesture.up();
    await tester.pump();

    final moved = layout.single;
    expect(moved.x, closeTo(start.x - 0.05, 1e-9));
    expect(moved.y, closeTo(start.y + 0.2, 1e-9));
    expect(scroll.offset, 0);
    expect(moved.width, start.width);
  });
}
