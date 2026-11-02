import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/features/auth/controllers/auth_controller.dart';
import 'package:all_fits/core/l10n/l10n.dart';

abstract final class AuthFlows {
  /// Confirms, then signs out. The app returns to the login screen.
  static Future<void> signOut(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: tr('Log out?'),
      message: tr('Your wardrobe stays saved on this device for next time.'),
      confirmLabel: tr('Log out'),
    );
    if (!confirmed || !context.mounted) return;
    try {
      await context.read<AuthController>().signOut();
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
    }
  }
}
