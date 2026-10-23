/// An AI stylist the user can pick; each has its own taste.
enum StylistPersona {
  kai(
    'Kai',
    'Streetwear',
    'Style the streetwear way: let the sneakers or one statement piece '
        'anchor the look, layer outerwear over tees and hoodies, balance '
        'loose and fitted shapes, and keep loud logos or prints to one or two '
        'pieces.',
  ),
  mila(
    'Mila',
    'Minimalist',
    'Keep it minimal: neutral colors, clean lines, few pieces, no loud '
        'logos, and basics that fit well.',
  ),
  theo(
    'Theo',
    'Old money',
    'Go for quiet luxury: classic tailoring, knitwear, loafers or clean '
        'leather shoes, muted earthy tones and no visible logos.',
  ),
  rae(
    'Rae',
    'Bohemian',
    'Go boho: relaxed flowing shapes, warm earthy colors, layered textures, '
        'prints and accessories.',
  ),
  jules(
    'Jules',
    'Sporty',
    'Go sporty: athletic pieces, sneakers and tech fabrics in comfortable '
        'fits that still look put together.',
  ),
  noor(
    'Noor',
    'Elegant',
    'Go elegant: polished, refined pieces, tonal colors, structured '
        'outerwear and sleek shoes for a dressed-up look.',
  );

  const StylistPersona(this.label, this.style, this.direction);

  /// The stylist's name.
  final String label;

  /// Their taste in a word or two.
  final String style;

  /// How they style outfits, for the AI.
  final String direction;
}
