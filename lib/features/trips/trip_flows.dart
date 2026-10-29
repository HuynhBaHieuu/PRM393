import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/outfit_calendar_entry.dart';
import 'package:all_fits/data/models/trip.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cards.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/trips/packing_list.dart';
import 'package:all_fits/features/trips/trip_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// Trip actions that need dialogs, and keep the planner in step: an outfit
/// chosen for a trip day is also planned on that day.
abstract final class TripFlows {
  /// Asks for a name and dates, then opens the new trip.
  static Future<void> create(BuildContext context) async {
    final details = await _askDetails(context);
    if (details == null || !context.mounted) return;
    try {
      final trip = await context.read<TripController>().createTrip(
        details.name,
        details.start,
        details.end,
      );
      if (context.mounted) await AppNavigator.tripDetail(context, trip.id);
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
    }
  }

  static Future<void> edit(BuildContext context, Trip trip) async {
    final details = await _askDetails(context, trip: trip);
    if (details == null || !context.mounted) return;
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
      );
      if (context.mounted) await _unplan(context, dropped);
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
    }
  }

  /// Chooses the outfit for [day], replacing the day's plan on the planner
  /// after asking when it held a different outfit.
  static Future<void> chooseOutfit(
    BuildContext context,
    Trip trip,
    DateTime day,
  ) async {
    final outfitId = await showOutfitPickerSheet(
      context,
      title: 'Outfit for ${AppFormatters.shortDate(day)}',
      outfits: context.read<OutfitController>().outfits,
      onCreateOutfit: () => AppNavigator.createOutfit(context, planDate: day),
    );
    if (outfitId == null || !context.mounted) return;
    final planned = context.read<PlannerController>().dayPlan(day).planned;
    final replacing =
        planned != null &&
        planned.outfitId != outfitId &&
        planned.outfitId != trip.outfitOn(day);
    if (replacing) {
      final replace = await showConfirmDialog(
        context,
        title: 'Replace the planned outfit?',
        message:
            '${AppFormatters.shortDate(day)} already has an outfit on your '
            'planner. Use this one for the trip instead?',
        confirmLabel: 'Replace',
      );
      if (!replace || !context.mounted) return;
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

  /// Returns true when the trip was deleted.
  static Future<bool> delete(BuildContext context, Trip trip) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete “${trip.name}”?',
      message:
          'Its outfits come off your planner too. The outfits themselves, '
          'and your clothes, stay.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return false;
    try {
      await context.read<TripController>().deleteTrip(trip.id);
      if (context.mounted) {
        await _unplan(context, {
          for (final day in trip.days) day: ?trip.outfitOn(day),
        });
      }
      if (context.mounted) context.showSnack('Trip deleted');
      return true;
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
      return false;
    }
  }

  static Future<void> addExtra(BuildContext context, Trip trip) async {
    final label = await showTextInputDialog(
      context,
      title: 'Add something to pack',
      hint: 'e.g. Phone charger',
      maxLength: Validators.maxNameLength,
      confirmLabel: 'Add',
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
    if (context.mounted) context.showSnack('Packing list copied');
  }

  /// Takes the trip's plans for [outfitByDay] off the planner. Days whose
  /// plan was changed elsewhere since, and worn days, are left alone.
  static Future<void> _unplan(
    BuildContext context,
    Map<DateTime, String> outfitByDay,
  ) async {
    final planner = context.read<PlannerController>();
    final ids = [
      for (final MapEntry(key: day, value: outfitId) in outfitByDay.entries)
        if (planner.dayPlan(day).planned case final OutfitCalendarEntry entry
            when entry.outfitId == outfitId)
          entry.id,
    ];
    if (ids.isNotEmpty) await planner.removeEntries(ids);
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

typedef _TripDetails = ({String name, DateTime start, DateTime end});

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
  late DateTimeRange? _dates = widget.trip == null
      ? null
      : DateTimeRange(start: widget.trip!.startDate, end: widget.trip!.endDate);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
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
      helpText: 'Trip dates',
      saveText: 'Done',
    );
    if (picked != null) {
      setState(() {
        _dates = picked;
        _error = null;
      });
    }
  }

  void _submit() {
    final dates = _dates;
    final nameError = Validators.requiredName(
      _name.text,
      subject: 'a trip name',
    );
    String? error = nameError;
    if (error == null && dates == null) error = 'Choose the trip dates';
    if (error == null &&
        DateHelpers.daysBetween(dates!.start, dates.end) + 1 > Trip.maxDays) {
      error = 'A trip can be at most ${Trip.maxDays} days long';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context)
        .pop((name: _name.text.trim(), start: dates!.start, end: dates.end));
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
                title: widget.trip == null ? 'Plan a trip' : 'Edit trip',
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
                      decoration: const InputDecoration(
                        labelText: 'Trip name',
                        hintText: 'e.g. Đà Lạt weekend',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: _pickDates,
                      icon: const Icon(Icons.date_range_rounded),
                      label: Text(
                        dates == null
                            ? 'Choose dates'
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
                      onPressed: _submit,
                      child: Text(
                        widget.trip == null ? 'Create trip' : 'Save changes',
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
