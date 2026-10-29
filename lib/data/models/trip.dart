import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/utils/json_reader.dart';
import 'package:all_fits/data/models/weather.dart';

const Object _unset = Object();

/// Something to pack that isn't in the wardrobe, e.g. "Phone charger".
class PackingExtra {
  const PackingExtra({
    required this.id,
    required this.label,
    this.packed = false,
  });

  static PackingExtra? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final id = JsonReader.nonEmptyString(map, 'id');
    final label = JsonReader.nonEmptyString(map, 'label');
    if (id == null || label == null) return null;
    return PackingExtra(
      id: id,
      label: label,
      packed: JsonReader.boolean(map, 'packed'),
    );
  }

  final String id;
  final String label;
  final bool packed;

  JsonMap toJson() => {'id': id, 'label': label, 'packed': packed};

  PackingExtra copyWith({String? label, bool? packed}) => PackingExtra(
    id: id,
    label: label ?? this.label,
    packed: packed ?? this.packed,
  );
}

/// A trip: one outfit per day between [startDate] and [endDate], and the
/// packing list gathered from them.
///
/// The packing list itself is never stored: it is worked out from the
/// outfits each time (see `PackingList`), so editing an outfit updates it.
/// Only what the user ticked, and the extras they typed, are kept.
class Trip {
  Trip({
    required this.id,
    required this.name,
    required DateTime startDate,
    required DateTime endDate,
    required this.createdAt,
    required this.updatedAt,
    this.location,
    this.outfitByDay = const {},
    this.packedItemIds = const [],
    this.extras = const [],
  }) : startDate = DateHelpers.dateOnly(startDate),
       endDate = DateHelpers.dateOnly(endDate);

  factory Trip.fromJson(JsonMap json) {
    final id = JsonReader.nonEmptyString(json, 'id');
    final start = DateHelpers.fromKey(JsonReader.string(json, 'startDate'));
    final end = DateHelpers.fromKey(JsonReader.string(json, 'endDate'));
    if (id == null || start == null || end == null) {
      throw const FormatException('Trip is incomplete');
    }
    final createdAt =
        JsonReader.date(json, 'createdAt') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final days = json['outfitByDay'];
    final extras = json['extras'];
    return Trip(
      id: id,
      name: JsonReader.nonEmptyString(json, 'name') ?? 'Untitled trip',
      startDate: start,
      endDate: end.isBefore(start) ? start : end,
      location: WeatherLocation.tryFromJson(json['location']),
      outfitByDay: {
        if (days is Map)
          for (final MapEntry(:key, :value) in days.entries)
            if (DateHelpers.fromKey('$key') != null &&
                value is String &&
                value.isNotEmpty)
              '$key': value,
      },
      packedItemIds: JsonReader.stringList(
        json,
        'packedItemIds',
      ).toSet().toList(),
      extras: [
        if (extras is List)
          for (final extra in extras) ?PackingExtra.tryFromJson(extra),
      ],
      createdAt: createdAt,
      updatedAt: JsonReader.date(json, 'updatedAt') ?? createdAt,
    );
  }

  /// Longest trip, in days.
  static const int maxDays = 30;

  final String id;
  final String name;

  /// First and last day, without a time.
  final DateTime startDate;
  final DateTime endDate;

  /// The city the trip goes to, for its weather; null when not given.
  final WeatherLocation? location;

  /// Outfit id by day key (`DateHelpers.toKey`). Days without an outfit
  /// are missing.
  final Map<String, String> outfitByDay;

  /// Clothing items already in the suitcase.
  final List<String> packedItemIds;
  final List<PackingExtra> extras;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Every day of the trip, first to last.
  List<DateTime> get days => [
    for (var i = 0; i <= DateHelpers.daysBetween(startDate, endDate); i++)
      DateHelpers.addDays(startDate, i),
  ];

  int get length => DateHelpers.daysBetween(startDate, endDate) + 1;

  String? outfitOn(DateTime day) => outfitByDay[DateHelpers.toKey(day)];

  bool contains(DateTime day) {
    final date = DateHelpers.dateOnly(day);
    return !date.isBefore(startDate) && !date.isAfter(endDate);
  }

  /// The trip is over once its last day has passed.
  bool isPast(DateTime today) => endDate.isBefore(DateHelpers.dateOnly(today));

  JsonMap toJson() => {
    'id': id,
    'name': name,
    'startDate': DateHelpers.toKey(startDate),
    'endDate': DateHelpers.toKey(endDate),
    'location': location?.toJson(),
    'outfitByDay': outfitByDay,
    'packedItemIds': packedItemIds,
    'extras': extras.map((e) => e.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  Trip copyWith({
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    Object? location = _unset,
    Map<String, String>? outfitByDay,
    List<String>? packedItemIds,
    List<PackingExtra>? extras,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: identical(location, _unset)
          ? this.location
          : location as WeatherLocation?,
      outfitByDay: outfitByDay ?? this.outfitByDay,
      packedItemIds: packedItemIds ?? this.packedItemIds,
      extras: extras ?? this.extras,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'Trip($id, $name)';
}
