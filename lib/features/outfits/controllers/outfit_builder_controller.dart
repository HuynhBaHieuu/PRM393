import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/occasion.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/outfit_board.dart';
import 'package:all_fits/data/models/outfit_placement.dart';
import 'package:all_fits/data/models/outfit_slot.dart';
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/features/outfits/controllers/outfit_draft.dart';
import 'package:all_fits/features/outfits/outfit_layout.dart';

typedef ItemLookup = ClothingItem? Function(String id);

/// Editing state for the outfit builder. Keeps the composition ordered by
/// slot (outerwear → top → bottom → shoes → accessories) as pieces are added,
/// while still allowing manual reordering.
class OutfitBuilderController extends ChangeNotifier {
  OutfitBuilderController({
    required this._lookup,
    Outfit? initial,
    List<String> initialItemIds = const [],
    IdGenerator idGenerator = const UuidIdGenerator(),
  }) : _ids = idGenerator,
       editingId = initial?.id,
       _occasion = initial?.occasion,
       _seasons = {...?initial?.seasons},
       _isFavorite = initial?.isFavorite ?? false,
       _layout = initial?.layout ?? const [],
       _background = initial?.background ?? BoardBackground.plain,
       _stickers = initial?.stickers ?? const [] {
    final ids = initial?.itemIds ?? initialItemIds;
    if (initial != null) {
      // Keep the saved order; drop pieces that were deleted since.
      _itemIds.addAll(ids.where((id) => _lookup(id) != null));
    } else {
      ids.forEach(_insertBySlot);
    }
  }

  /// Default size of a new sticker, as a fraction of the board's width.
  static const double stickerWidth = 0.22;
  static const double hairWidth = 0.3;

  final ItemLookup _lookup;
  final IdGenerator _ids;

  /// Id of the outfit being edited, or null when creating a new one.
  final String? editingId;

  final List<String> _itemIds = [];
  Occasion? _occasion;
  final Set<Season> _seasons;
  bool _isFavorite;
  List<OutfitPlacement> _layout;
  BoardBackground _background;
  List<OutfitSticker> _stickers;
  String? _selectedStickerId;

  bool get isEditing => editingId != null;
  List<String> get itemIds => List.unmodifiable(_itemIds);
  bool get isEmpty => _itemIds.isEmpty;
  Occasion? get occasion => _occasion;
  Set<Season> get seasons => Set.unmodifiable(_seasons);
  bool get isFavorite => _isFavorite;

  /// Where pieces sit on the canvas; empty until the user moves one.
  List<OutfitPlacement> get layout => _layout;

  BoardBackground get background => _background;

  /// Emoji and hairstyles on the board, back to front.
  List<OutfitSticker> get stickers => _stickers;

  /// The sticker touched last, which "Remove" acts on.
  String? get selectedStickerId => _selectedStickerId;

  bool contains(String id) => _itemIds.contains(id);

  List<String> idsInSlot(OutfitSlot slot) =>
      _itemIds.where((id) => _slotOf(id) == slot).toList();

  void addItem(String id) {
    if (_lookup(id) == null || contains(id)) return;
    _insertBySlot(id);
    notifyListeners();
  }

  void removeItem(String id) {
    if (_itemIds.remove(id)) notifyListeners();
  }

  void toggleItem(String id) => contains(id) ? removeItem(id) : addItem(id);

  /// Makes [ids] the selection for [slot], keeping the position of pieces
  /// that remain selected.
  void setSlotSelection(OutfitSlot slot, Iterable<String> ids) {
    final wanted = ids.toSet();
    _itemIds.removeWhere((id) => _slotOf(id) == slot && !wanted.contains(id));
    for (final id in wanted) {
      if (!contains(id) && _lookup(id) != null) _insertBySlot(id);
    }
    notifyListeners();
  }

  /// Swaps [oldId] for [newId] in the same position.
  void replaceItem(String oldId, String newId) {
    final index = _itemIds.indexOf(oldId);
    if (index < 0 || oldId == newId || _lookup(newId) == null) return;
    _itemIds[index] = newId;
    // If the new piece was already elsewhere in the outfit, move it here.
    for (var i = _itemIds.length - 1; i >= 0; i--) {
      if (i != index && _itemIds[i] == newId) _itemIds.removeAt(i);
    }
    notifyListeners();
  }

  /// Moves the piece at [oldIndex] so it ends up at [newIndex].
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _itemIds.length) return;
    final id = _itemIds.removeAt(oldIndex);
    _itemIds.insert(newIndex.clamp(0, _itemIds.length), id);
    notifyListeners();
  }

  void setOccasion(Occasion? occasion) {
    _occasion = occasion;
    notifyListeners();
  }

  void toggleSeason(Season season) {
    if (!_seasons.remove(season)) _seasons.add(season);
    notifyListeners();
  }

  void setFavorite(bool value) {
    _isFavorite = value;
    notifyListeners();
  }

  void setLayout(List<OutfitPlacement> layout) {
    _layout = List.unmodifiable(layout);
    notifyListeners();
  }

  /// Puts every piece back in its default spot.
  void resetLayout() => setLayout(const []);

  void setBackground(BoardBackground background) {
    _background = background;
    notifyListeners();
  }

  /// Adds an emoji sticker in the clearest spot near the middle of the
  /// board and selects it.
  void addEmojiSticker(String emoji) =>
      _addSticker((p) => OutfitSticker(placement: p, emoji: emoji), 0.5, 0.5);

  /// Adds a hairstyle above the top, or in the clearest spot near the top of
  /// the board, and selects it.
  void addHair(Hairstyle style, HairColor color) {
    final top = _pieces()
        .where((p) => _wornAbove.contains(_slotOf(p.itemId)))
        .fold<OutfitPlacement?>(
          null,
          (best, p) =>
              best == null || p.y - p.height / 2 < best.y - best.height / 2
              ? p
              : best,
        );
    _addSticker(
      (p) => OutfitSticker(placement: p, hairstyle: style, hairColor: color),
      top?.x ?? 0.5,
      top == null
          ? 0.12
          : top.y - top.height / 2 - hairWidth * AppSizes.outfitImageAspect / 3,
      width: hairWidth,
      overlap: 0.3,
    );
  }

  /// Slots the hair sits above.
  static const Set<OutfitSlot> _wornAbove = {
    OutfitSlot.top,
    OutfitSlot.dress,
    OutfitSlot.outerwear,
  };

  /// Where the pieces are on the board right now.
  List<OutfitPlacement> _pieces() =>
      OutfitLayout.resolve([for (final id in _itemIds) ?_lookup(id)], _layout);

  /// The centre nearest ([x], [y]) for a [width] × [height] box that covers
  /// the least of the pieces and stickers, so a new sticker doesn't land on
  /// the clothes.
  /// ([x], [y]) itself is kept when it covers no more than [overlap] of the
  /// box, e.g. hair resting on a collar.
  (double, double) _clearSpot(
    double x,
    double y,
    double width,
    double height, {
    double overlap = 0,
  }) {
    final pieces = [..._pieces(), for (final s in _stickers) s.placement];
    double covered(double cx, double cy) {
      var area = 0.0;
      for (final p in pieces) {
        final w =
            math.min(cx + width / 2, p.x + p.width / 2) -
            math.max(cx - width / 2, p.x - p.width / 2);
        final h =
            math.min(cy + height / 2, p.y + p.height / 2) -
            math.max(cy - height / 2, p.y - p.height / 2);
        if (w > 0 && h > 0) area += w * h;
      }
      return area;
    }

    final halfW = math.min(width / 2, 0.5);
    final halfH = math.min(height / 2, 0.5);
    double clampX(double v) => v.clamp(halfW, 1 - halfW);
    double clampY(double v) => v.clamp(halfH, 1 - halfH);
    var best = (clampX(x), clampY(y));
    var bestCover = covered(best.$1, best.$2);
    if (bestCover <= overlap * width * height + 1e-9) return best;
    var bestDistance = 0.0;
    const steps = 10;
    for (var i = 0; i <= steps; i++) {
      for (var j = 0; j <= steps; j++) {
        final cx = clampX(i / steps);
        final cy = clampY(j / steps);
        final cover = covered(cx, cy);
        final distance = (cx - x) * (cx - x) + (cy - y) * (cy - y);
        // A clearly clearer spot wins; between similar ones, the nearer.
        if (cover < bestCover - 0.005 ||
            (cover <= bestCover + 0.005 && distance < bestDistance)) {
          best = (cx, cy);
          bestCover = cover;
          bestDistance = distance;
        }
      }
    }
    return best;
  }

  void setStickers(List<OutfitSticker> stickers) {
    _stickers = List.unmodifiable(stickers);
    notifyListeners();
  }

  /// Null clears the selection.
  void selectSticker(String? id) {
    if (_selectedStickerId == id) return;
    _selectedStickerId = id;
    notifyListeners();
  }

  void removeSelectedSticker() {
    final id = _selectedStickerId;
    if (id == null) return;
    _selectedStickerId = null;
    setStickers(_stickers.where((s) => s.id != id).toList());
  }

  void _addSticker(
    OutfitSticker Function(OutfitPlacement placement) create,
    double x,
    double y, {
    double width = stickerWidth,
    double overlap = 0,
  }) {
    // Square on the board, whose height is width / aspect.
    final height = width * AppSizes.outfitImageAspect;
    final (cx, cy) = _clearSpot(x, y, width, height, overlap: overlap);
    final sticker = create(
      OutfitPlacement(
        itemId: _ids.next(),
        x: cx,
        y: cy,
        width: width,
        height: height,
      ),
    );
    _selectedStickerId = sticker.id;
    setStickers([..._stickers, sticker]);
  }

  OutfitDraft buildDraft({
    required String name,
    required String fallbackName,
    String? notes,
    String? newPhotoPath,
    bool keepsPhoto = false,
  }) {
    final trimmed = name.trim();
    return OutfitDraft(
      name: trimmed.isEmpty ? fallbackName : trimmed,
      itemIds: itemIds,
      occasion: _occasion,
      seasons: Season.values.where(_seasons.contains).toList(),
      notes: notes,
      isFavorite: _isFavorite,
      layout: _layout.where((p) => _itemIds.contains(p.itemId)).toList(),
      background: _background,
      stickers: _stickers,
      newPhotoPath: newPhotoPath,
      keepsPhoto: keepsPhoto,
    );
  }

  OutfitSlot _slotOf(String id) {
    final item = _lookup(id);
    return item == null
        ? OutfitSlot.accessories
        : OutfitSlot.forCategory(item.category);
  }

  void _insertBySlot(String id) {
    if (_lookup(id) == null || contains(id)) return;
    final slotIndex = _slotOf(id).index;
    final position = _itemIds.indexWhere((e) => _slotOf(e).index > slotIndex);
    if (position < 0) {
      _itemIds.add(id);
    } else {
      _itemIds.insert(position, id);
    }
  }
}
