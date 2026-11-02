import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/outfit_board.dart';
import 'package:all_fits/data/remote/payos_checkout.dart';
import 'package:all_fits/features/collections/controllers/collection_controller.dart';
import 'package:all_fits/features/premium/widgets/premium_widgets.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/trips/trip_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/core/l10n/l10n.dart';

/// Plan checks and the upgrade / cancel flows: payOS with Supabase, a
/// simulated checkout otherwise.
abstract final class PremiumFlows {
  /// Price and length of paid Premium, e.g. "2,000 VND / 30 days".
  static String get payOSPrice => tr('{0} VND / {1} days', [
    AppFormatters.price(AppConfig.premiumPriceVnd.toDouble(), ''),
    AppConfig.premiumDays,
  ]);

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

  /// Whether the user's plan has room for another trip that hasn't ended.
  /// [excluding] is a trip being edited, which doesn't count.
  static bool canAddTrip(BuildContext context, {String? excluding}) {
    final plan = context.read<SettingsController>().plan;
    final trips = context.read<TripController>();
    final editing = excluding == null ? null : trips.tripById(excluding);
    final counted = editing != null && trips.isActive(editing) ? 1 : 0;
    return plan.canAddTrip(trips.activeCount - counted);
  }

  /// Explains which stickers and hairstyles the Free plan has.
  static Future<void> showStickerLimit(BuildContext context) => _showLimit(
    context,
    title: tr('A Premium sticker'),
    message: tr(
      'The Free plan has a few stickers and {0}, and every background. Go Premium for all of them. Stickers already on your outfits stay either way.',
      [AppFormatters.count(Hairstyle.freeCount, 'hairstyle')],
    ),
  );

  /// Explains the Free trip limit and offers Premium.
  static Future<void> showTripLimit(BuildContext context) => _showLimit(
    context,
    title: tr('You already have a trip planned'),
    message: tr(
      'The Free plan has {0} at a time until it ends. Go Premium to plan as many trips as you like, or delete the one you have.',
      [AppFormatters.count(AppConfig.freeActiveTripLimit, 'trip')],
    ),
  );

  /// Whether the user's plan has room for another distinct tag.
  static bool canAddTag(BuildContext context) {
    final plan = context.read<SettingsController>().plan;
    return plan.canAddTag(context.read<WardrobeController>().tags.length);
  }

  /// Explains the Free tag limit and offers Premium.
  static Future<void> showTagLimit(BuildContext context) => _showLimit(
    context,
    title: tr('Tag limit reached'),
    message: tr(
      'The Free plan has {0}. Your tags keep working; go Premium to create more, or reuse one you already have.',
      [AppFormatters.count(AppConfig.freeTagLimit, tr('custom tag'))],
    ),
  );

  /// Explains the Free wardrobe limit and offers Premium.
  static Future<void> showWardrobeLimit(BuildContext context) => _showLimit(
    context,
    title: tr('Your wardrobe is full'),
    message: tr(
      'The Free plan holds {0}, archived ones included. Go Premium for unlimited space, or delete pieces you no longer wear.',
      [AppFormatters.count(AppConfig.freeWardrobeLimit, 'piece')],
    ),
  );

  /// Explains the Free collection limit and offers Premium.
  static Future<void> showCollectionLimit(BuildContext context) => _showLimit(
    context,
    title: tr('Collection limit reached'),
    message: tr(
      'The Free plan holds {0}. Go Premium for unlimited collections, or delete one you no longer need.',
      [AppFormatters.count(AppConfig.freeCollectionLimit, 'collection')],
    ),
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
                      child: Text(tr('See Premium')),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text(tr('Not now')),
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
            tr('Premium is active until {0}', [AppFormatters.shortDate(until)]),
          );
        }
      case PaymentStatus.cancelled:
        context.showSnack(tr('Payment cancelled'));
      case PaymentStatus.expired:
        context.showSnack(tr('The payment link expired. Please try again.'));
      case PaymentStatus.pending || null:
        context.showSnack(
          tr('If you paid, Premium starts once payOS confirms it.'),
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
      title: tr('Start Premium?'),
      message: tr(
        'Premium is {0} a month. This is a demo checkout, so no payment is taken and Premium starts right away.',
        [price],
      ),
      confirmLabel: tr('Start Premium'),
    );
    if (!confirmed || !context.mounted) return false;
    await ClosetFlows.guard(
      context,
      settings.startPremium,
      successMessage: tr('Welcome to Premium'),
    );
    return settings.isPremium;
  }

  static Future<void> cancel(BuildContext context) async {
    final settings = context.read<SettingsController>();
    final confirmed = await showConfirmDialog(
      context,
      title: tr('Cancel Premium?'),
      message: tr(
        'You’ll move to the Free plan. Your clothes and outfits stay, but the AI Stylist drops to {0} messages a day and you can’t add clothes past {1} pieces or collections past {2}.',
        [
          AppConfig.freeStylistMessagesPerDay,
          AppConfig.freeWardrobeLimit,
          AppConfig.freeCollectionLimit,
        ],
      ),
      confirmLabel: tr('Cancel Premium'),
      cancelLabel: tr('Keep Premium'),
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ClosetFlows.guard(
      context,
      settings.cancelPremium,
      successMessage: tr('You’re on the Free plan'),
    );
  }
}
