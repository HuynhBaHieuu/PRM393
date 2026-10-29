import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/app.dart';
import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit_slot.dart';
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/features/outfits/outfit_ideas.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/planner/screens/week_plan_screen.dart';
import 'package:all_fits/features/planner/week_planner.dart';

import '../helpers/test_harness.dart';

ClothingItem _item(
  String id,
  ClothingCategory category, {
  List<Season> seasons = const [],
  DateTime? lastWornAt,
}) => ClothingItem(
  id: id,
  name: id,
  category: category,
  seasons: seasons,
  lastWornAt: lastWornAt,
  createdAt: testNow,
  updatedAt: testNow,
);

List<ClothingItem> _wardrobe({int tops = 7, int bottoms = 7}) => [
  for (var i = 0; i < tops; i++) _item('top$i', ClothingCategory.tops),
  for (var i = 0; i < bottoms; i++) _item('bottom$i', ClothingCategory.bottoms),
  _item('sneakers', ClothingCategory.shoes),
  _item('boots', ClothingCategory.shoes),
];

final DateTime _monday = DateTime(2026, 11, 2);
final List<DateTime> _week = [
  for (var i = 0; i < WeekPlanner.length; i++) DateHelpers.addDays(_monday, i),
];

Set<String> _mainPieces(OutfitIdea idea) => {
  for (final item in idea.items)
    if (OutfitSlot.forCategory(item.category) != OutfitSlot.shoes) item.id,
};

void main() {
  group('WeekPlanner', () {
    test('plans seven complete looks without repeating a piece', () {
      final ideas = WeekPlanner.planWeek(_wardrobe(), days: _week);
      expect(ideas, hasLength(7));
      expect(ideas, everyElement(isNotNull));
      final seen = <String>{};
      for (final idea in ideas) {
        final pieces = _mainPieces(idea!);
        expect(pieces.where((p) => p.startsWith('top')), hasLength(1));
        expect(pieces.where((p) => p.startsWith('bottom')), hasLength(1));
        for (final piece in pieces) {
          expect(seen.add(piece), isTrue, reason: '$piece repeats');
        }
      }
      expect(WeekPlanner.repeats([for (final i in ideas) i!.items]), 0);
    });

    test('is the same every time for the same week', () {
      List<String> keys(List<OutfitIdea?> ideas) => [
        for (final idea in ideas) OutfitIdeas.lookKey(idea!.itemIds),
      ];
      expect(
        keys(WeekPlanner.planWeek(_wardrobe(), days: _week)),
        keys(WeekPlanner.planWeek(_wardrobe(), days: _week)),
      );
    });

    test('a small wardrobe still fills every day, without identical '
        'neighbours where it can', () {
      final ideas = WeekPlanner.planWeek(
        _wardrobe(tops: 2, bottoms: 2),
        days: _week,
      );
      expect(ideas, everyElement(isNotNull));
      final keys = {for (final i in ideas) OutfitIdeas.lookKey(i!.itemIds)};
      // 2 tops × 2 bottoms × 2 shoes make 8 looks: enough for a week.
      expect(keys, hasLength(7));
      expect(
        WeekPlanner.repeats([for (final i in ideas) i!.items]),
        greaterThan(0),
      );
    });

    test('kept looks count as used', () {
      final kept = [
        ['top0', 'bottom0', 'sneakers'],
      ];
      final ideas = WeekPlanner.planWeek(
        _wardrobe(),
        days: _week.take(6).toList(),
        kept: kept,
      );
      for (final idea in ideas) {
        expect(idea!.itemIds, isNot(contains('top0')));
        expect(idea.itemIds, isNot(contains('bottom0')));
      }
    });

    test('a swap gives a different look that avoids the other days', () {
      final ideas = WeekPlanner.planWeek(_wardrobe(tops: 8), days: _week);
      final monday = ideas.first!;
      final others = [for (final idea in ideas.skip(1)) idea!.itemIds];
      final swapped = WeekPlanner.lookFor(
        _wardrobe(tops: 8),
        day: _monday,
        others: [...others, monday.itemIds],
        variant: 1,
      )!;
      expect(
        OutfitIdeas.lookKey(swapped.itemIds),
        isNot(OutfitIdeas.lookKey(monday.itemIds)),
      );
      final taken = {for (final look in others) ...look};
      expect(
        swapped.itemIds.where((id) => id.startsWith('top')),
        everyElement(isNot(isIn(taken))),
      );
    });

    test('yesterday’s clothes wait', () {
      final wardrobe = [
        _item(
          'worn-top',
          ClothingCategory.tops,
          lastWornAt: DateHelpers.addDays(_monday, -1),
        ),
        _item('fresh-top', ClothingCategory.tops),
        _item('jeans', ClothingCategory.bottoms),
        _item('sneakers', ClothingCategory.shoes),
      ];
      final idea = WeekPlanner.lookFor(wardrobe, day: _monday)!;
      expect(idea.itemIds, contains('fresh-top'));
    });

    test('each day follows its own forecast', () {
      final wardrobe = [
        _item('tee', ClothingCategory.tops, seasons: [Season.summer]),
        _item('knit', ClothingCategory.tops, seasons: [Season.winter]),
        _item('shorts', ClothingCategory.bottoms, seasons: [Season.summer]),
        _item('wool', ClothingCategory.bottoms, seasons: [Season.winter]),
        _item('coat', ClothingCategory.outerwear, seasons: [Season.winter]),
        _item('sneakers', ClothingCategory.shoes),
      ];
      DayForecast day(DateTime date, double high) => DayForecast(
        date: date,
        high: high,
        low: high - 6,
        condition: WeatherCondition.clear,
        rainChance: 0,
      );
      final ideas = WeekPlanner.planWeek(
        wardrobe,
        days: _week.take(2).toList(),
        weather: {
          _week[0]: day(_week[0], 34).toReport(testCity),
          _week[1]: day(_week[1], 4).toReport(testCity),
        },
      );
      expect(ideas[0]!.itemIds, containsAll(['tee', 'shorts']));
      expect(ideas[1]!.itemIds, containsAll(['knit', 'wool', 'coat']));
    });

    test('needs a full look', () {
      final ideas = WeekPlanner.planWeek([
        _item('tee', ClothingCategory.tops),
        _item('sneakers', ClothingCategory.shoes),
      ], days: _week);
      expect(ideas, everyElement(isNull));
    });
  });

  testWidgets('plans the week, swaps a day and saves it to the planner', (
    tester,
  ) async {
    final deps = testDependencies(seedSampleData: true);
    await registerTestUser(deps);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AllFitsApp(dependencies: deps));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Navigator).first);
    final planner = context.read<PlannerController>();
    // Through the planner's ✨ button, as the user gets there.
    AppNavigator.planner(context);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Plan my week'));
    await tester.pumpAndSettle();

    final list = find
        .descendant(
          of: find.byType(WeekPlanScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    expect(find.text('Plan my week'), findsOneWidget);
    // The sample plans for today and in two and four days stay; the other
    // four days get new looks.
    expect(find.text('Already planned'), findsWidgets);
    final saveFour = find.text('Save 4 outfits to planner');
    expect(saveFour, findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Already planned').last,
      200,
      scrollable: list,
    );
    // Back to the top: "Today" is the start pill, then today's card.
    await tester.scrollUntilVisible(
      find.text('Today').first,
      -200,
      scrollable: list,
    );

    // Swapping a planned day offers to replace it.
    await tester.tap(find.widgetWithText(TextButton, 'Swap').first);
    await tester.pumpAndSettle();
    expect(find.text('Replaces your plan'), findsOneWidget);
    expect(find.text('Save 5 outfits to planner'), findsOneWidget);

    // Skipping a new day leaves it off.
    await tester.tap(find.byTooltip('Skip').first);
    await tester.pumpAndSettle();
    expect(saveFour, findsOneWidget);

    await tester.tap(saveFour);
    await tester.pumpAndSettle();
    expect(find.byType(WeekPlanScreen), findsNothing);
    expect(find.text('Planned 4 outfits'), findsOneWidget);

    final today = testNow;
    final planned = [
      for (var i = 0; i < WeekPlanner.length; i++)
        planner.dayPlan(DateHelpers.addDays(today, i)).planned,
    ];
    // Six days have an outfit: one was skipped.
    expect(planned.whereType<Object>(), hasLength(6));
  });
}
