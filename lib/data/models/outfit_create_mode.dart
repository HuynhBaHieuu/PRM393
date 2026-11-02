import 'package:all_fits/data/models/outfit_board.dart';
import 'package:all_fits/core/l10n/l10n.dart';

/// How "Add outfit" turns the chosen pieces into an outfit, as in Fits.
enum OutfitCreateMode {
  collage('Collage'),
  dressingRoom('Dressing Room'),
  tryOn('AI Try On');

  const OutfitCreateMode(this._label);

  final String _label;

  String get label => tr(_label);
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
