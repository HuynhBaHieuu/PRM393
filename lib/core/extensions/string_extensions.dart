extension StringX on String {
  /// Lowercased with Vietnamese accents removed, for searching: "Hiếu" and
  /// "hieu" both give "hieu".
  String get folded {
    final buffer = StringBuffer();
    for (final rune in toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_unaccented[char] ?? char);
    }
    return buffer.toString();
  }
}

final Map<String, String> _unaccented = {
  for (final MapEntry(key: base, value: accented) in const {
    'a': 'àáảãạăằắẳẵặâầấẩẫậ',
    'e': 'èéẻẽẹêềếểễệ',
    'i': 'ìíỉĩị',
    'o': 'òóỏõọôồốổỗộơờớởỡợ',
    'u': 'ùúủũụưừứửữự',
    'y': 'ỳýỷỹỵ',
    'd': 'đ',
  }.entries)
    for (final char in accented.split('')) char: base,
};

extension NullableStringX on String? {
  /// The trimmed value, or null when null or blank.
  String? get trimmedOrNull {
    final text = this?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
