import 'package:flutter/foundation.dart';

import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/occasion.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/outfit_placement.dart';
import 'package:all_fits/data/models/outfit_slot.dart';
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/features/outfits/controllers/outfit_draft.dart';

typedef ItemLookup = ClothingItem? Function(String id);

/// Editing state for the outfit builder. Keeps the composition ordered by
/// slot (outerwear → top → bottom → shoes → accessories) as pieces are added,
/// while still allowing manual reordering.
class OutfitBuilderController extends ChangeNotifier {
  OutfitBuilderController({
    required this._lookup,
    Outfit? initial,
    List<String> initialItemIds = const [],
  }) : editingId = initial?.id,
       _occasion = initial?.occasion,
       _seasons = {...?initial?.seasons},
       _isFavorite = initial?.isFavorite ?? false,
       _layout = initial?.layout ?? const [] {
    final ids = initial?.itemIds ?? initialItemIds;
    if (initial != null) {
      // Keep the saved order; drop pieces that were deleted since.
      _itemIds.addAll(ids.where((id) => _lookup(id) != null));
    } else {
      ids.forEach(_insertBySlot);
    }
  }

  final ItemLookup _lookup;

  /// Id of the outfit being edited, or null when creating a new one.
  final String? editingId;

  final List<String> _itemIds = [];
  Occasion? _occasion;
  final Set<Season> _seasons;
  bool _isFavorite;
  List<OutfitPlacement> _layout;

  bool get isEditing => editingId != null;
  List<String> get itemIds => List.unmodifiable(_itemIds);
  bool get isEmpty => _itemIds.isEmpty;
  Occasion? get occasion => _occasion;
  Set<Season> get seasons => Set.unmodifiable(_seasons);
  bool get isFavorite => _isFavorite;

  /// Where pieces sit on the canvas; empty until the user moves one.
  List<OutfitPlacement> get layout => _layout;

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

  OutfitDraft buildDraft({
    required String name,
    required String fallbackName,
    String? notes,
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
