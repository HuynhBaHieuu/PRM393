import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/theme/app_theme.dart';
import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/data/local/image_picker_service.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_subcategory.dart';
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/data/models/subscription_plan.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';
import 'package:all_fits/data/repositories/settings_repository.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/auto_detect_controller.dart';
import 'package:all_fits/features/wardrobe/screens/clothing_form_screen.dart';
import 'package:all_fits/navigation/app_navigation.dart';

import '../helpers/test_harness.dart';

const _tee = ClothingDetection(
  category: ClothingCategory.tops,
  subcategory: ClothingSubcategory.tShirts,
  colors: [ClothingColor.black, ClothingColor.white],
  seasons: [Season.spring, Season.summer],
  name: 'Adidas t-shirt',
  brand: 'Adidas',
);

/// Answers detections with [answer], or fails with [failWith].
class _FakeDetector extends AiStylistService {
  _FakeDetector() : super(apiKey: 'key');

  ClothingDetection answer = _tee;
  Object? failWith;
  int calls = 0;

  @override
  Future<ClothingDetection> detectClothing(
    List<int> photo, {
    Future<void>? cancel,
  }) async {
    calls++;
    if (failWith case final error?) throw error;
    return answer;
  }
}

void main() {
  late InMemoryStorageService storage;
  late _FakeDetector service;
  late DateTime now;

  AutoDetectController detector() => AutoDetectController(
    storage: storage,
    service: service,
    clock: () => now,
    readFile: (_) async => [1, 2, 3],
  );

  setUp(() {
    storage = InMemoryStorageService();
    service = _FakeDetector();
    now = testNow;
  });

  group('AutoDetectController', () {
    test('Free gets five detections a month; failures are free', () async {
      final controller = detector();
      await controller.load();
      expect(controller.left(SubscriptionPlan.free), 5);
      expect(controller.left(SubscriptionPlan.premium), isNull);

      await controller.detect('/a.jpg');
      service.failWith = const AiException('offline');
      await expectLater(
        controller.detect('/b.jpg'),
        throwsA(isA<AiException>()),
      );
      expect(controller.left(SubscriptionPlan.free), 4);

      // A new month starts over.
      now = DateTime(2026, 11, 2);
      expect(controller.left(SubscriptionPlan.free), 5);
    });

    test('remembers consent and the Settings switch', () async {
      final first = detector();
      await first.load();
      expect(first.consented, isFalse);
      expect(first.isOn, isTrue);
      await first.consent();
      await first.setEnabled(false);
      await first.detect('/a.jpg');

      final again = detector();
      await again.load();
      expect(again.consented, isTrue);
      expect(again.enabled, isFalse);
      expect(again.isOn, isFalse);
      expect(again.usedThisMonth, 1);
    });

    test('is unavailable without an AI key', () {
      final controller = AutoDetectController(
        storage: storage,
        service: const AiStylistService(apiKey: ''),
      );
      expect(controller.isOn, isFalse);
    });
  });

  group('clothing form', () {
    late AutoDetectController controller;

    Future<void> pumpForm(
      WidgetTester tester, {
      bool consented = true,
      bool tipsSeen = true,
    }) async {
      final closet = TestCloset();
      await closet.load();
      final settings = SettingsController(
        repository: LocalSettingsRepository(storage),
        clock: () => now,
      );
      await settings.load();
      controller = detector();
      await controller.load();
      if (consented) await controller.consent();
      if (tipsSeen) await controller.markTipsSeen();
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ImagePickerService>.value(value: FakeImagePickerService()),
            ChangeNotifierProvider.value(value: closet.wardrobe),
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: controller),
            ChangeNotifierProvider.value(value: ShellController()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ClothingFormScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pickPhoto(WidgetTester tester) async {
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
    }

    String fieldText(WidgetTester tester, String label) => tester
        .widget<TextField>(
          find.descendant(
            of: find.widgetWithText(TextFormField, label),
            matching: find.byType(TextField),
          ),
        )
        .controller!
        .text;

    testWidgets('fills only empty fields and marks them; Undo puts them '
        'back', (tester) async {
      await pumpForm(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'My gym tee',
      );
      await pickPhoto(tester);

      expect(find.textContaining('Filled in by AI'), findsOneWidget);
      // What the user typed stays.
      expect(fieldText(tester, 'Name'), 'My gym tee');
      expect(fieldText(tester, 'Brand'), 'Adidas');
      expect(find.text('T-Shirts'), findsOneWidget);
      expect(find.text('Black'), findsOneWidget);
      // Category, type, color, season and brand: not the name.
      expect(find.byTooltip('Filled in by AI'), findsNWidgets(5));
      expect(
        find.textContaining(
          '${AppConfig.freeDetectionsPerMonth - 1} free detections left',
        ),
        findsOneWidget,
      );

      // Changing a value makes it the user's own.
      await tester.ensureVisible(find.text('Winter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Winter'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Filled in by AI'), findsNWidgets(4));

      await tester.ensureVisible(find.text('Undo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Filled in by AI'), findsNothing);
      expect(fieldText(tester, 'Name'), 'My gym tee');
      expect(fieldText(tester, 'Brand'), isEmpty);
      // No category means the type row is gone.
      expect(find.text('T-Shirts'), findsNothing);
      // The season the user picked stays.
      final winter = tester.widget<SelectablePill>(
        find.widgetWithText(SelectablePill, 'Winter'),
      );
      expect(winter.selected, isTrue);
    });

    testWidgets('shows photo tips once, before the first photo', (
      tester,
    ) async {
      await pumpForm(tester, tipsSeen: false);
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      expect(find.text('How to get best results'), findsOneWidget);
      expect(service.calls, 0);

      await tester.tap(find.text('Got it 👌'));
      await tester.pumpAndSettle();
      expect(controller.tipsSeen, isTrue);
      expect(service.calls, 1);

      await tester.ensureVisible(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();
      expect(find.text('How to get best results'), findsNothing);
    });

    testWidgets('fills the main color and offers the others', (tester) async {
      await pumpForm(tester);
      await pickPhoto(tester);
      expect(find.text('Also in this piece'), findsOneWidget);

      await tester.ensureVisible(find.text('White'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('White'));
      await tester.pumpAndSettle();
      // White is the main color now and Black moves to the extras.
      final extras = find.ancestor(
        of: find.text('Also in this piece'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: extras.first, matching: find.text('Black')),
        findsOneWidget,
      );
      expect(find.text('White'), findsOneWidget);
    });

    testWidgets('a new photo detects again from scratch', (tester) async {
      await pumpForm(tester);
      await pickPhoto(tester);
      expect(fieldText(tester, 'Name'), 'Adidas t-shirt');

      service.answer = const ClothingDetection(
        category: ClothingCategory.shoes,
        name: 'White sneakers',
      );
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();

      expect(service.calls, 2);
      expect(fieldText(tester, 'Name'), 'White sneakers');
      expect(fieldText(tester, 'Brand'), isEmpty);
      expect(find.text('Sneakers'), findsOneWidget);
    });

    testWidgets('asks before sending the first photo', (tester) async {
      await pumpForm(tester, consented: false);
      await pickPhoto(tester);
      expect(find.text('Let AI fill in this piece?'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(service.calls, 0);
      expect(controller.enabled, isFalse);
      expect(fieldText(tester, 'Name'), isEmpty);
    });

    testWidgets('a failed detection leaves the form to the user', (
      tester,
    ) async {
      await pumpForm(tester);
      service.failWith = const AiException('timeout');
      await pickPhoto(tester);
      expect(
        find.text('Couldn’t detect this piece. Fill it in yourself.'),
        findsOneWidget,
      );
      expect(fieldText(tester, 'Name'), isEmpty);
    });

    testWidgets('Free stops after five a month', (tester) async {
      await pumpForm(tester);
      for (var i = 0; i < AppConfig.freeDetectionsPerMonth; i++) {
        await controller.detect('/x.jpg');
      }
      await pickPhoto(tester);
      expect(service.calls, AppConfig.freeDetectionsPerMonth);
      expect(find.text('Go Premium'), findsOneWidget);
    });
  });
}
