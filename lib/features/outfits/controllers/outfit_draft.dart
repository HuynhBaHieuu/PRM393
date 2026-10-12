import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/data/models/occasion.dart';
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
  });

  final String name;
  final List<String> itemIds;
  final Occasion? occasion;
  final List<Season> seasons;
  final String? notes;
  final bool isFavorite;

  void ensureValid() {
    if (itemIds.isEmpty) {
      throw const ValidationException('Add at least one piece to your outfit.');
    }
    final nameError = Validators.requiredName(name);
    if (nameError != null) throw ValidationException(nameError);
  }
}
