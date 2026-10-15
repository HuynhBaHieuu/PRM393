import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/shopping_item.dart';

/// User input for creating or editing a shopping list item.
class ShoppingDraft {
  const ShoppingDraft({
    required this.name,
    required this.category,
    this.color,
    this.brand,
    this.price,
    this.link,
    this.notes,
    this.priority = ShoppingPriority.medium,
  });

  final String name;
  final ClothingCategory? category;
  final ClothingColor? color;
  final String? brand;
  final double? price;
  final String? link;
  final String? notes;
  final ShoppingPriority priority;

  /// Throws [ValidationException] when the draft can't be saved.
  void ensureValid() {
    final nameError = Validators.requiredName(name);
    if (nameError != null) throw ValidationException(nameError);
    if (category == null) {
      throw const ValidationException('Choose a category.');
    }
    final value = price;
    if (value != null && (value < 0 || value > Validators.maxPrice)) {
      throw const ValidationException('Enter a valid price.');
    }
    final linkError = Validators.optionalLink(link);
    if (linkError != null) throw ValidationException(linkError);
  }
}
