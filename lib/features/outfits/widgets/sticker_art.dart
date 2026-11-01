import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:all_fits/data/models/outfit_board.dart';

/// Hair only, with the face left open, drawn in a square: it sits on the
/// Dressing Room mannequin's head, or over the collar of a collage. Each
/// style is a silhouette with tapered locks, shaded for volume, with a sheen
/// on the crown and strands that follow how the hair falls.
class HairPainter extends CustomPainter {
  const HairPainter({required this.style, required this.color});

  final Hairstyle style;
  final Color color;

  /// Where the face sits in the square, for lining the hair up with a head.
  static const Rect face = Hairstyle.face;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s);
    canvas.saveLayer(const Rect.fromLTRB(-0.1, -0.1, 1.1, 1.1), Paint());

    final look = _HairLook.of(style);
    final hair = Paint()..color = color;
    // Clipped sides show the skin through, so they read lighter.
    // Fading out towards the ears, as a fade cut does.
    if (look.fade case final fade?) {
      canvas.drawPath(
        fade,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.8),
              color.withValues(alpha: 0.55),
              color.withValues(alpha: 0.18),
            ],
            stops: const [0.2, 0.32, 0.46],
          ).createShader(const Rect.fromLTRB(0, 0, 1, 1)),
      );
    }
    canvas.drawPath(look.outline, hair);
    _openFace(canvas, look.hairline);
    if (look.fringe case final fringe?) canvas.drawPath(fringe, hair);
    _shade(canvas, look);

    canvas.restore();
    canvas.restore();
  }

  /// Clears the face below an arched hairline, and the neck below it. Two
  /// separate draws: as one path, the overlap could cancel out.
  static void _openFace(Canvas canvas, double hairline) {
    final clear = Paint()..blendMode = BlendMode.clear;
    final below = Path()
      ..moveTo(-0.1, hairline + 0.08)
      ..lineTo(0.3, hairline + 0.06)
      ..quadraticBezierTo(0.5, hairline - 0.05, 0.7, hairline + 0.06)
      ..lineTo(1.1, hairline + 0.08)
      ..lineTo(1.1, 1.1)
      ..lineTo(-0.1, 1.1)
      ..close();
    canvas.drawPath(
      Path.combine(PathOperation.intersect, Path()..addOval(face), below),
      clear,
    );
    canvas.drawRect(const Rect.fromLTRB(0.39, 0.5, 0.61, 1.05), clear);
  }

  /// Shading, sheen and strands, kept on the hair.
  void _shade(Canvas canvas, _HairLook look) {
    const unit = Rect.fromLTRB(0, 0, 1, 1);
    const all = Rect.fromLTRB(-0.1, -0.1, 1.1, 1.1);
    final shadow = Color.lerp(color, Colors.black, 0.6)!;
    final shine = Color.lerp(color, Colors.white, 0.55)!;
    Paint atop() => Paint()..blendMode = BlendMode.srcATop;
    Paint stroke(Color c, double width) => atop()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    // Volume: darker towards the edges and the ends.
    canvas.drawRect(
      all,
      atop()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.45),
          radius: 0.72,
          colors: [
            shadow.withValues(alpha: 0),
            shadow.withValues(alpha: 0),
            shadow.withValues(alpha: 0.55),
          ],
          stops: const [0, 0.42, 1],
        ).createShader(unit),
    );
    // The back of the hair, seen beside the neck.
    canvas.drawRect(
      all,
      atop()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.45),
          radius: 0.2,
          colors: [shadow.withValues(alpha: 0.6), shadow.withValues(alpha: 0)],
        ).createShader(unit),
    );
    if (look.part case final part?) {
      canvas.drawLine(
        part,
        part.translate(0, 0.1),
        stroke(shadow.withValues(alpha: 0.6), 0.008),
      );
    }

    final random = math.Random(style.index + 7);
    double between(double a, double b) => a + random.nextDouble() * (b - a);
    Paint strand(bool light) => stroke(
      light
          ? shine.withValues(alpha: between(0.12, 0.3))
          : shadow.withValues(alpha: between(0.2, 0.4)),
      light ? between(0.003, 0.006) : between(0.004, 0.008),
    );

    // Stubble on clipped sides.
    if (look.fade case final fade?) {
      canvas.save();
      canvas.clipPath(
        Path.combine(PathOperation.difference, fade, look.outline),
      );
      for (var i = 0; i < 160; i++) {
        canvas.drawCircle(
          Offset(between(0.28, 0.72), between(0.15, 0.5)),
          between(0.0015, 0.003),
          atop()..color = shadow.withValues(alpha: between(0.3, 0.6)),
        );
      }
      canvas.restore();
    }

    switch (look.texture) {
      case _Texture.curls:
        final area = look.textureArea;
        for (var i = 0; i < 90; i++) {
          final center = Offset(
            between(area.left, area.right),
            between(area.top, area.bottom),
          );
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: between(0.012, 0.028)),
            between(0, math.pi * 2),
            between(math.pi * 0.9, math.pi * 1.6),
            false,
            strand(i.isEven),
          );
        }
        // Curls are matte: no sheen.
        return;
      case _Texture.buzz:
        final area = look.textureArea;
        for (var i = 0; i < 220; i++) {
          canvas.drawCircle(
            Offset(
              between(area.left, area.right),
              between(area.top, area.bottom),
            ),
            between(0.002, 0.004),
            atop()
              ..color = (i.isEven ? shine : shadow).withValues(
                alpha: between(0.2, 0.45),
              ),
          );
        }
      case _Texture.strands:
        for (final (start, c1, c2, end) in look.strands(random)) {
          // A dark strand with a light one beside it reads as a glossy lock.
          for (final light in const [false, true]) {
            final nudge = light ? 0.006 : 0.0;
            canvas.drawPath(
              Path()
                ..moveTo(start.dx + nudge, start.dy)
                ..cubicTo(
                  c1.dx + nudge,
                  c1.dy,
                  c2.dx + nudge,
                  c2.dy,
                  end.dx,
                  end.dy,
                ),
              strand(light),
            );
          }
        }
    }

    // Sheen on the crown: soft, built from a few faint strokes.
    for (final (width, alpha) in const [
      (0.07, 0.07),
      (0.045, 0.1),
      (0.022, 0.16),
    ]) {
      canvas.drawArc(
        look.sheen,
        math.pi * 1.1,
        math.pi * 0.38,
        false,
        stroke(shine.withValues(alpha: alpha), width),
      );
    }
  }

  @override
  bool shouldRepaint(HairPainter old) =>
      old.style != style || old.color != color;
}

enum _Texture { strands, curls, buzz }

/// One hairstyle's shapes in the unit square.
class _HairLook {
  const _HairLook({
    required this.outline,
    this.fade,
    this.fringe,
    this.hairline = 0.3,
    this.part,
    this.crown = const Offset(0.5, 0.11),
    this.ends = const [],
    this.wave = 0,
    this.texture = _Texture.strands,
    this.textureArea = const Rect.fromLTRB(0.2, 0.08, 0.8, 0.9),
    this.sheen = const Rect.fromLTRB(0.31, 0.12, 0.69, 0.55),
    this.flows,
  });

  /// The hair, before the face is opened.
  final Path outline;

  /// Sides clipped short, e.g. under an undercut, drawn faint with stubble
  /// where [outline] leaves them showing.
  final Path? fade;

  /// Hair that falls over the forehead, drawn after the face is opened.
  final Path? fringe;

  /// Where the forehead starts, at its highest.
  final double hairline;

  /// A parting, drawn as a short line down from here.
  final Offset? part;

  /// Where strands start: the parting or the crown.
  final Offset crown;

  /// Lock tips the strands run to, in order round the hair.
  final List<Offset> ends;

  /// How far strands swing from side to side, for waves.
  final double wave;

  final _Texture texture;

  /// Where curls or stubble are drawn.
  final Rect textureArea;

  /// The oval whose upper left arc catches the light.
  final Rect sheen;

  /// Strands drawn as given instead of from [crown] to [ends], e.g. hair
  /// swept up or pulled back.
  final List<(Offset, Offset, Offset, Offset)>? flows;

  /// Strands as (start, control, control, end) curves.
  List<(Offset, Offset, Offset, Offset)> strands(math.Random random) {
    if (flows case final flows?) return flows;
    if (ends.length < 2) return const [];
    double jitter(double by) => (random.nextDouble() - 0.5) * by;
    final strands = <(Offset, Offset, Offset, Offset)>[];
    for (var i = 0; i < (ends.length - 1) * 4; i++) {
      final end = Offset.lerp(
        ends[i ~/ 4],
        ends[i ~/ 4 + 1],
        random.nextDouble(),
      )!;
      final start = crown.translate(jitter(0.08), jitter(0.02));
      final swing = i.isEven ? wave : -wave;
      strands.add((
        start,
        // Out over the skull first, then down to the tip.
        Offset(
          end.dx + (end.dx - 0.5) * 0.55,
          start.dy + (end.dy - start.dy) * 0.3,
        ),
        Offset(end.dx + swing, start.dy + (end.dy - start.dy) * 0.72),
        end,
      ));
    }
    return strands;
  }

  static _HairLook of(Hairstyle style) => switch (style) {
    Hairstyle.short => _HairLook(
      outline:
          (_Pen(0.335, 0.5)
                ..curve(0.3, 0.42, 0.305, 0.33)
                ..cubic(0.31, 0.18, 0.4, 0.105, 0.52, 0.105)
                ..cubic(0.64, 0.105, 0.715, 0.19, 0.7, 0.33)
                ..curve(0.695, 0.43, 0.665, 0.5)
                ..line(0.64, 0.4)
                ..line(0.36, 0.4))
              .close(),
      fringe:
          (_Pen(0.69, 0.26)
                ..curve(0.56, 0.19, 0.4, 0.25)
                ..curve(0.345, 0.28, 0.335, 0.38)
                ..locks(const [
                  Offset(0.45, 0.365),
                  Offset(0.58, 0.345),
                  Offset(0.665, 0.36),
                ]))
              .close(),
      hairline: 0.31,
      crown: const Offset(0.62, 0.12),
      ends: const [
        Offset(0.335, 0.5),
        Offset(0.335, 0.38),
        Offset(0.45, 0.365),
        Offset(0.58, 0.345),
        Offset(0.665, 0.5),
      ],
    ),
    Hairstyle.bob => _HairLook(
      outline:
          (_Pen(0.5, 0.1)
                ..cubic(0.32, 0.1, 0.245, 0.21, 0.25, 0.36)
                ..cubic(0.252, 0.5, 0.235, 0.62, 0.235, 0.7)
                ..curve(0.24, 0.75, 0.29, 0.76)
                ..locks(const [
                  Offset(0.335, 0.765),
                  Offset(0.38, 0.74),
                ], depth: 0.045)
                ..line(0.385, 0.6)
                ..line(0.615, 0.6)
                ..line(0.62, 0.74)
                ..locks(const [
                  Offset(0.665, 0.765),
                  Offset(0.71, 0.76),
                ], depth: 0.045)
                ..curve(0.76, 0.75, 0.765, 0.7)
                ..cubic(0.765, 0.62, 0.748, 0.5, 0.75, 0.36)
                ..cubic(0.755, 0.21, 0.68, 0.1, 0.5, 0.1))
              .close(),
      part: const Offset(0.5, 0.11),
      ends: const [
        Offset(0.25, 0.7),
        Offset(0.3, 0.755),
        Offset(0.38, 0.735),
        Offset(0.62, 0.735),
        Offset(0.7, 0.755),
        Offset(0.75, 0.7),
      ],
    ),
    Hairstyle.long => _HairLook(
      outline: _long(0.95, wavy: false),
      part: const Offset(0.5, 0.11),
      ends: const [
        Offset(0.215, 0.88),
        Offset(0.27, 0.965),
        Offset(0.36, 0.9),
        Offset(0.64, 0.9),
        Offset(0.73, 0.965),
        Offset(0.785, 0.88),
      ],
    ),
    Hairstyle.quiff => _HairLook(
      outline:
          (_Pen(0.335, 0.45)
                ..curve(0.305, 0.38, 0.31, 0.3)
                ..cubic(0.305, 0.2, 0.33, 0.13, 0.4, 0.1)
                ..cubic(0.47, 0.045, 0.6, 0.03, 0.69, 0.075)
                ..cubic(0.745, 0.1, 0.75, 0.16, 0.71, 0.19)
                ..curve(0.7, 0.27, 0.69, 0.33)
                ..curve(0.685, 0.4, 0.665, 0.45)
                ..line(0.64, 0.38)
                ..line(0.36, 0.38))
              .close(),
      hairline: 0.29,
      sheen: const Rect.fromLTRB(0.33, 0.06, 0.73, 0.5),
      flows: [
        // Swept up from the forehead and back over the crown...
        for (var i = 0; i < 12; i++)
          (
            Offset(0.34 + i * 0.027, 0.32 - (i % 3) * 0.01),
            Offset(0.33 + i * 0.022, 0.16),
            Offset(0.45 + i * 0.02, 0.06 + (i % 4) * 0.01),
            Offset(0.6 + i * 0.012, 0.08 + i * 0.006),
          ),
        // ...and up from the temple.
        for (var i = 0; i < 6; i++)
          (
            Offset(0.32 + i * 0.004, 0.42 - i * 0.03),
            Offset(0.31, 0.3 - i * 0.02),
            Offset(0.34, 0.2 - i * 0.015),
            Offset(0.42 + i * 0.02, 0.12 - i * 0.008),
          ),
      ],
    ),
    Hairstyle.buzz => _HairLook(
      outline:
          (_Pen(0.335, 0.43)
                ..curve(0.315, 0.36, 0.32, 0.3)
                ..cubic(0.325, 0.19, 0.4, 0.135, 0.5, 0.135)
                ..cubic(0.6, 0.135, 0.675, 0.19, 0.68, 0.3)
                ..curve(0.685, 0.36, 0.665, 0.43)
                ..line(0.64, 0.37)
                ..line(0.36, 0.37))
              .close(),
      hairline: 0.29,
      texture: _Texture.buzz,
      textureArea: const Rect.fromLTRB(0.31, 0.13, 0.69, 0.44),
    ),
    Hairstyle.bangs => _HairLook(
      outline:
          (_Pen(0.5, 0.105)
                ..cubic(0.32, 0.105, 0.25, 0.21, 0.252, 0.37)
                ..cubic(0.255, 0.55, 0.24, 0.7, 0.235, 0.84)
                ..curve(0.235, 0.87, 0.26, 0.88)
                ..locks(const [
                  Offset(0.3, 0.885),
                  Offset(0.34, 0.875),
                  Offset(0.37, 0.85),
                ], depth: 0.06)
                ..line(0.375, 0.64)
                ..line(0.625, 0.64)
                ..line(0.63, 0.85)
                ..locks(const [
                  Offset(0.66, 0.875),
                  Offset(0.7, 0.885),
                  Offset(0.74, 0.88),
                ], depth: 0.06)
                ..curve(0.765, 0.87, 0.765, 0.84)
                ..cubic(0.76, 0.7, 0.745, 0.55, 0.748, 0.37)
                ..cubic(0.75, 0.21, 0.68, 0.105, 0.5, 0.105))
              .close(),
      fringe:
          (_Pen(0.33, 0.36)
                ..cubic(0.32, 0.24, 0.4, 0.18, 0.5, 0.18)
                ..cubic(0.6, 0.18, 0.68, 0.24, 0.67, 0.36)
                ..locks(const [
                  Offset(0.61, 0.4),
                  Offset(0.555, 0.405),
                  Offset(0.5, 0.41),
                  Offset(0.445, 0.405),
                  Offset(0.39, 0.4),
                  Offset(0.335, 0.37),
                ], depth: 0.025))
              .close(),
      ends: const [
        Offset(0.25, 0.84),
        Offset(0.34, 0.875),
        Offset(0.39, 0.4),
        Offset(0.61, 0.4),
        Offset(0.66, 0.875),
        Offset(0.75, 0.84),
      ],
    ),
    Hairstyle.lob => _HairLook(
      outline:
          (_Pen(0.42, 0.11)
                ..cubic(0.31, 0.12, 0.265, 0.22, 0.272, 0.37)
                ..cubic(0.278, 0.52, 0.262, 0.66, 0.235, 0.75)
                ..curve(0.2, 0.8, 0.215, 0.815)
                ..locks(const [
                  Offset(0.27, 0.8),
                  Offset(0.32, 0.815),
                  Offset(0.36, 0.78),
                ], depth: 0.055)
                ..line(0.37, 0.63)
                ..line(0.63, 0.63)
                ..line(0.64, 0.78)
                ..locks(const [
                  Offset(0.68, 0.815),
                  Offset(0.73, 0.8),
                  Offset(0.785, 0.815),
                ], depth: 0.055)
                ..curve(0.8, 0.8, 0.765, 0.75)
                ..cubic(0.74, 0.65, 0.73, 0.52, 0.735, 0.37)
                ..cubic(0.74, 0.19, 0.62, 0.1, 0.42, 0.11))
              .close(),
      // Swept from the side parting across the forehead.
      fringe:
          (_Pen(0.42, 0.15)
                ..cubic(0.5, 0.17, 0.62, 0.22, 0.665, 0.33)
                ..curve(0.68, 0.38, 0.675, 0.44)
                ..curve(0.64, 0.34, 0.56, 0.3)
                ..curve(0.47, 0.27, 0.4, 0.3))
              .close(),
      part: const Offset(0.42, 0.115),
      crown: const Offset(0.42, 0.115),
      ends: const [
        Offset(0.215, 0.815),
        Offset(0.36, 0.78),
        Offset(0.675, 0.44),
        Offset(0.64, 0.78),
        Offset(0.785, 0.815),
      ],
    ),
    Hairstyle.wavy => _HairLook(
      outline: _long(0.96, wavy: true),
      part: const Offset(0.47, 0.11),
      crown: const Offset(0.47, 0.11),
      wave: 0.035,
      ends: const [
        Offset(0.235, 0.89),
        Offset(0.27, 0.975),
        Offset(0.36, 0.91),
        Offset(0.64, 0.91),
        Offset(0.73, 0.975),
        Offset(0.765, 0.89),
      ],
    ),
    Hairstyle.curly => _HairLook(
      outline: _curls(
        center: const Offset(0.5, 0.44),
        radiusX: 0.27,
        radiusY: 0.33,
        count: 18,
        size: 0.065,
        extra: const [
          Offset(0.25, 0.72),
          Offset(0.31, 0.79),
          Offset(0.36, 0.74),
          Offset(0.64, 0.74),
          Offset(0.69, 0.79),
          Offset(0.75, 0.72),
        ],
      ),
      hairline: 0.31,
      texture: _Texture.curls,
      textureArea: const Rect.fromLTRB(0.17, 0.06, 0.83, 0.84),
    ),
    Hairstyle.afro => _HairLook(
      outline: _curls(
        center: const Offset(0.5, 0.37),
        radiusX: 0.3,
        radiusY: 0.3,
        count: 26,
        size: 0.042,
        full: true,
      ),
      texture: _Texture.curls,
      textureArea: const Rect.fromLTRB(0.17, 0.04, 0.83, 0.7),
    ),
    Hairstyle.ponytail => _HairLook(
      outline: _sleek()
        ..addPath(
          (_Pen(0.62, 0.15)
                ..cubic(0.78, 0.12, 0.86, 0.3, 0.8, 0.52)
                ..cubic(0.77, 0.66, 0.76, 0.76, 0.72, 0.9)
                ..cubic(0.73, 0.76, 0.72, 0.62, 0.71, 0.5)
                ..cubic(0.7, 0.38, 0.69, 0.26, 0.64, 0.21))
              .close(),
          Offset.zero,
        ),
      sheen: const Rect.fromLTRB(0.32, 0.13, 0.68, 0.5),
      flows: [
        // Pulled back to the tie...
        for (var i = 0; i < 9; i++)
          (
            Offset(0.34 + i * 0.035, 0.31 - (i - 4).abs() * 0.008),
            Offset(0.34 + i * 0.03, 0.18),
            Offset(0.5 + i * 0.012, 0.13),
            const Offset(0.65, 0.16),
          ),
        // ...and down the tail.
        for (var i = 0; i < 7; i++)
          (
            const Offset(0.66, 0.17),
            Offset(0.8 + i * 0.006, 0.24),
            Offset(0.79 - i * 0.01, 0.55),
            Offset(0.72 + i * 0.006, 0.86 - i * 0.04),
          ),
      ],
    ),
    Hairstyle.bun => _HairLook(
      outline: _sleek()
        ..addOval(
          Rect.fromCircle(center: const Offset(0.5, 0.09), radius: 0.085),
        ),
      sheen: const Rect.fromLTRB(0.32, 0.13, 0.68, 0.5),
      flows: [
        // Pulled up to the bun...
        for (var i = 0; i < 9; i++)
          (
            Offset(0.34 + i * 0.035, 0.31 - (i - 4).abs() * 0.008),
            Offset(0.34 + i * 0.03, 0.2),
            Offset(0.44 + i * 0.015, 0.15),
            Offset(0.47 + i * 0.008, 0.15),
          ),
        // ...and twisted round in it.
        for (var i = 0; i < 5; i++)
          (
            Offset(0.43 + i * 0.01, 0.13),
            Offset(0.4 + i * 0.02, 0.03),
            Offset(0.6 - i * 0.02, 0.03),
            Offset(0.57 - i * 0.01, 0.13),
          ),
      ],
    ),
    Hairstyle.undercut => _HairLook(
      outline:
          (_Pen(0.31, 0.31)
                ..cubic(0.295, 0.18, 0.37, 0.08, 0.5, 0.075)
                ..cubic(0.64, 0.07, 0.73, 0.13, 0.72, 0.24)
                ..curve(0.715, 0.29, 0.695, 0.31)
                ..line(0.5, 0.29))
              .close(),
      fade: _sleek(),
      // The long top swept over to one side, hanging over the brow.
      fringe:
          (_Pen(0.37, 0.2)
                ..cubic(0.46, 0.2, 0.6, 0.23, 0.68, 0.3)
                ..curve(0.7, 0.34, 0.675, 0.375)
                ..curve(0.63, 0.3, 0.5, 0.27)
                ..curve(0.42, 0.255, 0.37, 0.27))
              .close(),
      hairline: 0.28,
      part: const Offset(0.37, 0.1),
      sheen: const Rect.fromLTRB(0.32, 0.07, 0.72, 0.45),
      flows: [
        for (var i = 0; i < 10; i++)
          (
            Offset(0.375, 0.1 + i * 0.018),
            Offset(0.48, 0.07 + i * 0.02),
            Offset(0.62, 0.09 + i * 0.022),
            Offset(0.69 - i * 0.002, 0.2 + i * 0.015),
          ),
        for (var i = 0; i < 4; i++)
          (
            Offset(0.36, 0.11 + i * 0.03),
            Offset(0.32, 0.13 + i * 0.03),
            Offset(0.305, 0.2 + i * 0.02),
            Offset(0.315, 0.27 + i * 0.008),
          ),
      ],
    ),
    Hairstyle.menLayered => _HairLook(
      outline:
          (_Pen(0.5, 0.1)
                ..cubic(0.34, 0.1, 0.27, 0.19, 0.275, 0.33)
                ..cubic(0.278, 0.4, 0.272, 0.45, 0.285, 0.49)
                ..locks(const [
                  Offset(0.32, 0.525),
                  Offset(0.36, 0.48),
                ], depth: 0.045)
                ..line(0.37, 0.4)
                ..line(0.63, 0.4)
                ..line(0.64, 0.48)
                ..locks(const [
                  Offset(0.68, 0.525),
                  Offset(0.715, 0.49),
                ], depth: 0.045)
                ..cubic(0.728, 0.45, 0.722, 0.4, 0.725, 0.33)
                ..cubic(0.73, 0.19, 0.66, 0.1, 0.5, 0.1))
              .close(),
      // A textured fringe, falling in uneven locks.
      fringe:
          (_Pen(0.32, 0.33)
                ..cubic(0.32, 0.22, 0.4, 0.17, 0.5, 0.17)
                ..cubic(0.6, 0.17, 0.68, 0.22, 0.68, 0.33)
                ..locks(const [
                  Offset(0.64, 0.37),
                  Offset(0.58, 0.39),
                  Offset(0.51, 0.38),
                  Offset(0.44, 0.375),
                  Offset(0.38, 0.36),
                  Offset(0.33, 0.34),
                ], depth: 0.035))
              .close(),
      wave: 0.01,
      ends: const [
        Offset(0.285, 0.49),
        Offset(0.32, 0.52),
        Offset(0.38, 0.375),
        Offset(0.62, 0.38),
        Offset(0.68, 0.52),
        Offset(0.715, 0.49),
      ],
    ),
    Hairstyle.shortQuiff => _HairLook(
      outline:
          (_Pen(0.315, 0.33)
                ..cubic(0.305, 0.2, 0.35, 0.13, 0.43, 0.105)
                ..cubic(0.5, 0.075, 0.62, 0.07, 0.68, 0.11)
                ..cubic(0.715, 0.14, 0.71, 0.19, 0.695, 0.23)
                ..curve(0.69, 0.29, 0.685, 0.33)
                ..line(0.5, 0.3))
              .close(),
      fade: _sleek(),
      hairline: 0.29,
      sheen: const Rect.fromLTRB(0.33, 0.08, 0.7, 0.45),
      flows: [
        // Lifted off the forehead and back over the crown.
        for (var i = 0; i < 11; i++)
          (
            Offset(0.35 + i * 0.03, 0.31 - (i % 3) * 0.01),
            Offset(0.34 + i * 0.026, 0.19),
            Offset(0.45 + i * 0.02, 0.09 + (i % 3) * 0.01),
            Offset(0.58 + i * 0.01, 0.1 + i * 0.006),
          ),
      ],
    ),
    Hairstyle.sidePart => _HairLook(
      outline:
          (_Pen(0.33, 0.44)
                ..curve(0.305, 0.37, 0.307, 0.29)
                ..cubic(0.31, 0.17, 0.38, 0.105, 0.48, 0.1)
                ..cubic(0.6, 0.095, 0.695, 0.14, 0.7, 0.25)
                ..curve(0.7, 0.36, 0.67, 0.44)
                ..line(0.64, 0.37)
                ..line(0.36, 0.37))
              .close(),
      // Combed over from the parting, rising off the forehead.
      fringe:
          (_Pen(0.4, 0.21)
                ..cubic(0.5, 0.19, 0.62, 0.21, 0.68, 0.27)
                ..curve(0.695, 0.3, 0.68, 0.33)
                ..curve(0.6, 0.27, 0.48, 0.275)
                ..curve(0.43, 0.275, 0.4, 0.25))
              .close(),
      hairline: 0.28,
      part: const Offset(0.4, 0.11),
      flows: [
        for (var i = 0; i < 9; i++)
          (
            Offset(0.41, 0.11 + i * 0.018),
            Offset(0.5, 0.1 + i * 0.02),
            Offset(0.62, 0.12 + i * 0.02),
            Offset(0.685, 0.2 + i * 0.02),
          ),
        for (var i = 0; i < 5; i++)
          (
            Offset(0.395, 0.11 + i * 0.025),
            Offset(0.34, 0.13 + i * 0.03),
            Offset(0.315, 0.22 + i * 0.03),
            Offset(0.32, 0.3 + i * 0.025),
          ),
      ],
    ),
    Hairstyle.slickBack => _HairLook(
      outline:
          (_Pen(0.335, 0.44)
                ..curve(0.308, 0.37, 0.31, 0.29)
                ..cubic(0.31, 0.16, 0.39, 0.095, 0.5, 0.095)
                ..cubic(0.61, 0.095, 0.69, 0.16, 0.69, 0.29)
                ..curve(0.692, 0.37, 0.665, 0.44)
                ..line(0.64, 0.37)
                ..line(0.36, 0.37))
              .close(),
      hairline: 0.27,
      sheen: const Rect.fromLTRB(0.31, 0.1, 0.69, 0.5),
      flows: [
        // Combed straight back off the forehead.
        for (var i = 0; i < 11; i++)
          (
            Offset(0.34 + i * 0.032, 0.3 - (i - 5).abs() * 0.006),
            Offset(0.34 + i * 0.032 + (i - 5) * 0.006, 0.2),
            Offset(0.5 + (i - 5) * 0.029, 0.12),
            Offset(0.5 + (i - 5) * 0.024, 0.1),
          ),
      ],
    ),
    Hairstyle.crewCut => _HairLook(
      outline:
          (_Pen(0.315, 0.32)
                ..cubic(0.31, 0.19, 0.39, 0.115, 0.5, 0.11)
                ..cubic(0.61, 0.115, 0.69, 0.19, 0.685, 0.32)
                ..line(0.5, 0.29))
              .close(),
      fade: _sleek(),
      hairline: 0.29,
      texture: _Texture.buzz,
      textureArea: const Rect.fromLTRB(0.31, 0.1, 0.69, 0.33),
    ),
    Hairstyle.frenchCrop => _HairLook(
      outline:
          (_Pen(0.315, 0.32)
                ..cubic(0.31, 0.19, 0.39, 0.12, 0.5, 0.115)
                ..cubic(0.61, 0.12, 0.69, 0.19, 0.685, 0.32)
                ..line(0.5, 0.3))
              .close(),
      fade: _sleek(),
      // A short, blunt fringe straight across.
      fringe:
          (_Pen(0.33, 0.3)
                ..cubic(0.34, 0.22, 0.42, 0.19, 0.5, 0.19)
                ..cubic(0.58, 0.19, 0.66, 0.22, 0.67, 0.3)
                ..curve(0.672, 0.33, 0.66, 0.345)
                ..locks(const [
                  Offset(0.6, 0.352),
                  Offset(0.54, 0.346),
                  Offset(0.48, 0.352),
                  Offset(0.42, 0.346),
                  Offset(0.36, 0.352),
                  Offset(0.335, 0.335),
                ], depth: 0.012))
              .close(),
      hairline: 0.29,
      sheen: const Rect.fromLTRB(0.32, 0.12, 0.68, 0.45),
      flows: [
        // Pushed forward from the crown.
        for (var i = 0; i < 12; i++)
          (
            Offset(0.5 + (i - 5.5) * 0.012, 0.13),
            Offset(0.5 + (i - 5.5) * 0.024, 0.17),
            Offset(0.5 + (i - 5.5) * 0.028, 0.25),
            Offset(0.5 + (i - 5.5) * 0.029, 0.34),
          ),
      ],
    ),
    Hairstyle.curtains => _HairLook(
      outline:
          (_Pen(0.5, 0.11)
                ..cubic(0.35, 0.11, 0.285, 0.2, 0.29, 0.32)
                ..curve(0.29, 0.42, 0.3, 0.48)
                ..locks(const [Offset(0.34, 0.5)], depth: 0.04)
                ..line(0.36, 0.4)
                ..line(0.64, 0.4)
                ..line(0.66, 0.5)
                ..locks(const [Offset(0.7, 0.48)], depth: 0.04)
                ..curve(0.71, 0.42, 0.71, 0.32)
                ..cubic(0.715, 0.2, 0.65, 0.11, 0.5, 0.11))
              .close(),
      // Parted in the middle and falling to both temples.
      fringe: Path()
        ..addPath(
          (_Pen(0.49, 0.17)
                ..cubic(0.42, 0.2, 0.34, 0.26, 0.335, 0.34)
                ..curve(0.335, 0.39, 0.38, 0.425)
                ..curve(0.39, 0.34, 0.445, 0.29)
                ..curve(0.48, 0.26, 0.49, 0.17))
              .close(),
          Offset.zero,
        )
        ..addPath(
          (_Pen(0.51, 0.17)
                ..cubic(0.58, 0.2, 0.66, 0.26, 0.665, 0.34)
                ..curve(0.665, 0.39, 0.62, 0.425)
                ..curve(0.61, 0.34, 0.555, 0.29)
                ..curve(0.52, 0.26, 0.51, 0.17))
              .close(),
          Offset.zero,
        ),
      hairline: 0.27,
      part: const Offset(0.5, 0.11),
      ends: const [
        Offset(0.3, 0.48),
        Offset(0.34, 0.5),
        Offset(0.335, 0.43),
        Offset(0.665, 0.43),
        Offset(0.66, 0.5),
        Offset(0.7, 0.48),
      ],
    ),
    Hairstyle.mullet => _HairLook(
      outline:
          (_Pen(0.5, 0.11)
                ..cubic(0.35, 0.11, 0.29, 0.19, 0.295, 0.31)
                ..curve(0.3, 0.38, 0.32, 0.43)
                // Short at the ear, long down the back of the neck.
                ..cubic(0.33, 0.52, 0.3, 0.6, 0.28, 0.68)
                ..locks(const [
                  Offset(0.32, 0.73),
                  Offset(0.36, 0.7),
                  Offset(0.4, 0.66),
                ], depth: 0.045)
                ..line(0.4, 0.45)
                ..line(0.6, 0.45)
                ..line(0.6, 0.66)
                ..locks(const [
                  Offset(0.64, 0.7),
                  Offset(0.68, 0.73),
                  Offset(0.72, 0.68),
                ], depth: 0.045)
                ..cubic(0.7, 0.6, 0.67, 0.52, 0.68, 0.43)
                ..curve(0.7, 0.38, 0.705, 0.31)
                ..cubic(0.71, 0.19, 0.65, 0.11, 0.5, 0.11))
              .close(),
      fringe:
          (_Pen(0.33, 0.3)
                ..cubic(0.34, 0.21, 0.42, 0.18, 0.5, 0.18)
                ..cubic(0.58, 0.18, 0.66, 0.21, 0.67, 0.3)
                ..locks(const [
                  Offset(0.62, 0.33),
                  Offset(0.55, 0.34),
                  Offset(0.48, 0.335),
                  Offset(0.41, 0.34),
                  Offset(0.34, 0.32),
                ], depth: 0.03))
              .close(),
      wave: 0.012,
      ends: const [
        Offset(0.28, 0.68),
        Offset(0.34, 0.72),
        Offset(0.41, 0.34),
        Offset(0.59, 0.34),
        Offset(0.66, 0.72),
        Offset(0.72, 0.68),
      ],
    ),
    Hairstyle.fauxHawk => _HairLook(
      outline:
          (_Pen(0.355, 0.3)
                ..cubic(0.355, 0.2, 0.375, 0.12, 0.41, 0.08)
                // Spiked up along the middle.
                ..locks(const [
                  Offset(0.44, 0.035),
                  Offset(0.49, 0.015),
                  Offset(0.54, 0.025),
                  Offset(0.59, 0.055),
                ], depth: -0.055)
                ..cubic(0.625, 0.12, 0.645, 0.2, 0.645, 0.3)
                ..line(0.5, 0.28))
              .close(),
      fade: _sleek(),
      hairline: 0.29,
      sheen: const Rect.fromLTRB(0.37, 0.05, 0.63, 0.4),
      flows: [
        for (var i = 0; i < 9; i++)
          (
            Offset(0.38 + i * 0.03, 0.3),
            Offset(0.38 + i * 0.03, 0.2),
            Offset(0.5 + (i - 4) * 0.022, 0.1),
            Offset(0.5 + (i - 4) * 0.02, 0.045),
          ),
      ],
    ),
    Hairstyle.shortCurls => _HairLook(
      outline: _curls(
        center: const Offset(0.5, 0.25),
        radiusX: 0.17,
        radiusY: 0.135,
        count: 13,
        size: 0.04,
        extra: const [Offset(0.335, 0.33), Offset(0.665, 0.33)],
      ),
      fade: _sleek(),
      hairline: 0.3,
      texture: _Texture.curls,
      textureArea: const Rect.fromLTRB(0.3, 0.07, 0.7, 0.38),
    ),
  };

  /// Long hair to [length] with a middle parting: straight, or in waves.
  static Path _long(double length, {required bool wavy}) {
    final tips = length - 0.07;
    final pen = _Pen(0.5, 0.1)..cubic(0.32, 0.1, 0.245, 0.21, 0.25, 0.37);
    if (wavy) {
      pen
        ..curve(0.21, 0.45, 0.245, 0.53)
        ..curve(0.28, 0.61, 0.225, 0.7)
        ..curve(0.185, 0.78, 0.235, tips);
    } else {
      pen.cubic(0.255, 0.55, 0.225, 0.72, 0.205, tips);
    }
    pen
      ..locks([
        Offset(0.26, length + 0.015),
        Offset(0.31, length - 0.005),
        Offset(0.355, length - 0.04),
      ], depth: 0.075)
      ..line(0.37, 0.66)
      ..line(0.63, 0.66)
      ..line(0.645, length - 0.04)
      ..locks([
        Offset(0.69, length - 0.005),
        Offset(0.74, length + 0.015),
        Offset(wavy ? 0.765 : 0.795, tips),
      ], depth: 0.075);
    if (wavy) {
      pen
        ..curve(0.815, 0.78, 0.775, 0.7)
        ..curve(0.72, 0.61, 0.755, 0.53)
        ..curve(0.79, 0.45, 0.75, 0.37);
    } else {
      pen.cubic(0.775, 0.72, 0.745, 0.55, 0.75, 0.37);
    }
    pen.cubic(0.755, 0.21, 0.68, 0.1, 0.5, 0.1);
    return pen.close();
  }

  /// Hair pulled back flat over the head, for a ponytail or a bun.
  static Path _sleek() =>
      (_Pen(0.335, 0.44)
            ..curve(0.31, 0.37, 0.315, 0.3)
            ..cubic(0.32, 0.18, 0.4, 0.12, 0.5, 0.12)
            ..cubic(0.6, 0.12, 0.68, 0.18, 0.685, 0.3)
            ..curve(0.69, 0.37, 0.665, 0.44)
            ..line(0.64, 0.38)
            ..line(0.36, 0.38))
          .close();

  /// A mass of curls: an oval ringed by [count] round curls over the top
  /// and down the sides, or all round when [full]; plus [extra] curls.
  static Path _curls({
    required Offset center,
    required double radiusX,
    required double radiusY,
    required int count,
    required double size,
    bool full = false,
    List<Offset> extra = const [],
  }) {
    final path = Path()
      ..addOval(
        Rect.fromCenter(
          center: center,
          width: radiusX * 2,
          height: radiusY * 2,
        ),
      );
    final from = full ? 0.0 : math.pi * 0.8;
    final sweep = full ? math.pi * 2 : math.pi * 1.4;
    for (var i = 0; i < count; i++) {
      final a = from + sweep * i / (full ? count : count - 1);
      path.addOval(
        Rect.fromCircle(
          center: center + Offset(radiusX * math.cos(a), radiusY * math.sin(a)),
          radius: size * (i.isEven ? 1 : 0.8),
        ),
      );
    }
    for (final at in extra) {
      path.addOval(Rect.fromCircle(center: at, radius: size));
    }
    return path;
  }
}

/// Draws a path while keeping track of where it is, for [locks].
class _Pen {
  _Pen(double x, double y) : _at = Offset(x, y) {
    _path.moveTo(x, y);
  }

  final Path _path = Path();
  Offset _at;

  void line(double x, double y) {
    _path.lineTo(x, y);
    _at = Offset(x, y);
  }

  void curve(double cx, double cy, double x, double y) {
    _path.quadraticBezierTo(cx, cy, x, y);
    _at = Offset(x, y);
  }

  void cubic(double ax, double ay, double bx, double by, double x, double y) {
    _path.cubicTo(ax, ay, bx, by, x, y);
    _at = Offset(x, y);
  }

  /// Tapered locks: a point at each of [tips], with a rounded notch [depth]
  /// up between each and the last.
  void locks(List<Offset> tips, {double depth = 0.04}) {
    for (final tip in tips) {
      final notchY = math.min(_at.dy, tip.dy) - depth;
      final notchX = (_at.dx + tip.dx) / 2;
      _path
        ..quadraticBezierTo(_at.dx, notchY, notchX, notchY)
        ..quadraticBezierTo(tip.dx, notchY, tip.dx, tip.dy);
      _at = tip;
    }
  }

  Path close() => _path..close();
}

/// A drawn sticker in a square. [ink] colours tintable art (shapes and
/// arrows); the rest keep their own colours.
class StickerArtPainter extends CustomPainter {
  const StickerArtPainter({required this.art, required this.ink});

  final StickerArt art;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s);
    _paint(canvas);
    canvas.restore();
  }

  static Paint _fill(Color color) => Paint()..color = color;

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// A star with [points] tips between radii [outer] and [inner].
  static Path _star(int points, double outer, double inner, {Offset? at}) {
    final c = at ?? const Offset(0.5, 0.5);
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + math.pi * i / points;
      final p = c + Offset(r * math.cos(a), r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// A heart filling the square, shrunk to [scale] around its centre.
  static Path _heart({double scale = 1}) {
    final heart = Path()
      ..moveTo(0.5, 0.9)
      ..cubicTo(0.06, 0.62, 0.0, 0.3, 0.22, 0.16)
      ..cubicTo(0.36, 0.08, 0.47, 0.16, 0.5, 0.27)
      ..cubicTo(0.53, 0.16, 0.64, 0.08, 0.78, 0.16)
      ..cubicTo(1.0, 0.3, 0.94, 0.62, 0.5, 0.9)
      ..close();
    if (scale == 1) return heart;
    final m = Matrix4.identity()
      ..translateByDouble(0.5, 0.5, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-0.5, -0.5, 0, 1);
    return heart.transform(m.storage);
  }

  static Path _sparkle(Offset c, double r) => Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx + r * 0.14, c.dy - r * 0.14, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx + r * 0.14, c.dy + r * 0.14, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx - r * 0.14, c.dy + r * 0.14, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx - r * 0.14, c.dy - r * 0.14, c.dx, c.dy - r)
    ..close();

  /// The two strokes of an arrow head at [tip], pointing along [angle].
  static void _head(Canvas canvas, Offset tip, double angle, Paint paint) {
    for (final side in const [-1.0, 1.0]) {
      final a = angle + math.pi - side * 0.55;
      canvas.drawLine(
        tip,
        tip + Offset(0.15 * math.cos(a), 0.15 * math.sin(a)),
        paint,
      );
    }
  }

  void _paint(Canvas canvas) {
    final line = _stroke(ink, 0.05);
    switch (art) {
      // Shapes.
      case StickerArt.circle:
        canvas.drawCircle(const Offset(0.5, 0.5), 0.42, _fill(ink));
      case StickerArt.heart:
        canvas.drawPath(_heart(), _fill(ink));
      case StickerArt.star:
        canvas.drawPath(
          _star(5, 0.46, 0.19, at: const Offset(0.5, 0.54)),
          _fill(ink),
        );
      case StickerArt.square:
        canvas.drawRect(const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9), _fill(ink));
      case StickerArt.triangle:
        canvas.drawPath(
          Path()
            ..moveTo(0.5, 0.1)
            ..lineTo(0.93, 0.86)
            ..lineTo(0.07, 0.86)
            ..close(),
          _fill(ink),
        );
      case StickerArt.sparkle:
        canvas.drawPath(_sparkle(const Offset(0.5, 0.5), 0.45), _fill(ink));
      case StickerArt.star6:
        canvas.drawPath(_star(6, 0.46, 0.25), _fill(ink));
      case StickerArt.burst:
        canvas.drawPath(_star(12, 0.47, 0.3), _fill(ink));
      case StickerArt.badge:
        canvas.drawCircle(const Offset(0.5, 0.5), 0.38, _fill(ink));
        for (var i = 0; i < 18; i++) {
          final a = math.pi * 2 * i / 18;
          canvas.drawCircle(
            Offset(0.5 + 0.38 * math.cos(a), 0.5 + 0.38 * math.sin(a)),
            0.07,
            _fill(ink),
          );
        }
      case StickerArt.heartOutline:
        canvas.drawPath(_heart(scale: 0.86), _stroke(ink, 0.07));
      case StickerArt.ring:
        canvas.drawCircle(const Offset(0.5, 0.5), 0.36, _stroke(ink, 0.11));
      case StickerArt.flower:
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + math.pi * 2 * i / 5;
          canvas.drawCircle(
            Offset(0.5 + 0.22 * math.cos(a), 0.5 + 0.22 * math.sin(a)),
            0.2,
            _fill(ink),
          );
        }
        canvas.drawCircle(
          const Offset(0.5, 0.5),
          0.12,
          _fill(Color.lerp(ink, Colors.white, 0.55)!),
        );

      // Arrows.
      case StickerArt.arrowStraight:
        canvas.drawLine(const Offset(0.08, 0.5), const Offset(0.9, 0.5), line);
        _head(canvas, const Offset(0.9, 0.5), 0, line);
      case StickerArt.arrowCurve:
        canvas.drawPath(
          Path()
            ..moveTo(0.1, 0.82)
            ..cubicTo(0.2, 0.3, 0.55, 0.8, 0.86, 0.2),
          line,
        );
        _head(canvas, const Offset(0.86, 0.2), -1.1, line);
      case StickerArt.arrowLoop:
        canvas.drawPath(
          Path()
            ..moveTo(0.12, 0.25)
            ..cubicTo(0.6, 0.2, 0.62, 0.62, 0.42, 0.6)
            ..cubicTo(0.22, 0.58, 0.32, 0.32, 0.52, 0.5)
            ..quadraticBezierTo(0.7, 0.68, 0.86, 0.84),
          line,
        );
        _head(canvas, const Offset(0.86, 0.84), 0.8, line);
      case StickerArt.arrowZigzag:
        canvas.drawPath(
          Path()
            ..moveTo(0.08, 0.32)
            ..lineTo(0.28, 0.66)
            ..lineTo(0.46, 0.32)
            ..lineTo(0.64, 0.66)
            ..lineTo(0.9, 0.36),
          line,
        );
        _head(canvas, const Offset(0.9, 0.36), -0.86, line);
      case StickerArt.arrowDouble:
        canvas.drawLine(const Offset(0.1, 0.5), const Offset(0.9, 0.5), line);
        _head(canvas, const Offset(0.9, 0.5), 0, line);
        _head(canvas, const Offset(0.1, 0.5), math.pi, line);
      case StickerArt.arrowDashed:
        for (var x = 0.08; x < 0.78; x += 0.1) {
          canvas.drawLine(Offset(x, 0.5), Offset(x + 0.04, 0.5), line);
        }
        _head(canvas, const Offset(0.9, 0.5), 0, line);
        canvas.drawLine(const Offset(0.8, 0.5), const Offset(0.9, 0.5), line);
      case StickerArt.arrowDot:
        canvas.drawCircle(const Offset(0.12, 0.5), 0.06, _fill(ink));
        canvas.drawLine(const Offset(0.12, 0.5), const Offset(0.9, 0.5), line);
        _head(canvas, const Offset(0.9, 0.5), 0, line);
      case StickerArt.arrowElbow:
        canvas.drawPath(
          Path()
            ..moveTo(0.2, 0.12)
            ..lineTo(0.2, 0.62)
            ..quadraticBezierTo(0.2, 0.82, 0.4, 0.82)
            ..lineTo(0.88, 0.82),
          line,
        );
        _head(canvas, const Offset(0.88, 0.82), 0, line);
      case StickerArt.arrowBold:
        final bold = _stroke(ink, 0.13)..strokeCap = StrokeCap.butt;
        canvas.drawLine(const Offset(0.16, 0.84), const Offset(0.7, 0.3), bold);
        canvas.drawPath(
          Path()
            ..moveTo(0.88, 0.12)
            ..lineTo(0.88, 0.58)
            ..lineTo(0.42, 0.12)
            ..close(),
          _fill(ink),
        );

      // Scribbles, in their own colours.
      case StickerArt.sparkles:
        canvas.drawPath(
          _sparkle(const Offset(0.42, 0.56), 0.32),
          _fill(const Color(0xFFF7C928)),
        );
        canvas.drawPath(
          _sparkle(const Offset(0.76, 0.24), 0.16),
          _fill(const Color(0xFFF08DB8)),
        );
        canvas.drawPath(
          _sparkle(const Offset(0.8, 0.72), 0.1),
          _fill(const Color(0xFF111111)),
        );
      case StickerArt.squiggle:
        final wave = Path()..moveTo(0.06, 0.5);
        for (var i = 0; i < 4; i++) {
          final x = 0.06 + i * 0.22;
          wave.quadraticBezierTo(x + 0.055, 0.3, x + 0.11, 0.5);
          wave.quadraticBezierTo(x + 0.165, 0.7, x + 0.22, 0.5);
        }
        canvas.drawPath(wave, _stroke(const Color(0xFFF07A22), 0.07));
      case StickerArt.rainbow:
        for (final (r, color) in const [
          (0.38, Color(0xFFF7C928)),
          (0.28, Color(0xFFF08DB8)),
          (0.18, Color(0xFFF07A22)),
        ]) {
          canvas.drawPath(
            Path()
              ..moveTo(0.5 - r, 0.88)
              ..lineTo(0.5 - r, 0.5)
              ..arcToPoint(Offset(0.5 + r, 0.5), radius: Radius.circular(r))
              ..lineTo(0.5 + r, 0.88),
            _stroke(color, 0.1)..strokeCap = StrokeCap.butt,
          );
        }
      case StickerArt.dots:
        for (var i = 0; i < 26; i++) {
          final a = i * 2.39996;
          final r = 0.4 * math.sqrt(i / 26);
          canvas.drawCircle(
            Offset(0.5 + r * math.cos(a), 0.5 + r * math.sin(a)),
            0.022 + (i % 3) * 0.006,
            _fill(const Color(0xFF111111)),
          );
        }
      case StickerArt.spiral:
        final spiral = Path()..moveTo(0.5, 0.5);
        for (var i = 1; i <= 80; i++) {
          final a = i * 0.2;
          final r = 0.005 * i;
          spiral.lineTo(0.5 + r * math.cos(a), 0.5 + r * math.sin(a));
        }
        canvas.drawPath(spiral, _stroke(const Color(0xFF111111), 0.025));
      case StickerArt.blob:
        canvas.drawPath(
          Path()
            ..moveTo(0.5, 0.1)
            ..cubicTo(0.86, 0.06, 0.94, 0.46, 0.84, 0.66)
            ..cubicTo(0.72, 0.92, 0.3, 0.96, 0.16, 0.72)
            ..cubicTo(0.04, 0.5, 0.18, 0.12, 0.5, 0.1),
          _fill(const Color(0xFFF8C6DA)),
        );
        for (var i = 0; i < 12; i++) {
          final a = i * 2.39996;
          final r = 0.3 * math.sqrt((i + 1) / 12);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(0.5 + r * math.cos(a), 0.5 + r * math.sin(a)),
              width: 0.035,
              height: 0.06,
            ),
            _fill(const Color(0xFFE0609A)),
          );
        }
      case StickerArt.sun:
        canvas.drawCircle(
          const Offset(0.5, 0.5),
          0.22,
          _fill(const Color(0xFFF07A22)),
        );
        final ray = _stroke(const Color(0xFFF7C928), 0.05);
        for (var i = 0; i < 10; i++) {
          final a = math.pi * 2 * i / 10;
          canvas.drawLine(
            Offset(0.5 + 0.3 * math.cos(a), 0.5 + 0.3 * math.sin(a)),
            Offset(0.5 + 0.44 * math.cos(a), 0.5 + 0.44 * math.sin(a)),
            ray,
          );
        }
      case StickerArt.bolt:
        final bolt = Path()
          ..moveTo(0.58, 0.06)
          ..lineTo(0.22, 0.56)
          ..lineTo(0.48, 0.56)
          ..lineTo(0.4, 0.94)
          ..lineTo(0.8, 0.4)
          ..lineTo(0.54, 0.4)
          ..close();
        canvas.drawPath(bolt, _fill(const Color(0xFFF7C928)));
        canvas.drawPath(bolt, _stroke(const Color(0xFF111111), 0.025));
      case StickerArt.scribbleRing:
        final ring = Path();
        for (var i = 0; i <= 90; i++) {
          final a = i / 90 * math.pi * 4.2;
          final r = 0.36 + 0.03 * math.sin(a * 1.5);
          final p = Offset(0.5 + r * math.cos(a), 0.5 + r * 0.8 * math.sin(a));
          i == 0 ? ring.moveTo(p.dx, p.dy) : ring.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(ring, _stroke(const Color(0xFF111111), 0.03));

      // Objects.
      case StickerArt.tape:
        _tape(canvas, const Offset(0.5, 0.5), -0.2);
      case StickerArt.tapeCross:
        _tape(canvas, const Offset(0.5, 0.5), -0.45);
        _tape(canvas, const Offset(0.5, 0.5), 0.4);
      case StickerArt.polaroid:
        final frame = Path()
          ..addRect(const Rect.fromLTRB(0.16, 0.06, 0.84, 0.94));
        canvas.drawShadow(frame, Colors.black, 0.02, false);
        canvas.drawPath(frame, _fill(Colors.white));
        canvas.drawRect(
          const Rect.fromLTRB(0.22, 0.12, 0.78, 0.7),
          _fill(const Color(0xFFE8E8EB)),
        );
      case StickerArt.pin:
        canvas.drawLine(
          const Offset(0.5, 0.6),
          const Offset(0.56, 0.94),
          _stroke(const Color(0xFF9A9A9E), 0.03),
        );
        canvas.drawPath(
          Path()
            ..moveTo(0.36, 0.36)
            ..lineTo(0.64, 0.36)
            ..lineTo(0.7, 0.6)
            ..lineTo(0.3, 0.6)
            ..close(),
          _fill(const Color(0xFFD62A2A)),
        );
        canvas.drawOval(
          const Rect.fromLTRB(0.28, 0.08, 0.72, 0.4),
          _fill(const Color(0xFFE5302A)),
        );
        canvas.drawOval(
          const Rect.fromLTRB(0.38, 0.14, 0.5, 0.24),
          _fill(Colors.white.withValues(alpha: 0.5)),
        );
      case StickerArt.paperclip:
        canvas.drawPath(
          Path()
            ..moveTo(0.58, 0.3)
            ..lineTo(0.58, 0.72)
            ..arcToPoint(
              const Offset(0.42, 0.72),
              radius: const Radius.circular(0.08),
            )
            ..lineTo(0.42, 0.2)
            ..arcToPoint(
              const Offset(0.7, 0.2),
              radius: const Radius.circular(0.14),
            )
            ..lineTo(0.7, 0.8)
            ..arcToPoint(
              const Offset(0.3, 0.8),
              radius: const Radius.circular(0.2),
            )
            ..lineTo(0.3, 0.32),
          _stroke(const Color(0xFF8E8E93), 0.035),
        );
      case StickerArt.note:
        final note = Path()
          ..moveTo(0.12, 0.12)
          ..lineTo(0.88, 0.12)
          ..lineTo(0.88, 0.7)
          ..lineTo(0.7, 0.88)
          ..lineTo(0.12, 0.88)
          ..close();
        canvas.drawShadow(note, Colors.black, 0.02, false);
        canvas.drawPath(note, _fill(const Color(0xFFFBE38A)));
        canvas.drawPath(
          Path()
            ..moveTo(0.88, 0.7)
            ..lineTo(0.7, 0.7)
            ..lineTo(0.7, 0.88)
            ..close(),
          _fill(const Color(0xFFE9C95A)),
        );
      case StickerArt.priceTag:
        final tag = Path()
          ..moveTo(0.32, 0.18)
          ..lineTo(0.86, 0.18)
          ..lineTo(0.86, 0.82)
          ..lineTo(0.32, 0.82)
          ..lineTo(0.12, 0.5)
          ..close();
        canvas.drawPath(tag, _fill(const Color(0xFFE9DECB)));
        canvas.drawCircle(const Offset(0.3, 0.5), 0.05, _fill(Colors.white));
        canvas.drawLine(
          const Offset(0.3, 0.5),
          const Offset(0.04, 0.2),
          _stroke(const Color(0xFF111111), 0.015),
        );
      case StickerArt.smiley:
        canvas.drawCircle(
          const Offset(0.5, 0.5),
          0.42,
          _fill(const Color(0xFFF7C928)),
        );
        final face = _fill(const Color(0xFF111111));
        canvas.drawOval(const Rect.fromLTRB(0.35, 0.3, 0.43, 0.46), face);
        canvas.drawOval(const Rect.fromLTRB(0.57, 0.3, 0.65, 0.46), face);
        canvas.drawArc(
          const Rect.fromLTRB(0.28, 0.32, 0.72, 0.74),
          0.35,
          math.pi - 0.7,
          false,
          _stroke(const Color(0xFF111111), 0.05),
        );
    }
  }

  /// A strip of paper tape with torn ends, centred on [c], turned [angle].
  static void _tape(Canvas canvas, Offset c, double angle) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    // Straight sides, torn only at the ends.
    final strip = Path()
      ..moveTo(-0.4, -0.1)
      ..lineTo(0.4, -0.1);
    for (var i = 1; i <= 8; i++) {
      strip.lineTo(i.isOdd ? 0.42 : 0.4, -0.1 + i * 0.025);
    }
    strip.lineTo(-0.4, 0.1);
    for (var i = 7; i >= 0; i--) {
      strip.lineTo(i.isOdd ? -0.42 : -0.4, -0.1 + i * 0.025);
    }
    strip.close();
    canvas.drawPath(
      strip,
      _fill(const Color(0xFFE6E1D6).withValues(alpha: 0.88)),
    );
    canvas.drawPath(strip, _stroke(const Color(0xFFCFC8BA), 0.006));
    canvas.restore();
  }

  @override
  bool shouldRepaint(StickerArtPainter old) => old.art != art || old.ink != ink;
}
