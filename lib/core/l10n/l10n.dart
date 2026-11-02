import 'package:all_fits/core/l10n/vi.dart';

/// Languages the app is translated into. English is the source text: every
/// [tr] key is the English string itself.
enum AppLanguage {
  en('English'),
  vi('Tiếng Việt');

  const AppLanguage(this.nativeName);

  /// The language's name in that language, as shown in the picker.
  final String nativeName;
}

/// The language [tr] translates into; set by `LanguageController`.
abstract final class L10n {
  static AppLanguage current = AppLanguage.en;

  static bool get isVietnamese => current == AppLanguage.vi;
}

final RegExp _placeholder = RegExp(r'\{(\d+)\}');

/// Translates [english] into the current language and fills its `{0}`,
/// `{1}`… placeholders with [args]. Text without a translation stays in
/// English.
///
/// A `|` suffix tells apart the same English word used in two senses:
/// `tr('Back|photo')` is "Back" in English but its own Vietnamese entry.
String tr(String english, [List<Object?> args = const []]) {
  final bar = english.indexOf('|');
  final source = bar < 0 ? english : english.substring(0, bar);
  final text = L10n.isVietnamese ? (vietnamese[english] ?? source) : source;
  if (args.isEmpty) return text;
  return text.replaceAllMapped(_placeholder, (match) {
    final index = int.parse(match[1]!);
    return index < args.length ? '${args[index]}' : match[0]!;
  });
}
