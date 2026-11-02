import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/core/l10n/l10n.dart';

/// Positions in an outfit composition, ordered top to bottom.
enum OutfitSlot {
  outerwear('Outerwear', {ClothingCategory.outerwear}),
  top('Top', {ClothingCategory.tops}),
  dress('Dress', {ClothingCategory.dresses}),
  bottom('Bottom', {ClothingCategory.bottoms}),
  shoes('Shoes', {ClothingCategory.shoes}),
  accessories('Accessories', {
    ClothingCategory.accessories,
    ClothingCategory.bags,
    ClothingCategory.other,
  });

  const OutfitSlot(this._label, this.categories);

  final String _label;
  final Set<ClothingCategory> categories;

  String get label => tr(_label);

  static OutfitSlot forCategory(ClothingCategory category) {
    for (final slot in values) {
      if (slot.categories.contains(category)) return slot;
    }
    return OutfitSlot.accessories;
  }
}
