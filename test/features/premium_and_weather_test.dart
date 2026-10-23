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
import 'package:all_fits/data/models/user_account.dart';
import 'package:all_fits/data/models/stylist_persona.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';
import 'package:all_fits/data/remote/payos_checkout.dart';
import 'package:all_fits/data/repositories/settings_repository.dart';
import 'package:all_fits/features/home/screens/home_screen.dart';
import 'package:all_fits/features/premium/premium_flows.dart';
import 'package:all_fits/features/premium/widgets/premium_widgets.dart';
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

/// Repeats the question back.
class _EchoStylist extends AiStylistService {
  const _EchoStylist() : super(apiKey: 'fake');

  @override
  Future<StylistMessage> reply({
    required List<ClothingItem> wardrobe,
    required List<StylistMessage> history,
    WeatherReport? weather,
    StylistPersona persona = StylistPersona.kai,
    String notes = '',
    String? Function(String photo)? resolvePhoto,
    Future<void>? cancel,
  }) async => StylistMessage.stylist('Answer to ${history.last.text}');
}

void main() {
  group('plans', () {
    test('Free holds a limited wardrobe, Premium does not', () {
      const limit = AppConfig.freeWardrobeLimit;
      expect(SubscriptionPlan.free.canAddItem(limit - 1), isTrue);
      expect(SubscriptionPlan.free.canAddItem(limit), isFalse);
      expect(SubscriptionPlan.premium.canAddItem(limit * 10), isTrue);
      expect(
        SubscriptionPlan.free.stylistMessagesPerDay,
        AppConfig.freeStylistMessagesPerDay,
      );
      expect(SubscriptionPlan.premium.stylistMessagesPerDay, isNull);
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
    Future<AppUser> pumpApp(
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
      return user;
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

    testWidgets('Free gets a few stylist messages a day, Premium unlimited', (
      tester,
    ) async {
      await pumpApp(
        tester,
        testDependencies(aiStylist: const _EchoStylist()),
        items: 3,
      );
      await create(tester, 'AI Stylist');
      const limit = AppConfig.freeStylistMessagesPerDay;
      expect(find.text('$limit free messages left today'), findsOneWidget);

      for (var i = 1; i <= limit; i++) {
        await tester.enterText(find.byType(TextField), 'Question $i');
        await tap(tester, find.byTooltip('Send'));
        expect(find.text('Answer to Question $i'), findsOneWidget);
      }
      expect(find.textContaining('used today’s free messages'), findsOneWidget);
      final send = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_upward_rounded),
      );
      expect(send.onPressed, isNull);

      await tap(tester, find.text('See Premium'));
      expect(find.text('Current plan'), findsOneWidget);
      await tap(tester, find.textContaining('Upgrade for'));
      await tap(tester, find.text('Start Premium'));
      await tap(tester, find.byTooltip('Back'));

      // Unlimited now: no count, and the chat is still there.
      expect(find.textContaining('free message'), findsNothing);
      expect(find.text('Answer to Question $limit'), findsOneWidget);
    });

    testWidgets('payOS checkout starts Premium once the payment arrives', (
      tester,
    ) async {
      final payments = FakePayOSCheckout([
        PaymentStatus.pending,
        PaymentStatus.paid,
      ]);
      final deps = testDependencies(payments: payments);
      final user = await pumpApp(tester, deps);
      // What the Edge Function does on the server once payOS reports paid.
      payments.onPaid = () async {
        final repository = deps.repositoriesFor(user.id).settings;
        final settings = await repository.load();
        await repository.save(
          settings.copyWith(
            plan: SubscriptionPlan.premium,
            premiumUntil: testNow.add(
              const Duration(days: AppConfig.premiumDays),
            ),
          ),
        );
      };

      await tapNav(tester, 'Profile');
      await tap(tester, find.byTooltip('Account'));
      await tap(tester, find.text('All Fits Premium'));
      expect(find.text(PremiumFlows.payOSPrice), findsOneWidget);
      // The wait dialog spins until paid, so pump by hand instead of settling.
      await tester.tap(find.textContaining('Upgrade for'));
      await tester.pump();
      await tester.pump();
      expect(payments.opened, [FakePayOSCheckout.checkoutUrl]);
      expect(find.text('Waiting for payment'), findsOneWidget);

      await tester.pump(PaymentWaitDialog.pollInterval);
      expect(find.text('Waiting for payment'), findsOneWidget);
      await tester.pump(PaymentWaitDialog.pollInterval);
      await tester.pumpAndSettle();
      expect(find.text('Waiting for payment'), findsNothing);
      expect(find.textContaining('Premium is active until'), findsOneWidget);
      expect(find.text('Add 30 days for 2,000 VND'), findsOneWidget);
      expect(find.text('Cancel Premium'), findsNothing);
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
