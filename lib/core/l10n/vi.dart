import 'package:all_fits/core/l10n/vi/vi_ai.dart';
import 'package:all_fits/core/l10n/vi/vi_closet.dart';
import 'package:all_fits/core/l10n/vi/vi_common.dart';
import 'package:all_fits/core/l10n/vi/vi_social.dart';

/// Vietnamese text, keyed by the English it replaces. Split by area so
/// each file stays readable; later files win when a key repeats.
final Map<String, String> vietnamese = {
  ...viCommon,
  ...viCloset,
  ...viSocial,
  ...viAi,
};
