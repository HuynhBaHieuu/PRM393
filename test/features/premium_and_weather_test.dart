import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/app/app.dart';
import 'package:all_fits/app/app_dependencies.dart';
import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/utils/load_status.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/app_settings.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/data/models/subscription_plan.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/data/repositories/settings_repository.dart';
import 'package:all_fits/features/home/screens/home_screen.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/weather/controllers/weather_controller.dart';
import 'package:all_fits/features/weather/weather_advice.dart';
import 'package:all_fits/navigation/app_navigation.dart';

import '../helpers/test_harness.dart';

ClothingItem _item(
  String id,
  ClothingCategory category,
  List<Season> seasons,
) => ClothingItem(
  id: id,
  name: id,
  category: category,
  seasons: seasons,
  createdAt: testNow,
  updatedAt: testNow,
);

Outfit _outfit(String id, List<String> itemIds) => Outfit(
  id: id,
  name: id,
  itemIds: itemIds,
  createdAt: testNow,
  updatedAt: testNow,
);

WeatherReport _report(double temperature, WeatherCondition condition) =>
    WeatherReport(
      location: testCity,
      temperature: temperature,
      high: temperature + 2,
      low: temperature - 2,
      condition: condition,
      rainChance: condition.isWet ? 80 : 0,
      fetchedAt: testNow,
    );

void main() {
  group('plans', () {
    test('Free holds a limited wardrobe, Premium does not', () {
      const limit = AppConfig.freeWardrobeLimit;
      expect(SubscriptionPlan.free.canAddItem(limit - 1), isTrue);
      expect(SubscriptionPlan.free.canAddItem(limit), isFalse);
      expect(SubscriptionPlan.premium.canAddItem(limit * 10), isTrue);
      expect(SubscriptionPlan.free.hasAiStylist, isFalse);
      expect(SubscriptionPlan.premium.hasAiStylist, isTrue);
    });

    test('upgrading and cancelling persist', () async {
      final storage = InMemoryStorageService();
      final settings = SettingsController(
        repository: LocalSettingsRepository(storage),
        clock: () => testNow,
      );
      await settings.load();
      expect(settings.plan, SubscriptionPlan.free);

      await settings.startPremium();
      final reloaded = SettingsController(
        repository: LocalSettingsRepository(storage),
      );
      await reloaded.load();
      expect(reloaded.isPremium, isTrue);
      expect(reloaded.settings.premiumSince, testNow);

      await reloaded.cancelPremium();
      expect(reloaded.plan, SubscriptionPlan.free);
      expect(reloaded.settings.premiumSince, isNull);
    });

    test('settings keep the weather city and tolerate bad data', () {
      final json = const AppSettings(weatherLocation: testCity).toJson();
      expect(AppSettings.fromJson(json).weatherLocation?.label, 'Oslo, Norway');
      final broken = AppSettings.fromJson({
        'plan': 'gold',
        'weatherLocation': {'name': 'Nowhere'},
      });
      expect(broken.plan, SubscriptionPlan.free);
      expect(broken.weatherLocation, isNull);
    });
  });

  group('weather advice', () {
    final coat = _item('coat', ClothingCategory.outerwear, [Season.winter]);
    final jumper = _item('jumper', ClothingCategory.tops, [Season.winter]);
    final tank = _item('tank', ClothingCategory.tops, [Season.summer]);
    final shorts = _item('shorts', ClothingCategory.bottoms, [Season.summer]);
    final byId = {
      for (final i in [coat, jumper, tank, shorts]) i.id: i,
    };
    final winterLook = _outfit('winter', ['coat', 'jumper']);
    final summerLook = _outfit('summer', ['tank', 'shorts']);
    List<ClothingItem> itemsOf(Outfit o) => [
      for (final id in o.itemIds) ?byId[id],
    ];

    test('cold rain picks layered looks', () {
      final advice = WeatherAdvice(_report(4, WeatherCondition.rain));
      expect(advice.needsOuterwear, isTrue);
      expect(advice.summary, contains('coat'));
      expect(advice.pickOutfits([summerLook, winterLook], itemsOf), [
        winterLook,
      ]);
    });

    test('heat picks light looks', () {
      final advice = WeatherAdvice(_report(30, WeatherCondition.clear));
      expect(advice.isHot, isTrue);
      expect(advice.pickOutfits([winterLook, summerLook], itemsOf), [
        summerLook,
      ]);
    });

    test('WMO codes map to conditions', () {
      expect(WeatherCondition.fromCode(0), WeatherCondition.clear);
      expect(WeatherCondition.fromCode(3), WeatherCondition.cloudy);
      expect(WeatherCondition.fromCode(61), WeatherCondition.rain);
      expect(WeatherCondition.fromCode(73), WeatherCondition.snow);
      expect(WeatherCondition.fromCode(95), WeatherCondition.storm);
    });

    test('the controller loads once and refreshes when stale', () async {
      var now = testNow;
      final weather = WeatherController(
        service: const FakeWeatherService(),
        clock: () => now,
      );
      expect(weather.needsRefresh(testCity), isTrue);
      await weather.refresh(testCity);
      expect(weather.status, LoadStatus.ready);
      expect(weather.report?.temperature, 6);
      expect(weather.needsRefresh(testCity), isFalse);
      now = testNow.add(AppConfig.weatherMaxAge * 2);
      expect(weather.needsRefresh(testCity), isTrue);
    });
  });

  group('screens', () {
    Future<void> pumpApp(
      WidgetTester tester,
      AppDependencies deps, {
      int items = 0,
    }) async {
      final user = await registerTestUser(deps);
      if (items > 0) await seedWardrobe(deps, user, items);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(AllFitsApp(dependencies: deps));
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> tapNav(WidgetTester tester, String label) => tap(
      tester,
      find.descendant(
        of: find.byType(AppBottomBar),
        matching: find.text(label),
      ),
    );

    /// Picks an option from the central "+" sheet.
    Future<void> create(WidgetTester tester, String option) async {
      await tap(tester, find.byTooltip('Create'));
      await tap(tester, find.text(option));
    }

    testWidgets('the AI Stylist unlocks after upgrading', (tester) async {
      await pumpApp(tester, testDependencies());
      await create(tester, 'AI Stylist');
      expect(find.text('AI Stylist is a Premium feature'), findsOneWidget);

      await tap(tester, find.text('See Premium'));
      expect(find.text('All Fits Premium'), findsOneWidget);
      expect(find.text('Current plan'), findsOneWidget);
      await tap(tester, find.textContaining('Upgrade for'));
      await tap(tester, find.text('Start Premium'));
      expect(find.text('Cancel Premium'), findsOneWidget);

      await tap(tester, find.byTooltip('Back'));
      // Unlocked: without an API key the stylist explains its setup.
      expect(find.text('AI stylist isn’t set up'), findsOneWidget);
    });

    testWidgets('a full Free wardrobe offers Premium instead of the form', (
      tester,
    ) async {
      await pumpApp(
        tester,
        testDependencies(),
        items: AppConfig.freeWardrobeLimit,
      );
      await create(tester, 'Add clothes');
      expect(find.text('Your wardrobe is full'), findsOneWidget);
      expect(find.text('Add clothing'), findsNothing);
    });

    testWidgets('home shows weather picks for the chosen city', (tester) async {
      await pumpApp(tester, testDependencies());
      await tester.scrollUntilVisible(
        find.text('Set city'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(HomeScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tap(tester, find.text('Set city'));
      await tester.enterText(find.byType(TextField), 'Oslo');
      await tap(tester, find.text('Find'));

      await tester.ensureVisible(find.text('Dress for the weather'));
      await tester.pumpAndSettle();
      expect(find.text('Oslo, Norway'), findsOneWidget);
      expect(find.text('6° · Rain'), findsOneWidget);
      expect(find.textContaining('coat'), findsOneWidget);
    });
    for (final (label, size) in [
      ('small phone', const Size(320, 640)),
      ('tablet', const Size(1024, 768)),
      ('desktop', const Size(1440, 900)),
    ]) {
      testWidgets('new screens lay out without overflow on a $label', (
        tester,
      ) async {
        final deps = testDependencies();
        final user = await registerTestUser(deps);
        await makePremium(deps, user);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(AllFitsApp(dependencies: deps));
        await tester.pumpAndSettle();

        await tapNav(tester, 'Profile');
        await tap(tester, find.byTooltip('Account'));
        expect(find.text('Premium'), findsWidgets);
        await tap(tester, find.text('All Fits Premium'));
        expect(find.text('Cancel Premium'), findsOneWidget);
        await tap(tester, find.byTooltip('Back'));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
