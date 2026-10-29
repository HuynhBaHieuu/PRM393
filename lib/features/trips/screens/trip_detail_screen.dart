import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/extensions/model_presentation.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/data/models/trip.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cover.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/trips/packing_list.dart';
import 'package:all_fits/features/trips/trip_controller.dart';
import 'package:all_fits/features/trips/trip_flows.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/weather/controllers/weather_controller.dart';

enum _TripMenu { edit, copy, untick, delete }

/// One trip: an outfit for each day, and the packing list made from them.
class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  Future<void> _onMenu(
    BuildContext context,
    Trip trip,
    _TripMenu choice,
  ) async {
    switch (choice) {
      case _TripMenu.edit:
        await TripFlows.edit(context, trip);
      case _TripMenu.copy:
        await TripFlows.copyPackingList(context, trip);
      case _TripMenu.untick:
        await context.read<TripController>().resetPacking(trip.id);
      case _TripMenu.delete:
        final deleted = await TripFlows.delete(context, trip);
        if (deleted && context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.select<TripController, Trip?>(
      (c) => c.tripById(tripId),
    );
    if (trip == null) {
      return const NotFoundView(
        title: 'Trip not found',
        message: 'This trip has been deleted.',
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trip.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                '${AppFormatters.shortDate(trip.startDate)} – '
                '${AppFormatters.shortDate(trip.endDate)}'
                '${trip.location == null ? '' : ' · ${trip.location!.name}'}',
                style: context.textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            PopupMenuButton<_TripMenu>(
              tooltip: 'More',
              onSelected: (choice) => _onMenu(context, trip, choice),
              itemBuilder: (_) => const [
                PopupMenuItem(value: _TripMenu.edit, child: Text('Edit trip')),
                PopupMenuItem(
                  value: _TripMenu.copy,
                  child: Text('Copy packing list'),
                ),
                PopupMenuItem(
                  value: _TripMenu.untick,
                  child: Text('Untick everything'),
                ),
                PopupMenuItem(
                  value: _TripMenu.delete,
                  child: Text('Delete trip'),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Days'),
              Tab(text: 'Packing list'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DaysTab(trip: trip),
            _PackingTab(trip: trip),
          ],
        ),
      ),
    );
  }
}

class _DaysTab extends StatefulWidget {
  const _DaysTab({required this.trip});

  final Trip trip;

  @override
  State<_DaysTab> createState() => _DaysTabState();
}

class _DaysTabState extends State<_DaysTab> {
  /// What [_forecast] was loaded for: the city and the dates.
  (WeatherLocation, DateTime, DateTime)? _loadedFor;
  Future<Map<DateTime, DayForecast>>? _forecast;

  @override
  void initState() {
    super.initState();
    _loadForecast();
  }

  @override
  void didUpdateWidget(_DaysTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadForecast();
  }

  void _loadForecast({bool force = false}) {
    final trip = widget.trip;
    final location = trip.location;
    if (location == null) {
      _loadedFor = null;
      _forecast = null;
      return;
    }
    final key = (location, trip.startDate, trip.endDate);
    if (!force && key == _loadedFor) return;
    _loadedFor = key;
    _forecast = context
        .read<WeatherController>()
        .forecast(location, start: trip.startDate, end: trip.endDate)
        .then((days) => {for (final d in days) d.date: d});
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final outfits = context.watch<OutfitController>();
    final wardrobe = context.watch<WardrobeController>();
    final today = context.read<ClosetActions>().today;
    final lastForecastDay = DateHelpers.addDays(
      today,
      AppConfig.forecastDays - 1,
    );
    final days = trip.days;
    return FutureBuilder<Map<DateTime, DayForecast>>(
      future: _forecast,
      builder: (context, snapshot) {
        final forecast = snapshot.data ?? const <DateTime, DayForecast>{};
        final loading =
            _forecast != null &&
            snapshot.connectionState != ConnectionState.done;
        return ListView.separated(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.xxl,
          ),
          itemCount: days.length + 1,
          separatorBuilder: (_, index) =>
              index == 0 ? const SizedBox.shrink() : const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _DaysHeader(
                trip: trip,
                weatherFailed: snapshot.hasError,
                onRetryWeather: () =>
                    setState(() => _loadForecast(force: true)),
                onSuggest: loading
                    ? null
                    : () => TripFlows.suggestOutfits(
                        context,
                        trip,
                        forecast: forecast,
                      ),
              );
            }
            final day = days[index - 1];
            final outfitId = trip.outfitOn(day);
            final outfit = outfitId == null
                ? null
                : outfits.outfitById(outfitId);
            final weather = trip.location == null || day.isBefore(today)
                ? null
                : _DayWeather(
                    forecast: forecast[day],
                    loading: loading,
                    tooFar: day.isAfter(lastForecastDay),
                  );
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.page,
                vertical: AppSpacing.xxs,
              ),
              leading: SizedBox(
                width: 52,
                height: 64,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: outfit == null
                      ? ColoredBox(
                          color: context.palette.surfaceMuted,
                          child: Icon(
                            Icons.add_rounded,
                            color: context.palette.textSecondary,
                          ),
                        )
                      : OutfitCover(
                          outfit: outfit,
                          items: wardrobe.itemsByIds(outfit.itemIds),
                        ),
                ),
              ),
              title: Text(
                'Day $index · ${AppFormatters.weekdayName(day)}, '
                '${AppFormatters.shortDate(day)}',
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outfit?.name ?? 'Tap to choose an outfit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  ?weather,
                ],
              ),
              trailing: outfit == null
                  ? null
                  : IconButton(
                      tooltip: 'Clear this day',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => TripFlows.clearDay(context, trip, day),
                    ),
              onTap: () => TripFlows.chooseOutfit(context, trip, day),
            );
          },
        );
      },
    );
  }
}

/// Where the trip's weather comes from, and the AI stylist button.
class _DaysHeader extends StatelessWidget {
  const _DaysHeader({
    required this.trip,
    required this.weatherFailed,
    required this.onRetryWeather,
    required this.onSuggest,
  });

  final Trip trip;
  final bool weatherFailed;
  final VoidCallback onRetryWeather;
  final VoidCallback? onSuggest;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final location = trip.location;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (location == null)
            TextButton.icon(
              onPressed: () => TripFlows.edit(context, trip),
              style: TextButton.styleFrom(alignment: Alignment.centerLeft),
              icon: const Icon(Icons.wb_sunny_outlined),
              label: const Text('Add a city to see each day’s weather'),
            )
          else if (weatherFailed)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Weather for ${location.name} is unavailable right now.',
                    style: text.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: onRetryWeather,
                  child: const Text('Retry'),
                ),
              ],
            )
          else
            Text(
              'Weather in ${location.label}. Forecasts reach '
              '${AppConfig.forecastDays} days ahead.',
              style: text.bodySmall,
            ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: onSuggest,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Suggest outfits with AI Stylist'),
          ),
        ],
      ),
    );
  }
}

/// "☀ 28° / 20° · 10%", or why there is no forecast.
class _DayWeather extends StatelessWidget {
  const _DayWeather({
    required this.forecast,
    required this.loading,
    required this.tooFar,
  });

  final DayForecast? forecast;
  final bool loading;
  final bool tooFar;

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.bodySmall;
    final f = forecast;
    if (f == null) {
      if (loading) return const SizedBox.shrink();
      return Text(tooFar ? 'No forecast yet' : 'No forecast', style: style);
    }
    return Row(
      children: [
        Icon(f.condition.icon, size: 14, color: style?.color),
        const SizedBox(width: AppSpacing.xxs),
        Flexible(
          child: Text(
            '${f.condition.label} · ${f.high.round()}° / ${f.low.round()}°'
            '${f.rainChance >= 30 ? ' · ${f.rainChance}% rain' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

class _PackingTab extends StatelessWidget {
  const _PackingTab({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final list = PackingList.of(
      trip,
      outfitById: context.watch<OutfitController>().outfitById,
      itemById: context.watch<WardrobeController>().itemById,
    );
    final controller = context.read<TripController>();
    final text = context.textTheme;

    if (list.lines.isEmpty && list.extras.isEmpty) {
      return AppEmptyState(
        icon: Icons.checklist_rounded,
        title: 'Nothing to pack yet',
        message:
            'Choose outfits on the Days tab: their pieces show up here, '
            'each listed once.',
        actionLabel: 'Add something else',
        onAction: () => TripFlows.addExtra(context, trip),
      );
    }

    final progress = list.total == 0 ? 0.0 : list.packedCount / list.total;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl * 2),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${list.packedCount} of ${list.total} packed',
                style: text.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: LinearProgressIndicator(value: progress, minHeight: 8),
              ),
            ],
          ),
        ),
        for (final MapEntry(key: category, value: lines)
            in list.byCategory.entries) ...[
          _SectionTitle(category.label),
          for (final line in lines)
            CheckboxListTile(
              value: line.packed,
              onChanged: (packed) =>
                  controller.setItemPacked(trip.id, line.item.id, packed!),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.page,
              ),
              title: Text(line.item.name),
              subtitle: line.days > 1
                  ? Text('Worn ${AppFormatters.count(line.days, 'day')}')
                  : null,
              secondary: SizedBox.square(
                dimension: 44,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: ClothingImage(item: line.item, decodeWidth: 120),
                ),
              ),
            ),
        ],
        _SectionTitle(
          PackingList.extrasTitle,
          trailing: TextButton.icon(
            onPressed: () => TripFlows.addExtra(context, trip),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add'),
          ),
        ),
        if (list.extras.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Text(
              'Things that aren’t clothes, like a phone charger or '
              'sunscreen.',
              style: text.bodySmall,
            ),
          ),
        for (final extra in list.extras)
          CheckboxListTile(
            value: extra.packed,
            onChanged: (packed) =>
                controller.setExtraPacked(trip.id, extra.id, packed!),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.page,
            ),
            title: Text(extra.label),
            secondary: IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => controller.removeExtra(trip.id, extra.id),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.xxs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: context.textTheme.labelMedium,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
