import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit_board.dart';
import 'package:all_fits/data/models/outfit_placement.dart';
import 'package:all_fits/features/outfits/outfit_layout.dart';
import 'package:all_fits/features/outfits/widgets/board_decorations.dart';

/// An outfit as a flat-lay: each piece cut out of its photo and placed on a
/// coloured board, with stickers and hairstyles over the pieces. Pieces
/// without a saved spot get a default one by category.
///
/// With [onChanged], pieces and stickers can be arranged: drag to move, pinch
/// to resize and turn. Touching one brings it to the front.
class OutfitCanvas extends StatefulWidget {
  const OutfitCanvas({
    super.key,
    required this.items,
    this.layout = const [],
    this.background = BoardBackground.plain,
    this.stickers = const [],
    this.onChanged,
    this.onStickersChanged,
    this.selectedStickerId,
    this.onStickerSelected,
  });

  final List<ClothingItem> items;
  final List<OutfitPlacement> layout;
  final BoardBackground background;
  final List<OutfitSticker> stickers;

  /// Receives the whole layout, back to front, after every change.
  final ValueChanged<List<OutfitPlacement>>? onChanged;

  /// Receives every sticker, back to front, after one is moved.
  final ValueChanged<List<OutfitSticker>>? onStickersChanged;

  /// Outlined, so the user sees which sticker "Remove" acts on.
  final String? selectedStickerId;

  /// The sticker just touched, or null when a piece was.
  final ValueChanged<String?>? onStickerSelected;

  @override
  State<OutfitCanvas> createState() => _OutfitCanvasState();
}

class _OutfitCanvasState extends State<OutfitCanvas> {
  static const double _minWidth = 0.08;
  static const double _maxWidth = 1.2;

  List<OutfitPlacement> _placements = const [];
  List<OutfitSticker> _stickers = const [];
  Size _size = Size.zero;

  /// The piece or sticker being moved, from the first touch until every
  /// finger lifts.
  String? _activeId;
  bool _activeIsSticker = false;
  OutfitPlacement? _start;
  Offset _startFocal = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (widget.items.isEmpty) {
      return ColoredBox(
        color: palette.surfaceMuted,
        child: Center(
          child: Icon(Icons.style_outlined, color: palette.textTertiary),
        ),
      );
    }
    _placements = OutfitLayout.resolve(widget.items, widget.layout);
    _stickers = widget.stickers;
    final byId = {for (final item in widget.items) item.id: item};
    Widget placed(OutfitPlacement p, Size size, bool outlined, Widget child) =>
        Positioned(
          left: (p.x - p.width / 2) * size.width,
          top: (p.y - p.height / 2) * size.height,
          width: p.width * size.width,
          height: p.height * size.height,
          child: Transform.rotate(
            angle: p.rotation,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: outlined ? Border.all(color: palette.ink) : null,
              ),
              child: child,
            ),
          ),
        );
    Widget canvas = LayoutBuilder(
      builder: (context, constraints) {
        final size = _size = constraints.biggest;
        return Stack(
          children: [
            for (final p in _placements)
              placed(
                p,
                size,
                p.itemId == _activeId,
                ClothingImage(
                  item: byId[p.itemId]!,
                  cutout: true,
                  fit: BoxFit.contain,
                  // Fixed per canvas so resizing a piece doesn't reload it.
                  decodeWidth: size.width,
                ),
              ),
            for (final sticker in _stickers)
              placed(
                sticker.placement,
                size,
                sticker.id == _activeId ||
                    sticker.id == widget.selectedStickerId,
                StickerView(sticker: sticker),
              ),
          ],
        );
      },
    );
    if (widget.onChanged != null) {
      canvas = RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          _PieceGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<_PieceGestureRecognizer>(
                () => _PieceGestureRecognizer(
                  claims: (point) => _activeId != null || _hit(point) != null,
                ),
                (recognizer) => recognizer
                  ..onStart = _onStart
                  ..onUpdate = _onUpdate
                  ..onEnd = _onEnd,
              ),
        },
        child: canvas,
      );
    }
    return ClipRect(
      child: ColoredBox(
        color: widget.background.color ?? palette.surface,
        child: canvas,
      ),
    );
  }

  /// The top-most sticker, then piece, whose (turned) box contains [point],
  /// and whether it is a sticker.
  (String, bool)? _hit(Offset point) {
    bool contains(OutfitPlacement p) {
      final center = Offset(p.x * _size.width, p.y * _size.height);
      final local = _rotate(point - center, -p.rotation);
      return local.dx.abs() <= p.width * _size.width / 2 &&
          local.dy.abs() <= p.height * _size.height / 2;
    }

    if (widget.onStickersChanged != null) {
      for (final sticker in _stickers.reversed) {
        if (contains(sticker.placement)) return (sticker.id, true);
      }
    }
    for (final p in _placements.reversed) {
      if (contains(p)) return (p.itemId, false);
    }
    return null;
  }

  // Called again whenever a finger is added or lifted, with the gesture's
  // scale and rotation measured from that moment.
  void _onStart(ScaleStartDetails details) {
    final active = _activeId;
    final hit = active != null
        ? (active, _activeIsSticker)
        : _hit(details.localFocalPoint);
    if (hit == null) return;
    final (id, isSticker) = hit;
    setState(() {
      _activeId = id;
      _activeIsSticker = isSticker;
    });
    _startFocal = details.focalPoint;
    if (isSticker) {
      final index = _stickers.indexWhere((s) => s.id == id);
      if (index < 0) return;
      final sticker = _stickers[index];
      _start = sticker.placement;
      _emitStickers(
        [..._stickers]
          ..removeAt(index)
          ..add(sticker),
      );
    } else {
      final index = _placements.indexWhere((p) => p.itemId == id);
      if (index < 0) return;
      final piece = _placements[index];
      _start = piece;
      _emit(
        [..._placements]
          ..removeAt(index)
          ..add(piece),
      );
    }
    if (active == null) widget.onStickerSelected?.call(isSticker ? id : null);
  }

  void _onUpdate(ScaleUpdateDetails details) {
    final start = _start;
    if (start == null || _size.isEmpty) return;
    final moved = details.focalPoint - _startFocal;
    final width = (start.width * details.scale).clamp(_minWidth, _maxWidth);
    final updated = start.copyWith(
      x: (start.x + moved.dx / _size.width).clamp(0.0, 1.0),
      y: (start.y + moved.dy / _size.height).clamp(0.0, 1.0),
      width: width,
      height: start.height * width / start.width,
      rotation: start.rotation + details.rotation,
    );
    if (_activeIsSticker) {
      _emitStickers([
        for (final s in _stickers)
          s.id == updated.itemId ? s.copyWith(placement: updated) : s,
      ]);
    } else {
      _emit([
        for (final p in _placements) p.itemId == updated.itemId ? updated : p,
      ]);
    }
  }

  void _onEnd(ScaleEndDetails details) {
    if (details.pointerCount > 0) return;
    _start = null;
    setState(() => _activeId = null);
  }

  void _emit(List<OutfitPlacement> next) {
    // Kept locally too: several updates can arrive before the next build.
    _placements = next;
    widget.onChanged!(next);
  }

  void _emitStickers(List<OutfitSticker> next) {
    _stickers = next;
    widget.onStickersChanged!(next);
  }

  static Offset _rotate(Offset offset, double angle) {
    final cos = math.cos(angle), sin = math.sin(angle);
    return Offset(
      offset.dx * cos - offset.dy * sin,
      offset.dx * sin + offset.dy * cos,
    );
  }
}

/// Wins a touch that lands on a piece straight away, so moving a piece
/// never scrolls the page; touches on the empty board still scroll.
class _PieceGestureRecognizer extends ScaleGestureRecognizer {
  _PieceGestureRecognizer({required this.claims});

  final bool Function(Offset localPosition) claims;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    if (claims(event.localPosition)) {
      resolvePointer(event.pointer, GestureDisposition.accepted);
    }
  }
}
