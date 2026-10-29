import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/data/models/occasion.dart';
import 'package:all_fits/data/models/outfit_board.dart';
import 'package:all_fits/data/models/outfit_placement.dart';
import 'package:all_fits/data/models/season.dart';

/// User input for creating or editing an outfit.
class OutfitDraft {
  const OutfitDraft({
    required this.name,
    required this.itemIds,
    this.occasion,
    this.seasons = const [],
    this.notes,
    this.isFavorite = false,
    this.layout = const [],
    this.background = BoardBackground.plain,
    this.stickers = const [],
    this.newPhotoPath,
    this.keepsPhoto = false,
  });

  final String name;
  final List<String> itemIds;
  final Occasion? occasion;
  final List<Season> seasons;
  final String? notes;
  final bool isFavorite;
  final List<OutfitPlacement> layout;
  final BoardBackground background;
  final List<OutfitSticker> stickers;

  /// A just-taken outfit selfie (a temporary file) to store with the outfit.
  final String? newPhotoPath;

  /// True when the outfit being edited already has a selfie and keeps it.
  final bool keepsPhoto;

  bool get hasPhoto => newPhotoPath != null || keepsPhoto;

  void ensureValid() {
    if (itemIds.isEmpty && !hasPhoto) {
      throw const ValidationException('Add at least one piece to your outfit.');
    }
    final nameError = Validators.requiredName(name);
    if (nameError != null) throw ValidationException(nameError);
  }
}
