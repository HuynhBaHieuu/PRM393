import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/outfit_calendar_entry.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cards.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/shared/closet_flows.dart';

/// Details and actions for the selected calendar day.
class DayPlanPanel extends StatelessWidget {
  const DayPlanPanel({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlannerController>().dayPlan(date);
    final closet = context.read<ClosetActions>();
    final today = closet.today;
    final daysFromToday = DateHelpers.daysBetween(today, date);
    final isPast = daysFromToday < 0;
    final isFuture = daysFromToday > 0;
    final text = context.textTheme;
    final planned = plan.planned;
    final worn = plan.worn;
    final plannedIsWorn = planned != null && worn?.outfitId == planned.outfitId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppFormatters.longDate(date),
                style: text.headlineSmall,
              ),
            ),
            if (daysFromToday == 0) const TagLabel('Today', inverted: true),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!isPast || planned != null)
          _EntryBlock(
            label: 'Planned',
            entry: planned,
            emptyTitle: 'Nothing planned',
            emptyMessage: 'Plan an outfit for this day.',
            emptyAction: isPast
                ? null
                : _PanelAction(
                    label: 'Plan Outfit',
                    icon: Icons.add_rounded,
                    primary: true,
                    onPressed: () => ClosetFlows.pickAndPlan(context, date),
                  ),
            actions: planned == null
                ? const []
                : [
                    if (!isFuture && !plannedIsWorn)
                      _PanelAction(
                        label: 'Mark as Worn',
                        icon: Icons.check_rounded,
                        primary: true,
                        onPressed: () => ClosetFlows.markWorn(
                          context,
                          planned.outfitId,
                          date: date,
                        ),
                      ),
                    if (!isPast)
                      _PanelAction(
                        label: 'Change',
                        icon: Icons.swap_horiz_rounded,
                        onPressed: () => ClosetFlows.pickAndPlan(context, date),
                      ),
                    _PanelAction(
                      label: 'Remove Plan',
                      icon: Icons.close_rounded,
                      destructive: true,
                      onPressed: () => ClosetFlows.guard(
                        context,
                        () => context.read<PlannerController>().removeEntry(
                          planned.id,
                        ),
                        successMessage: 'Plan removed',
                      ),
                    ),
                  ],
          ),
        if (!isFuture) ...[
          const SizedBox(height: AppSpacing.lg),
          _EntryBlock(
            label: 'Worn',
            entry: worn,
            emptyTitle: 'Nothing logged',
            emptyMessage: 'Log what you wore to track your wardrobe.',
            emptyAction: _PanelAction(
              label: planned == null ? 'Log Outfit' : 'Log another outfit',
              icon: Icons.checkroom_outlined,
              primary: planned == null,
              onPressed: () => ClosetFlows.pickAndMarkWorn(context, date),
            ),
            actions: worn == null
                ? const []
                : [
                    _PanelAction(
                      label: 'Undo',
                      icon: Icons.undo_rounded,
                      onPressed: () => ClosetFlows.guard(
                        context,
                        () => closet.unmarkWorn(worn),
                        successMessage: 'Wear removed',
                      ),
                    ),
                  ],
          ),
        ],
      ],
    );
  }
}

class _PanelAction {
  const _PanelAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;
  final bool destructive;

  Widget build(BuildContext context) {
    final palette = context.palette;
    const size = Size(0, AppSizes.compactButtonHeight);
    final icon = Icon(this.icon, size: AppSizes.iconSm);
    if (primary) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(minimumSize: size),
        icon: icon,
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: size,
        foregroundColor: destructive ? palette.danger : palette.ink,
      ),
      icon: icon,
      label: Text(label),
    );
  }
}

class _EntryBlock extends StatelessWidget {
  const _EntryBlock({
    required this.label,
    required this.entry,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.actions,
    this.emptyAction,
  });

  final String label;
  final OutfitCalendarEntry? entry;
  final String emptyTitle;
  final String emptyMessage;
  final List<_PanelAction> actions;
  final _PanelAction? emptyAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final current = entry;
    final outfit = current == null
        ? null
        : context.watch<OutfitController>().outfitById(current.outfitId);
    final buttons = current == null ? [?emptyAction] : actions;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: text.labelSmall),
          const SizedBox(height: AppSpacing.sm),
          if (current == null) ...[
            Text(emptyTitle, style: text.titleMedium),
            const SizedBox(height: 2),
            Text(emptyMessage, style: text.bodySmall),
          ] else if (outfit == null)
            Text(
              'This outfit is no longer available.',
              style: text.bodyMedium?.copyWith(color: palette.textSecondary),
            )
          else
            OutfitListRow(
              outfit: outfit,
              onTap: () => AppNavigator.outfitDetail(context, outfit.id),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          if (buttons.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [for (final action in buttons) action.build(context)],
            ),
          ],
        ],
      ),
    );
  }
}
