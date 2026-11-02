import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/outfit_calendar_entry.dart';
import 'package:all_fits/data/models/trip.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/controllers/outfit_draft.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cards.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/premium/premium_flows.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/stylist/stylist_store.dart';
import 'package:all_fits/features/trips/packing_list.dart';
import 'package:all_fits/features/trips/trip_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/weather/controllers/weather_controller.dart';
import 'package:all_fits/core/l10n/l10n.dart';

enum _DayChoice { pick, create, swipe }

enum _DeleteChoice { keepPlans, removePlans }

/// Trip actions that need dialogs, and keep the planner in step: an outfit
/// chosen for a trip day is also planned on that day.
abstract final class TripFlows {
  /// Asks for a name and dates, then opens the new trip. The Free plan
  /// has one trip at a time until it ends.
  static Future<void> create(BuildContext context) async {
    if (!PremiumFlows.canAddTrip(context)) {
      await PremiumFlows.showTripLimit(context);
      return;
    }
    final details = await _askDetails(context);
    if (details == null || !context.mounted) return;
    try {
      final trip = await context.read<TripController>().createTrip(
        details.name,
        details.start,
        details.end,
        location: details.location,
      );
      if (context.mounted) await AppNavigator.tripDetail(context, trip.id);
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
    }
  }

  static Future<void> edit(BuildContext context, Trip trip) async {
    final details = await _askDetails(context, trip: trip);
    if (details == null || !context.mounted) return;
    // Moving a past trip to new dates makes it count again.
    final today = context.read<ClosetActions>().today;
    if (!details.end.isBefore(today) &&
        !PremiumFlows.canAddTrip(context, excluding: trip.id)) {
      await PremiumFlows.showTripLimit(context);
      return;
    }
    final dropped = {
      for (final day in trip.days)
        if (details.start.isAfter(day) || details.end.isBefore(day))
          day: ?trip.outfitOn(day),
    };
    try {
      await context.read<TripController>().updateDetails(
        trip.id,
        name: details.name,
        start: details.start,
        end: details.end,
        location: details.location,
      );
      if (context.mounted) await _unplan(context, dropped);
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
    }
  }

  /// Fills [day]: with a saved outfit, a new one, or one made by swiping.
  /// A plan already on the planner that day is only replaced after asking.
  static Future<void> chooseOutfit(
    BuildContext context,
    Trip trip,
    DateTime day,
  ) async {
    final choice = await showModalBottomSheet<_DayChoice>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title:
                  '${AppFormatters.weekdayName(day)}, '
                  '${AppFormatters.shortDate(day)}',
            ),
            ListTile(
              leading: const Icon(Icons.checkroom_outlined),
              title: Text(tr('Choose a saved outfit')),
              onTap: () => Navigator.of(sheetContext).pop(_DayChoice.pick),
            ),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: Text(tr('Create a new outfit')),
              onTap: () => Navigator.of(sheetContext).pop(_DayChoice.create),
            ),
            ListTile(
              leading: const Icon(Icons.swipe_outlined),
              title: Text(tr('Swipe an outfit')),
              subtitle: Text(tr('Dressing Room')),
              onTap: () => Navigator.of(sheetContext).pop(_DayChoice.swipe),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == _DayChoice.pick) {
      await _pickSaved(context, trip, day);
      return;
    }

    // New outfits are planned on the day by the outfit builder; the trip
    // then takes whatever was planned.
    if (!await _mayReplace(context, trip, day) || !context.mounted) return;
    final planner = context.read<PlannerController>();
    final before = planner.dayPlan(day).planned?.outfitId;
    if (choice == _DayChoice.create) {
      await AppNavigator.createOutfit(context, planDate: day);
    } else {
      await AppNavigator.swipeOutfit(context, planDate: day);
    }
    final after = planner.dayPlan(day).planned?.outfitId;
    if (after == null || after == before || !context.mounted) return;
    try {
      await context.read<TripController>().setDayOutfit(trip.id, day, after);
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
    }
  }

  static Future<void> _pickSaved(
    BuildContext context,
    Trip trip,
    DateTime day,
  ) async {
    final outfitId = await showOutfitPickerSheet(
      context,
      title: tr('Outfit for {0}', [AppFormatters.shortDate(day)]),
      outfits: context.read<OutfitController>().outfits,
    );
    if (outfitId == null || !context.mounted) return;
    final planned = context.read<PlannerController>().dayPlan(day).planned;
    if (planned?.outfitId != outfitId &&
        (!await _mayReplace(context, trip, day) || !context.mounted)) {
      return;
    }
    try {
      await context.read<ClosetActions>().planOutfit(outfitId, day);
      if (context.mounted) {
        await context.read<TripController>().setDayOutfit(
          trip.id,
          day,
          outfitId,
        );
      }
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
    }
  }

  /// True unless [day] has an outfit planned outside the trip that the
  /// user wants to keep.
  static Future<bool> _mayReplace(
    BuildContext context,
    Trip trip,
    DateTime day,
  ) async {
    final planned = context.read<PlannerController>().dayPlan(day).planned;
    if (planned == null || planned.outfitId == trip.outfitOn(day)) return true;
    return showConfirmDialog(
      context,
      title: tr('Replace the planned outfit?'),
      message: tr(
        '{0} already has an outfit on your planner. Use a new one for the trip instead?',
        [AppFormatters.shortDate(day)],
      ),
      confirmLabel: tr('Replace'),
      cancelLabel: tr('Keep it'),
    );
  }

  static Future<void> clearDay(
    BuildContext context,
    Trip trip,
    DateTime day,
  ) async {
    final outfitId = trip.outfitOn(day);
    if (outfitId == null) return;
    try {
      await context.read<TripController>().setDayOutfit(trip.id, day, null);
      if (context.mounted) await _unplan(context, {day: outfitId});
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
    }
  }

  /// Asks the AI stylist for an outfit for every day still empty, using
  /// each day's [forecast] when known, and adds those the user keeps. One
  /// request counts as one AI Stylist message.
  static Future<void> suggestOutfits(
    BuildContext context,
    Trip trip, {
    Map<DateTime, DayForecast> forecast = const {},
  }) async {
    final service = context.read<AiStylistService>();
    final store = context.read<StylistStore>();
    final today = context.read<ClosetActions>().today;
    final wardrobe = context.read<WardrobeController>().activeItems;
    final days = [
      for (final day in trip.days)
        if (trip.outfitOn(day) == null && !day.isBefore(today)) day,
    ];
    if (!service.isConfigured) {
      context.showSnack(tr('The AI stylist is not set up.'));
      return;
    }
    if (days.isEmpty) {
      context.showSnack(tr('Every day of this trip already has an outfit.'));
      return;
    }
    if (wardrobe.length < 3) {
      context.showSnack(tr('Add a few more clothes first, then ask again.'));
      return;
    }
    await store.load();
    if (!context.mounted) return;
    final limit = context.read<SettingsController>().plan.stylistMessagesPerDay;
    if (limit != null &&
        math.max(0, limit + store.bonusToday - store.usedToday) == 0) {
      context.showSnack(
        tr(
          'You’ve used today’s AI Stylist messages. Try again tomorrow, or go '
          'Premium for unlimited ones.',
        ),
      );
      return;
    }

    final prompt = _tripPrompt(trip, days, forecast);
    final answer = await showDialog<StylistMessage>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StylingDialog(
        run: (cancel) => service.reply(
          wardrobe: wardrobe,
          history: [StylistMessage.user(prompt)],
          persona: store.persona,
          notes: store.notes,
          cancel: cancel,
        ),
      ),
    );
    if (answer == null || !context.mounted) return;
    try {
      await store.countMessage();
    } catch (_) {
      // Counting is best effort; the answer is still good.
    }
    if (!context.mounted) return;
    final suggestions = [
      for (final outfit in answer.outfits)
        if (outfit.itemIds.isNotEmpty) outfit,
    ];
    if (suggestions.isEmpty) {
      context.showSnack(
        answer.text.isEmpty
            ? tr('The stylist didn’t suggest any outfits. Try again.')
            : answer.text,
      );
      return;
    }
    final pairs = [
      for (var i = 0; i < math.min(days.length, suggestions.length); i++)
        (day: days[i], outfit: suggestions[i]),
    ];
    final keep = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SuggestionsSheet(pairs: pairs, note: answer.text),
    );
    if (keep != true || !context.mounted) return;
    await _addSuggestions(context, trip, pairs);
  }

  static String _tripPrompt(
    Trip trip,
    List<DateTime> days,
    Map<DateTime, DayForecast> forecast,
  ) {
    final place = trip.location == null
        ? ''
        : tr(' to {0}', [trip.location!.label]);
    final lines = [
      for (final (index, day) in days.indexed)
        '${index + 1}. ${AppFormatters.weekdayName(day)} '
            '${AppFormatters.shortDate(day)}'
            '${switch (forecast[day]) {
              final f? => tr(': {0}, {1}–{2}°C, {3}% chance of rain', [f.condition.label.toLowerCase(), f.low.round(), f.high.round(), f.rainChance]),
              null => '',
            }}',
    ];
    return tr(
      'I’m going on a {0} trip “{1}”{2}. Make exactly {3} from my wardrobe, one for each of these days, in this order:\n{4}\nDress for each day’s weather and re-use pieces across days so I can pack light. Leave the packing list and shopping empty.',
      [
        AppFormatters.count(trip.length, 'day'),
        trip.name,
        place,
        AppFormatters.count(days.length, 'outfit'),
        lines.join('\n'),
      ],
    );
  }

  static Future<void> _addSuggestions(
    BuildContext context,
    Trip trip,
    List<({DateTime day, OutfitSuggestion outfit})> pairs,
  ) async {
    final planner = context.read<PlannerController>();
    final busy = [
      for (final pair in pairs)
        if (planner.dayPlan(pair.day).planned != null) pair.day,
    ];
    var replaceBusy = true;
    if (busy.isNotEmpty) {
      replaceBusy = await showConfirmDialog(
        context,
        title: tr('Replace planned outfits?'),
        message: tr(
          '{0} of the trip already {1} on your planner. Replace them with the stylist’s, or keep them?',
          [
            AppFormatters.count(busy.length, 'day'),
            busy.length == 1 ? tr('has an outfit') : tr('have outfits'),
          ],
        ),
        confirmLabel: tr('Replace'),
        cancelLabel: tr('Keep them'),
      );
      if (!context.mounted) return;
    }
    final outfits = context.read<OutfitController>();
    final closet = context.read<ClosetActions>();
    final trips = context.read<TripController>();
    var added = 0;
    try {
      for (final (:day, :outfit) in pairs) {
        if (!replaceBusy && busy.contains(day)) continue;
        final saved = await outfits.createOutfit(
          OutfitDraft(
            name: outfit.name.isEmpty
                ? tr('{0} · Day {1}', [trip.name, trip.days.indexOf(day) + 1])
                : outfit.name,
            itemIds: outfit.itemIds,
            notes: outfit.reason,
          ),
        );
        await closet.planOutfit(saved.id, day);
        await trips.setDayOutfit(trip.id, day, saved.id);
        added++;
      }
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
      return;
    }
    if (context.mounted) {
      context.showSnack(
        added == 0
            ? tr('Nothing was added; your planned outfits stay.')
            : tr('Added {0} to the trip', [
                AppFormatters.count(added, 'outfit'),
              ]),
      );
    }
  }

  /// Returns true when the trip was deleted. When some of its outfits are
  /// still on the planner, asks whether to take them off too.
  static Future<bool> delete(BuildContext context, Trip trip) async {
    final plans = {for (final day in trip.days) day: ?trip.outfitOn(day)};
    final planned = _plannedEntries(context, plans).length;
    final _DeleteChoice? choice;
    if (planned == 0) {
      final confirmed = await showConfirmDialog(
        context,
        title: tr('Delete “{0}”?', [trip.name]),
        message: tr('Your outfits and clothes stay.'),
        confirmLabel: tr('Delete'),
        destructive: true,
      );
      choice = confirmed ? _DeleteChoice.keepPlans : null;
    } else {
      choice = await showDialog<_DeleteChoice>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('Delete “{0}”?', [trip.name])),
          content: Text(
            tr(
              '{0} of this trip {1} on your planner. Take {2} off the planner too? The outfits themselves, and your clothes, stay either way.',
              [
                AppFormatters.count(planned, 'outfit'),
                tr(planned == 1 ? 'is' : 'are'),
                tr(planned == 1 ? 'it' : 'them'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr('Cancel')),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_DeleteChoice.keepPlans),
              child: Text(tr('Keep on planner')),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_DeleteChoice.removePlans),
              style: TextButton.styleFrom(
                foregroundColor: context.palette.danger,
              ),
              child: Text(tr('Remove')),
            ),
          ],
        ),
      );
    }
    if (choice == null || !context.mounted) return false;
    try {
      await context.read<TripController>().deleteTrip(trip.id);
      if (choice == _DeleteChoice.removePlans && context.mounted) {
        await _unplan(context, plans);
      }
      if (context.mounted) context.showSnack(tr('Trip deleted'));
      return true;
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
      return false;
    }
  }

  static Future<void> addExtra(BuildContext context, Trip trip) async {
    final label = await showTextInputDialog(
      context,
      title: tr('Add something to pack'),
      hint: tr('e.g. Phone charger'),
      maxLength: Validators.maxNameLength,
      confirmLabel: tr('Add'),
    );
    if (label == null || label.trim().isEmpty || !context.mounted) return;
    try {
      await context.read<TripController>().addExtra(trip.id, label);
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
    }
  }

  static Future<void> copyPackingList(BuildContext context, Trip trip) async {
    final wardrobe = context.read<WardrobeController>();
    final outfits = context.read<OutfitController>();
    final list = PackingList.of(
      trip,
      outfitById: outfits.outfitById,
      itemById: wardrobe.itemById,
    );
    await Clipboard.setData(ClipboardData(text: list.toText()));
    if (context.mounted) context.showSnack(tr('Packing list copied'));
  }

  /// The planner entries still holding the trip's plans for [outfitByDay].
  /// Days whose plan was changed elsewhere since, and worn days, are left
  /// out.
  static List<String> _plannedEntries(
    BuildContext context,
    Map<DateTime, String> outfitByDay,
  ) {
    final planner = context.read<PlannerController>();
    return [
      for (final MapEntry(key: day, value: outfitId) in outfitByDay.entries)
        if (planner.dayPlan(day).planned case final OutfitCalendarEntry entry
            when entry.outfitId == outfitId)
          entry.id,
    ];
  }

  /// Takes the trip's plans for [outfitByDay] off the planner.
  static Future<void> _unplan(
    BuildContext context,
    Map<DateTime, String> outfitByDay,
  ) async {
    final ids = _plannedEntries(context, outfitByDay);
    if (ids.isNotEmpty) {
      await context.read<PlannerController>().removeEntries(ids);
    }
  }

  static Future<_TripDetails?> _askDetails(BuildContext context, {Trip? trip}) {
    return showModalBottomSheet<_TripDetails>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TripDetailsSheet(trip: trip),
    );
  }
}

typedef _TripDetails = ({
  String name,
  DateTime start,
  DateTime end,
  WeatherLocation? location,
});

class _TripDetailsSheet extends StatefulWidget {
  const _TripDetailsSheet({this.trip});

  final Trip? trip;

  @override
  State<_TripDetailsSheet> createState() => _TripDetailsSheetState();
}

class _TripDetailsSheetState extends State<_TripDetailsSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.trip?.name,
  );
  late final TextEditingController _city = TextEditingController(
    text: widget.trip?.location?.name,
  );
  late DateTimeRange? _dates = widget.trip == null
      ? null
      : DateTimeRange(start: widget.trip!.startDate, end: widget.trip!.endDate);
  String? _error;
  String? _cityError;
  bool _findingCity = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final today = DateHelpers.dateOnly(DateTime.now());
    final first = widget.trip != null && widget.trip!.startDate.isBefore(today)
        ? widget.trip!.startDate
        : today;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: DateHelpers.addDays(today, 365),
      initialDateRange: _dates,
      helpText: tr('Trip dates'),
      saveText: tr('Done'),
    );
    if (picked != null) {
      setState(() {
        _dates = picked;
        _error = null;
      });
    }
  }

  /// The trip's city, looked up when it was typed or changed. Null when
  /// none was given; throws [ValidationException] when it can't be found.
  Future<WeatherLocation?> _location() async {
    final typed = _city.text.trim();
    if (typed.isEmpty) return null;
    final current = widget.trip?.location;
    if (current != null && current.name == typed) return current;
    final found = await context.read<WeatherController>().findCity(typed);
    if (found == null) {
      throw ValidationException(
        tr('We couldn’t find that city. Check the spelling.'),
      );
    }
    return found;
  }

  Future<void> _submit() async {
    if (_findingCity) return;
    final dates = _dates;
    final nameError = Validators.requiredName(
      _name.text,
      subject: tr('a trip name'),
    );
    String? error = nameError;
    if (error == null && dates == null) error = tr('Choose the trip dates');
    if (error == null &&
        DateHelpers.daysBetween(dates!.start, dates.end) + 1 > Trip.maxDays) {
      error = tr('A trip can be at most {0} days long', [Trip.maxDays]);
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _findingCity = true;
      _cityError = null;
    });
    final WeatherLocation? location;
    try {
      location = await _location();
    } catch (error) {
      if (mounted) {
        setState(() {
          _findingCity = false;
          _cityError = describeError(error);
        });
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop((
      name: _name.text.trim(),
      start: dates!.start,
      end: dates.end,
      location: location,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dates = _dates;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(
                title: widget.trip == null
                    ? tr('Plan a trip')
                    : tr('Edit trip'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      autofocus: widget.trip == null,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: Validators.maxNameLength,
                      decoration: InputDecoration(
                        labelText: tr('Trip name'),
                        hintText: tr('e.g. Đà Lạt weekend'),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _city,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      maxLength: Validators.maxNameLength,
                      onChanged: (_) {
                        if (_cityError != null) {
                          setState(() => _cityError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: tr('City (optional)'),
                        hintText: tr('For each day’s weather, e.g. Da Lat'),
                        counterText: '',
                        errorText: _cityError,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: _pickDates,
                      icon: const Icon(Icons.date_range_rounded),
                      label: Text(
                        dates == null
                            ? tr('Choose dates')
                            : '${AppFormatters.shortDate(dates.start)} – '
                                  '${AppFormatters.shortDate(dates.end)} · '
                                  '${AppFormatters.count(DateHelpers.daysBetween(dates.start, dates.end) + 1, 'day')}',
                      ),
                    ),
                    if (_error case final error?) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        error,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.palette.danger,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: _findingCity ? null : _submit,
                      child: _findingCity
                          ? const SizedBox.square(
                              dimension: AppSizes.iconSm,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.trip == null
                                  ? tr('Create trip')
                                  : tr('Save changes'),
                            ),
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
}

/// Waits for the stylist, with Cancel; shows the error, with Try again,
/// when it fails. Pops with the answer, or null when cancelled.
class _StylingDialog extends StatefulWidget {
  const _StylingDialog({required this.run});

  final Future<StylistMessage> Function(Future<void> cancel) run;

  @override
  State<_StylingDialog> createState() => _StylingDialogState();
}

class _StylingDialogState extends State<_StylingDialog> {
  Completer<void>? _cancel;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _stop() {
    final cancel = _cancel;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
  }

  Future<void> _start() async {
    final cancel = _cancel = Completer<void>();
    setState(() => _error = null);
    try {
      final answer = await widget.run(cancel.future);
      if (mounted && !cancel.isCompleted) Navigator.of(context).pop(answer);
    } catch (error) {
      if (mounted && !cancel.isCompleted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return AlertDialog(
      title: Text(
        error == null ? tr('Styling your trip…') : tr('Something went wrong'),
      ),
      content: error == null
          ? Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: AppSpacing.lg),
                Expanded(child: Text(tr('Picking an outfit for each day.'))),
              ],
            )
          : Text(describeError(error)),
      actions: [
        TextButton(
          onPressed: () {
            _stop();
            Navigator.of(context).pop();
          },
          child: Text(error == null ? tr('Cancel') : tr('Close')),
        ),
        if (error != null)
          TextButton(onPressed: _start, child: Text(tr('Try again'))),
      ],
    );
  }
}

/// The stylist's outfit for each day, to keep or drop.
class _SuggestionsSheet extends StatelessWidget {
  const _SuggestionsSheet({required this.pairs, required this.note});

  final List<({DateTime day, OutfitSuggestion outfit})> pairs;
  final String note;

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.read<WardrobeController>();
    final text = context.textTheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          SheetHeader(title: tr('Outfits for your trip')),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              children: [
                if (note.isNotEmpty) ...[
                  Text(note, style: text.bodySmall),
                  const SizedBox(height: AppSpacing.md),
                ],
                for (final (:day, :outfit) in pairs) ...[
                  Text(
                    '${AppFormatters.weekdayName(day)}, '
                    '${AppFormatters.shortDate(day)}',
                    style: text.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(outfit.name, style: text.titleMedium),
                  if (outfit.reason.isNotEmpty)
                    Text(outfit.reason, style: text.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    height: 64,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final item in wardrobe.itemsByIds(outfit.itemIds))
                          Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.xs,
                            ),
                            child: SizedBox.square(
                              dimension: 64,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                                child: ClothingImage(
                                  item: item,
                                  decodeWidth: 160,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: AppSpacing.xl),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(tr('Not now')),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(tr('Add to trip')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
