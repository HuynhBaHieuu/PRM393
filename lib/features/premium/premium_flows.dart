import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/remote/payos_checkout.dart';
import 'package:all_fits/features/collections/controllers/collection_controller.dart';
import 'package:all_fits/features/premium/widgets/premium_widgets.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// Plan checks and the upgrade / cancel flows: payOS with Supabase, a
/// simulated checkout otherwise.
abstract final class PremiumFlows {
  /// Price and length of paid Premium, e.g. "2,000 VND / 30 days".
  static String get payOSPrice =>
      '${AppFormatters.price(AppConfig.premiumPriceVnd.toDouble(), '')} VND'
      ' / ${AppConfig.premiumDays} days';

  /// Whether the user's plan has room for another clothing item.
  /// Archived pieces count, since they still take up space.
  static bool canAddClothing(BuildContext context) {
    final plan = context.read<SettingsController>().plan;
    return plan.canAddItem(context.read<WardrobeController>().allItems.length);
  }

  /// Whether the user's plan has room for another collection.
  static bool canAddCollection(BuildContext context) {
    final plan = context.read<SettingsController>().plan;
    return plan.canAddCollection(
      context.read<CollectionController>().collections.length,
    );
  }

  /// Whether the user's plan has room for another distinct tag.
  static bool canAddTag(BuildContext context) {
    final plan = context.read<SettingsController>().plan;
    return plan.canAddTag(context.read<WardrobeController>().tags.length);
  }

  /// Explains the Free tag limit and offers Premium.
  static Future<void> showTagLimit(BuildContext context) => _showLimit(
    context,
    title: 'Tag limit reached',
    message:
        'The Free plan has '
        '${AppFormatters.count(AppConfig.freeTagLimit, 'custom tag')}. '
        'Your tags keep working; go Premium to create more, or reuse one '
        'you already have.',
  );

  /// Explains the Free wardrobe limit and offers Premium.
  static Future<void> showWardrobeLimit(BuildContext context) => _showLimit(
    context,
    title: 'Your wardrobe is full',
    message:
        'The Free plan holds '
        '${AppFormatters.count(AppConfig.freeWardrobeLimit, 'piece')}, '
        'archived ones included. Go Premium for unlimited '
        'space, or delete pieces you no longer wear.',
  );

  /// Explains the Free collection limit and offers Premium.
  static Future<void> showCollectionLimit(BuildContext context) => _showLimit(
    context,
    title: 'Collection limit reached',
    message:
        'The Free plan holds '
        '${AppFormatters.count(AppConfig.freeCollectionLimit, 'collection')}. '
        'Go Premium for unlimited collections, or delete one you no '
        'longer need.',
  );

  static Future<void> _showLimit(
    BuildContext context, {
    required String title,
    required String message,
  }) {
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
              SheetHeader(title: title),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      message,
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

  /// Buys (or extends) Premium. Returns whether the user has Premium now.
  static Future<bool> upgrade(BuildContext context) async {
    final payments = context.read<PayOSCheckout?>();
    if (payments != null) return _payWithPayOS(context, payments);
    return _simulatedUpgrade(context);
  }

  /// Opens a payOS payment link and waits for the payment. The server starts
  /// Premium; the app then reloads the plan from it.
  static Future<bool> _payWithPayOS(
    BuildContext context,
    PayOSCheckout payments,
  ) async {
    final settings = context.read<SettingsController>();
    final PayOSOrder order;
    try {
      order = await payments.create();
      await payments.open(order.checkoutUrl);
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
      return false;
    }
    if (!context.mounted) return false;
    final status = await showDialog<PaymentStatus>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentWaitDialog(payments: payments, order: order),
    );
    if (!context.mounted) return false;
    switch (status) {
      case PaymentStatus.paid:
        await ClosetFlows.guard(context, settings.load);
        final until = settings.premiumUntil;
        if (context.mounted && until != null) {
          context.showSnack(
            'Premium is active until ${AppFormatters.shortDate(until)}',
          );
        }
      case PaymentStatus.cancelled:
        context.showSnack('Payment cancelled');
      case PaymentStatus.expired:
        context.showSnack('The payment link expired. Please try again.');
      case PaymentStatus.pending || null:
        context.showSnack(
          'If you paid, Premium starts once payOS confirms it.',
        );
    }
    return settings.isPremium;
  }

  /// Simulated checkout: confirms, then switches the account to Premium.
  static Future<bool> _simulatedUpgrade(BuildContext context) async {
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
          'but the AI Stylist drops to '
          '${AppConfig.freeStylistMessagesPerDay} messages a day and you '
          'can’t add clothes past ${AppConfig.freeWardrobeLimit} pieces '
          'or collections past ${AppConfig.freeCollectionLimit}.',
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
