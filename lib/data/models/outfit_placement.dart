import 'package:all_fits/core/utils/json_reader.dart';

/// Where one piece sits on an outfit canvas. Positions and sizes are
/// fractions of the canvas, so a layout looks the same at any size.
class OutfitPlacement {
  const OutfitPlacement({
    required this.itemId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
  });

  /// Returns null for an entry that can't be placed.
  static OutfitPlacement? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = JsonMap.from(raw);
    final itemId = JsonReader.nonEmptyString(json, 'itemId');
    final x = JsonReader.decimal(json, 'x');
    final y = JsonReader.decimal(json, 'y');
    final width = JsonReader.decimal(json, 'width');
    final height = JsonReader.decimal(json, 'height');
    if (itemId == null || x == null || y == null) return null;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return OutfitPlacement(
      itemId: itemId,
      x: x,
      y: y,
      width: width,
      height: height,
      rotation: JsonReader.decimal(json, 'rotation') ?? 0,
    );
  }

  final String itemId;

  /// Centre of the piece, as fractions of the canvas width and height.
  final double x;
  final double y;

  /// Size of the box the piece is fitted into, as fractions of the canvas
  /// width and height.
  final double width;
  final double height;

  /// Clockwise turn in radians.
  final double rotation;

  JsonMap toJson() => {
    'itemId': itemId,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'rotation': rotation,
  };

  OutfitPlacement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
  }) => OutfitPlacement(
    itemId: itemId,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    rotation: rotation ?? this.rotation,
  );
}
