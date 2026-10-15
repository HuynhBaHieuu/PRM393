import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/extensions/model_presentation.dart';
import 'package:all_fits/core/utils/load_status.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/core/widgets/section_header.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cards.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/weather/controllers/weather_controller.dart';
import 'package:all_fits/features/weather/weather_advice.dart';

/// Today's weather for the user's city and outfits that suit it.
class WeatherSection extends StatelessWidget {
  const WeatherSection({super.key});

  static const int _maxCityLength = 60;

  /// Asks for a city, looks it up and saves it.
  static Future<void> chooseCity(BuildContext context) async {
    final settings = context.read<SettingsController>();
    final weather = context.read<WeatherController>();
    final name = await showTextInputDialog(
      context,
      title: 'Your city',
      initialValue: settings.weatherLocation?.name ?? '',
      hint: 'e.g. Ho Chi Minh City',
      maxLength: _maxCityLength,
      confirmLabel: 'Find',
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    try {
      final location = await weather.findCity(name);
      if (!context.mounted) return;
      if (location == null) {
        context.showSnack('We couldn’t find “$name”. Try another spelling.');
        return;
      }
      await settings.setWeatherLocation(location);
      await weather.refresh(location);
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = context.select<SettingsController, WeatherLocation?>(
      (s) => s.weatherLocation,
    );
    final weather = context.watch<WeatherController>();
    if (location != null && weather.needsRefresh(location)) {
      // Load after this frame; refresh() notifies listeners.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => weather.refresh(location),
      );
    }
    final report = weather.report;
    final showReport =
        location != null &&
        report != null &&
        report.location == location &&
        weather.status == LoadStatus.ready;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Dress for the weather',
          subtitle: location?.label,
          actionLabel: location == null ? null : 'Change',
          onAction: () => chooseCity(context),
        ),
        const SizedBox(height: AppSpacing.md),
        if (location == null)
          _Panel(
            child: _MessageRow(
              message: 'Set your city to get outfit picks for today’s weather.',
              actionLabel: 'Set city',
              onAction: () => chooseCity(context),
            ),
          )
        else if (showReport)
          _WeatherPicks(report: report)
        else if (weather.status == LoadStatus.failure)
          _Panel(
            child: _MessageRow(
              message: describeError(weather.error!),
              actionLabel: 'Retry',
              onAction: () => weather.refresh(location),
            ),
          )
        else
          const _Panel(child: AppLoadingView()),
      ],
    );
  }
}

class _WeatherPicks extends StatelessWidget {
  const _WeatherPicks({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final advice = WeatherAdvice(report);
    final wardrobe = context.watch<WardrobeController>();
    final picks = advice.pickOutfits(
      context.watch<OutfitController>().outfits,
      (outfit) => wardrobe.itemsByIds(outfit.itemIds),
    );
    final footer = MediaQuery.textScalerOf(context)
        .scale(AppSizes.outfitTileFooterHeight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          child: Row(
            children: [
              Icon(report.condition.icon, size: AppSizes.iconLg),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${report.temperature.round()}° · '
                      '${report.condition.label}',
                      style: text.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'H ${report.high.round()}°  L ${report.low.round()}°  ·  '
                      '${report.rainChance}% chance of rain',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      advice.summary,
                      style: text.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (picks.isEmpty)
          _Panel(
            child: _MessageRow(
              message:
                  'No saved outfits match today yet. Tag clothes with '
                  'seasons to get better picks.',
              actionLabel: 'Create',
              onAction: () => AppNavigator.createOutfit(context),
            ),
          )
        else
          SizedBox(
            height:
                AppSizes.recentOutfitWidth / AppSizes.outfitImageAspect +
                footer,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              itemCount: picks.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final outfit = picks[index];
                return SizedBox(
                  width: AppSizes.recentOutfitWidth,
                  child: OutfitCard(
                    outfit: outfit,
                    onTap: () => AppNavigator.outfitDetail(context, outfit.id),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Bordered box matching the other inline panels on Home.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: context.palette.border),
        ),
        child: child,
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}
