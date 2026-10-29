import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_photo.dart';
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
    this.sourceUrl,
    this.isFavorite = false,
    this.newImagePath,
    this.extraPhotos,
  });

  final String name;
  final ClothingCategory? category;
  final ClothingSubcategory? subcategory;
  final ClothingColor? color;
  final List<Season> seasons;
  final String? brand;
  final double? price;
  final String? notes;

  /// The shop page the piece came from; see `ClothingItem.sourceUrl`.
  final String? sourceUrl;
  final bool isFavorite;

  /// Temporary path of a newly picked photo, imported on save.
  final String? newImagePath;

  /// The piece's extra photos as they should be after saving, or null to
  /// leave them as they are.
  final List<ExtraPhotoDraft>? extraPhotos;

  /// Throws [ValidationException] when the draft can't be saved.
  /// A photo is required for new items ([requireImage]); edits may keep
  /// the existing one.
  void ensureValid({required bool requireImage}) {
    if (requireImage && newImagePath == null) {
      throw const ValidationException('Add a photo of this item.');
    }
    final nameError = Validators.requiredName(
      name,
      max: Validators.maxItemNameLength,
    );
    if (nameError != null) throw ValidationException(nameError);
    if (category == null) {
      throw const ValidationException('Choose a category.');
    }
    final value = price;
    if (value != null && (value < 0 || value > Validators.maxPrice)) {
      throw const ValidationException('Enter a valid price.');
    }
    final linkError = Validators.optionalLink(sourceUrl);
    if (linkError != null) throw ValidationException(linkError);
    if ((extraPhotos?.length ?? 0) > AppConfig.maxExtraPhotos) {
      throw const ValidationException(
        'A piece can have up to ${AppConfig.maxExtraPhotos} extra photos.',
      );
    }
  }
}

/// An extra photo in the clothing form: one the piece already has, or one
/// just picked that is imported on save.
class ExtraPhotoDraft {
  const ExtraPhotoDraft.saved(String this.reference, this.kind)
    : newPath = null;

  const ExtraPhotoDraft.picked(String this.newPath, this.kind)
    : reference = null;

  /// Storage reference of a photo the piece already has.
  final String? reference;

  /// Temporary path of a newly picked photo.
  final String? newPath;
  final PhotoKind kind;

  ExtraPhotoDraft withKind(PhotoKind kind) => reference != null
      ? ExtraPhotoDraft.saved(reference!, kind)
      : ExtraPhotoDraft.picked(newPath!, kind);
}
