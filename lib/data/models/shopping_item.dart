import 'package:all_fits/core/utils/json_reader.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';

const Object _unset = Object();

/// How much the user wants an item on their shopping list.
enum ShoppingPriority {
  low('Low'),
  medium('Medium'),
  high('Must-have');

  const ShoppingPriority(this.label);

  final String label;
}

/// A piece the user plans to buy. Once bought it can be added to the
/// wardrobe, which links it to the new clothing item via [wardrobeItemId].
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.color,
    this.brand,
    this.price,
    this.link,
    this.notes,
    this.priority = ShoppingPriority.medium,
    this.purchasedAt,
    this.wardrobeItemId,
  });

  /// Throws [FormatException] when required fields are missing; all other
  /// fields fall back to safe defaults.
  factory ShoppingItem.fromJson(JsonMap json) {
    final id = JsonReader.nonEmptyString(json, 'id');
    final name = JsonReader.nonEmptyString(json, 'name');
    if (id == null || name == null) {
      throw const FormatException('Shopping item is missing an id or name');
    }
    final createdAt =
        JsonReader.date(json, 'createdAt') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final price = JsonReader.decimal(json, 'price');
    return ShoppingItem(
      id: id,
      name: name,
      category:
          JsonReader.enumValue(ClothingCategory.values, json['category']) ??
          ClothingCategory.other,
      color: JsonReader.enumValue(ClothingColor.values, json['color']),
      brand: JsonReader.nonEmptyString(json, 'brand'),
      price: price != null && price >= 0 ? price : null,
      link: JsonReader.nonEmptyString(json, 'link'),
      notes: JsonReader.nonEmptyString(json, 'notes'),
      priority:
          JsonReader.enumValue(ShoppingPriority.values, json['priority']) ??
          ShoppingPriority.medium,
      purchasedAt: JsonReader.date(json, 'purchasedAt'),
      wardrobeItemId: JsonReader.nonEmptyString(json, 'wardrobeItemId'),
      createdAt: createdAt,
      updatedAt: JsonReader.date(json, 'updatedAt') ?? createdAt,
    );
  }

  final String id;
  final String name;
  final ClothingCategory category;
  final ClothingColor? color;
  final String? brand;

  /// Expected price while on the list; the price paid once bought.
  final double? price;

  /// Where to buy it, e.g. a product page.
  final String? link;
  final String? notes;
  final ShoppingPriority priority;

  /// Set when the item has been bought.
  final DateTime? purchasedAt;

  /// The wardrobe item created from this purchase, if any.
  final String? wardrobeItemId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPurchased => purchasedAt != null;

  JsonMap toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'color': color?.name,
    'brand': brand,
    'price': price,
    'link': link,
    'notes': notes,
    'priority': priority.name,
    'purchasedAt': purchasedAt?.toIso8601String(),
    'wardrobeItemId': wardrobeItemId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Nullable fields accept an explicit `null` to clear the value.
  ShoppingItem copyWith({
    String? name,
    ClothingCategory? category,
    Object? color = _unset,
    Object? brand = _unset,
    Object? price = _unset,
    Object? link = _unset,
    Object? notes = _unset,
    ShoppingPriority? priority,
    Object? purchasedAt = _unset,
    Object? wardrobeItemId = _unset,
    DateTime? updatedAt,
  }) {
    return ShoppingItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      color: identical(color, _unset) ? this.color : color as ClothingColor?,
      brand: identical(brand, _unset) ? this.brand : brand as String?,
      price: identical(price, _unset) ? this.price : price as double?,
      link: identical(link, _unset) ? this.link : link as String?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      priority: priority ?? this.priority,
      purchasedAt: identical(purchasedAt, _unset)
          ? this.purchasedAt
          : purchasedAt as DateTime?,
      wardrobeItemId: identical(wardrobeItemId, _unset)
          ? this.wardrobeItemId
          : wardrobeItemId as String?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'ShoppingItem($id, $name)';
}
