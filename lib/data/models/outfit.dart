import 'dart:math' as math;

import 'package:all_fits/core/utils/json_reader.dart';
import 'package:all_fits/data/models/occasion.dart';
import 'package:all_fits/data/models/outfit_placement.dart';
import 'package:all_fits/data/models/season.dart';

const Object _unset = Object();

class Outfit {
  const Outfit({
    required this.id,
    required this.name,
    required this.itemIds,
    required this.createdAt,
    required this.updatedAt,
    this.occasion,
    this.seasons = const [],
    this.notes,
    this.isFavorite = false,
    this.wearCount = 0,
    this.lastWornAt,
    this.layout = const [],
  });

  factory Outfit.fromJson(JsonMap json) {
    final id = JsonReader.nonEmptyString(json, 'id');
    if (id == null) {
      throw const FormatException('Outfit is missing an id');
    }
    final createdAt =
        JsonReader.date(json, 'createdAt') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return Outfit(
      id: id,
      name: JsonReader.nonEmptyString(json, 'name') ?? 'Untitled outfit',
      // Drop duplicates while preserving the composition order.
      itemIds: JsonReader.stringList(json, 'itemIds').toSet().toList(),
      occasion: JsonReader.enumValue(Occasion.values, json['occasion']),
      seasons: JsonReader.enumList(Season.values, json['seasons']),
      notes: JsonReader.nonEmptyString(json, 'notes'),
      isFavorite: JsonReader.boolean(json, 'isFavorite'),
      wearCount: math.max(0, JsonReader.integer(json, 'wearCount')),
      lastWornAt: JsonReader.date(json, 'lastWornAt'),
      layout: [
        if (json['layout'] case final List<dynamic> raw)
          ...raw.map(OutfitPlacement.tryFromJson).whereType<OutfitPlacement>(),
      ],
      createdAt: createdAt,
      updatedAt: JsonReader.date(json, 'updatedAt') ?? createdAt,
    );
  }

  final String id;
  final String name;

  /// Clothing item ids in composition order (top to bottom).
  final List<String> itemIds;
  final Occasion? occasion;
  final List<Season> seasons;
  final String? notes;
  final bool isFavorite;
  final int wearCount;
  final DateTime? lastWornAt;

  /// Where each piece sits on the outfit canvas, back to front. Pieces
  /// without an entry get a default spot when shown.
  final List<OutfitPlacement> layout;
  final DateTime createdAt;
  final DateTime updatedAt;

  JsonMap toJson() => {
    'id': id,
    'name': name,
    'itemIds': itemIds,
    'occasion': occasion?.name,
    'seasons': seasons.map((s) => s.name).toList(),
    'notes': notes,
    'isFavorite': isFavorite,
    'wearCount': wearCount,
    'lastWornAt': lastWornAt?.toIso8601String(),
    'layout': layout.map((p) => p.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  Outfit copyWith({
    String? name,
    List<String>? itemIds,
    Object? occasion = _unset,
    List<Season>? seasons,
    Object? notes = _unset,
    bool? isFavorite,
    int? wearCount,
    Object? lastWornAt = _unset,
    List<OutfitPlacement>? layout,
    DateTime? updatedAt,
  }) {
    return Outfit(
      id: id,
      name: name ?? this.name,
      itemIds: itemIds ?? this.itemIds,
      occasion: identical(occasion, _unset)
          ? this.occasion
          : occasion as Occasion?,
      seasons: seasons ?? this.seasons,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      isFavorite: isFavorite ?? this.isFavorite,
      wearCount: wearCount ?? this.wearCount,
      lastWornAt: identical(lastWornAt, _unset)
          ? this.lastWornAt
          : lastWornAt as DateTime?,
      layout: layout ?? this.layout,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'Outfit($id, $name)';
}
