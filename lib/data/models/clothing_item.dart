import 'dart:math' as math;

import 'package:all_fits/core/utils/json_reader.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
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
    this.color,
    this.seasons = const [],
    this.brand,
    this.price,
    this.notes,
    this.isFavorite = false,
    this.isArchived = false,
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
    return ClothingItem(
      id: id,
      name: name,
      imagePath: JsonReader.nonEmptyString(json, 'imagePath'),
      category:
          JsonReader.enumValue(ClothingCategory.values, json['category']) ??
          ClothingCategory.other,
      color: JsonReader.enumValue(ClothingColor.values, json['color']),
      seasons: JsonReader.enumList(Season.values, json['seasons']),
      brand: JsonReader.nonEmptyString(json, 'brand'),
      price: price != null && price >= 0 ? price : null,
      notes: JsonReader.nonEmptyString(json, 'notes'),
      isFavorite: JsonReader.boolean(json, 'isFavorite'),
      isArchived: JsonReader.boolean(json, 'isArchived'),
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
  final ClothingCategory category;
  final ClothingColor? color;
  final List<Season> seasons;
  final String? brand;
  final double? price;
  final String? notes;
  final bool isFavorite;
  final bool isArchived;
  final int wearCount;
  final DateTime? lastWornAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  JsonMap toJson() => {
    'id': id,
    'name': name,
    'imagePath': imagePath,
    'category': category.name,
    'color': color?.name,
    'seasons': seasons.map((s) => s.name).toList(),
    'brand': brand,
    'price': price,
    'notes': notes,
    'isFavorite': isFavorite,
    'isArchived': isArchived,
    'wearCount': wearCount,
    'lastWornAt': lastWornAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Nullable fields accept an explicit `null` to clear the value.
  ClothingItem copyWith({
    String? name,
    Object? imagePath = _unset,
    ClothingCategory? category,
    Object? color = _unset,
    List<Season>? seasons,
    Object? brand = _unset,
    Object? price = _unset,
    Object? notes = _unset,
    bool? isFavorite,
    bool? isArchived,
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
      category: category ?? this.category,
      color: identical(color, _unset) ? this.color : color as ClothingColor?,
      seasons: seasons ?? this.seasons,
      brand: identical(brand, _unset) ? this.brand : brand as String?,
      price: identical(price, _unset) ? this.price : price as double?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      wearCount: wearCount ?? this.wearCount,
      lastWornAt: identical(lastWornAt, _unset)
          ? this.lastWornAt
          : lastWornAt as DateTime?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'ClothingItem($id, $name)';
}
