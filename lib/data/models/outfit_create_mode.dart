import 'package:all_fits/data/models/outfit_board.dart';

/// How "Add outfit" turns the chosen pieces into an outfit, as in Fits.
enum OutfitCreateMode {
  collage('Collage'),
  dressingRoom('Dressing Room'),
  tryOn('AI Try On');

  const OutfitCreateMode(this.label);

  final String label;
}

/// What the Collage or Dressing Room closes with when the user picks
/// another mode with "Switch mode": the look so far, to carry on in [mode].
class OutfitModeSwitch {
  const OutfitModeSwitch(this.mode, {this.itemIds = const [], this.hair});

  final OutfitCreateMode mode;
  final List<String> itemIds;

  /// The hair worn so far, if any.
  final (Hairstyle, HairColor)? hair;
}
