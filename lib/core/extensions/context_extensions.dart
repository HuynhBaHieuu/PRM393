import 'package:flutter/material.dart';

import 'package:all_fits/app/theme/app_colors.dart';
import 'package:all_fits/core/constants/app_durations.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';

extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);

  TextTheme get textTheme => Theme.of(this).textTheme;

  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  Size get screenSize => MediaQuery.sizeOf(this);

  void showSnack(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: AppDurations.snackBar,
          action: actionLabel != null && onAction != null
              ? SnackBarAction(label: actionLabel, onPressed: onAction)
              : null,
        ),
      );
  }

  void showErrorSnack(Object error) => showSnack(describeError(error));
}
