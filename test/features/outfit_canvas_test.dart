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
import 'package:all_fits/features/outfits/widgets/sticker_art.dart';

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

      // A drawn sticker keeps its colour, layer, flip and lock.
      const tape = OutfitSticker(
        placement: OutfitPlacement(
          itemId: 's3',
          x: 0.2,
          y: 0.2,
          width: 0.2,
          height: 0.16,
          flipped: true,
          locked: true,
        ),
        art: StickerArt.heart,
        ink: StickerInk.red,
        behind: true,
      );
      final drawn = OutfitSticker.tryFromJson(tape.toJson())!;
      expect(drawn.art, StickerArt.heart);
      expect(drawn.ink, StickerInk.red);
      expect(drawn.behind, isTrue);
      expect(drawn.placement.flipped, isTrue);
      expect(drawn.placement.locked, isTrue);
      expect(
        OutfitSticker.tryFromJson({...tape.toJson(), 'emoji': '✨'}),
        isNull,
      );

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
      expect(builder.selectedId, builder.stickers.last.id);
      // Square on the 4:5 board.
      final placement = builder.stickers.first.placement;
      expect(placement.height / placement.width, closeTo(0.8, 1e-9));

      builder.deleteSelected();
      expect(builder.stickers.single.emoji, '🌸');
      expect(builder.selectedId, isNull);

      final draft = builder.buildDraft(name: 'Look', fallbackName: 'Outfit');
      expect(draft.background, BoardBackground.blush);
      expect(draft.stickers.single.emoji, '🌸');
    });

    testWidgets('every hairstyle paints, men\'s cuts included', (tester) async {
      expect(
        Hairstyle.values.map((h) => h.label),
        containsAll(['Undercut', 'Layered', 'Short quiff', 'Faux hawk']),
      );
      await tester.pumpWidget(
        Wrap(
          textDirection: TextDirection.ltr,
          children: [
            for (final style in Hairstyle.values)
              SizedBox.square(
                dimension: 60,
                child: CustomPaint(
                  painter: HairPainter(
                    style: style,
                    color: HairColor.brown.color,
                  ),
                ),
              ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
    });

    test('only a few stickers and three hairstyles are free', () {
      expect(StickerArt.values.where((a) => a.free), hasLength(10));
      expect(Hairstyle.values.where((h) => h.isFree), hasLength(3));
      for (final category in StickerCategory.values) {
        if (category == StickerCategory.hair ||
            category == StickerCategory.emoji) {
          continue;
        }
        expect(StickerArt.of(category), isNotEmpty, reason: category.name);
      }
    });

    test('the selection tools duplicate, flip, lock, layer and delete', () {
      final builder = OutfitBuilderController(
        lookup: (id) => id == 'tee' ? tee : null,
        initialItemIds: const ['tee'],
        idGenerator: SequentialIdGenerator(),
      );
      addTearDown(builder.dispose);
      builder.addSticker(
        const OutfitSticker(
          placement: OutfitPlacement(
            itemId: '',
            x: 0.5,
            y: 0.5,
            width: 0.2,
            height: 0.2,
          ),
          art: StickerArt.star,
          ink: StickerInk.yellow,
        ),
      );
      final original = builder.stickers.single;
      expect(original.art, StickerArt.star);
      expect(original.ink, StickerInk.yellow);

      builder.duplicateSelected();
      expect(builder.stickers, hasLength(2));
      final copy = builder.stickers.last;
      expect(builder.selectedId, copy.id);
      expect(copy.id, isNot(original.id));
      expect(
        copy.placement.x,
        closeTo(
          original.placement.x + OutfitBuilderController.duplicateOffset,
          1e-9,
        ),
      );

      builder
        ..flipSelected()
        ..toggleLockSelected()
        ..sendSelectedToBack();
      final back = builder.stickers.first;
      expect(back.id, copy.id);
      expect(back.behind, isTrue);
      expect(back.placement.flipped, isTrue);
      expect(builder.selectedLocked, isTrue);
      expect(builder.selectedBehind, isTrue);

      builder.bringSelectedToFront();
      expect(builder.stickers.last.id, copy.id);
      expect(builder.stickers.last.behind, isFalse);

      builder.deleteSelected();
      expect(builder.stickers.single.id, original.id);
      expect(builder.selectedId, isNull);

      // A selected piece flips and locks too; deleting takes it out.
      builder
        ..select('tee')
        ..flipSelected()
        ..toggleLockSelected();
      expect(builder.selectedPiece!.flipped, isTrue);
      expect(builder.selectedLocked, isTrue);
      builder.deleteSelected();
      expect(builder.itemIds, isEmpty);
      expect(builder.selectedId, isNull);
    });

    test('new stickers land clear of the pieces, hair on the collar', () {
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
      // The hair sits on the top's collar, centred on it.
      expect(hair.x, closeTo(top.x, 1e-9));
      expect(hair.y, lessThan(top.y));
      expect(covered(hair, top), greaterThan(0));
      for (final p in [emoji, hair]) {
        expect(p.x - p.width / 2, greaterThanOrEqualTo(0));
        expect(p.y + p.height / 2, lessThanOrEqualTo(1));
      }
    });
  });

  group('dressed board', () {
    final jacket = _item('jacket', ClothingCategory.outerwear);
    ClothingItem? lookup(String id) => {
      for (final i in [tee, jeans, jacket]) i.id: i,
    }[id];

    test('stacks pieces down the middle with room for a head', () {
      final layout = OutfitLayout.dressed([jeans, tee]);
      final top = layout.firstWhere((p) => p.itemId == 'tee');
      final bottom = layout.firstWhere((p) => p.itemId == 'jeans');
      expect(top.x, 0.5);
      expect(bottom.x, 0.5);
      expect(top.y - top.height / 2, greaterThan(0.12));
      expect(bottom.y, greaterThan(top.y));
      // A jacket over the top stands beside it, so both show.
      final layered = OutfitLayout.dressed([tee, jacket]);
      expect(
        layered.firstWhere((p) => p.itemId == 'jacket').x,
        lessThan(layered.firstWhere((p) => p.itemId == 'tee').x),
      );
    });

    test('a new outfit is saved where its pieces stand', () {
      final builder = OutfitBuilderController(
        lookup: lookup,
        initialItemIds: const ['tee', 'jeans'],
        dressed: true,
        idGenerator: SequentialIdGenerator(),
      );
      addTearDown(builder.dispose);
      expect(
        builder.layout.map((p) => p.itemId),
        unorderedEquals(['tee', 'jeans']),
      );
      final draft = builder.buildDraft(name: 'Look', fallbackName: 'Outfit 1');
      expect(draft.layout, hasLength(2));
      expect(draft.layout.every((p) => p.x == 0.5), isTrue);

      // "Add clothes" swaps the pieces, keeping those that stay.
      builder.setItems(['tee', 'jacket']);
      expect(builder.itemIds, unorderedEquals(['tee', 'jacket']));
    });

    test('hair rests on the shoulders with a neck under the chin', () {
      final builder = OutfitBuilderController(
        lookup: lookup,
        initialItemIds: const ['tee', 'jeans'],
        dressed: true,
        idGenerator: SequentialIdGenerator(),
      );
      addTearDown(builder.dispose);
      expect(builder.hair, isNull);
      builder.addHair(Hairstyle.quiff, HairColor.blonde);
      expect(builder.hair, (Hairstyle.quiff, HairColor.blonde));

      final top = builder.layout.firstWhere((p) => p.itemId == 'tee');
      final hair = builder.stickers.single.placement;
      final collar = top.y - top.height / 2;
      final chin = hair.y + (Hairstyle.face.bottom - 0.5) * hair.height;
      expect(hair.x, closeTo(top.x, 1e-9));
      expect(chin, lessThan(collar));
      expect(chin, greaterThan(collar - 0.05));
      // About a head's width: narrower than the shoulders.
      expect(hair.width, lessThan(top.width));
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
                selectedId: selected,
                onSelected: (id) => setState(() => selected = id),
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

  testWidgets('a locked sticker stays put; tapping the board deselects', (
    tester,
  ) async {
    var stickers = const [
      OutfitSticker(
        placement: OutfitPlacement(
          itemId: 'pin',
          x: 0.5,
          y: 0.5,
          width: 0.2,
          height: 0.16,
          locked: true,
        ),
        art: StickerArt.pin,
      ),
    ];
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
                stickers: stickers,
                onChanged: (_) {},
                onStickersChanged: (next) => setState(() => stickers = next),
                selectedId: selected,
                onSelected: (id) => setState(() => selected = id),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.dragFrom(const Offset(200, 250), const Offset(40, -50));
    await tester.pump();
    expect(selected, 'pin');
    expect(stickers.single.placement.x, 0.5);

    // An empty corner of the board.
    await tester.tapAt(const Offset(5, 495));
    await tester.pump();
    expect(selected, isNull);
  });
}
