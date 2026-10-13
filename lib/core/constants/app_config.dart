/// App-wide configuration values.
abstract final class AppConfig {
  static const String appName = 'All Fits';

  /// When true, a small sample wardrobe is created on first launch.
  /// Set to false (or remove `lib/data/sample/`) to ship without demo data.
  static const bool seedSampleDataOnFirstLaunch = true;

  static const String defaultCurrencySymbol = '\$';

  /// Brands offered as one-tap choices in the clothing form, streetwear
  /// first. Any other brand can still be typed in.
  static const List<String> suggestedBrands = [
    'Supreme',
    'Stüssy',
    'BAPE',
    'Off-White',
    'Palace',
    'Fear of God',
    'Carhartt WIP',
    'The North Face',
    'Stone Island',
    'Kith',
    'Champion',
    'Dickies',
    'Chrome Hearts',
    'Comme des Garçons',
    'Nike',
    'Jordan',
    'Adidas',
    'New Balance',
    'Converse',
    'Vans',
    'Puma',
    'Asics',
    'Yeezy',
    'Balenciaga',
    'Louis Vuitton',
    'Gucci',
    'Dior',
    'Chanel',
    'Prada',
    'New Era',
    'Levi’s',
    'Uniqlo',
    'Zara',
    'H&M',
  ];

  static const int recentItemsLimit = 10;
  static const int recentOutfitsLimit = 8;

  /// Picked photos are downscaled to fit within this many pixels per side.
  static const double maxImageDimension = 1600;

  /// JPEG quality (0-100) used when the picker re-encodes images.
  static const int imageQuality = 85;

  /// Images larger than this are rejected before being copied.
  static const int maxImageBytes = 25 * 1024 * 1024;

  /// How far ahead/behind the planner date pickers allow.
  static const int plannerRangeDays = 365 * 2;
}
