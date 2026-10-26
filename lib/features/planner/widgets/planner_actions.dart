import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/option_sheets.dart';
import 'package:all_fits/data/models/outfit_calendar_entry.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/shared/closet_flows.dart';

/// What the planner can do with one day; shared by the Day and Month views.
abstract final class PlannerActions {
  /// Fits' "+ Add outfit": a new outfit, or one already saved.
  static Future<void> addOutfit(BuildContext context, DateTime day) async {
    final choice = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetActionTile(
              icon: Icons.add_rounded,
              label: 'Create a new outfit',
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
            SheetActionTile(
              icon: Icons.style_outlined,
              label: 'Choose a saved outfit',
              onTap: () => Navigator.of(sheetContext).pop(false),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice) {
      await AppNavigator.createOutfit(context, planDate: day);
    } else {
      await ClosetFlows.pickAndPlan(context, day);
    }
  }

  /// The "⋯" sheet on a day card.
  static Future<void> showDayMenu(
    BuildContext context,
    DateTime day,
    DayPlan plan,
  ) {
    final today = context.read<ClosetActions>().today;
    final planned = plan.planned;
    final worn = plan.worn;
    final canWear =
        planned != null &&
        worn?.outfitId != planned.outfitId &&
        !day.isAfter(today);
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        void go(Future<void> Function() action) {
          Navigator.of(sheetContext).pop();
          action();
        }

        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canWear)
                SheetActionTile(
                  icon: Icons.check_rounded,
                  label: 'Mark as worn',
                  onTap: () => go(
                    () => ClosetFlows.markWorn(
                      context,
                      planned.outfitId,
                      date: day,
                    ),
                  ),
                ),
              SheetActionTile(
                icon: Icons.add_rounded,
                label: 'Add another outfit',
                onTap: () => go(() => addOutfit(context, day)),
              ),
              SheetActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Remove',
                onTap: () => go(() => remove(context, plan)),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }

  /// Takes the day's outfits off the planner; a worn one also gives back
  /// its wear.
  static Future<void> remove(BuildContext context, DayPlan plan) async {
    final closet = context.read<ClosetActions>();
    final planner = context.read<PlannerController>();
    await ClosetFlows.guard(context, () async {
      final worn = plan.worn;
      if (worn != null) await closet.unmarkWorn(worn);
      final planned = plan.planned;
      if (planned != null) await planner.removeEntry(planned.id);
    }, successMessage: 'Removed from planner');
  }

  static Future<void> editNote(
    BuildContext context,
    OutfitCalendarEntry entry,
  ) async {
    final note = await showTextInputDialog(
      context,
      title: 'Note',
      initialValue: entry.note ?? '',
      hint: 'Add a note...',
      maxLength: Validators.maxNotesLength,
      multiline: true,
    );
    if (note == null || !context.mounted) return;
    final planner = context.read<PlannerController>();
    await ClosetFlows.guard(
      context,
      () => planner.saveEntry(entry.copyWith(note: note.isEmpty ? null : note)),
    );
  }

  /// "Today", "Tomorrow", "Yesterday" or the date.
  static String dayLabel(DateTime day, DateTime today) {
    final diff = DateHelpers.daysBetween(today, day);
    return switch (diff) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      _ => '${_weekday(day)}, ${_month(day)} ${day.day}',
    };
  }

  static String _weekday(DateTime day) => const [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
  ][day.weekday - 1];

  static String _month(DateTime day) => const [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', //
    'Nov', 'Dec',
  ][day.month - 1];
}
