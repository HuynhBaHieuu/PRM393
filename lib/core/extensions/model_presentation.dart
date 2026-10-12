import 'package:flutter/material.dart';

import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/occasion.dart';
import 'package:all_fits/data/models/outfit_slot.dart';

/// UI-only presentation details for data enums, kept out of the data layer.
extension ClothingCategoryPresentation on ClothingCategory {
  IconData get icon => switch (this) {
    ClothingCategory.tops => Icons.checkroom_outlined,
    ClothingCategory.bottoms => Icons.straighten_outlined,
    ClothingCategory.outerwear => Icons.dry_cleaning_outlined,
    ClothingCategory.dresses => Icons.woman_outlined,
    ClothingCategory.shoes => Icons.directions_walk_outlined,
    ClothingCategory.bags => Icons.shopping_bag_outlined,
    ClothingCategory.accessories => Icons.watch_outlined,
    ClothingCategory.other => Icons.category_outlined,
  };
}

extension OutfitSlotPresentation on OutfitSlot {
  IconData get icon => switch (this) {
    OutfitSlot.outerwear => Icons.dry_cleaning_outlined,
    OutfitSlot.top => Icons.checkroom_outlined,
    OutfitSlot.dress => Icons.woman_outlined,
    OutfitSlot.bottom => Icons.straighten_outlined,
    OutfitSlot.shoes => Icons.directions_walk_outlined,
    OutfitSlot.accessories => Icons.watch_outlined,
  };
}

extension OccasionPresentation on Occasion {
  IconData get icon => switch (this) {
    Occasion.casual => Icons.weekend_outlined,
    Occasion.work => Icons.work_outline_rounded,
    Occasion.formal => Icons.star_border_rounded,
    Occasion.party => Icons.celebration_outlined,
    Occasion.date => Icons.favorite_border_rounded,
    Occasion.sport => Icons.fitness_center_outlined,
    Occasion.travel => Icons.flight_takeoff_outlined,
    Occasion.lounge => Icons.chair_outlined,
  };
}
