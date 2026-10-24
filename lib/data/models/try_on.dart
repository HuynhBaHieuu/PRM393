import 'package:all_fits/core/utils/json_reader.dart';

enum BodyGender {
  female('Female', 'woman'),
  male('Male', 'man');

  const BodyGender(this.label, this.noun);

  final String label;

  /// Used in the image prompt.
  final String noun;
}

enum BodySize {
  s('S', 'slim'),
  m('M', 'average'),
  l('L', 'fuller');

  const BodySize(this.label, this.build);

  final String label;
  final String build;
}

enum LegLength {
  regular(null, null),
  short('Short legs', 'shorter legs'),
  long('Long legs', 'long legs');

  const LegLength(this.label, this.prompt);

  final String? label;
  final String? prompt;
}

/// One of the 18 silhouettes on the "Body type" sheet.
class BodyType {
  const BodyType(this.gender, this.size, [this.legs = LegLength.regular]);

  /// Reads "female-m-long"; null for anything else.
  static BodyType? tryParse(Object? value) {
    if (value is! String) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final gender = JsonReader.enumValue(BodyGender.values, parts[0]);
    final size = JsonReader.enumValue(BodySize.values, parts[1]);
    final legs = JsonReader.enumValue(LegLength.values, parts[2]);
    if (gender == null || size == null || legs == null) return null;
    return BodyType(gender, size, legs);
  }

  static const BodyType fallback = BodyType(BodyGender.female, BodySize.m);

  final BodyGender gender;
  final BodySize size;
  final LegLength legs;

  /// E.g. "Female · M · Long legs".
  String get label => [gender.label, size.label, ?legs.label].join(' · ');

  /// E.g. "a woman with a slim build and long legs".
  String get prompt =>
      'a ${gender.noun} with a ${size.build} build'
      '${legs.prompt == null ? '' : ' and ${legs.prompt}'}';

  String get key => '${gender.name}-${size.name}-${legs.name}';

  @override
  bool operator ==(Object other) =>
      other is BodyType &&
      other.gender == gender &&
      other.size == size &&
      other.legs == legs;

  @override
  int get hashCode => Object.hash(gender, size, legs);
}

/// Where the try-on picture is set. [asset] is the thumbnail on the
/// Background sheet; the scene itself is drawn from [prompt].
enum TryOnBackground {
  studio('Studio', null, 'a plain light grey photo studio'),
  street(
    'Brick wall',
    'assets/tryon/brick-wall.jpg',
    'a city street in front of a brown brick wall, daylight',
  ),
  subway(
    'NYC Subway',
    'assets/tryon/subway.jpg',
    'a New York subway platform with a train arriving',
  ),
  tokyo(
    'Tokyo Night',
    'assets/tryon/tokyo-night.jpg',
    'a wet Tokyo street at night with neon signs',
  ),
  skatepark(
    'Skatepark',
    'assets/tryon/skatepark.jpg',
    'an outdoor skatepark on a sunny day',
  ),
  cafe('Café', 'assets/tryon/cafe.jpg', 'inside a cosy coffee shop'),
  paris(
    'Paris',
    'assets/tryon/paris.jpg',
    'a Paris street with the Eiffel Tower behind',
  ),
  oldTown(
    'Old town',
    'assets/tryon/old-town.jpg',
    'a rooftop terrace over an old European town',
  ),
  beach('Beach', 'assets/tryon/beach.jpg', 'a sunny beach with palm trees');

  const TryOnBackground(this.label, this.asset, this.prompt);

  final String label;
  final String? asset;
  final String prompt;
}

/// Who wears the outfit: the user's own photos, or an AI model of their
/// body type.
enum TryOnWearer { me, model }

/// The photos and body type used for try-ons. Only ever kept for the
/// signed-in user; never part of the public profile.
class TryOnProfile {
  const TryOnProfile({
    this.selfiePhoto,
    this.bodyPhoto,
    this.bodyType,
    this.appearance = '',
    this.consented = false,
  });

  factory TryOnProfile.fromJson(JsonMap json) => TryOnProfile(
    selfiePhoto: JsonReader.nonEmptyString(json, 'selfiePhoto'),
    bodyPhoto: JsonReader.nonEmptyString(json, 'bodyPhoto'),
    bodyType: BodyType.tryParse(json['bodyType']),
    appearance: JsonReader.nonEmptyString(json, 'appearance') ?? '',
    consented: JsonReader.boolean(json, 'consented'),
  );

  static const int maxAppearanceLength = 300;

  /// Image storage references.
  final String? selfiePhoto;
  final String? bodyPhoto;
  final BodyType? bodyType;

  /// What the user wrote about how they look, e.g. "glasses, short beard".
  final String appearance;

  /// Whether the user agreed to send their photos to the AI provider.
  final bool consented;

  bool get hasPhoto => selfiePhoto != null || bodyPhoto != null;

  TryOnProfile copyWith({
    String? Function()? selfiePhoto,
    String? Function()? bodyPhoto,
    BodyType? bodyType,
    String? appearance,
    bool? consented,
  }) => TryOnProfile(
    selfiePhoto: selfiePhoto == null ? this.selfiePhoto : selfiePhoto(),
    bodyPhoto: bodyPhoto == null ? this.bodyPhoto : bodyPhoto(),
    bodyType: bodyType ?? this.bodyType,
    appearance: appearance ?? this.appearance,
    consented: consented ?? this.consented,
  );

  JsonMap toJson() => {
    'selfiePhoto': ?selfiePhoto,
    'bodyPhoto': ?bodyPhoto,
    'bodyType': ?bodyType?.key,
    if (appearance.isNotEmpty) 'appearance': appearance,
    'consented': consented,
  };
}

/// One generated try-on picture.
class TryOnResult {
  const TryOnResult({
    required this.id,
    required this.photo,
    required this.itemIds,
    required this.createdAt,
    this.outfitId,
    this.background = TryOnBackground.studio,
    this.wearer = TryOnWearer.me,
  });

  factory TryOnResult.fromJson(JsonMap json) => TryOnResult(
    id:
        JsonReader.nonEmptyString(json, 'id') ??
        (throw const FormatException('Try-on without an id')),
    photo:
        JsonReader.nonEmptyString(json, 'photo') ??
        (throw const FormatException('Try-on without a photo')),
    itemIds: JsonReader.stringList(json, 'itemIds'),
    createdAt:
        JsonReader.date(json, 'createdAt') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    outfitId: JsonReader.nonEmptyString(json, 'outfitId'),
    background:
        JsonReader.enumValue(TryOnBackground.values, json['background']) ??
        TryOnBackground.studio,
    wearer:
        JsonReader.enumValue(TryOnWearer.values, json['wearer']) ??
        TryOnWearer.me,
  );

  final String id;

  /// Image storage reference of the picture.
  final String photo;
  final List<String> itemIds;
  final DateTime createdAt;

  /// The saved outfit it was made from, if any.
  final String? outfitId;
  final TryOnBackground background;
  final TryOnWearer wearer;

  JsonMap toJson() => {
    'id': id,
    'photo': photo,
    'itemIds': itemIds,
    'createdAt': createdAt.toIso8601String(),
    'outfitId': ?outfitId,
    'background': background.name,
    'wearer': wearer.name,
  };
}
