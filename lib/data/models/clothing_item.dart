import 'dart:math' as math;

import 'package:all_fits/core/utils/json_reader.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_photo.dart';
import 'package:all_fits/data/models/clothing_subcategory.dart';
import 'package:all_fits/data/models/laundry_status.dart';
import 'package:all_fits/data/models/season.dart';

const Object _unset = Object();

class ClothingItem {
  const ClothingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.imagePath,
    this.cutoutPath,
    this.extraPhotos = const [],
    this.subcategory,
    this.color,
    this.seasons = const [],
    this.brand,
    this.price,
    this.notes,
    this.sourceUrl,
    this.materials = const [],
    this.tags = const [],
    this.purchaseDate,
    this.isFavorite = false,
    this.isArchived = false,
    this.hideInProfile = false,
    this.noStyling = false,
    this.sortIndex,
    this.wearCount = 0,
    this.lastWornAt,
    this.laundry = LaundryStatus.clean,
    this.wearsSinceWash = 0,
  });

  /// Throws [FormatException] when required fields are missing; all other
  /// fields fall back to safe defaults.
  factory ClothingItem.fromJson(JsonMap json) {
    final id = JsonReader.nonEmptyString(json, 'id');
    final name = JsonReader.nonEmptyString(json, 'name');
    if (id == null || name == null) {
      throw const FormatException('Clothing item is missing an id or name');
    }
    final createdAt =
        JsonReader.date(json, 'createdAt') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final price = JsonReader.decimal(json, 'price');
    final category =
        JsonReader.enumValue(ClothingCategory.values, json['category']) ??
        ClothingCategory.other;
    final subcategory = JsonReader.enumValue(
      ClothingSubcategory.values,
      json['subcategory'],
    );
    return ClothingItem(
      id: id,
      name: name,
      imagePath: JsonReader.nonEmptyString(json, 'imagePath'),
      cutoutPath: JsonReader.nonEmptyString(json, 'cutoutPath'),
      extraPhotos: _readPhotos(json['extraPhotos']),
      category: category,
      subcategory: subcategory?.category == category ? subcategory : null,
      color: JsonReader.enumValue(ClothingColor.values, json['color']),
      seasons: JsonReader.enumList(Season.values, json['seasons']),
      brand: JsonReader.nonEmptyString(json, 'brand'),
      price: price != null && price >= 0 ? price : null,
      notes: JsonReader.nonEmptyString(json, 'notes'),
      sourceUrl: JsonReader.nonEmptyString(json, 'sourceUrl'),
      materials: JsonReader.stringList(json, 'materials').toSet().toList(),
      tags: normalizeTags(JsonReader.stringList(json, 'tags')),
      purchaseDate: JsonReader.date(json, 'purchaseDate'),
      isFavorite: JsonReader.boolean(json, 'isFavorite'),
      isArchived: JsonReader.boolean(json, 'isArchived'),
      hideInProfile: JsonReader.boolean(json, 'hideInProfile'),
      noStyling: JsonReader.boolean(json, 'noStyling'),
      sortIndex: json['sortIndex'] is int ? json['sortIndex'] as int : null,
      wearCount: math.max(0, JsonReader.integer(json, 'wearCount')),
      lastWornAt: JsonReader.date(json, 'lastWornAt'),
      laundry:
          JsonReader.enumValue(LaundryStatus.values, json['laundry']) ??
          LaundryStatus.clean,
      wearsSinceWash: math.max(0, JsonReader.integer(json, 'wearsSinceWash')),
      createdAt: createdAt,
      updatedAt: JsonReader.date(json, 'updatedAt') ?? createdAt,
    );
  }

  final String id;
  final String name;

  /// Storage reference resolved by `ImageStorageService`, not an absolute path.
  final String? imagePath;

  /// The photo with its background removed, cropped to the piece. Stored
  /// like [imagePath]; null until a cut-out has been made.
  final String? cutoutPath;

  /// Photos besides the main one, e.g. the back or the care label, in the
  /// order the user added them.
  final List<ClothingPhoto> extraPhotos;
  final ClothingCategory category;

  /// Always one of [category]'s subcategories, or null.
  final ClothingSubcategory? subcategory;
  final ClothingColor? color;
  final List<Season> seasons;
  final String? brand;
  final double? price;
  final String? notes;

  /// The shop's product page the piece was added from, if any. Pieces with
  /// one are never shown to other people, since the photo is the shop's.
  final String? sourceUrl;

  /// Fabrics such as "Cotton" or "Denim", in the order they were added.
  final List<String> materials;

  /// The user's own labels, such as "school" or "vintage", in the order they
  /// were added. Never two that differ only in case.
  final List<String> tags;
  final DateTime? purchaseDate;
  final bool isFavorite;
  final bool isArchived;

  /// Keeps the piece off the closet other people see on your profile.
  final bool hideInProfile;

  /// Stops people who style you from putting this piece in an outfit.
  final bool noStyling;

  /// Position in the user's own order ("Custom" sort); null until reordered.
  final int? sortIndex;
  final int wearCount;
  final DateTime? lastWornAt;

  /// Clean, in the hamper or in the wash. Wearing a piece moves it to the
  /// hamper once it reaches [LaundryStatus.wearsBeforeWash].
  final LaundryStatus laundry;

  /// Wears since the piece was last marked clean.
  final int wearsSinceWash;
  final DateTime createdAt;
  final DateTime updatedAt;

  JsonMap toJson() => {
    'id': id,
    'name': name,
    'imagePath': imagePath,
    'cutoutPath': cutoutPath,
    'extraPhotos': extraPhotos.map((p) => p.toJson()).toList(),
    'category': category.name,
    'subcategory': subcategory?.name,
    'color': color?.name,
    'seasons': seasons.map((s) => s.name).toList(),
    'brand': brand,
    'price': price,
    'notes': notes,
    'sourceUrl': sourceUrl,
    'materials': materials,
    'tags': tags,
    'purchaseDate': purchaseDate?.toIso8601String(),
    'isFavorite': isFavorite,
    'isArchived': isArchived,
    'hideInProfile': hideInProfile,
    'noStyling': noStyling,
    'sortIndex': sortIndex,
    'wearCount': wearCount,
    'lastWornAt': lastWornAt?.toIso8601String(),
    'laundry': laundry.name,
    'wearsSinceWash': wearsSinceWash,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Nullable fields accept an explicit `null` to clear the value.
  ClothingItem copyWith({
    String? name,
    Object? imagePath = _unset,
    Object? cutoutPath = _unset,
    List<ClothingPhoto>? extraPhotos,
    ClothingCategory? category,
    Object? subcategory = _unset,
    Object? color = _unset,
    List<Season>? seasons,
    Object? brand = _unset,
    Object? price = _unset,
    Object? notes = _unset,
    Object? sourceUrl = _unset,
    List<String>? materials,
    List<String>? tags,
    Object? purchaseDate = _unset,
    bool? isFavorite,
    bool? isArchived,
    bool? hideInProfile,
    bool? noStyling,
    Object? sortIndex = _unset,
    int? wearCount,
    Object? lastWornAt = _unset,
    LaundryStatus? laundry,
    int? wearsSinceWash,
    DateTime? updatedAt,
  }) {
    return ClothingItem(
      id: id,
      name: name ?? this.name,
      imagePath: identical(imagePath, _unset)
          ? this.imagePath
          : imagePath as String?,
      cutoutPath: identical(cutoutPath, _unset)
          ? this.cutoutPath
          : cutoutPath as String?,
      extraPhotos: extraPhotos ?? this.extraPhotos,
      category: category ?? this.category,
      subcategory: identical(subcategory, _unset)
          ? this.subcategory
          : subcategory as ClothingSubcategory?,
      color: identical(color, _unset) ? this.color : color as ClothingColor?,
      seasons: seasons ?? this.seasons,
      brand: identical(brand, _unset) ? this.brand : brand as String?,
      price: identical(price, _unset) ? this.price : price as double?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      sourceUrl: identical(sourceUrl, _unset)
          ? this.sourceUrl
          : sourceUrl as String?,
      materials: materials ?? this.materials,
      tags: tags == null ? this.tags : normalizeTags(tags),
      purchaseDate: identical(purchaseDate, _unset)
          ? this.purchaseDate
          : purchaseDate as DateTime?,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      hideInProfile: hideInProfile ?? this.hideInProfile,
      noStyling: noStyling ?? this.noStyling,
      sortIndex: identical(sortIndex, _unset)
          ? this.sortIndex
          : sortIndex as int?,
      wearCount: wearCount ?? this.wearCount,
      lastWornAt: identical(lastWornAt, _unset)
          ? this.lastWornAt
          : lastWornAt as DateTime?,
      laundry: laundry ?? this.laundry,
      wearsSinceWash: wearsSinceWash ?? this.wearsSinceWash,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Whether the piece can be suggested for an outfit right now.
  bool get isAvailable => !isArchived && laundry.isAvailable;

  /// The same piece after one more wear: it goes in the hamper once it has
  /// been worn as often as its category allows between washes.
  ClothingItem afterWear() {
    final wears = wearsSinceWash + 1;
    final limit = LaundryStatus.wearsBeforeWash(category);
    return copyWith(
      wearsSinceWash: wears,
      laundry: limit != null && wears >= limit ? LaundryStatus.dirty : null,
    );
  }

  /// Undoes [afterWear]: takes the piece back out of the hamper when the
  /// wear being reversed is what put it there.
  ClothingItem beforeWear() {
    final wears = math.max(0, wearsSinceWash - 1);
    final limit = LaundryStatus.wearsBeforeWash(category);
    final backOut =
        laundry == LaundryStatus.dirty &&
        limit != null &&
        wearsSinceWash >= limit &&
        wears < limit;
    return copyWith(
      wearsSinceWash: wears,
      laundry: backOut ? LaundryStatus.clean : null,
    );
  }

  /// Drops malformed entries and repeats of the same photo.
  static List<ClothingPhoto> _readPhotos(Object? raw) {
    if (raw is! List) return const [];
    final seen = <String>{};
    return [
      for (final entry in raw)
        if (ClothingPhoto.tryFromJson(entry) case final photo?
            when seen.add(photo.path))
          photo,
    ];
  }

  /// Trims [tags] and drops blanks and case-insensitive repeats, keeping
  /// the first spelling.
  static List<String> normalizeTags(Iterable<String> tags) {
    final seen = <String>{};
    return [
      for (final tag in tags.map((t) => t.trim()))
        if (tag.isNotEmpty && seen.add(tag.toLowerCase())) tag,
    ];
  }

  @override
  String toString() => 'ClothingItem($id, $name)';
}
