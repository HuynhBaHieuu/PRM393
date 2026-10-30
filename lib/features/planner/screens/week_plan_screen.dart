import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/constants/app_durations.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/extensions/model_presentation.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/controllers/outfit_draft.dart';
import 'package:all_fits/features/outfits/outfit_ideas.dart';
import 'package:all_fits/features/outfits/outfit_layout.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cover.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/planner/week_planner.dart';
import 'package:all_fits/features/planner/widgets/planner_actions.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/weather/controllers/weather_controller.dart';

/// When the week starts, counted from today.
enum _Start {
  today('Today', 0),
  tomorrow('Tomorrow', 1);

  const _Start(this.label, this.offset);

  final String label;
  final int offset;
}

/// One day of the plan being made.
class _PlanDay {
  _PlanDay(this.day, {this.existing, this.worn = false});

  final DateTime day;

  /// The outfit already on the planner for this day, kept unless the user
  /// swaps it for a new look.
  final Outfit? existing;

  /// [existing] was worn, so the day can't change.
  final bool worn;

  /// A new look for this day, saved to the planner.
  OutfitIdea? idea;
  bool skipped = false;

  /// Bumped on every swap so each one gives another look.
  int swaps = 0;

  bool get saves => idea != null && !skipped;
}

/// Smart Outfit Planner: a different outfit for each of the next seven
/// days, matched to each day's forecast, that the user can swap and save
/// to the planner in one go. Pops with the first planned day.
class WeekPlanScreen extends StatefulWidget {
  const WeekPlanScreen({super.key});

  @override
  State<WeekPlanScreen> createState() => _WeekPlanScreenState();
}

class _WeekPlanScreenState extends State<WeekPlanScreen> {
  late final DateTime _today = context.read<ClosetActions>().today;
  _Start _start = _Start.today;
  List<_PlanDay> _days = const [];
  Map<DateTime, DayForecast> _forecast = const {};
  bool _loading = true;
  bool _saving = false;

  /// Bumped by "Shuffle all".
  int _shuffles = 0;

  WardrobeController get _wardrobe => context.read<WardrobeController>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final location = context.read<SettingsController>().weatherLocation;
    if (location != null) {
      try {
        final days = await context.read<WeatherController>().forecast(
          location,
          start: _today,
          end: DateHelpers.addDays(_today, WeekPlanner.length),
        );
        _forecast = {for (final d in days) DateHelpers.dateOnly(d.date): d};
      } catch (_) {
        // Without a forecast the season comes from the month.
      }
    }
    if (!mounted) return;
    _plan();
    setState(() => _loading = false);
  }

  WeatherReport? _weatherOn(DateTime day) {
    final location = context.read<SettingsController>().weatherLocation;
    final forecast = _forecast[day];
    return location == null || forecast == null
        ? null
        : forecast.toReport(location);
  }

  /// Fresh looks for every day that has nothing planned yet.
  void _plan() {
    final planner = context.read<PlannerController>();
    final outfits = context.read<OutfitController>();
    final days = [
      for (var i = 0; i < WeekPlanner.length; i++)
        DateHelpers.addDays(_today, _start.offset + i),
    ];
    final plan = <_PlanDay>[];
    for (final day in days) {
      final entry = planner.dayPlan(day);
      final outfitId = (entry.worn ?? entry.planned)?.outfitId;
      final outfit = outfitId == null ? null : outfits.outfitById(outfitId);
      plan.add(_PlanDay(day, existing: outfit, worn: entry.worn != null));
    }
    final open = plan.where((d) => d.existing == null).toList();
    final ideas = WeekPlanner.planWeek(
      _wardrobe.activeItems,
      days: [for (final d in open) d.day],
      weather: {for (final d in open) d.day: ?_weatherOn(d.day)},
      kept: [
        for (final d in plan)
          if (d.existing case final outfit?) outfit.itemIds,
      ],
      variant: _shuffles,
    );
    for (var i = 0; i < open.length; i++) {
      open[i].idea = ideas[i];
    }
    _days = plan;
  }

  void _setStart(_Start start) {
    if (start == _start) return;
    setState(() {
      _start = start;
      _plan();
    });
  }

  void _shuffleAll() => setState(() {
    _shuffles++;
    _plan();
  });

  /// The look each day will have, as item ids: its new one, else the one
  /// already planned.
  List<String>? _lookOf(_PlanDay day) =>
      day.idea?.itemIds ?? day.existing?.itemIds;

  void _swap(_PlanDay day) {
    final others = [
      for (final other in _days)
        if (other != day && !other.skipped) ?_lookOf(other),
      // Counting the current look too steers the swap away from it.
      ?_lookOf(day),
    ];
    final idea = WeekPlanner.lookFor(
      _wardrobe.activeItems,
      day: day.day,
      others: others,
      weather: _weatherOn(day.day),
      variant: ++day.swaps,
    );
    if (idea == null ||
        OutfitIdeas.lookKey(idea.itemIds) ==
            OutfitIdeas.lookKey(_lookOf(day) ?? const [])) {
      context.showSnack('No other look yet. Add more clothes for variety.');
      return;
    }
    setState(() {
      day.idea = idea;
      day.skipped = false;
    });
  }

  /// Puts the outfit that was planned before back on a swapped day.
  void _keepExisting(_PlanDay day) => setState(() => day.idea = null);

  Future<void> _save() async {
    final toSave = _days.where((d) => d.saves).toList();
    if (toSave.isEmpty || _saving) return;
    setState(() => _saving = true);
    final outfits = context.read<OutfitController>();
    final closet = context.read<ClosetActions>();
    final navigator = Navigator.of(context);
    // A look the user already saved is planned as is, not saved twice.
    final saved = {
      for (final outfit in outfits.outfits)
        OutfitIdeas.lookKey(outfit.itemIds): outfit.id,
    };
    try {
      for (final day in toSave) {
        final idea = day.idea!;
        final key = OutfitIdeas.lookKey(idea.itemIds);
        final outfitId =
            saved[key] ??
            (await outfits.createOutfit(
              OutfitDraft(name: idea.title, itemIds: idea.itemIds),
            )).id;
        saved[key] = outfitId;
        await closet.planOutfit(outfitId, day.day);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        context.showErrorSnack(error);
      }
      return;
    }
    navigator.pop(toSave.first.day);
    if (mounted) {
      context.showSnack(
        'Planned ${AppFormatters.count(toSave.length, 'outfit')}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeController>();
    final looks = [
      for (final day in _days)
        if (!day.skipped)
          if (day.idea case final idea?)
            idea.items
          else if (day.existing case final outfit?)
            wardrobe.itemsByIds(outfit.itemIds),
    ];
    final empty = !_loading && looks.isEmpty;
    final saving = _days.where((d) => d.saves).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan my week'),
        actions: [
          if (!empty)
            TextButton.icon(
              onPressed: _loading || _saving ? null : _shuffleAll,
              icon: const Icon(Icons.shuffle_rounded, size: AppSizes.iconSm),
              label: const Text('Shuffle'),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : empty
          ? AppEmptyState(
              icon: Icons.checkroom_outlined,
              title: 'Not enough clothes yet',
              message:
                  'Add tops, bottoms and shoes, and the planner will put '
                  'together a different outfit for every day.',
              actionLabel: 'Add clothes',
              onAction: () => AppNavigator.addClothing(context),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              children: [
                _Header(
                  start: _start,
                  onStart: _saving ? null : _setStart,
                  repeats: WeekPlanner.repeats(looks),
                  city: _forecast.isEmpty
                      ? null
                      : context.read<SettingsController>().weatherLocation,
                ),
                for (final day in _days)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      0,
                      AppSpacing.page,
                      AppSpacing.sm,
                    ),
                    child: _DayCard(
                      day: day,
                      label: PlannerActions.dayLabel(day.day, _today),
                      forecast: _forecast[day.day],
                      items:
                          day.idea?.items ??
                          (day.existing == null
                              ? const []
                              : wardrobe.itemsByIds(day.existing!.itemIds)),
                      onSwap: _saving || day.worn ? null : () => _swap(day),
                      onSkip: _saving || day.idea == null
                          ? null
                          : () => setState(() => day.skipped = !day.skipped),
                      onKeep: _saving ? null : () => _keepExisting(day),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: _loading || empty
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.xs,
                  AppSpacing.page,
                  AppSpacing.sm,
                ),
                child: FilledButton(
                  onPressed: saving == 0 || _saving ? null : _save,
                  child: _saving
                      ? SizedBox.square(
                          dimension: AppSizes.iconSm,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.palette.onInk,
                          ),
                        )
                      : Text(
                          saving == 0
                              ? 'Nothing new to plan'
                              : 'Save ${AppFormatters.count(saving, 'outfit')} '
                                    'to planner',
                        ),
                ),
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.start,
    required this.onStart,
    required this.repeats,
    required this.city,
  });

  final _Start start;
  final ValueChanged<_Start>? onStart;
  final int repeats;
  final WeatherLocation? city;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A different outfit for each day, from your own clothes'
            '${city == null ? '' : ' and ${city!.name}’s forecast'}.',
            style: text.bodyMedium?.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledSection(
            label: 'Starts',
            child: PillGroup<_Start>(
              options: _Start.values,
              selected: {start},
              labelOf: (s) => s.label,
              onToggle: (s) => onStart?.call(s),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                repeats == 0
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                size: AppSizes.iconSm,
                color: repeats == 0 ? palette.success : palette.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  repeats == 0
                      ? 'No top, bottom or dress is repeated this week.'
                      : '${AppFormatters.count(repeats, 'piece')} '
                            '${repeats == 1 ? 'repeats' : 'repeat'}. Add '
                            'more clothes for more variety.',
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One day: the look on the left; the date, weather, caption and actions
/// on the right.
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.label,
    required this.forecast,
    required this.items,
    required this.onSwap,
    required this.onSkip,
    required this.onKeep,
  });

  final _PlanDay day;
  final String label;
  final DayForecast? forecast;
  final List<ClothingItem> items;
  final VoidCallback? onSwap;
  final VoidCallback? onSkip;
  final VoidCallback? onKeep;

  static const double _previewWidth = 116;
  static const double _height = 172;
  static const double _skippedOpacity = 0.45;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final idea = day.idea;
    final existing = day.existing;
    final replaces = idea != null && existing != null;
    final f = forecast;

    final Widget preview;
    if (idea != null) {
      preview = OutfitCanvas(
        items: idea.items,
        layout: OutfitLayout.worn(idea.items),
      );
    } else if (existing != null) {
      preview = OutfitCover(outfit: existing, items: items, worn: true);
    } else {
      preview = Center(
        child: Icon(Icons.checkroom_outlined, color: palette.textTertiary),
      );
    }

    final String? tag = switch ((day.worn, existing != null, replaces)) {
      (true, _, _) => 'Worn',
      (_, true, false) => 'Already planned',
      (_, _, true) => 'Replaces your plan',
      _ => null,
    };

    return AnimatedOpacity(
      duration: AppDurations.fast,
      opacity: day.skipped ? _skippedOpacity : 1,
      child: Container(
        height: _height,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: _previewWidth,
              color: palette.surfaceMuted.withValues(alpha: 0.5),
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: preview,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: text.titleMedium),
                    if (f != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            f.condition.icon,
                            size: 14,
                            color: palette.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Flexible(
                            child: Text(
                              '${f.high.round()}° / ${f.low.round()}°'
                              '${f.rainChance >= 30 ? ' · ${f.rainChance}% rain' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        day.skipped
                            ? 'Skipped. Nothing will be planned.'
                            : idea?.title ??
                                  existing?.name ??
                                  'No full look for this day.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium,
                      ),
                    ),
                    if (tag != null) ...[
                      TagLabel(tag, inverted: day.worn),
                      const SizedBox(height: AppSpacing.xxs),
                    ],
                    Row(
                      children: [
                        if (!day.worn)
                          TextButton.icon(
                            onPressed: onSwap,
                            icon: const Icon(
                              Icons.autorenew_rounded,
                              size: AppSizes.iconSm,
                            ),
                            label: const Text('Swap'),
                          ),
                        const Spacer(),
                        if (replaces)
                          IconButton(
                            tooltip: 'Keep the planned outfit',
                            onPressed: onKeep,
                            icon: const Icon(Icons.undo_rounded),
                          )
                        else if (idea != null)
                          IconButton(
                            tooltip: day.skipped ? 'Plan this day' : 'Skip',
                            onPressed: onSkip,
                            icon: Icon(
                              day.skipped
                                  ? Icons.add_circle_outline_rounded
                                  : Icons.remove_circle_outline_rounded,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
