import 'package:all_fits/core/utils/json_reader.dart';

/// What an extra photo of a piece shows.
enum PhotoKind {
  front('Front'),
  back('Back'),
  detail('Detail'),
  tag('Label'),
  other('Other');

  const PhotoKind(this.label);

  final String label;
}

/// A photo of a piece besides its main one, e.g. the back, the stitching or
/// the care label. Extra photos are never cut out.
class ClothingPhoto {
  const ClothingPhoto({required this.path, this.kind = PhotoKind.other});

  /// Returns null when [json] isn't a photo with a usable path.
  static ClothingPhoto? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final map = JsonMap.from(json);
    final path = JsonReader.nonEmptyString(map, 'path');
    if (path == null) return null;
    return ClothingPhoto(
      path: path,
      kind:
          JsonReader.enumValue(PhotoKind.values, map['kind']) ??
          PhotoKind.other,
    );
  }

  /// Storage reference resolved by `ImageStorageService`, like
  /// `ClothingItem.imagePath`.
  final String path;
  final PhotoKind kind;

  JsonMap toJson() => {'path': path, 'kind': kind.name};

  ClothingPhoto copyWith({PhotoKind? kind}) =>
      ClothingPhoto(path: path, kind: kind ?? this.kind);

  @override
  bool operator ==(Object other) =>
      other is ClothingPhoto && other.path == path && other.kind == kind;

  @override
  int get hashCode => Object.hash(path, kind);

  @override
  String toString() => 'ClothingPhoto($path, ${kind.name})';
}
