import 'package:flutter/material.dart';

import 'package:all_fits/app/theme/app_colors.dart';

/// Typography: a heavy condensed sans for display text, the platform
/// sans-serif for UI text and a monospace for small labels.
abstract final class AppTextStyles {
  /// Resolves to the system condensed sans (Roboto Condensed on Android).
  static const String displayFamily = 'sans-serif-condensed';

  /// Resolves to the system monospace.
  static const String labelFamily = 'monospace';

  static const double _bodyHeight = 1.45;
  static const double _displayHeight = 1.12;

  static TextTheme textTheme(AppPalette palette) {
    TextStyle display(double size, {double spacing = 0}) => TextStyle(
      fontFamily: displayFamily,
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
      String? family,
    }) => TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: spacing,
      height: height,
      color: color ?? palette.ink,
    );

    return TextTheme(
      displayLarge: display(44, spacing: -1),
      displayMedium: display(36, spacing: -0.8),
      displaySmall: display(32, spacing: -0.6),
      headlineLarge: display(30, spacing: -0.5),
      headlineMedium: display(26, spacing: -0.4),
      headlineSmall: display(22, spacing: -0.2),
      titleLarge: display(20, spacing: -0.1),
      titleMedium: sans(16, weight: FontWeight.w600, spacing: -0.1),
      titleSmall: sans(14, weight: FontWeight.w600),
      bodyLarge: sans(16),
      bodyMedium: sans(14),
      bodySmall: sans(12.5, color: palette.textSecondary),
      labelLarge: sans(14, weight: FontWeight.w600, spacing: 0.1),
      labelMedium: sans(12, weight: FontWeight.w600, spacing: 0.2),
      // Used for small uppercase "eyebrow" labels.
      labelSmall: sans(
        11,
        weight: FontWeight.w600,
        spacing: 1.4,
        color: palette.textSecondary,
        family: labelFamily,
      ),
    );
  }
}
