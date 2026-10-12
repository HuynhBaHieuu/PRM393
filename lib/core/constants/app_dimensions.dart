/// Spacing scale used throughout the app (4pt grid).
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Horizontal padding for top-level page content.
  static const double page = 20;
}

abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

abstract final class AppSizes {
  static const double buttonHeight = 52;
  static const double compactButtonHeight = 40;
  static const double headerActionSize = 42;
  static const double navBarHeight = 68;

  static const double iconSm = 18;
  static const double icon = 22;
  static const double iconLg = 28;
  static const double iconXl = 36;

  static const double thumbSm = 44;
  static const double thumbMd = 56;
  static const double thumbLg = 72;
  static const double avatar = 88;
  static const double swatch = 32;
  static const double swatchDot = 12;

  static const double maxContentWidth = 720;
  static const double maxFormWidth = 560;
  static const double maxPreviewWidth = 420;
  static const double wideLayoutBreakpoint = 760;
  static const double plannerSidePanelWidth = 340;

  static const double gridMinTileWidth = 156;

  /// Width / height of clothing photos in grids.
  static const double clothingImageAspect = 3 / 4;

  /// Width / height of outfit previews.
  static const double outfitImageAspect = 4 / 5;

  static const double clothingTileFooterHeight = 50;
  static const double outfitTileFooterHeight = 50;

  static const double recentItemWidth = 124;
  static const double recentOutfitWidth = 156;
  static const double todayOutfitPreviewHeight = 220;
  static const double barHeight = 6;
}
