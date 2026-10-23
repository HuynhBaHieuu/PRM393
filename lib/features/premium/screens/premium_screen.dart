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

/// Compares the Free and Premium plans and handles upgrading or cancelling.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  static const List<(bool, String)> _freeFeatures = [
    (true, 'Up to ${AppConfig.freeWardrobeLimit} clothing items'),
    (true, 'Outfits, planner and insights'),
    (true, 'Weather outfit picks'),
    (
      true,
      'AI Stylist: ${AppConfig.freeStylistMessagesPerDay} messages a day',
    ),
  ];

  static const List<(bool, String)> _premiumFeatures = [
    (true, 'Unlimited clothing items'),
    (true, 'Outfits, planner and insights'),
    (true, 'Weather outfit picks'),
    (true, 'Unlimited AI Stylist chat'),
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
        : '${AppFormatters.price(AppConfig.premiumMonthlyPrice, settings.currencySymbol)} / month';

    final free = PlanCard(
      name: 'Free',
      price: '${AppFormatters.price(0, settings.currencySymbol)} forever',
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
      appBar: AppBar(title: const Text('All Fits Premium')),
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
                const Eyebrow('Plans'),
                const SizedBox(height: AppSpacing.xs),
                Text('Style more, limit less.', style: text.headlineMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isPremium
                      ? 'You have every feature unlocked.'
                      : 'Chat with the AI Stylist as much as you like and '
                            'make room for your whole wardrobe.',
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
                          'Active until '
                          '${AppFormatters.shortDate(premiumUntil)}',
                          style: text.bodySmall,
                        )
                      else if (premiumSince != null)
                        Text(
                          'Active since '
                          '${AppFormatters.shortDate(premiumSince)}',
                          style: text.bodySmall,
                        ),
                    ],
                  )
                else
                  Text(
                    '$itemCount of ${AppConfig.freeWardrobeLimit} '
                    'wardrobe spaces used',
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
                      'Add ${AppConfig.premiumDays} days for '
                      '${AppFormatters.price(AppConfig.premiumPriceVnd.toDouble(), '')} VND',
                    ),
                  )
                else if (isPremium)
                  OutlinedButton(
                    onPressed: () => PremiumFlows.cancel(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.danger,
                    ),
                    child: const Text('Cancel Premium'),
                  )
                else
                  FilledButton(
                    onPressed: () => PremiumFlows.upgrade(context),
                    child: Text('Upgrade for $premiumPrice'),
                  ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  paid
                      ? 'Pay by bank transfer or VietQR through payOS. '
                            'Premium lasts ${AppConfig.premiumDays} days and '
                            'doesn’t renew by itself.'
                      : 'Demo checkout: no payment is taken. You can cancel '
                            'any time from this screen.',
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
