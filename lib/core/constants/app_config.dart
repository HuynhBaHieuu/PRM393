/// App-wide configuration values.
abstract final class AppConfig {
  static const String appName = 'All Fits';

  /// When true, a small sample wardrobe is created on first launch.
  /// Set to false (or remove `lib/data/sample/`) to ship without demo data.
  static const bool seedSampleDataOnFirstLaunch = true;

  static const String defaultCurrencySymbol = '\$';

  /// Fabrics offered on the clothing detail screen; others can be typed in.
  static const List<String> suggestedMaterials = [
    'Cotton',
    'Denim',
    'Leather',
    'Suede',
    'Wool',
    'Cashmere',
    'Fleece',
    'Nylon',
    'Polyester',
    'Linen',
    'Silk',
    'Canvas',
    'Corduroy',
    'Knit',
    'Mesh',
    'Rubber',
  ];

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

  /// Clothing items a Free account can hold; Premium has no limit.
  static const int freeWardrobeLimit = 30;

  /// Collections a Free account can create; Premium has no limit.
  static const int freeCollectionLimit = 3;

  /// Distinct custom tags a Free account can use; Premium has no limit.
  static const int freeTagLimit = 5;

  /// AI Stylist messages a Free account can send per day; Premium has no
  /// limit.
  static const int freeStylistMessagesPerDay = 3;

  /// Extra Free AI Stylist messages for sharing the app, once a day.
  static const int shareBonusMessages = 3;

  /// AI try-on pictures a Free account can make, ever: one to see how it
  /// works.
  static const int freeTryOns = 1;

  /// AI try-on pictures Premium can make each calendar month. Each one costs
  /// money at the image provider. Failed ones don't count.
  static const int premiumTryOnsPerMonth = 20;

  /// Photos a Free account can have the AI tag each calendar month;
  /// Premium has no limit. Failed detections don't count.
  static const int freeDetectionsPerMonth = 5;

  /// Past AI Stylist chats kept on the device, newest first.
  static const int stylistChatsKept = 30;

  /// Shown on the Premium screen. Checkout is simulated: nothing is charged.
  static const double premiumMonthlyPrice = 4.99;

  /// Real Premium through payOS (with Supabase). Shown only: the price and
  /// length charged are PREMIUM_PRICE_VND and PREMIUM_DAYS in the `payos`
  /// Edge Function, so keep them in step.
  static const int premiumPriceVnd = 2000;
  static const int premiumDays = 30;

  /// Weather is fetched again once it is older than this.
  static const Duration weatherMaxAge = Duration(minutes: 30);

  static const int recentItemsLimit = 10;
  static const int recentOutfitsLimit = 8;

  /// Picked photos are downscaled to fit within this many pixels per side.
  static const double maxImageDimension = 1600;

  /// JPEG quality (0-100) used when the picker re-encodes images.
  static const int imageQuality = 85;

  /// Images larger than this are rejected before being copied.
  static const int maxImageBytes = 25 * 1024 * 1024;

  /// Photos a piece can have besides its main one (back, label, …).
  static const int maxExtraPhotos = 8;

  /// How far ahead/behind the planner date pickers allow.
  static const int plannerRangeDays = 365 * 2;
}
