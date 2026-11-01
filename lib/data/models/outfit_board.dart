import 'dart:ui' show Color, Rect;

import 'package:all_fits/core/utils/json_reader.dart';
import 'package:all_fits/data/models/outfit_placement.dart';

/// The colour behind an outfit collage. [plain] follows the app theme.
enum BoardBackground {
  plain('Plain', null),
  cream('Cream', Color(0xFFF6F0E6)),
  blush('Blush', Color(0xFFF8E1E4)),
  peach('Peach', Color(0xFFFBE3D3)),
  sky('Sky', Color(0xFFDDEBF7)),
  mint('Mint', Color(0xFFDDF1E6)),
  lavender('Lavender', Color(0xFFE8E2F5)),
  sand('Sand', Color(0xFFE9DECB)),
  charcoal('Charcoal', Color(0xFF2B2B2E));

  const BoardBackground(this.label, this.color);

  final String label;

  /// Null for [plain], which uses the theme's surface colour.
  final Color? color;
}

/// A hairstyle put on the collage over the pieces, or on the Dressing Room
/// mannequin, so the look reads as worn by a person. Drawn as hair only,
/// with an open face. The first [freeCount] are on the Free plan.
enum Hairstyle {
  short('Pixie'),
  bob('Bob'),
  long('Long'),
  quiff('Quiff'),
  buzz('Buzz cut'),
  bangs('Bangs'),
  lob('Lob'),
  wavy('Wavy'),
  curly('Curly'),
  afro('Afro'),
  ponytail('Ponytail'),
  bun('Bun'),
  undercut('Undercut'),
  menLayered('Layered'),
  shortQuiff('Short quiff'),
  sidePart('Side part'),
  slickBack('Slick back'),
  crewCut('Crew cut'),
  frenchCrop('French crop'),
  curtains('Curtains'),
  mullet('Mullet'),
  fauxHawk('Faux hawk'),
  shortCurls('Short curls');

  const Hairstyle(this.label);

  final String label;

  static const int freeCount = 3;

  /// Where the open face sits in a hairstyle's square, for lining the hair
  /// up with a head or a collar.
  static const Rect face = Rect.fromLTRB(0.35, 0.27, 0.65, 0.67);

  bool get isFree => index < freeCount;
}

enum HairColor {
  black('Black', Color(0xFF151312)),
  espresso('Espresso', Color(0xFF2E2119)),
  brown('Brown', Color(0xFF5B3A24)),
  chestnut('Chestnut', Color(0xFF7A4A2A)),
  caramel('Caramel', Color(0xFFA9764A)),
  blonde('Blonde', Color(0xFFD9B66C)),
  platinum('Platinum', Color(0xFFEDE3CC)),
  ginger('Ginger', Color(0xFFC8642D)),
  auburn('Auburn', Color(0xFF8E3B22)),
  burgundy('Burgundy', Color(0xFF6E1F2E)),
  pink('Pink', Color(0xFFE79AB8)),
  gray('Gray', Color(0xFFA7A4A0));

  const HairColor(this.label, this.color);

  final String label;
  final Color color;
}

/// Colours a shape or arrow sticker can be drawn in.
enum StickerInk {
  black('Black', Color(0xFF111111)),
  white('White', Color(0xFFFFFFFF)),
  gray('Gray', Color(0xFF8E8E93)),
  red('Red', Color(0xFFE5302A)),
  pink('Pink', Color(0xFFF08DB8)),
  purple('Purple', Color(0xFFB03CD6)),
  blue('Blue', Color(0xFF2448D8)),
  sky('Sky', Color(0xFF1FA8E8)),
  green('Green', Color(0xFF1DB45A)),
  lime('Lime', Color(0xFF7ED321)),
  yellow('Yellow', Color(0xFFF7C928)),
  orange('Orange', Color(0xFFF07A22));

  const StickerInk(this.label, this.color);

  final String label;
  final Color color;
}

/// The tabs of the Stickers sheet.
enum StickerCategory {
  hair('Hair', tintable: true),
  scribbles('Scribbles'),
  shapes('Shapes', tintable: true),
  arrows('Arrows', tintable: true),
  objects('Objects'),
  emoji('Emoji');

  const StickerCategory(this.label, {this.tintable = false});

  final String label;

  /// Whether the sheet offers a colour row for this tab.
  final bool tintable;
}

/// A drawn sticker. Everything is painted in code (see `StickerArtPainter`),
/// so no outside artwork is needed. [free] ones are on the Free plan.
enum StickerArt {
  sparkles(StickerCategory.scribbles, free: true),
  squiggle(StickerCategory.scribbles, free: true),
  rainbow(StickerCategory.scribbles),
  dots(StickerCategory.scribbles),
  spiral(StickerCategory.scribbles),
  blob(StickerCategory.scribbles),
  sun(StickerCategory.scribbles),
  bolt(StickerCategory.scribbles),
  scribbleRing(StickerCategory.scribbles),
  circle(StickerCategory.shapes, free: true),
  heart(StickerCategory.shapes, free: true),
  star(StickerCategory.shapes, free: true),
  square(StickerCategory.shapes),
  triangle(StickerCategory.shapes),
  sparkle(StickerCategory.shapes),
  star6(StickerCategory.shapes),
  burst(StickerCategory.shapes),
  badge(StickerCategory.shapes),
  heartOutline(StickerCategory.shapes),
  ring(StickerCategory.shapes),
  flower(StickerCategory.shapes),
  arrowStraight(StickerCategory.arrows, free: true),
  arrowCurve(StickerCategory.arrows, free: true),
  arrowLoop(StickerCategory.arrows),
  arrowZigzag(StickerCategory.arrows),
  arrowDouble(StickerCategory.arrows),
  arrowDashed(StickerCategory.arrows),
  arrowDot(StickerCategory.arrows),
  arrowElbow(StickerCategory.arrows),
  arrowBold(StickerCategory.arrows),
  tape(StickerCategory.objects, free: true),
  polaroid(StickerCategory.objects, free: true),
  tapeCross(StickerCategory.objects),
  pin(StickerCategory.objects, free: true),
  paperclip(StickerCategory.objects),
  note(StickerCategory.objects),
  priceTag(StickerCategory.objects),
  smiley(StickerCategory.objects);

  const StickerArt(this.category, {this.free = false});

  final StickerCategory category;
  final bool free;

  bool get tintable => category.tintable;

  static List<StickerArt> of(StickerCategory category) => [
    for (final art in values)
      if (art.category == category) art,
  ];
}

/// Emoji offered as stickers on the collage board.
const List<String> boardStickerEmoji = [
  '❤️', '✨', '⭐', '🔥', '🌸', '🌈', '☀️', '🌙', //
  '🦋', '🍀', '🎀', '👑', '💎', '💋', '🕶️', '👜', //
  '☕', '🍓', '🎧', '📸', '✈️', '🌴', '🎉', '💌', //
];

/// A decoration on the collage: a drawn sticker ([art]), an emoji, or a
/// hairstyle. Its [placement] works like a piece's, with [id] in place of
/// an item id. One sitting [behind] is drawn under the pieces, e.g. hair
/// that falls behind a jacket.
class OutfitSticker {
  const OutfitSticker({
    required this.placement,
    this.art,
    this.ink = StickerInk.black,
    this.emoji,
    this.hairstyle,
    this.hairColor = HairColor.brown,
    this.behind = false,
  }) : assert(
         (art != null ? 1 : 0) +
                 (emoji != null ? 1 : 0) +
                 (hairstyle != null ? 1 : 0) ==
             1,
       );

  /// Returns null for an entry that can't be drawn.
  static OutfitSticker? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = JsonMap.from(raw);
    final placement = OutfitPlacement.tryFromJson({
      ...json,
      'itemId': json['id'],
    });
    if (placement == null) return null;
    final art = JsonReader.enumValue(StickerArt.values, json['art']);
    final emoji = JsonReader.nonEmptyString(json, 'emoji');
    final hairstyle = JsonReader.enumValue(Hairstyle.values, json['hairstyle']);
    final kinds = [art, emoji, hairstyle].where((k) => k != null).length;
    if (kinds != 1) return null;
    return OutfitSticker(
      placement: placement,
      art: art,
      ink:
          JsonReader.enumValue(StickerInk.values, json['ink']) ??
          StickerInk.black,
      emoji: emoji,
      hairstyle: hairstyle,
      hairColor:
          JsonReader.enumValue(HairColor.values, json['hairColor']) ??
          HairColor.brown,
      behind: JsonReader.boolean(json, 'behind'),
    );
  }

  final OutfitPlacement placement;

  /// Set for a drawn sticker.
  final StickerArt? art;

  /// The colour of a tintable [art].
  final StickerInk ink;

  /// Set for an emoji sticker.
  final String? emoji;

  /// Set for a hairstyle.
  final Hairstyle? hairstyle;
  final HairColor hairColor;

  /// Drawn under the pieces instead of over them.
  final bool behind;

  String get id => placement.itemId;

  /// Whether the Free plan can add another sticker like this one.
  bool get isFree => switch ((art, hairstyle)) {
    (final StickerArt art, _) => art.free,
    (_, final Hairstyle hair) => hair.isFree,
    _ => true,
  };

  JsonMap toJson() => {
    ...placement.toJson()..remove('itemId'),
    'id': id,
    'art': art?.name,
    if (art != null && art!.tintable) 'ink': ink.name,
    'emoji': emoji,
    'hairstyle': hairstyle?.name,
    if (hairstyle != null) 'hairColor': hairColor.name,
    if (behind) 'behind': true,
  };

  OutfitSticker copyWith({OutfitPlacement? placement, bool? behind}) =>
      OutfitSticker(
        placement: placement ?? this.placement,
        art: art,
        ink: ink,
        emoji: emoji,
        hairstyle: hairstyle,
        hairColor: hairColor,
        behind: behind ?? this.behind,
      );
}
