import 'package:flutter/material.dart';

import 'package:all_fits/app/theme/app_colors.dart';

/// Typography: the platform sans-serif throughout, bold and tightly spaced
/// for titles, regular for UI text.
abstract final class AppTextStyles {
  static const double _bodyHeight = 1.45;
  static const double _displayHeight = 1.15;

  static TextTheme textTheme(AppPalette palette) {
    TextStyle display(double size, {double spacing = 0}) => TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: spacing,
      height: _displayHeight,
      color: palette.ink,
    );

    TextStyle sans(
      double size, {
      FontWeight weight = FontWeight.w400,
      double spacing = 0,
      double height = _bodyHeight,
      Color? color,
    }) => TextStyle(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: spacing,
      height: height,
      color: color ?? palette.ink,
    );

    return TextTheme(
      displayLarge: display(40, spacing: -1.2),
      displayMedium: display(34, spacing: -1),
      displaySmall: display(30, spacing: -0.8),
      headlineLarge: display(28, spacing: -0.7),
      headlineMedium: display(24, spacing: -0.5),
      headlineSmall: display(20, spacing: -0.3),
      titleLarge: display(18, spacing: -0.2),
      titleMedium: sans(16, weight: FontWeight.w600, spacing: -0.2),
      titleSmall: sans(14, weight: FontWeight.w500),
      bodyLarge: sans(16),
      bodyMedium: sans(14),
      bodySmall: sans(12.5, color: palette.textSecondary),
      labelLarge: sans(14, weight: FontWeight.w500),
      labelMedium: sans(12, weight: FontWeight.w500),
      // Used for small "eyebrow" labels.
      labelSmall: sans(
        11,
        weight: FontWeight.w500,
        spacing: 0.4,
        color: palette.textSecondary,
      ),
    );
  }
}
