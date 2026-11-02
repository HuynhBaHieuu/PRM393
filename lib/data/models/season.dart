import 'package:all_fits/core/l10n/l10n.dart';

enum Season {
  spring('Spring', '🌱'),
  summer('Summer', '☀️'),
  autumn('Fall', '🍂'),
  winter('Winter', '❄️');

  const Season(this._label, this.emoji);

  final String _label;
  final String emoji;

  String get label => tr(_label);
}
