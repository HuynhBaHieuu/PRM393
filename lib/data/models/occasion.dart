import 'package:all_fits/core/l10n/l10n.dart';

enum Occasion {
  casual('Casual'),
  work('Work'),
  formal('Formal'),
  party('Party'),
  date('Date'),
  sport('Sport'),
  travel('Travel'),
  lounge('Lounge');

  const Occasion(this._label);

  final String _label;

  String get label => tr(_label);
}
