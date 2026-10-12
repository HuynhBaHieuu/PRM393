import 'package:all_fits/data/models/clothing_category.dart';

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

  const OutfitSlot(this.label, this.categories);

  final String label;
  final Set<ClothingCategory> categories;

  static OutfitSlot forCategory(ClothingCategory category) {
    for (final slot in values) {
      if (slot.categories.contains(category)) return slot;
    }
    return OutfitSlot.accessories;
  }
}
