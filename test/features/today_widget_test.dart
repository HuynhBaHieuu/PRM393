import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/l10n/l10n.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/data/local/home_screen_widget.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/data/repositories/settings_repository.dart';
import 'package:all_fits/features/settings/controllers/language_controller.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/today_widget/today_widget_data.dart';
import 'package:all_fits/features/today_widget/today_widget_sync.dart';
import 'package:all_fits/features/weather/controllers/weather_controller.dart';

import '../helpers/test_harness.dart';

/// Records what the app hands the home screen widget, and plays taps.
class _FakeHomeWidget implements HomeScreenWidget {
  final List<Map<String, String?>> updates = [];
  final StreamController<Uri> _taps = StreamController.broadcast();

  void tap(Uri link) => _taps.add(link);

  Map<String, String?> get last => updates.last;

  @override
  Future<void> update(
    Map<String, String?> values, {
    Uint8List? picture,
  }) async => updates.add(values);

  @override
  Stream<Uri> get taps => _taps.stream;

  @override
  bool get showsPicture => false;
}

void main() {
  late TestCloset closet;
  late String tee;
  late String jeans;
  late String sneakers;

  final today = DateHelpers.dateOnly(testNow);

  setUp(() async {
    closet = TestCloset();
    await closet.load();
    tee = await closet.addItem('Tee', ClothingCategory.tops);
    jeans = await closet.addItem('Jeans', ClothingCategory.bottoms);
    sneakers = await closet.addItem('Sneakers', ClothingCategory.shoes);
  });

  TodayWidgetData dataFor({WeatherReport? weather}) => TodayWidgetData.from(
    today: testNow,
    plan: closet.planner.dayPlan(today),
    outfitById: closet.outfits.outfitById,
    itemsByIds: closet.wardrobe.itemsByIds,
    wardrobe: closet.wardrobe.activeItems,
    weather: weather,
  );

  group('what the widget shows', () {
    test('the outfit planned for today, with a button to wear it', () async {
      final outfit = await closet.addOutfit('Casual', [tee, jeans, sneakers]);
      await closet.planner.planOutfit(today, outfit);

      final data = dataFor();
      expect(data.state, TodayWidgetState.planned);
      expect(data.title, 'Casual');
      expect(data.subtitle, 'Tee · Jeans · Sneakers');
      expect(data.actionLabel, 'Mark as worn');
      expect(data.actionLink, TodayWidgetLink.wear(outfit));
      expect(data.openLink, TodayWidgetLink.outfit(outfit));
      expect(data.toWidgetValues()['today_day'], '2026-10-01');
    });

    test('a worn outfit has nothing left to do', () async {
      final outfit = await closet.addOutfit('Casual', [tee, jeans]);
      await closet.closet.markWorn(outfit);

      final data = dataFor();
      expect(data.state, TodayWidgetState.worn);
      expect(data.heading, 'Worn today');
      expect(data.actionLabel, isNull);
      expect(data.toWidgetValues()['today_action_link'], isNull);
    });

    test('without a plan, a look from the wardrobe to save', () {
      final data = dataFor();
      expect(data.state, TodayWidgetState.idea);
      expect(data.outfit, isNull);
      expect(data.items.map((i) => i.id), containsAll([tee, jeans]));
      final link = data.actionLink!;
      expect(link.path, '/compose');
      expect(link.queryParameters['items']!.split(','), containsAll([tee]));
    });

    test('an empty wardrobe asks for clothes', () {
      final empty = TestCloset();
      final data = TodayWidgetData.from(
        today: testNow,
        plan: empty.planner.dayPlan(today),
        outfitById: empty.outfits.outfitById,
        itemsByIds: empty.wardrobe.itemsByIds,
        wardrobe: const [],
      );
      expect(data.state, TodayWidgetState.empty);
      expect(data.hasPicture, isFalse);
      expect(data.actionLink, TodayWidgetLink.addClothes);
    });

    test('everything it says follows the app language', () async {
      addTearDown(() => L10n.current = AppLanguage.en);
      L10n.current = AppLanguage.vi;

      final idea = dataFor();
      expect(idea.heading, 'Gợi ý hôm nay');
      expect(idea.actionLabel, 'Lưu outfit này');

      final outfit = await closet.addOutfit('Casual', [tee, jeans]);
      await closet.planner.planOutfit(today, outfit);
      final planned = dataFor();
      expect(planned.heading, 'Đã lên lịch hôm nay');
      expect(planned.actionLabel, 'Đánh dấu đã mặc');
      expect(planned.title, 'Casual');
      expect(
        planned.toWidgetValues()['today_open_title'],
        'Mở All Fits để xem outfit hôm nay',
      );

      await closet.closet.markWorn(outfit);
      expect(dataFor().heading, 'Đã mặc hôm nay');

      final none = TestCloset();
      final empty = TodayWidgetData.from(
        today: testNow,
        plan: none.planner.dayPlan(today),
        outfitById: none.outfits.outfitById,
        itemsByIds: none.wardrobe.itemsByIds,
        wardrobe: const [],
      );
      expect(empty.heading, 'Hôm nay');
      expect(empty.title, 'Hôm nay chưa có lịch');
      expect(
        empty.subtitle,
        'Thêm áo, quần và giày để có gợi ý outfit mỗi ngày.',
      );
      expect(empty.actionLabel, 'Thêm quần áo');

      expect(
        TodayWidgetData.signedOutValues['today_title'],
        'Đăng nhập để xem outfit hôm nay',
      );
    });

    test('the weather line and a signature that follows changes', () async {
      final report = WeatherReport(
        location: testCity,
        temperature: 28.6,
        high: 31,
        low: 24,
        condition: WeatherCondition.clear,
        rainChance: 10,
        fetchedAt: testNow,
      );
      final before = dataFor(weather: report);
      expect(before.weather, '☀️ 29° · ${testCity.name}');

      final outfit = await closet.addOutfit('Casual', [tee, jeans]);
      await closet.planner.planOutfit(today, outfit);
      expect(dataFor(weather: report).signature, isNot(before.signature));
    });
  });

  group('keeping the widget up to date', () {
    late _FakeHomeWidget homeWidget;
    late SettingsController settings;

    setUp(() async {
      settings = SettingsController(
        repository: LocalSettingsRepository(closet.storage),
        clock: () => testNow,
      );
      await settings.load();
    });

    Future<void> pumpSync(
      WidgetTester tester, {
      LanguageController? language,
    }) async {
      homeWidget = _FakeHomeWidget();
      final weather = WeatherController(service: const FakeWeatherService());
      addTearDown(weather.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<HomeScreenWidget>.value(value: homeWidget),
            Provider<ImageStorageService>.value(value: closet.images),
            ChangeNotifierProvider.value(value: closet.wardrobe),
            ChangeNotifierProvider.value(value: closet.outfits),
            ChangeNotifierProvider.value(value: closet.planner),
            ChangeNotifierProvider.value(value: weather),
            ChangeNotifierProvider.value(value: settings),
            Provider.value(value: closet.closet),
            if (language != null) ChangeNotifierProvider.value(value: language),
          ],
          child: const MaterialApp(
            home: TodayWidgetSync(child: Scaffold(body: Text('App'))),
          ),
        ),
      );
      // Updates wait for changes to settle.
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('updates after a change, and only when something changed', (
      tester,
    ) async {
      await pumpSync(tester);
      expect(homeWidget.updates, hasLength(1));
      expect(homeWidget.last['today_state'], 'idea');

      final outfit = await closet.addOutfit('Casual', [tee, jeans]);
      await closet.planner.planOutfit(today, outfit);
      await tester.pump(const Duration(seconds: 1));
      expect(homeWidget.updates, hasLength(2));
      expect(homeWidget.last['today_state'], 'planned');
      expect(homeWidget.last['today_title'], 'Casual');

      // A change elsewhere in the closet that the widget doesn't show.
      await closet.addItem('Scarf', ClothingCategory.accessories);
      await tester.pump(const Duration(seconds: 1));
      expect(homeWidget.updates, hasLength(2));
    });

    testWidgets('changing the language updates the widget', (tester) async {
      addTearDown(() => L10n.current = AppLanguage.en);
      final language = LanguageController(closet.storage);
      addTearDown(language.dispose);
      final outfit = await closet.addOutfit('Casual', [tee, jeans]);
      await closet.planner.planOutfit(today, outfit);
      await pumpSync(tester, language: language);
      expect(homeWidget.last['today_heading'], 'Planned for today');

      await language.setLanguage(AppLanguage.vi);
      await tester.pump(const Duration(seconds: 1));

      expect(homeWidget.last['today_heading'], 'Đã lên lịch hôm nay');
      expect(homeWidget.last['today_action'], 'Đánh dấu đã mặc');
      expect(homeWidget.last['today_title'], 'Casual');
    });

    testWidgets('loads the weather for the saved city', (tester) async {
      await settings.setWeatherLocation(testCity);
      await pumpSync(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(homeWidget.last['today_weather'], contains(testCity.name));
    });

    testWidgets('"Mark as worn" on the widget marks the outfit worn', (
      tester,
    ) async {
      final outfit = await closet.addOutfit('Casual', [tee, jeans]);
      await closet.planner.planOutfit(today, outfit);
      await pumpSync(tester);

      homeWidget.tap(TodayWidgetLink.wear(outfit));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(closet.planner.dayPlan(today).worn?.outfitId, outfit);
      expect(find.text('Marked as worn'), findsOneWidget);
      expect(homeWidget.last['today_state'], 'worn');
    });

    testWidgets('signing out clears the outfit from the home screen', (
      tester,
    ) async {
      await pumpSync(tester);
      await tester.pumpWidget(const SizedBox());
      expect(homeWidget.last['today_state'], 'signedOut');
      expect(homeWidget.last['today_title'], isNot(contains('Tee')));
    });
  });
}
