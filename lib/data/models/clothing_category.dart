enum ClothingCategory {
  tops('Tops', 'Top'),
  bottoms('Bottoms', 'Bottom'),
  outerwear('Outerwear', 'Outerwear'),
  dresses('Dresses', 'Dress'),
  shoes('Shoes', 'Shoes'),
  bags('Bags', 'Bag'),
  accessories('Accessories', 'Accessory'),
  other('Other', 'Other');

  const ClothingCategory(this.label, this.singularLabel);

  final String label;
  final String singularLabel;
}
