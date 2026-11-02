import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/section_header.dart';
import 'package:all_fits/data/remote/payos_checkout.dart';
import 'package:all_fits/features/premium/premium_flows.dart';
import 'package:all_fits/features/premium/widgets/premium_widgets.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/core/l10n/l10n.dart';

/// Compares the Free and Premium plans and handles upgrading or cancelling.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  static List<(bool, String)> get _freeFeatures => [
    (true, tr('Up to {0} clothing items', [AppConfig.freeWardrobeLimit])),
    (true, tr('Up to {0} collections', [AppConfig.freeCollectionLimit])),
    (true, tr('Up to {0} custom tags', [AppConfig.freeTagLimit])),
    (true, tr('{0} trip at a time', [AppConfig.freeActiveTripLimit])),
    (true, tr('Outfits, planner and insights')),
    (true, tr('Weather outfit picks')),
    (
      true,
      tr('AI Stylist: {0} messages a day', [
        AppConfig.freeStylistMessagesPerDay,
      ]),
    ),
    (true, tr('AI Try On: {0} free try', [AppConfig.freeTryOns])),
    (
      true,
      tr('AI detection: {0} photos a month', [
        AppConfig.freeDetectionsPerMonth,
      ]),
    ),
  ];

  static List<(bool, String)> get _premiumFeatures => [
    (true, tr('Unlimited clothing items')),
    (true, tr('Unlimited collections')),
    (true, tr('Unlimited custom tags')),
    (true, tr('Unlimited trips')),
    (true, tr('Outfits, planner and insights')),
    (true, tr('Weather outfit picks')),
    (true, tr('Unlimited AI Stylist chat')),
    (
      true,
      tr('AI Try On: {0} pictures a month', [AppConfig.premiumTryOnsPerMonth]),
    ),
    (true, tr('Unlimited AI detection')),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final itemCount = context.select<WardrobeController, int>(
      (w) => w.allItems.length,
    );
    final palette = context.palette;
    final text = context.textTheme;
    final isPremium = settings.isPremium;
    final premiumSince = settings.settings.premiumSince;
    final premiumUntil = settings.premiumUntil;
    // Real payments through payOS; without them Premium is a demo.
    final paid = context.read<PayOSCheckout?>() != null;
    final premiumPrice = paid
        ? PremiumFlows.payOSPrice
        : tr('{0} / month', [
            AppFormatters.price(
              AppConfig.premiumMonthlyPrice,
              settings.currencySymbol,
            ),
          ]);

    final free = PlanCard(
      name: tr('Free'),
      price: tr('{0} forever', [
        AppFormatters.price(0, settings.currencySymbol),
      ]),
      features: _freeFeatures,
      isCurrent: !isPremium,
    );
    final premium = PlanCard(
      name: 'Premium',
      price: premiumPrice,
      features: _premiumFeatures,
      isCurrent: isPremium,
      highlighted: true,
    );

    return Scaffold(
      appBar: AppBar(title: Text(tr('All Fits Premium'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.md,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        children: [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Eyebrow(tr('Plans')),
                const SizedBox(height: AppSpacing.xs),
                Text(tr('Style more, limit less.'), style: text.headlineMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isPremium
                      ? tr('You have every feature unlocked.')
                      : tr(
                          'Chat with the AI Stylist as much as you like and '
                          'make room for your whole wardrobe.',
                        ),
                  style: text.bodyLarge?.copyWith(color: palette.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (isPremium)
                  Row(
                    children: [
                      const PremiumBadge(),
                      const SizedBox(width: AppSpacing.xs),
                      if (premiumUntil != null)
                        Text(
                          tr('Active until {0}', [
                            AppFormatters.shortDate(premiumUntil),
                          ]),
                          style: text.bodySmall,
                        )
                      else if (premiumSince != null)
                        Text(
                          tr('Active since {0}', [
                            AppFormatters.shortDate(premiumSince),
                          ]),
                          style: text.bodySmall,
                        ),
                    ],
                  )
                else
                  Text(
                    tr('{0} of {1} wardrobe spaces used', [
                      itemCount,
                      AppConfig.freeWardrobeLimit,
                    ]),
                    style: text.bodySmall,
                  ),
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= AppSizes.maxFormWidth) {
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: free),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: premium),
                          ],
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        premium,
                        const SizedBox(height: AppSpacing.sm),
                        free,
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                if (isPremium && paid)
                  OutlinedButton(
                    onPressed: () => PremiumFlows.upgrade(context),
                    child: Text(
                      tr('Add {0} days for {1} VND', [
                        AppConfig.premiumDays,
                        AppFormatters.price(
                          AppConfig.premiumPriceVnd.toDouble(),
                          '',
                        ),
                      ]),
                    ),
                  )
                else if (isPremium)
                  OutlinedButton(
                    onPressed: () => PremiumFlows.cancel(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.danger,
                    ),
                    child: Text(tr('Cancel Premium')),
                  )
                else
                  FilledButton(
                    onPressed: () => PremiumFlows.upgrade(context),
                    child: Text(tr('Upgrade for {0}', [premiumPrice])),
                  ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  paid
                      ? tr(
                          'Pay by bank transfer or VietQR through payOS. Premium lasts {0} days and doesn’t renew by itself.',
                          [AppConfig.premiumDays],
                        )
                      : tr(
                          'Demo checkout: no payment is taken. You can cancel '
                          'any time from this screen.',
                        ),
                  textAlign: TextAlign.center,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
