import 'package:flutter/material.dart';

import 'package:all_fits/app/theme/app_colors.dart';

/// Typography: an editorial serif for display text paired with the
/// platform sans-serif for UI text.
abstract final class AppTextStyles {
  /// Resolves to the system serif (Noto Serif on Android).
  static const String serifFamily = 'serif';

  static const double _bodyHeight = 1.45;
  static const double _displayHeight = 1.12;

  static TextTheme textTheme(AppPalette palette) {
    TextStyle serif(double size, {double spacing = 0, FontWeight? weight}) =>
        TextStyle(
          fontFamily: serifFamily,
          fontSize: size,
          fontWeight: weight ?? FontWeight.w400,
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
      displayLarge: serif(44, spacing: -1),
      displayMedium: serif(36, spacing: -0.8),
      displaySmall: serif(32, spacing: -0.6),
      headlineLarge: serif(30, spacing: -0.5),
      headlineMedium: serif(26, spacing: -0.4),
      headlineSmall: serif(22, spacing: -0.2),
      titleLarge: serif(20, spacing: -0.1),
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
      ),
    );
  }
}
