import 'package:flutter/material.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';

/// Small ink tag marking Premium status or a Premium-only feature.
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key});

  @override
  Widget build(BuildContext context) => const TagLabel(
    'Premium',
    inverted: true,
    icon: Icons.workspace_premium_outlined,
  );
}

/// Full-page placeholder for a feature the user's plan doesn't include.
class PremiumLockedView extends StatelessWidget {
  const PremiumLockedView({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.lock_outline_rounded,
      title: title,
      message: message,
      actionLabel: 'See Premium',
      onAction: () => AppNavigator.premium(context),
    );
  }
}

/// One plan on the Premium screen: name, price and what it includes.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.name,
    required this.price,
    required this.features,
    this.isCurrent = false,
    this.highlighted = false,
  });

  final String name;
  final String price;
  final List<(bool included, String label)> features;
  final bool isCurrent;

  /// Draws the card with an ink border, for the plan being promoted.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: highlighted ? palette.ink : palette.border,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: text.headlineSmall)),
              if (isCurrent) const TagLabel('Current plan'),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(price, style: text.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          for (final (included, label) in features)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    included ? Icons.check_rounded : Icons.close_rounded,
                    size: AppSizes.iconSm,
                    color: included ? palette.ink : palette.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      label,
                      style: text.bodyMedium?.copyWith(
                        color: included ? null : palette.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
