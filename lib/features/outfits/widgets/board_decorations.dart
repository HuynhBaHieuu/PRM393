import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/outfit_board.dart';

/// What a sticker shows: its emoji, or a head with its hairstyle. Fills its
/// box, kept square.
class StickerView extends StatelessWidget {
  const StickerView({super.key, required this.sticker});

  final OutfitSticker sticker;

  @override
  Widget build(BuildContext context) {
    final hairstyle = sticker.hairstyle;
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: hairstyle != null
            ? HairView(style: hairstyle, color: sticker.hairColor)
            : FittedBox(
                child: Text(
                  sticker.emoji ?? '',
                  style: const TextStyle(fontSize: 64, height: 1.1),
                ),
              ),
      ),
    );
  }
}

class HairView extends StatelessWidget {
  const HairView({super.key, required this.style, required this.color});

  final Hairstyle style;
  final HairColor color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: HairPainter(style: style, color: color.color),
    size: Size.infinite,
  );
}

/// A plain mannequin head wearing [style], drawn in a square.
class HairPainter extends CustomPainter {
  const HairPainter({required this.style, required this.color});

  /// Same neutral as the mannequin behind the swipe rows.
  static const Color head = Color(0xFFE6DDD3);

  final Hairstyle style;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Every measure is a fraction of the side.
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s);
    final hair = Paint()..color = color;
    final skin = Paint()..color = head;
    Rect box(double l, double t, double r, double b) =>
        Rect.fromLTRB(l, t, r, b);

    // Hair behind the head.
    switch (style) {
      case Hairstyle.long:
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            box(0.25, 0.18, 0.75, 0.94),
            topLeft: const Radius.circular(0.25),
            topRight: const Radius.circular(0.25),
            bottomLeft: const Radius.circular(0.06),
            bottomRight: const Radius.circular(0.06),
          ),
          hair,
        );
      case Hairstyle.bob:
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            box(0.27, 0.18, 0.73, 0.7),
            topLeft: const Radius.circular(0.23),
            topRight: const Radius.circular(0.23),
            bottomLeft: const Radius.circular(0.04),
            bottomRight: const Radius.circular(0.04),
          ),
          hair,
        );
      case Hairstyle.curly:
        canvas.drawOval(box(0.2, 0.12, 0.8, 0.68), hair);
        for (final (x, y) in const [
          (0.24, 0.24), (0.36, 0.13), (0.5, 0.1), (0.64, 0.13), //
          (0.76, 0.24), (0.8, 0.4), (0.78, 0.56), (0.22, 0.56), (0.2, 0.4),
        ]) {
          canvas.drawCircle(Offset(x, y), 0.1, hair);
        }
      case Hairstyle.ponytail:
        canvas.save();
        canvas.translate(0.72, 0.42);
        canvas.rotate(-0.35);
        canvas.drawOval(box(-0.08, -0.04, 0.08, 0.42), hair);
        canvas.restore();
      case Hairstyle.bun:
        canvas.drawCircle(const Offset(0.5, 0.13), 0.11, hair);
      case Hairstyle.short:
        break;
    }

    // Neck and face.
    canvas.drawRect(box(0.44, 0.6, 0.56, 0.86), skin);
    canvas.drawOval(box(0.33, 0.26, 0.67, 0.7), skin);

    // Hair over the top of the head.
    canvas.save();
    canvas.clipRect(box(0, 0, 1, style == Hairstyle.short ? 0.38 : 0.36));
    canvas.drawOval(box(0.29, 0.17, 0.71, 0.6), hair);
    canvas.restore();
    switch (style) {
      case Hairstyle.short:
        // Sideburns.
        canvas.drawRect(box(0.31, 0.3, 0.355, 0.45), hair);
        canvas.drawRect(box(0.645, 0.3, 0.69, 0.45), hair);
      case Hairstyle.bob || Hairstyle.long:
        // Locks framing the face.
        canvas.drawRect(box(0.29, 0.3, 0.36, 0.62), hair);
        canvas.drawRect(box(0.64, 0.3, 0.71, 0.62), hair);
      case Hairstyle.curly:
        for (final x in const [0.36, 0.45, 0.55, 0.64]) {
          canvas.drawCircle(Offset(x, 0.3), 0.065, hair);
        }
      case Hairstyle.ponytail:
        // The hair tie.
        canvas.drawCircle(
          const Offset(0.7, 0.4),
          0.035,
          Paint()..color = Color.lerp(color, Colors.black, 0.35)!,
        );
      case Hairstyle.bun:
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(HairPainter old) =>
      old.style != style || old.color != color;
}

/// Grid of emoji stickers; resolves to the picked one, or null.
Future<String?> showStickerPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(title: 'Stickers'),
          GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.lg,
            ),
            children: [
              for (final emoji in boardStickerEmoji)
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => Navigator.of(sheetContext).pop(emoji),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 30)),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Hairstyles in a chosen colour; resolves to the picked pair, or null.
Future<(Hairstyle, HairColor)?> showHairPicker(BuildContext context) {
  return showModalBottomSheet<(Hairstyle, HairColor)>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _HairPicker(),
  );
}

class _HairPicker extends StatefulWidget {
  const _HairPicker();

  @override
  State<_HairPicker> createState() => _HairPickerState();
}

class _HairPickerState extends State<_HairPicker> {
  HairColor _color = HairColor.brown;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(title: 'Hairstyle'),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              children: [
                for (final color in HairColor.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: BoardColorDot(
                      color: color.color,
                      label: color.label,
                      selected: color == _color,
                      onTap: () => setState(() => _color = color),
                    ),
                  ),
              ],
            ),
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              for (final style in Hairstyle.values)
                Material(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop((style, _color)),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Column(
                        children: [
                          Expanded(
                            child: HairView(style: style, color: _color),
                          ),
                          Text(style.label, style: context.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Round colour choice with a ring when [selected].
class BoardColorDot extends StatelessWidget {
  const BoardColorDot({
    super.key,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const double size = 36;

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: size / 2 + 4,
          child: Container(
            width: size + 8,
            height: size + 8,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? palette.ink : Colors.transparent,
                width: 2,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: palette.border),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
