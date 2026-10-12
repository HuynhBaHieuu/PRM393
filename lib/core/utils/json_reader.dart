typedef JsonMap = Map<String, dynamic>;

/// Defensive helpers for reading persisted JSON. Every reader tolerates
/// missing or wrongly-typed values so malformed data never crashes the app.
abstract final class JsonReader {
  static String? string(JsonMap json, String key) {
    final value = json[key];
    return value is String ? value : null;
  }

  /// Returns the trimmed string, or null when missing or blank.
  static String? nonEmptyString(JsonMap json, String key) {
    final value = string(json, key)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static bool boolean(JsonMap json, String key, {bool fallback = false}) {
    final value = json[key];
    return value is bool ? value : fallback;
  }

  static int integer(JsonMap json, String key, {int fallback = 0}) {
    final value = json[key];
    if (value is int) return value;
    if (value is num && value.isFinite) return value.toInt();
    return fallback;
  }

  static double? decimal(JsonMap json, String key) {
    final value = json[key];
    final parsed = switch (value) {
      num() => value.toDouble(),
      String() => double.tryParse(value),
      _ => null,
    };
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  static DateTime? date(JsonMap json, String key) {
    final value = json[key];
    return value is String ? DateTime.tryParse(value) : null;
  }

  static List<String> stringList(JsonMap json, String key) {
    final value = json[key];
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static T? enumValue<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  /// Parses a list of enum names, dropping unknown entries and duplicates.
  static List<T> enumList<T extends Enum>(List<T> values, Object? raw) {
    if (raw is! List) return const [];
    final result = <T>{};
    for (final name in raw) {
      final value = enumValue(values, name);
      if (value != null) result.add(value);
    }
    return result.toList();
  }
}
