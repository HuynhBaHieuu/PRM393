enum Occasion {
  casual('Casual'),
  work('Work'),
  formal('Formal'),
  party('Party'),
  date('Date'),
  sport('Sport'),
  travel('Travel'),
  lounge('Lounge');

  const Occasion(this.label);

  final String label;
}
