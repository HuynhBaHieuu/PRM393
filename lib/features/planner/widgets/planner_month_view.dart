import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cover.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/planner/widgets/planner_actions.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// Fits' Month tab: a Sunday-first grid where every day is a tile, showing
/// its outfit or a grey "+". Swipe sideways for other months.
class PlannerMonthView extends StatefulWidget {
  const PlannerMonthView({
    super.key,
    required this.today,
    required this.initialMonth,
    required this.onOpenDay,
  });

  final DateTime today;
  final DateTime initialMonth;

  /// Shows a day that has an outfit in the Day tab.
  final ValueChanged<DateTime> onOpenDay;

  @override
  State<PlannerMonthView> createState() => _PlannerMonthViewState();
}

class _PlannerMonthViewState extends State<PlannerMonthView> {
  static const int _basePage = 1200;

  late final DateTime _baseMonth = DateHelpers.firstDayOfMonth(
    widget.initialMonth,
  );
  late final PageController _pages = PageController(initialPage: _basePage);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pages,
      itemBuilder: (context, page) => _MonthPage(
        month: DateHelpers.addMonths(_baseMonth, page - _basePage),
        today: widget.today,
        onOpenDay: widget.onOpenDay,
      ),
    );
  }
}

class _MonthPage extends StatelessWidget {
  const _MonthPage({
    required this.month,
    required this.today,
    required this.onOpenDay,
  });

  final DateTime month;
  final DateTime today;
  final ValueChanged<DateTime> onOpenDay;

  static const List<String> _weekdays = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', //
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final days = DateHelpers.calendarDays(month, firstWeekday: DateTime.sunday);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final weeks = [
      for (var w = 0; w < DateHelpers.calendarWeeks; w++)
        if (!days[w * 7].isAfter(lastDay)) days.sublist(w * 7, w * 7 + 7),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.xl,
      ),
      children: [
        Text(
          AppFormatters.monthYear(month),
          textAlign: TextAlign.center,
          style: text.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            for (final name in _weekdays)
              Expanded(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: palette.textTertiary),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final week in weeks) ...[
          Divider(height: 1, color: palette.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final day in week)
                  Expanded(
                    child: _DayCell(
                      day: day,
                      inMonth: day.month == month.month,
                      isToday: DateHelpers.isSameDay(day, today),
                      onOpenDay: onOpenDay,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.onOpenDay,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final ValueChanged<DateTime> onOpenDay;

  static const double _tileAspect = 0.58;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final number = Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isToday ? palette.ink : Colors.transparent,
      ),
      child: Text(
        '${day.day}',
        style: text.bodyLarge?.copyWith(
          color: isToday
              ? palette.onInk
              : inMonth
              ? palette.ink
              : palette.textTertiary.withValues(alpha: 0.5),
        ),
      ),
    );
    if (!inMonth) return Column(children: [number]);

    final plan = context.watch<PlannerController>().dayPlan(day);
    final entry = plan.primary;
    final outfit = entry == null
        ? null
        : context.watch<OutfitController>().outfitById(entry.outfitId);
    final items = outfit == null
        ? const []
        : context.watch<WardrobeController>().itemsByIds(outfit.itemIds);

    return Column(
      children: [
        number,
        const SizedBox(height: AppSpacing.xxs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: AspectRatio(
            aspectRatio: _tileAspect,
            child: Material(
              color: outfit == null ? palette.surfaceMuted : palette.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                side: outfit == null
                    ? BorderSide.none
                    : BorderSide(color: palette.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: outfit == null
                    ? () => PlannerActions.addOutfit(context, day)
                    : () => onOpenDay(day),
                child: outfit == null
                    ? Icon(
                        Icons.add_rounded,
                        semanticLabel:
                            'Add outfit on ${AppFormatters.shortDate(day)}',
                        color: palette.textSecondary,
                      )
                    : OutfitCover(
                        outfit: outfit,
                        items: [...items],
                        worn: true,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
