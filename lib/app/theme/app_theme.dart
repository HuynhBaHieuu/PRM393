import 'package:flutter/material.dart';

import 'package:all_fits/app/theme/app_colors.dart';
import 'package:all_fits/app/theme/app_text_styles.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';

/// Material 3 theme customised toward a quiet, editorial look.
abstract final class AppTheme {
  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final text = AppTextStyles.textTheme(p);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.ink,
      onPrimary: p.onInk,
      primaryContainer: p.surfaceMuted,
      onPrimaryContainer: p.ink,
      secondary: p.accent,
      onSecondary: p.onInk,
      secondaryContainer: p.surfaceMuted,
      onSecondaryContainer: p.ink,
      tertiary: p.accent,
      onTertiary: p.onInk,
      error: p.danger,
      onError: p.onInk,
      surface: p.surface,
      onSurface: p.ink,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surface,
      surfaceContainerHighest: p.surfaceMuted,
      outline: p.border,
      outlineVariant: p.border,
      inverseSurface: p.ink,
      onInverseSurface: p.onInk,
      surfaceTint: Colors.transparent,
      shadow: Colors.black,
    );

    final roundedMd = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpacing.lg);
    const minButtonSize = Size(0, AppSizes.buttonHeight);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: p.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      textTheme: text,
      extensions: [p],
      splashFactory: InkRipple.splashFactory,
      dividerColor: p.border,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: p.ink, size: AppSizes.icon),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSizes.navBarHeight,
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: p.ink,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: AppSizes.icon,
            color: states.contains(WidgetState.selected)
                ? p.onInk
                : p.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected)
                ? p.ink
                : p.textSecondary,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.ink,
          foregroundColor: p.onInk,
          disabledBackgroundColor: p.surfaceMuted,
          disabledForegroundColor: p.textTertiary,
          minimumSize: minButtonSize,
          padding: buttonPadding,
          shape: roundedMd,
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          minimumSize: minButtonSize,
          padding: buttonPadding,
          shape: roundedMd,
          side: BorderSide(color: p.border),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.ink,
          textStyle: text.labelLarge,
          shape: roundedMd,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.ink),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.ink,
        foregroundColor: p.onInk,
        elevation: 2,
        highlightElevation: 4,
        shape: roundedMd,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md - 2,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: p.ink, width: 1.2),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: p.danger),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: p.danger, width: 1.2),
        ),
        labelStyle: text.bodyMedium?.copyWith(color: p.textSecondary),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: p.ink),
        hintStyle: text.bodyMedium?.copyWith(color: p.textTertiary),
        prefixIconColor: p.textSecondary,
        suffixIconColor: p.textSecondary,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        showDragHandle: true,
        dragHandleColor: p.border,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.onInk),
        actionTextColor: p.onInk,
        shape: roundedMd,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      tabBarTheme: TabBarThemeData(
        labelColor: p.ink,
        unselectedLabelColor: p.textSecondary,
        indicatorColor: p.ink,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: p.border,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall,
        overlayColor: WidgetStatePropertyAll(p.surfaceMuted),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.ink,
        textColor: p.ink,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.ink,
        linearTrackColor: p.surfaceMuted,
        circularTrackColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.onInk : p.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.ink : p.surfaceMuted,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : p.border,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? p.ink : p.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? p.onInk : p.ink,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: p.border)),
          textStyle: WidgetStatePropertyAll(text.labelMedium),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: roundedMd,
        textStyle: text.bodyMedium,
        elevation: 3,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: p.background,
        headerForegroundColor: p.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        todayBorder: BorderSide(color: p.ink),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: p.border),
        ),
      ),
    );
  }
}
