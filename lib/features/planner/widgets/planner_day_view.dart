import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_durations.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cover.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/planner/widgets/planner_actions.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// Fits' Day tab: the week's days over one large card per day, swiped
/// sideways.
class PlannerDayView extends StatefulWidget {
  const PlannerDayView({
    super.key,
    required this.today,
    required this.initialDay,
    required this.onDayChanged,
  });

  final DateTime today;
  final DateTime initialDay;
  final ValueChanged<DateTime> onDayChanged;

  @override
  State<PlannerDayView> createState() => _PlannerDayViewState();
}

class _PlannerDayViewState extends State<PlannerDayView> {
  /// Page index of [PlannerDayView.today]; pages before it are past days.
  static const int _todayPage = 100000;
  static const double _swipeVelocity = 250;

  late final PageController _pages = PageController(
    viewportFraction: 0.8,
    initialPage: _todayPage + _offsetOf(widget.initialDay),
  );
  late DateTime _day = widget.initialDay;

  int _offsetOf(DateTime day) => DateHelpers.daysBetween(widget.today, day);

  DateTime _dayOf(int page) =>
      DateHelpers.addDays(widget.today, page - _todayPage);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _select(DateTime day) {
    final target = _todayPage + _offsetOf(day);
    final distance = (target - (_pages.page ?? target).round()).abs();
    if (distance > 7) {
      _pages.jumpToPage(target);
    } else {
      _pages.animateToPage(
        target,
        duration: AppDurations.medium,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final planner = context.watch<PlannerController>();
    // The week of the selected day, Sunday first as in Fits.
    final weekStart = DateHelpers.addDays(_day, -(_day.weekday % 7));
    return Column(
      children: [
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() < _swipeVelocity) return;
            _select(DateHelpers.addDays(_day, velocity < 0 ? 7 : -7));
          },
          child: Container(
            color: palette.surfaceMuted.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _WeekDay(
                      day: DateHelpers.addDays(weekStart, i),
                      selected: DateHelpers.isSameDay(
                        DateHelpers.addDays(weekStart, i),
                        _day,
                      ),
                      hasOutfit: !planner
                          .dayPlan(DateHelpers.addDays(weekStart, i))
                          .isEmpty,
                      onTap: () => _select(DateHelpers.addDays(weekStart, i)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: palette.border),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Text(
            PlannerActions.dayLabel(_day, widget.today),
            style: context.textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            onPageChanged: (page) {
              final day = _dayOf(page);
              setState(() => _day = day);
              widget.onDayChanged(day);
            },
            itemBuilder: (context, page) => Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                0,
                AppSpacing.xs,
                AppSpacing.lg,
              ),
              child: _DayCard(day: _dayOf(page)),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.day,
    required this.selected,
    required this.hasOutfit,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool hasOutfit;
  final VoidCallback onTap;

  static const List<String> _names = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Text(
              _names[day.weekday - 1],
              style: text.bodySmall?.copyWith(color: palette.textTertiary),
            ),
            const SizedBox(height: AppSpacing.xxs),
            AnimatedContainer(
              duration: AppDurations.fast,
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? palette.ink : Colors.transparent,
              ),
              child: Text(
                '${day.day}',
                style: text.titleMedium?.copyWith(
                  color: selected ? palette.onInk : palette.ink,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 3),
            // A dot under days that have an outfit.
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasOutfit ? palette.ink : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One day: its outfit filling a white card with "⋯" and a note, or
/// "+ Add outfit".
class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final plan = context.watch<PlannerController>().dayPlan(day);
    final entry = plan.primary;
    final outfit = entry == null
        ? null
        : context.watch<OutfitController>().outfitById(entry.outfitId);
    final items = outfit == null
        ? const []
        : context.watch<WardrobeController>().itemsByIds(outfit.itemIds);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: outfit == null || entry == null
            ? Center(
                child: FilledButton.icon(
                  onPressed: () => PlannerActions.addOutfit(context, day),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add outfit'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, AppSizes.buttonHeight),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                  ),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () => AppNavigator.outfitDetail(context, outfit.id),
                    child: OutfitCover(
                      outfit: outfit,
                      items: [...items],
                      worn: true,
                      padding: const EdgeInsets.all(AppSpacing.md),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.sm,
                    top: AppSpacing.sm,
                    child: TagLabel(
                      plan.worn != null ? 'Worn' : 'Planned',
                      inverted: plan.worn != null,
                    ),
                  ),
                  Positioned(
                    right: AppSpacing.sm,
                    top: AppSpacing.sm,
                    child: IconButton(
                      tooltip: 'More',
                      onPressed: () =>
                          PlannerActions.showDayMenu(context, day, plan),
                      icon: const Icon(Icons.more_horiz_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: palette.surfaceMuted,
                        foregroundColor: palette.ink,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () => PlannerActions.editNote(context, entry),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        // A flat band rather than Fits' fade: no gradients.
                        color: Colors.black.withValues(alpha: 0.3),
                        child: Text(
                          entry.note ?? 'Add a note...',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
