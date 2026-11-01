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
    this.dressed = false,
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
  static const double hairWidth = 0.28;

  /// How far a duplicate lands from its original, as a fraction of the
  /// board.
  static const double duplicateOffset = 0.04;

  final ItemLookup _lookup;
  final IdGenerator _ids;

  /// Id of the outfit being edited, or null when creating a new one.
  final String? editingId;

  /// Pieces without a spot of their own stand head to toe down the middle
  /// (see [OutfitLayout.dressed]) instead of in the flat-lay, and are saved
  /// where they stand.
  final bool dressed;

  final List<String> _itemIds = [];
  Occasion? _occasion;
  final Set<Season> _seasons;
  bool _isFavorite;
  List<OutfitPlacement> _layout;
  BoardBackground _background;
  List<OutfitSticker> _stickers;
  String? _selectedId;

  bool get isEditing => editingId != null;
  List<String> get itemIds => List.unmodifiable(_itemIds);
  bool get isEmpty => _itemIds.isEmpty;
  Occasion? get occasion => _occasion;
  Set<Season> get seasons => Set.unmodifiable(_seasons);
  bool get isFavorite => _isFavorite;

  /// Where pieces sit on the canvas; unless [dressed], empty until the
  /// user moves one.
  List<OutfitPlacement> get layout => dressed ? _pieces() : _layout;

  BoardBackground get background => _background;

  /// Stickers and hairstyles on the board, back to front.
  List<OutfitSticker> get stickers => _stickers;

  /// The first hairstyle on the board, to carry into the Dressing Room.
  (Hairstyle, HairColor)? get hair {
    for (final sticker in _stickers) {
      if (sticker.hairstyle case final style?) {
        return (style, sticker.hairColor);
      }
    }
    return null;
  }

  /// The piece or sticker touched last, which the selection tools act on.
  String? get selectedId => _selectedId;

  /// The selected sticker, or null when nothing or a piece is selected.
  OutfitSticker? get selectedSticker {
    final id = _selectedId;
    return id == null ? null : _stickers.where((s) => s.id == id).firstOrNull;
  }

  /// Where the selected piece is, or null when nothing or a sticker is
  /// selected.
  OutfitPlacement? get selectedPiece {
    final id = _selectedId;
    if (id == null || !contains(id)) return null;
    return _pieces().where((p) => p.itemId == id).firstOrNull;
  }

  OutfitPlacement? get _selectedPlacement =>
      selectedSticker?.placement ?? selectedPiece;

  bool get selectedLocked => _selectedPlacement?.locked ?? false;

  bool contains(String id) => _itemIds.contains(id);

  List<String> idsInSlot(OutfitSlot slot) =>
      _itemIds.where((id) => _slotOf(id) == slot).toList();

  void addItem(String id) {
    if (_lookup(id) == null || contains(id)) return;
    _insertBySlot(id);
    notifyListeners();
  }

  void removeItem(String id) {
    if (!_itemIds.remove(id)) return;
    if (_selectedId == id) _selectedId = null;
    notifyListeners();
  }

  void toggleItem(String id) => contains(id) ? removeItem(id) : addItem(id);

  /// Makes [ids] the outfit's pieces, as picked in "Add clothes": pieces
  /// that stay keep their place and spot.
  void setItems(Iterable<String> ids) {
    final wanted = ids.toSet();
    _itemIds.removeWhere((id) => !wanted.contains(id));
    if (_selectedId case final id?
        when !contains(id) && selectedSticker == null) {
      _selectedId = null;
    }
    wanted.forEach(_insertBySlot);
    notifyListeners();
  }

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

  /// Adds a sticker picked in the Stickers sheet (its placement is ignored)
  /// and selects it: hair above the top, anything else in the clearest spot
  /// near the middle of the board.
  void addSticker(OutfitSticker picked) {
    final hair = picked.hairstyle;
    if (hair != null) {
      addHair(hair, picked.hairColor);
    } else {
      _addSticker(
        (p) => OutfitSticker(
          placement: p,
          art: picked.art,
          ink: picked.ink,
          emoji: picked.emoji,
        ),
        0.5,
        0.5,
      );
    }
  }

  /// Adds an emoji sticker in the clearest spot near the middle of the
  /// board and selects it.
  void addEmojiSticker(String emoji) =>
      _addSticker((p) => OutfitSticker(placement: p, emoji: emoji), 0.5, 0.5);

  /// Adds a hairstyle as if worn and selects it: a head's width above the
  /// highest top, with a little neck between the chin and the collar.
  /// Without a top it goes near the top of the board.
  void addHair(Hairstyle style, HairColor color) {
    OutfitSticker create(OutfitPlacement p) =>
        OutfitSticker(placement: p, hairstyle: style, hairColor: color);
    final uppers = _pieces()
        .where((p) => _wornAbove.contains(_slotOf(p.itemId)))
        .toList();
    if (uppers.isEmpty) {
      _addSticker(create, 0.5, 0.12, width: hairWidth, overlap: 0.3);
      return;
    }
    double topOf(OutfitPlacement p) => p.y - p.height / 2;
    final collar = uppers.map(topOf).reduce(math.min);
    // Pieces starting at the collar, e.g. a jacket beside a top.
    final shoulders = uppers.where((p) => topOf(p) <= collar + 0.03).toList();
    final x =
        shoulders.map((p) => p.x).reduce((a, b) => a + b) / shoulders.length;
    final width = (shoulders.map((p) => p.width).reduce(math.max) * 0.55).clamp(
      0.18,
      0.4,
    );
    final height = width * AppSizes.outfitImageAspect;
    // The chin is this far below the middle of the hair's square.
    final chin = (Hairstyle.face.bottom - 0.5) * height;
    _addSticker(create, x, collar - _neck - chin, width: width, overlap: 1);
  }

  /// The gap between the chin and the collar, as a fraction of the board.
  static const double _neck = 0.02;

  /// Slots the hair sits above.
  static const Set<OutfitSlot> _wornAbove = {
    OutfitSlot.top,
    OutfitSlot.dress,
    OutfitSlot.outerwear,
  };

  /// Where the pieces are on the board right now.
  List<OutfitPlacement> _pieces() => OutfitLayout.resolve(
    [for (final id in _itemIds) ?_lookup(id)],
    _layout,
    dressed: dressed,
  );

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

  /// Selects a piece or sticker; null clears the selection.
  void select(String? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  /// Takes the selected sticker off the board, or the selected piece out
  /// of the outfit.
  void deleteSelected() {
    final id = _selectedId;
    if (id == null) return;
    if (contains(id)) {
      removeItem(id);
      return;
    }
    _selectedId = null;
    setStickers(_stickers.where((s) => s.id != id).toList());
  }

  /// Copies the selected sticker a little down and to the right, and
  /// selects the copy. Pieces can't be in an outfit twice.
  void duplicateSelected() {
    final sticker = selectedSticker;
    if (sticker == null) return;
    final p = sticker.placement;
    final copy = sticker.copyWith(
      placement: p.copyWith(
        itemId: _ids.next(),
        x: (p.x + duplicateOffset).clamp(0.0, 1.0),
        y: (p.y + duplicateOffset).clamp(0.0, 1.0),
        locked: false,
      ),
    );
    _selectedId = copy.id;
    setStickers([..._stickers, copy]);
  }

  void flipSelected() =>
      _changeSelected((p) => p.copyWith(flipped: !p.flipped));

  void toggleLockSelected() =>
      _changeSelected((p) => p.copyWith(locked: !p.locked));

  /// Whether the selected sticker sits under the pieces.
  bool get selectedBehind => selectedSticker?.behind ?? false;

  /// Puts the selected sticker under every piece, or the selected piece
  /// under the other pieces.
  void sendSelectedToBack() {
    final id = _selectedId;
    if (id == null) return;
    final sticker = selectedSticker;
    if (sticker != null) {
      setStickers([
        sticker.copyWith(behind: true),
        for (final s in _stickers)
          if (s.id != id) s,
      ]);
    } else if (contains(id)) {
      final pieces = _pieces();
      setLayout([
        ...pieces.where((p) => p.itemId == id),
        ...pieces.where((p) => p.itemId != id),
      ]);
    }
  }

  /// Puts the selected sticker back over the pieces, on top.
  void bringSelectedToFront() {
    final sticker = selectedSticker;
    if (sticker == null) return;
    setStickers([
      for (final s in _stickers)
        if (s.id != sticker.id) s,
      sticker.copyWith(behind: false),
    ]);
  }

  void _changeSelected(OutfitPlacement Function(OutfitPlacement p) change) {
    final id = _selectedId;
    if (id == null) return;
    final sticker = selectedSticker;
    if (sticker != null) {
      setStickers([
        for (final s in _stickers)
          s.id == id ? s.copyWith(placement: change(s.placement)) : s,
      ]);
    } else if (contains(id)) {
      setLayout([for (final p in _pieces()) p.itemId == id ? change(p) : p]);
    }
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
    _selectedId = sticker.id;
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
      layout: layout.where((p) => _itemIds.contains(p.itemId)).toList(),
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
