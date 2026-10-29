import 'dart:ui' show Color;

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

/// A hairstyle that can be put on a collage above the pieces, so the flat-lay
/// reads as a look on a person.
enum Hairstyle {
  short('Short'),
  bob('Bob'),
  long('Long'),
  ponytail('Ponytail'),
  bun('Bun'),
  curly('Curly');

  const Hairstyle(this.label);

  final String label;
}

enum HairColor {
  black('Black', Color(0xFF1F1A17)),
  brown('Brown', Color(0xFF5B3A24)),
  blonde('Blonde', Color(0xFFD9B66C)),
  auburn('Auburn', Color(0xFF8E3B22)),
  gray('Gray', Color(0xFFA7A4A0)),
  pink('Pink', Color(0xFFE79AB8));

  const HairColor(this.label, this.color);

  final String label;
  final Color color;
}

/// Emoji offered as stickers on the collage board.
const List<String> boardStickerEmoji = [
  '❤️', '✨', '⭐', '🔥', '🌸', '🌈', '☀️', '🌙', //
  '🦋', '🍀', '🎀', '👑', '💎', '💋', '🕶️', '👜', //
  '☕', '🍓', '🎧', '📸', '✈️', '🌴', '🎉', '💌', //
];

/// A decoration on the collage: an emoji sticker or a hairstyle. Its
/// [placement] works like a piece's, with [id] in place of an item id.
class OutfitSticker {
  const OutfitSticker({
    required this.placement,
    this.emoji,
    this.hairstyle,
    this.hairColor = HairColor.brown,
  }) : assert((emoji == null) != (hairstyle == null));

  /// Returns null for an entry that can't be drawn.
  static OutfitSticker? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = JsonMap.from(raw);
    final placement = OutfitPlacement.tryFromJson({
      ...json,
      'itemId': json['id'],
    });
    if (placement == null) return null;
    final emoji = JsonReader.nonEmptyString(json, 'emoji');
    final hairstyle = JsonReader.enumValue(Hairstyle.values, json['hairstyle']);
    if ((emoji == null) == (hairstyle == null)) return null;
    return OutfitSticker(
      placement: placement,
      emoji: emoji,
      hairstyle: hairstyle,
      hairColor:
          JsonReader.enumValue(HairColor.values, json['hairColor']) ??
          HairColor.brown,
    );
  }

  final OutfitPlacement placement;

  /// Set for an emoji sticker.
  final String? emoji;

  /// Set for a hairstyle.
  final Hairstyle? hairstyle;
  final HairColor hairColor;

  String get id => placement.itemId;

  JsonMap toJson() => {
    ...placement.toJson()..remove('itemId'),
    'id': id,
    'emoji': emoji,
    'hairstyle': hairstyle?.name,
    if (hairstyle != null) 'hairColor': hairColor.name,
  };

  OutfitSticker copyWith({OutfitPlacement? placement}) => OutfitSticker(
    placement: placement ?? this.placement,
    emoji: emoji,
    hairstyle: hairstyle,
    hairColor: hairColor,
  );
}
