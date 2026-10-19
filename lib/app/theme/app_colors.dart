import 'package:flutter/material.dart';

/// Raw color tokens. Widgets should read colors through [AppPalette]
/// (`context.palette`) so light and dark themes both work.
abstract final class AppColors {
  // Light
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceMuted = Color(0xFFF3F3F3);
  static const Color lightInk = Color(0xFF111111);
  static const Color lightOnInk = Color(0xFFFFFFFF);
  static const Color lightTextSecondary = Color(0xFF6E6E6E);
  static const Color lightTextTertiary = Color(0xFFA3A3A3);
  static const Color lightBorder = Color(0xFFE8E8E8);
  // Black-and-white UI: the accent is the ink color.
  static const Color lightAccent = lightInk;
  static const Color lightDanger = Color(0xFFC1121F);
  static const Color lightSuccess = Color(0xFF1F7A3D);

  // Dark
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkSurfaceMuted = Color(0xFF1E1E1E);
  static const Color darkInk = Color(0xFFF5F5F5);
  static const Color darkOnInk = Color(0xFF000000);
  static const Color darkTextSecondary = Color(0xFFA3A3A3);
  static const Color darkTextTertiary = Color(0xFF6B6B6B);
  static const Color darkBorder = Color(0xFF2A2A2A);
  static const Color darkAccent = darkInk;
  static const Color darkDanger = Color(0xFFFF6B6B);
  static const Color darkSuccess = Color(0xFF7BD88F);

  /// Fill for garment silhouettes when an item has no color.
  static const Color neutralGarment = Color(0xFFB5B5B1);

  static const Color scrim = Color(0x66000000);
}

/// Semantic color palette exposed as a [ThemeExtension].
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.ink,
    required this.onInk,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.accent,
    required this.danger,
    required this.success,
  });

  final Color background;
  final Color surface;

  /// Soft fill behind photos, placeholders and progress tracks.
  final Color surfaceMuted;

  /// Primary text and strong UI elements.
  final Color ink;
  final Color onInk;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color accent;
  final Color danger;
  final Color success;

  static const AppPalette light = AppPalette(
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    surfaceMuted: AppColors.lightSurfaceMuted,
    ink: AppColors.lightInk,
    onInk: AppColors.lightOnInk,
    textSecondary: AppColors.lightTextSecondary,
    textTertiary: AppColors.lightTextTertiary,
    border: AppColors.lightBorder,
    accent: AppColors.lightAccent,
    danger: AppColors.lightDanger,
    success: AppColors.lightSuccess,
  );

  static const AppPalette dark = AppPalette(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceMuted: AppColors.darkSurfaceMuted,
    ink: AppColors.darkInk,
    onInk: AppColors.darkOnInk,
    textSecondary: AppColors.darkTextSecondary,
    textTertiary: AppColors.darkTextTertiary,
    border: AppColors.darkBorder,
    accent: AppColors.darkAccent,
    danger: AppColors.darkDanger,
    success: AppColors.darkSuccess,
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? ink,
    Color? onInk,
    Color? textSecondary,
    Color? textTertiary,
    Color? border,
    Color? accent,
    Color? danger,
    Color? success,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      ink: ink ?? this.ink,
      onInk: onInk ?? this.onInk,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      danger: danger ?? this.danger,
      success: success ?? this.success,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      ink: mix(ink, other.ink),
      onInk: mix(onInk, other.onInk),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      border: mix(border, other.border),
      accent: mix(accent, other.accent),
      danger: mix(danger, other.danger),
      success: mix(success, other.success),
    );
  }
}
