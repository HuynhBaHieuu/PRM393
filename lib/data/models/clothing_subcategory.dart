import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/core/l10n/l10n.dart';

/// A finer kind of piece within a [ClothingCategory], e.g. T-Shirts.
enum ClothingSubcategory {
  tShirts('T-Shirts', ClothingCategory.tops),
  longSleeves('Long Sleeves', ClothingCategory.tops),
  polos('Polos', ClothingCategory.tops),
  shirts('Shirts', ClothingCategory.tops),
  hoodies('Hoodies', ClothingCategory.tops),
  sweaters('Sweaters', ClothingCategory.tops),
  tankTops('Tank Tops', ClothingCategory.tops),
  jeans('Jeans', ClothingCategory.bottoms),
  trousers('Trousers', ClothingCategory.bottoms),
  cargos('Cargos', ClothingCategory.bottoms),
  joggers('Joggers', ClothingCategory.bottoms),
  shorts('Shorts', ClothingCategory.bottoms),
  skirts('Skirts', ClothingCategory.bottoms),
  jackets('Jackets', ClothingCategory.outerwear),
  coats('Coats', ClothingCategory.outerwear),
  zipHoodies('Zip Hoodies', ClothingCategory.outerwear),
  blazers('Blazers', ClothingCategory.outerwear),
  miniDresses('Mini', ClothingCategory.dresses),
  midiDresses('Midi', ClothingCategory.dresses),
  maxiDresses('Maxi', ClothingCategory.dresses),
  sneakers('Sneakers', ClothingCategory.shoes),
  boots('Boots', ClothingCategory.shoes),
  sandals('Sandals', ClothingCategory.shoes),
  loafers('Loafers', ClothingCategory.shoes),
  heels('Heels', ClothingCategory.shoes),
  shoulderBags('Shoulder Bags', ClothingCategory.bags),
  totes('Totes', ClothingCategory.bags),
  backpacks('Backpacks', ClothingCategory.bags),
  caps('Caps', ClothingCategory.accessories),
  beanies('Beanies', ClothingCategory.accessories),
  jewelry('Jewelry', ClothingCategory.accessories),
  belts('Belts', ClothingCategory.accessories),
  sunglasses('Sunglasses', ClothingCategory.accessories);

  const ClothingSubcategory(this._label, this.category);

  final String _label;
  final ClothingCategory category;

  String get label => tr(_label);

  static List<ClothingSubcategory> of(ClothingCategory category) => [
    for (final sub in values)
      if (sub.category == category) sub,
  ];
}
