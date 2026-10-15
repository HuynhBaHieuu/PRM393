import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// Plan checks and the simulated upgrade / cancel flows.
abstract final class PremiumFlows {
  /// Whether the user's plan has room for another clothing item.
  /// Archived pieces count, since they still take up space.
  static bool canAddClothing(BuildContext context) {
    final plan = context.read<SettingsController>().plan;
    return plan.canAddItem(context.read<WardrobeController>().allItems.length);
  }

  /// Explains the Free wardrobe limit and offers Premium.
  static Future<void> showWardrobeLimit(BuildContext context) {
    final text = context.textTheme;
    final palette = context.palette;
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHeader(title: 'Your wardrobe is full'),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'The Free plan holds '
                      '${AppFormatters.count(AppConfig.freeWardrobeLimit, 'piece')}, '
                      'archived ones included. Go Premium for unlimited '
                      'space, or delete pieces you no longer wear.',
                      style: text.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        AppNavigator.premium(context);
                      },
                      child: const Text('See Premium'),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Not now'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Simulated checkout: confirms, then switches the account to Premium.
  static Future<bool> upgrade(BuildContext context) async {
    final settings = context.read<SettingsController>();
    final price = AppFormatters.price(
      AppConfig.premiumMonthlyPrice,
      settings.currencySymbol,
    );
    final confirmed = await showConfirmDialog(
      context,
      title: 'Start Premium?',
      message:
          'Premium is $price a month. This is a demo checkout, so no '
          'payment is taken and Premium starts right away.',
      confirmLabel: 'Start Premium',
    );
    if (!confirmed || !context.mounted) return false;
    await ClosetFlows.guard(
      context,
      settings.startPremium,
      successMessage: 'Welcome to Premium',
    );
    return settings.isPremium;
  }

  static Future<void> cancel(BuildContext context) async {
    final settings = context.read<SettingsController>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancel Premium?',
      message:
          'You’ll move to the Free plan. Your clothes and outfits stay, '
          'but the AI Stylist locks and you can’t add clothes past '
          '${AppConfig.freeWardrobeLimit} pieces.',
      confirmLabel: 'Cancel Premium',
      cancelLabel: 'Keep Premium',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ClosetFlows.guard(
      context,
      settings.cancelPremium,
      successMessage: 'You’re on the Free plan',
    );
  }
}
