import 'dart:ui' show Color;

/// A curated set of colors keeps filtering and statistics meaningful.
enum ClothingColor {
  black('Black', Color(0xFF1E1E1E)),
  white('White', Color(0xFFF8F7F4)),
  grey('Grey', Color(0xFF9E9E9E)),
  beige('Beige', Color(0xFFD9C7A7)),
  brown('Brown', Color(0xFF7B5236)),
  navy('Navy', Color(0xFF243150)),
  blue('Blue', Color(0xFF5B83B8)),
  green('Green', Color(0xFF5B7553)),
  red('Red', Color(0xFFB23A3A)),
  pink('Pink', Color(0xFFE3A5B5)),
  purple('Purple', Color(0xFF7D5BA6)),
  yellow('Yellow', Color(0xFFE5C04A)),
  orange('Orange', Color(0xFFD9793A)),
  multi('Multicolor', Color(0xFFB0A090));

  const ClothingColor(this.label, this.swatch);

  final String label;

  /// Representative color. For [multi], widgets draw [multiBlocks] instead.
  final Color swatch;

  bool get isMulti => this == ClothingColor.multi;

  /// Flat blocks of color used to render [multi].
  static const List<Color> multiBlocks = [
    Color(0xFFB23A3A),
    Color(0xFFE5C04A),
    Color(0xFF5B7553),
    Color(0xFF5B83B8),
  ];
}
