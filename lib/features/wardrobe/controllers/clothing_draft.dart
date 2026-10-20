import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_subcategory.dart';
import 'package:all_fits/data/models/season.dart';

/// User input for creating or editing a clothing item.
class ClothingDraft {
  const ClothingDraft({
    required this.name,
    required this.category,
    this.subcategory,
    this.color,
    this.seasons = const [],
    this.brand,
    this.price,
    this.notes,
    this.isFavorite = false,
    this.newImagePath,
  });

  final String name;
  final ClothingCategory? category;
  final ClothingSubcategory? subcategory;
  final ClothingColor? color;
  final List<Season> seasons;
  final String? brand;
  final double? price;
  final String? notes;
  final bool isFavorite;

  /// Temporary path of a newly picked photo, imported on save.
  final String? newImagePath;

  /// Throws [ValidationException] when the draft can't be saved.
  /// A photo is required for new items ([requireImage]); edits may keep
  /// the existing one.
  void ensureValid({required bool requireImage}) {
    if (requireImage && newImagePath == null) {
      throw const ValidationException('Add a photo of this item.');
    }
    final nameError = Validators.requiredName(name);
    if (nameError != null) throw ValidationException(nameError);
    if (category == null) {
      throw const ValidationException('Choose a category.');
    }
    final value = price;
    if (value != null && (value < 0 || value > Validators.maxPrice)) {
      throw const ValidationException('Enter a valid price.');
    }
  }
}
