import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/app/theme/app_theme.dart';
import 'package:all_fits/data/local/background_remover.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/outfit_board.dart';
import 'package:all_fits/data/models/outfit_placement.dart';
import 'package:all_fits/features/outfits/controllers/outfit_builder_controller.dart';
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

  group('board decorations', () {
    test('background and stickers survive JSON; broken stickers drop', () {
      const sticker = OutfitSticker(
        placement: OutfitPlacement(
          itemId: 's1',
          x: 0.4,
          y: 0.3,
          width: 0.2,
          height: 0.16,
          rotation: 0.5,
        ),
        emoji: '✨',
      );
      const hair = OutfitSticker(
        placement: OutfitPlacement(
          itemId: 's2',
          x: 0.5,
          y: 0.1,
          width: 0.3,
          height: 0.24,
        ),
        hairstyle: Hairstyle.bun,
        hairColor: HairColor.blonde,
      );
      final outfit = Outfit(
        id: 'o',
        name: 'Look',
        itemIds: const ['tee'],
        background: BoardBackground.mint,
        stickers: const [sticker, hair],
        createdAt: testNow,
        updatedAt: testNow,
      );
      final back = Outfit.fromJson({
        ...outfit.toJson(),
        'stickers': [
          sticker.toJson(),
          hair.toJson(),
          // Neither emoji nor hairstyle, and not a map.
          {'id': 'x', 'x': 0.5, 'y': 0.5, 'width': 0.2, 'height': 0.2},
          'junk',
        ],
      });
      expect(back.background, BoardBackground.mint);
      expect(back.stickers.map((s) => s.id), ['s1', 's2']);
      expect(back.stickers.first.emoji, '✨');
      expect(back.stickers.first.placement.rotation, 0.5);
      expect(back.stickers.last.hairstyle, Hairstyle.bun);
      expect(back.stickers.last.hairColor, HairColor.blonde);
      expect(Outfit.fromJson(outfit.toJson()).stickers, hasLength(2));

      final old = Outfit.fromJson({'id': 'old', 'name': 'Old'});
      expect(old.background, BoardBackground.plain);
      expect(old.stickers, isEmpty);
    });

    test('the builder adds, selects and removes stickers', () {
      final builder = OutfitBuilderController(
        lookup: (id) => id == 'tee' ? tee : null,
        initialItemIds: const ['tee'],
        idGenerator: SequentialIdGenerator(),
      );
      addTearDown(builder.dispose);
      builder
        ..setBackground(BoardBackground.blush)
        ..addEmojiSticker('🌸')
        ..addHair(Hairstyle.curly, HairColor.black);
      expect(builder.stickers, hasLength(2));
      expect(builder.selectedStickerId, builder.stickers.last.id);
      // Square on the 4:5 board.
      final placement = builder.stickers.first.placement;
      expect(placement.height / placement.width, closeTo(0.8, 1e-9));

      builder.removeSelectedSticker();
      expect(builder.stickers.single.emoji, '🌸');
      expect(builder.selectedStickerId, isNull);

      final draft = builder.buildDraft(name: 'Look', fallbackName: 'Outfit');
      expect(draft.background, BoardBackground.blush);
      expect(draft.stickers.single.emoji, '🌸');
    });

    test('new stickers land clear of the pieces, hair above the top', () {
      final builder = OutfitBuilderController(
        lookup: (id) => id == 'tee' ? tee : null,
        initialItemIds: const ['tee'],
        idGenerator: SequentialIdGenerator(),
      );
      addTearDown(builder.dispose);
      final top = OutfitLayout.resolve([tee], const []).single;
      // Share of [a]'s box that [b] covers.
      double covered(OutfitPlacement a, OutfitPlacement b) {
        final w =
            (a.width + b.width) / 2 - (a.x - b.x).abs().clamp(0, 1).toDouble();
        final h =
            (a.height + b.height) / 2 -
            (a.y - b.y).abs().clamp(0, 1).toDouble();
        if (w <= 0 || h <= 0) return 0;
        return w.clamp(0, a.width) *
            h.clamp(0, a.height) /
            (a.width * a.height);
      }

      builder
        ..addEmojiSticker('🌸')
        ..addHair(Hairstyle.bob, HairColor.brown);
      final emoji = builder.stickers.first.placement;
      final hair = builder.stickers.last.placement;
      expect(covered(emoji, top), 0);
      // The flat-lay's top is at the very top, so the hair moves beside it.
      expect(covered(hair, top), lessThanOrEqualTo(0.3));
      expect(covered(hair, emoji), 0);
      for (final p in [emoji, hair]) {
        expect(p.x - p.width / 2, greaterThanOrEqualTo(0));
        expect(p.y + p.height / 2, lessThanOrEqualTo(1));
      }
    });
  });

  testWidgets('dragging a sticker moves it and selects it', (tester) async {
    var stickers = const [
      OutfitSticker(
        placement: OutfitPlacement(
          itemId: 'star',
          x: 0.5,
          y: 0.5,
          width: 0.2,
          height: 0.16,
        ),
        emoji: '⭐',
      ),
    ];
    var layout = <OutfitPlacement>[];
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 500,
            child: StatefulBuilder(
              builder: (context, setState) => OutfitCanvas(
                items: [tee],
                layout: layout,
                background: BoardBackground.sky,
                stickers: stickers,
                onChanged: (next) => setState(() => layout = next),
                onStickersChanged: (next) => setState(() => stickers = next),
                selectedStickerId: selected,
                onStickerSelected: (id) => setState(() => selected = id),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('⭐'), findsOneWidget);

    await tester.dragFrom(const Offset(200, 250), const Offset(40, -50));
    await tester.pump();

    final moved = stickers.single.placement;
    expect(moved.x, closeTo(0.6, 1e-9));
    expect(moved.y, closeTo(0.4, 1e-9));
    expect(selected, 'star');
    // The piece underneath stayed put.
    expect(layout, isEmpty);
  });
}
