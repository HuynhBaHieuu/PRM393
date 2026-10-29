import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_durations.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/features/planner/widgets/planner_day_view.dart';
import 'package:all_fits/features/planner/widgets/planner_month_view.dart';
import 'package:all_fits/features/shared/closet_actions.dart';

/// Fits' planner: a Day tab (week strip over swipeable day cards) and a
/// Month tab, with "Today" in the app bar.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  late final DateTime _today = context.read<ClosetActions>().today;
  late DateTime _selected = _today;

  /// Bumped to make both views jump to [_selected].
  int _jump = 0;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _planWeek() async {
    final first = await AppNavigator.planWeek(context);
    if (first != null && mounted) _goTo(first, showDay: true);
  }

  void _goTo(DateTime day, {bool showDay = false}) {
    setState(() {
      _selected = DateHelpers.dateOnly(day);
      _jump++;
    });
    if (showDay) _tabs.animateTo(0, duration: AppDurations.fast);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planner'),
        actions: [
          IconButton(
            tooltip: 'Plan my week',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: _planWeek,
          ),
          IconButton(
            tooltip: 'Trips',
            icon: const Icon(Icons.luggage_outlined),
            onPressed: () => AppNavigator.trips(context),
          ),
          FilledButton(
            onPressed: () => _goTo(_today),
            style: FilledButton.styleFrom(
              backgroundColor: palette.surfaceMuted,
              foregroundColor: palette.ink,
              minimumSize: const Size(0, AppSizes.compactButtonHeight - 4),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            child: const Text('Today'),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Day'),
            Tab(text: 'Month'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          PlannerDayView(
            key: ValueKey('day$_jump'),
            today: _today,
            initialDay: _selected,
            onDayChanged: (day) => _selected = day,
            onPlanWeek: _planWeek,
          ),
          PlannerMonthView(
            key: ValueKey('month$_jump'),
            today: _today,
            initialMonth: _selected,
            onOpenDay: (day) => _goTo(day, showDay: true),
          ),
        ],
      ),
    );
  }
}
