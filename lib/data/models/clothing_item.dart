import 'dart:math' as math;

import 'package:all_fits/core/utils/json_reader.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_subcategory.dart';
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
    this.subcategory,
    this.color,
    this.seasons = const [],
    this.brand,
    this.price,
    this.notes,
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
      category: category,
      subcategory: subcategory?.category == category ? subcategory : null,
      color: JsonReader.enumValue(ClothingColor.values, json['color']),
      seasons: JsonReader.enumList(Season.values, json['seasons']),
      brand: JsonReader.nonEmptyString(json, 'brand'),
      price: price != null && price >= 0 ? price : null,
      notes: JsonReader.nonEmptyString(json, 'notes'),
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
  final ClothingCategory category;

  /// Always one of [category]'s subcategories, or null.
  final ClothingSubcategory? subcategory;
  final ClothingColor? color;
  final List<Season> seasons;
  final String? brand;
  final double? price;
  final String? notes;

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
  final DateTime createdAt;
  final DateTime updatedAt;

  JsonMap toJson() => {
    'id': id,
    'name': name,
    'imagePath': imagePath,
    'cutoutPath': cutoutPath,
    'category': category.name,
    'subcategory': subcategory?.name,
    'color': color?.name,
    'seasons': seasons.map((s) => s.name).toList(),
    'brand': brand,
    'price': price,
    'notes': notes,
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
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Nullable fields accept an explicit `null` to clear the value.
  ClothingItem copyWith({
    String? name,
    Object? imagePath = _unset,
    Object? cutoutPath = _unset,
    ClothingCategory? category,
    Object? subcategory = _unset,
    Object? color = _unset,
    List<Season>? seasons,
    Object? brand = _unset,
    Object? price = _unset,
    Object? notes = _unset,
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
      category: category ?? this.category,
      subcategory: identical(subcategory, _unset)
          ? this.subcategory
          : subcategory as ClothingSubcategory?,
      color: identical(color, _unset) ? this.color : color as ClothingColor?,
      seasons: seasons ?? this.seasons,
      brand: identical(brand, _unset) ? this.brand : brand as String?,
      price: identical(price, _unset) ? this.price : price as double?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
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
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
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
