import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/constants/app_durations.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/data/models/clothing_item.dart';

/// What a calendar cell needs to know about its day.
class CalendarDayInfo {
  const CalendarDayInfo({
    this.thumbnail,
    this.hasWorn = false,
    this.hasPlanned = false,
  });

  static const CalendarDayInfo empty = CalendarDayInfo();

  /// A representative piece of the featured outfit.
  final ClothingItem? thumbnail;
  final bool hasWorn;
  final bool hasPlanned;

  bool get hasOutfit => hasWorn || hasPlanned;
}

/// Monthly grid (Monday first) with outfit thumbnails on planned/worn days.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.today,
    required this.infoOf,
    required this.onSelect,
    this.onSwipeMonth,
  });

  final DateTime month;
  final DateTime selectedDay;
  final DateTime today;
  final CalendarDayInfo Function(DateTime day) infoOf;
  final ValueChanged<DateTime> onSelect;

  /// Called with -1 / +1 when the user swipes to another month.
  final ValueChanged<int>? onSwipeMonth;

  static const double _cellAspect = 0.78;
  static const double _swipeVelocity = 250;

  @override
  Widget build(BuildContext context) {
    final days = DateHelpers.calendarDays(month);
    // Skip trailing weeks that fall entirely in the next month.
    final weeks =
        List.generate(
              DateHelpers.calendarWeeks,
              (week) => days[week * DateHelpers.daysPerWeek],
            )
            .where(
              (start) =>
                  !start.isAfter(DateTime(month.year, month.month + 1, 0)),
            )
            .length;
    final text = context.textTheme;
    return GestureDetector(
      onHorizontalDragEnd: onSwipeMonth == null
          ? null
          : (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity.abs() < _swipeVelocity) return;
              onSwipeMonth!(velocity < 0 ? 1 : -1);
            },
      child: Column(
        children: [
          Row(
            children: [
              for (final label in AppFormatters.weekdayInitials())
                Expanded(
                  child: Center(child: Text(label, style: text.labelSmall)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth = constraints.maxWidth / DateHelpers.daysPerWeek;
              final cellHeight = cellWidth / _cellAspect;
              return Column(
                children: [
                  for (var week = 0; week < weeks; week++)
                    SizedBox(
                      height: cellHeight,
                      child: Row(
                        children: [
                          for (var d = 0; d < DateHelpers.daysPerWeek; d++)
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final day =
                                      days[week * DateHelpers.daysPerWeek + d];
                                  return _DayCell(
                                    day: day,
                                    info: infoOf(day),
                                    inMonth: DateHelpers.isSameMonth(
                                      day,
                                      month,
                                    ),
                                    isToday: DateHelpers.isSameDay(day, today),
                                    isSelected: DateHelpers.isSameDay(
                                      day,
                                      selectedDay,
                                    ),
                                    onTap: () => onSelect(day),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.info,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final CalendarDayInfo info;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  static const double _numberSize = 24;
  static const double _dotSize = 7;
  static const double _outsideMonthOpacity = 0.35;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final thumbnail = info.thumbnail;

    final number = Container(
      width: _numberSize,
      height: _numberSize,
      alignment: Alignment.center,
      decoration: isToday
          ? BoxDecoration(color: palette.ink, shape: BoxShape.circle)
          : null,
      child: Text(
        '${day.day}',
        style: text.labelMedium?.copyWith(
          color: isToday ? palette.onInk : palette.ink,
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: isSelected,
      label: [
        AppFormatters.longDate(day),
        if (info.hasWorn) 'outfit worn',
        if (info.hasPlanned) 'outfit planned',
      ].join(', '),
      child: Opacity(
        opacity: inMonth ? 1 : _outsideMonthOpacity,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isSelected ? palette.surface : null,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: isSelected ? palette.ink : Colors.transparent,
              ),
            ),
            child: Column(
              children: [
                number,
                const SizedBox(height: 2),
                Expanded(
                  child: info.hasOutfit
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            if (thumbnail != null)
                              ClothingImage(
                                item: thumbnail,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xs,
                                ),
                                decodeWidth: 48,
                              )
                            else
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: palette.surfaceMuted,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xs,
                                  ),
                                ),
                              ),
                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: _StatusDot(worn: info.hasWorn),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.worn});

  final bool worn;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: _DayCell._dotSize,
      height: _DayCell._dotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: worn ? palette.ink : palette.surface,
        border: Border.all(color: worn ? palette.surface : palette.ink),
      ),
    );
  }
}

/// Explains the worn / planned markers.
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    Widget entry(bool worn, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatusDot(worn: worn),
        const SizedBox(width: AppSpacing.xxs + 2),
        Text(label, style: text.bodySmall),
      ],
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        entry(true, 'Worn'),
        const SizedBox(width: AppSpacing.lg),
        entry(false, 'Planned'),
      ],
    );
  }
}
