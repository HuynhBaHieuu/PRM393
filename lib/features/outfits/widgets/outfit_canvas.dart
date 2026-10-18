import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit_placement.dart';
import 'package:all_fits/features/outfits/outfit_layout.dart';

/// An outfit as a flat-lay: each piece cut out of its photo and placed on a
/// plain board. Pieces without a saved spot get a default one by category.
///
/// With [onChanged], pieces can be arranged: drag to move, pinch to resize
/// and turn. Touching a piece brings it to the front.
class OutfitCanvas extends StatefulWidget {
  const OutfitCanvas({
    super.key,
    required this.items,
    this.layout = const [],
    this.onChanged,
  });

  final List<ClothingItem> items;
  final List<OutfitPlacement> layout;

  /// Receives the whole layout, back to front, after every change.
  final ValueChanged<List<OutfitPlacement>>? onChanged;

  @override
  State<OutfitCanvas> createState() => _OutfitCanvasState();
}

class _OutfitCanvasState extends State<OutfitCanvas> {
  static const double _minWidth = 0.08;
  static const double _maxWidth = 1.2;

  List<OutfitPlacement> _placements = const [];
  Size _size = Size.zero;

  /// The piece being moved, from the first touch until every finger lifts.
  String? _activeId;
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
    final byId = {for (final item in widget.items) item.id: item};
    Widget canvas = LayoutBuilder(
      builder: (context, constraints) {
        final size = _size = constraints.biggest;
        return Stack(
          children: [
            for (final p in _placements)
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
                      border: p.itemId == _activeId
                          ? Border.all(color: palette.ink)
                          : null,
                    ),
                    child: ClothingImage(
                      item: byId[p.itemId]!,
                      cutout: true,
                      fit: BoxFit.contain,
                      // Fixed per canvas so resizing a piece doesn't reload it.
                      decodeWidth: size.width,
                    ),
                  ),
                ),
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
                  claims: (point) =>
                      _activeId != null || _pieceAt(point) != null,
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
      child: ColoredBox(color: palette.surface, child: canvas),
    );
  }

  /// The top-most piece whose (turned) box contains [point].
  String? _pieceAt(Offset point) {
    for (final p in _placements.reversed) {
      final center = Offset(p.x * _size.width, p.y * _size.height);
      final local = _rotate(point - center, -p.rotation);
      if (local.dx.abs() <= p.width * _size.width / 2 &&
          local.dy.abs() <= p.height * _size.height / 2) {
        return p.itemId;
      }
    }
    return null;
  }

  // Called again whenever a finger is added or lifted, with the gesture's
  // scale and rotation measured from that moment.
  void _onStart(ScaleStartDetails details) {
    final id = _activeId ?? _pieceAt(details.localFocalPoint);
    if (id == null) return;
    final index = _placements.indexWhere((p) => p.itemId == id);
    if (index < 0) return;
    final piece = _placements[index];
    setState(() => _activeId = id);
    _start = piece;
    _startFocal = details.focalPoint;
    _emit([..._placements]..removeAt(index)..add(piece));
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
    _emit([
      for (final p in _placements) p.itemId == updated.itemId ? updated : p,
    ]);
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
