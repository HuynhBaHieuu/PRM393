import 'package:all_fits/core/l10n/l10n.dart';

enum ClothingCategory {
  tops('Tops', 'Top'),
  bottoms('Bottoms', 'Bottom'),
  outerwear('Outerwear', 'Outerwear'),
  dresses('Dresses', 'Dress'),
  shoes('Shoes', 'Shoes'),
  bags('Bags', 'Bag'),
  accessories('Accessories', 'Accessory'),
  other('Other', 'Other');

  const ClothingCategory(this._label, this._singular);

  final String _label;
  final String _singular;

  String get label => tr(_label);
  String get singularLabel => tr(_singular);
}
