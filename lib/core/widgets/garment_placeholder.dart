import 'package:flutter/material.dart';

import 'package:all_fits/app/theme/app_colors.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';

/// Illustrated stand-in for items without a usable photo: a flat silhouette
/// of the garment's category, filled with its color.
class GarmentPlaceholder extends StatelessWidget {
  const GarmentPlaceholder({
    super.key,
    required this.category,
    this.color,
    this.showBrokenImage = false,
  });

  final ClothingCategory category;
  final ClothingColor? color;

  /// Adds a small indicator when the stored photo could not be loaded.
  final bool showBrokenImage;

  static const double _silhouetteFraction = 0.62;
  static const double _badgeInset = 8;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ColoredBox(
      color: palette.surfaceMuted,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: FractionallySizedBox(
              widthFactor: _silhouetteFraction,
              heightFactor: _silhouetteFraction,
              child: AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(
                  painter: GarmentPainter(
                    category: category,
                    color: color,
                    outline: palette.textTertiary,
                  ),
                ),
              ),
            ),
          ),
          if (showBrokenImage)
            Positioned(
              right: _badgeInset,
              bottom: _badgeInset,
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 16,
                color: palette.textTertiary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Paints simple garment shapes on a 100×100 grid.
class GarmentPainter extends CustomPainter {
  GarmentPainter({
    required this.category,
    required this.color,
    required this.outline,
  });

  final ClothingCategory category;
  final ClothingColor? color;
  final Color outline;

  static const double _grid = 100;
  static const double _strokeWidth = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _grid;
    canvas.save();
    canvas.translate(
      (size.width - _grid * scale) / 2,
      (size.height - _grid * scale) / 2,
    );
    canvas.scale(scale);

    final shape = _shapeFor(category);
    final bounds = shape.body.getBounds();
    final fill = Paint()..style = PaintingStyle.fill;
    final itemColor = color;
    if (itemColor != null && itemColor.isMulti) {
      fill.shader = const LinearGradient(colors: ClothingColor.multiStops)
          .createShader(bounds);
    } else {
      fill.color = itemColor?.swatch ?? AppColors.neutralGarment;
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      // Divide by scale so the outline keeps a constant on-screen width.
      ..strokeWidth = _strokeWidth / scale
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = outline;

    canvas.drawPath(shape.body, fill);
    canvas.drawPath(shape.body, stroke);
    if (shape.details != null) canvas.drawPath(shape.details!, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(GarmentPainter oldDelegate) =>
      oldDelegate.category != category ||
      oldDelegate.color != color ||
      oldDelegate.outline != outline;

  static _GarmentShape _shapeFor(ClothingCategory category) {
    return switch (category) {
      ClothingCategory.tops => _tee(),
      ClothingCategory.outerwear => _jacket(),
      ClothingCategory.bottoms => _trousers(),
      ClothingCategory.dresses => _dress(),
      ClothingCategory.shoes => _sneaker(),
      ClothingCategory.bags => _tote(),
      ClothingCategory.accessories => _cap(),
      ClothingCategory.other => _hanger(),
    };
  }

  static _GarmentShape _tee() {
    final body = Path()
      ..moveTo(36, 14)
      ..quadraticBezierTo(50, 26, 64, 14)
      ..lineTo(84, 22)
      ..lineTo(96, 42)
      ..lineTo(80, 49)
      ..lineTo(75, 40)
      ..lineTo(75, 88)
      ..quadraticBezierTo(50, 91, 25, 88)
      ..lineTo(25, 40)
      ..lineTo(20, 49)
      ..lineTo(4, 42)
      ..lineTo(16, 22)
      ..close();
    return _GarmentShape(body);
  }

  static _GarmentShape _jacket() {
    final body = Path()
      ..moveTo(36, 12)
      ..lineTo(50, 30)
      ..lineTo(64, 12)
      ..lineTo(82, 18)
      ..lineTo(94, 82)
      ..lineTo(82, 85)
      ..lineTo(76, 46)
      ..lineTo(76, 90)
      ..lineTo(24, 90)
      ..lineTo(24, 46)
      ..lineTo(18, 85)
      ..lineTo(6, 82)
      ..lineTo(18, 18)
      ..close();
    final details = Path()
      ..moveTo(50, 30)
      ..lineTo(50, 90)
      ..moveTo(36, 12)
      ..lineTo(42, 34)
      ..moveTo(64, 12)
      ..lineTo(58, 34)
      ..moveTo(32, 62)
      ..lineTo(42, 62)
      ..moveTo(58, 62)
      ..lineTo(68, 62);
    return _GarmentShape(body, details);
  }

  static _GarmentShape _trousers() {
    final body = Path()
      ..moveTo(28, 8)
      ..lineTo(72, 8)
      ..lineTo(79, 92)
      ..lineTo(58, 92)
      ..lineTo(50, 34)
      ..lineTo(42, 92)
      ..lineTo(21, 92)
      ..close();
    final details = Path()
      ..moveTo(28.6, 16)
      ..lineTo(71.4, 16)
      ..moveTo(50, 16)
      ..lineTo(50, 30);
    return _GarmentShape(body, details);
  }

  static _GarmentShape _dress() {
    final body = Path()
      ..moveTo(37, 6)
      ..lineTo(43, 6)
      ..quadraticBezierTo(50, 16, 57, 6)
      ..lineTo(63, 6)
      ..lineTo(64, 30)
      ..lineTo(60, 38)
      ..lineTo(84, 90)
      ..quadraticBezierTo(50, 97, 16, 90)
      ..lineTo(40, 38)
      ..lineTo(36, 30)
      ..close();
    final details = Path()
      ..moveTo(38, 38)
      ..quadraticBezierTo(50, 41, 62, 38);
    return _GarmentShape(body, details);
  }

  static _GarmentShape _sneaker() {
    final body = Path()
      ..moveTo(8, 70)
      ..lineTo(10, 44)
      ..quadraticBezierTo(22, 38, 32, 46)
      ..lineTo(46, 54)
      ..quadraticBezierTo(72, 56, 88, 63)
      ..quadraticBezierTo(96, 67, 94, 76)
      ..lineTo(8, 76)
      ..close();
    final details = Path()
      ..moveTo(8, 69)
      ..lineTo(95, 69)
      ..moveTo(36, 50)
      ..lineTo(40, 46)
      ..moveTo(42, 53)
      ..lineTo(46, 49);
    return _GarmentShape(body, details);
  }

  static _GarmentShape _tote() {
    final body = Path()
      ..addRRect(RRect.fromLTRBR(16, 38, 84, 90, const Radius.circular(6)));
    final details = Path()
      ..moveTo(34, 38)
      ..cubicTo(34, 12, 66, 12, 66, 38);
    return _GarmentShape(body, details);
  }

  static _GarmentShape _cap() {
    final body = Path()
      ..moveTo(16, 64)
      ..cubicTo(14, 30, 70, 26, 76, 58)
      ..lineTo(94, 62)
      ..quadraticBezierTo(97, 69, 88, 69)
      ..lineTo(16, 69)
      ..close();
    final details = Path()
      ..moveTo(46, 34)
      ..quadraticBezierTo(44, 48, 46, 64);
    return _GarmentShape(body, details);
  }

  static _GarmentShape _hanger() {
    final body = Path()
      ..moveTo(50, 34)
      ..lineTo(90, 70)
      ..lineTo(10, 70)
      ..close();
    final details = Path()
      ..moveTo(50, 34)
      ..lineTo(50, 28)
      ..quadraticBezierTo(58, 26, 57, 18)
      ..quadraticBezierTo(55, 10, 47, 12)
      ..quadraticBezierTo(43, 14, 43, 18);
    return _GarmentShape(body, details);
  }
}

class _GarmentShape {
  const _GarmentShape(this.body, [this.details]);

  final Path body;
  final Path? details;
}
