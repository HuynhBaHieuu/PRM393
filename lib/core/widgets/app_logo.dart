import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';

/// The "ALL FITS" wordmark, tinted with the theme's ink so it works in
/// light and dark mode.
class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key, this.height = 24});

  final double height;

  static const String asset = 'assets/logo/wordmark.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      height: height,
      color: context.palette.ink,
      semanticLabel: AppConfig.appName,
      // The file is 916 px wide; decode no larger than needed.
      cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).round(),
    );
  }
}
