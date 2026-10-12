extension NullableStringX on String? {
  /// The trimmed value, or null when null or blank.
  String? get trimmedOrNull {
    final text = this?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
