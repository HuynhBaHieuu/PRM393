import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit_placement.dart';
import 'package:all_fits/data/models/outfit_slot.dart';

/// Where pieces sit on the outfit canvas until the user moves them, laid
/// out like a flat-lay: top and bottom down the right, outerwear and shoes
/// on the left, accessories in the gaps.
abstract final class OutfitLayout {
  /// Spots as (x, y, width, height) fractions of the canvas, see
  /// [OutfitPlacement].
  static const Map<OutfitSlot, List<(double, double, double, double)>> _spots =
      {
        OutfitSlot.outerwear: [(0.28, 0.22, 0.46, 0.34)],
        OutfitSlot.top: [(0.66, 0.20, 0.42, 0.30)],
        OutfitSlot.dress: [(0.66, 0.42, 0.48, 0.58)],
        OutfitSlot.bottom: [(0.66, 0.60, 0.44, 0.50)],
        OutfitSlot.shoes: [(0.28, 0.84, 0.42, 0.20)],
        OutfitSlot.accessories: [
          (0.24, 0.53, 0.32, 0.20),
          (0.90, 0.46, 0.18, 0.14),
          (0.90, 0.86, 0.18, 0.14),
          (0.90, 0.10, 0.18, 0.14),
        ],
      };

  /// Spots for [worn], the pieces stacked head to toe down the middle as if
  /// worn, as on Fits' idea cards.
  static const Map<OutfitSlot, List<(double, double, double, double)>>
  _wornSpots = {
    OutfitSlot.outerwear: [(0.42, 0.24, 0.62, 0.36)],
    OutfitSlot.top: [(0.56, 0.24, 0.6, 0.34)],
    OutfitSlot.dress: [(0.5, 0.42, 0.68, 0.66)],
    OutfitSlot.bottom: [(0.5, 0.6, 0.56, 0.46)],
    OutfitSlot.shoes: [(0.5, 0.9, 0.46, 0.16)],
    OutfitSlot.accessories: [(0.84, 0.08, 0.24, 0.12), (0.16, 0.5, 0.22, 0.14)],
  };

  /// Back to front, so tops sit over bottoms and accessories over all.
  static const List<OutfitSlot> _paintOrder = [
    OutfitSlot.bottom,
    OutfitSlot.dress,
    OutfitSlot.top,
    OutfitSlot.outerwear,
    OutfitSlot.shoes,
    OutfitSlot.accessories,
  ];

  /// Offset for each extra piece once a slot's spots are used up.
  static const double _stagger = 0.06;

  /// Placements for [items], back to front: [saved] ones in their saved
  /// order, then default spots for pieces that have none.
  static List<OutfitPlacement> resolve(
    List<ClothingItem> items,
    List<OutfitPlacement> saved,
  ) {
    final unplaced = {for (final item in items) item.id};
    final kept = saved.where((p) => unplaced.remove(p.itemId)).toList();
    return [
      ...kept,
      ...defaults(items.where((item) => unplaced.contains(item.id)).toList()),
    ];
  }

  /// The pieces stacked head to toe, for previews of suggested looks.
  static List<OutfitPlacement> worn(List<ClothingItem> items) =>
      defaults(items, spots: _wornSpots);

  static List<OutfitPlacement> defaults(
    List<ClothingItem> items, {
    Map<OutfitSlot, List<(double, double, double, double)>> spots = _spots,
  }) {
    final bySlot = <OutfitSlot, List<String>>{};
    for (final item in items) {
      bySlot
          .putIfAbsent(OutfitSlot.forCategory(item.category), () => [])
          .add(item.id);
    }
    return [
      for (final slot in _paintOrder)
        for (final (index, id) in (bySlot[slot] ?? const <String>[]).indexed)
          _spot(spots[slot]!, index, id),
    ];
  }

  static OutfitPlacement _spot(
    List<(double, double, double, double)> spots,
    int index,
    String itemId,
  ) {
    final (x, y, width, height) = spots[index % spots.length];
    final shift = (index ~/ spots.length) * _stagger;
    return OutfitPlacement(
      itemId: itemId,
      x: x + shift,
      y: y + shift,
      width: width,
      height: height,
    );
  }
}
