import 'package:all_fits/data/models/clothing_category.dart';

/// Where a piece is in the wash cycle. Only [clean] pieces are suggested
/// for outfits.
enum LaundryStatus {
  clean('Clean'),
  dirty('In the hamper'),
  washing('In the wash');

  const LaundryStatus(this.label);

  final String label;

  bool get isAvailable => this == LaundryStatus.clean;

  /// How many wears a piece of [category] takes before it goes in the
  /// hamper on its own; null when it never needs washing (shoes, bags).
  static int? wearsBeforeWash(ClothingCategory category) => switch (category) {
    ClothingCategory.tops || ClothingCategory.dresses => 1,
    ClothingCategory.bottoms => 3,
    ClothingCategory.outerwear => 5,
    ClothingCategory.other => 2,
    ClothingCategory.shoes ||
    ClothingCategory.bags ||
    ClothingCategory.accessories => null,
  };
}
