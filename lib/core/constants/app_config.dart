/// App-wide configuration values.
abstract final class AppConfig {
  static const String appName = 'All Fits';

  /// When true, a small sample wardrobe is created on first launch.
  /// Set to false (or remove `lib/data/sample/`) to ship without demo data.
  static const bool seedSampleDataOnFirstLaunch = true;

  static const String defaultCurrencySymbol = '\$';

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
