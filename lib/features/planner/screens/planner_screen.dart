import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/page_header.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/planner/widgets/day_plan_panel.dart';
import 'package:all_fits/features/planner/widgets/month_calendar.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final today = context.read<ClosetActions>().today;
    _selected = today;
    _month = DateHelpers.firstDayOfMonth(today);
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateHelpers.addMonths(_month, delta));
  }

  void _select(DateTime day) {
    setState(() {
      _selected = day;
      if (!DateHelpers.isSameMonth(day, _month)) {
        _month = DateHelpers.firstDayOfMonth(day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerController>();
    final outfits = context.watch<OutfitController>();
    final wardrobe = context.watch<WardrobeController>();
    final today = context.read<ClosetActions>().today;

    CalendarDayInfo infoOf(DateTime day) {
      final plan = planner.dayPlan(day);
      final entry = plan.primary;
      if (entry == null) return CalendarDayInfo.empty;
      final outfit = outfits.outfitById(entry.outfitId);
      return CalendarDayInfo(
        thumbnail: outfit == null
            ? null
            : wardrobe.itemsByIds(outfit.itemIds).firstOrNull,
        hasWorn: plan.worn != null,
        hasPlanned: plan.planned != null,
      );
    }

    final upcoming = planner.entries
        .where(
          (e) =>
              e.isPlanned &&
              DateHelpers.isSameMonth(e.date, _month) &&
              !e.date.isBefore(today),
        )
        .length;

    final calendar = Column(
      children: [
        _MonthNavigator(
          month: _month,
          onPrevious: () => _changeMonth(-1),
          onNext: () => _changeMonth(1),
        ),
        const SizedBox(height: AppSpacing.sm),
        MonthCalendar(
          month: _month,
          selectedDay: _selected,
          today: today,
          infoOf: infoOf,
          onSelect: _select,
          onSwipeMonth: _changeMonth,
        ),
        const SizedBox(height: AppSpacing.sm),
        const CalendarLegend(),
      ],
    );
    final panel = DayPlanPanel(date: _selected);

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= AppSizes.wideLayoutBreakpoint;
          final header = PageHeader(
            title: 'Planner',
            subtitle: upcoming == 0
                ? 'Plan your looks ahead'
                : '${AppFormatters.count(upcoming, 'outfit')} planned this month',
            actions: [
              HeaderIconButton(
                icon: Icons.today_outlined,
                tooltip: 'Go to today',
                onPressed: () => _select(today),
              ),
            ],
          );
          if (wide) {
            return ListView(
              children: [
                header,
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: calendar),
                      const SizedBox(width: AppSpacing.xl),
                      SizedBox(
                        width: AppSizes.plannerSidePanelWidth,
                        child: panel,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              header,
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page - AppSpacing.xs,
                ),
                child: calendar,
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                child: panel,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous month',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            AppFormatters.monthYear(month),
            textAlign: TextAlign.center,
            style: context.textTheme.titleLarge,
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}
