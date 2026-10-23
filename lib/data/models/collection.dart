import 'package:all_fits/core/utils/json_reader.dart';

const Object _unset = Object();

/// A group the user names themselves, e.g. "Beach trip" or "Wishlist",
/// holding clothing items and outfits side by side.
class Collection {
  const Collection({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.itemIds = const [],
    this.outfitIds = const [],
    this.coverImagePath,
  });

  factory Collection.fromJson(JsonMap json) {
    final id = JsonReader.nonEmptyString(json, 'id');
    if (id == null) {
      throw const FormatException('Collection is missing an id');
    }
    final createdAt =
        JsonReader.date(json, 'createdAt') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return Collection(
      id: id,
      name: JsonReader.nonEmptyString(json, 'name') ?? 'Untitled collection',
      itemIds: JsonReader.stringList(json, 'itemIds').toSet().toList(),
      outfitIds: JsonReader.stringList(json, 'outfitIds').toSet().toList(),
      coverImagePath: JsonReader.nonEmptyString(json, 'coverImagePath'),
      createdAt: createdAt,
      updatedAt: JsonReader.date(json, 'updatedAt') ?? createdAt,
    );
  }

  final String id;
  final String name;

  /// Clothing item ids, most recently added first.
  final List<String> itemIds;

  /// Outfit ids, most recently added first.
  final List<String> outfitIds;

  /// A photo the user picked as the cover. Without one the cover is a
  /// collage of the first pieces inside.
  final String? coverImagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isEmpty => itemIds.isEmpty && outfitIds.isEmpty;

  bool containsItem(String itemId) => itemIds.contains(itemId);

  bool containsOutfit(String outfitId) => outfitIds.contains(outfitId);

  JsonMap toJson() => {
    'id': id,
    'name': name,
    'itemIds': itemIds,
    'outfitIds': outfitIds,
    'coverImagePath': coverImagePath,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  Collection copyWith({
    String? name,
    List<String>? itemIds,
    List<String>? outfitIds,
    Object? coverImagePath = _unset,
    DateTime? updatedAt,
  }) {
    return Collection(
      id: id,
      name: name ?? this.name,
      itemIds: itemIds ?? this.itemIds,
      outfitIds: outfitIds ?? this.outfitIds,
      coverImagePath: identical(coverImagePath, _unset)
          ? this.coverImagePath
          : coverImagePath as String?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'Collection($id, $name)';
}
