/// How "Add outfit" turns the chosen pieces into an outfit, as in Fits.
enum OutfitCreateMode {
  collage('Collage'),
  dressingRoom('Dressing Room'),
  tryOn('AI Try On');

  const OutfitCreateMode(this.label);

  final String label;
}
