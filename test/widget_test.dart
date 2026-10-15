import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/app/app.dart';
import 'package:all_fits/app/app_dependencies.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/occasion.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';

import 'helpers/test_harness.dart';

/// Pixel 6a-like viewport.
const Size _phoneSize = Size(1080, 2400);
const double _phoneRatio = 2.625;

/// Starts the app, signed in as the test user unless [signedIn] is false.
Future<void> _pumpApp(
  WidgetTester tester,
  AppDependencies deps, {
  bool signedIn = true,
  bool premium = false,
}) async {
  if (signedIn) {
    final user = await registerTestUser(deps);
    if (premium) await makePremium(deps, user);
  }
  tester.view.physicalSize = _phoneSize;
  tester.view.devicePixelRatio = _phoneRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(AllFitsApp(dependencies: deps));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapNav(WidgetTester tester, String label) => _tap(
  tester,
  find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
);

Future<void> _addClothing(
  WidgetTester tester, {
  required String name,
  required String category,
}) async {
  expect(find.text('Add clothing'), findsOneWidget);
  await _tap(tester, find.text('Gallery'));
  await tester.enterText(find.widgetWithText(TextFormField, 'Name'), name);
  await _tap(tester, find.text(category));
  await _tap(tester, find.text('Save'));
}

/// Answers instantly with one outfit made of the first three items.
class _FakeStylist extends AiStylistService {
  const _FakeStylist() : super(apiKey: 'fake');

  @override
  Future<List<OutfitSuggestion>> suggest({
    required List<ClothingItem> wardrobe,
    Occasion? occasion,
    String note = '',
  }) async => [
    OutfitSuggestion(
      name: 'Rainy Monday',
      itemIds: [for (final item in wardrobe.take(3)) item.id],
      reason: 'Picked for ${occasion?.label}: $note',
    ),
  ];
}

void main() {
  testWidgets('home shows a greeting and empty states', (tester) async {
    await _pumpApp(tester, testDependencies());

    expect(find.text('What are you wearing today?'), findsOneWidget);
    expect(find.text('No outfit for today'), findsOneWidget);
    expect(find.text('Create Outfit'), findsWidgets);
    expect(find.text('Recently added'), findsOneWidget);
  });

  testWidgets('bottom navigation switches between sections', (tester) async {
    await _pumpApp(tester, testDependencies());

    await _tapNav(tester, 'Wardrobe');
    expect(find.text('Your Wardrobe'), findsOneWidget);
    expect(find.text('Your wardrobe is empty'), findsOneWidget);

    await _tapNav(tester, 'Outfits');
    expect(find.text('No outfits yet'), findsOneWidget);

    await _tapNav(tester, 'Planner');
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Nothing planned'), findsOneWidget);

    await _tapNav(tester, 'Profile');
    expect(find.text('Wardrobe Insights'), findsOneWidget);
    expect(find.text('Archived Items'), findsOneWidget);
  });

  testWidgets('sample data is seeded on first launch only', (tester) async {
    final storage = InMemoryStorageService();
    await _pumpApp(
      tester,
      testDependencies(storage: storage, seedSampleData: true),
    );
    // A sample outfit is planned for today.
    expect(find.text('Weekend Denim'), findsWidgets);
    expect(find.text('Planned for today'), findsOneWidget);

    await _tapNav(tester, 'Wardrobe');
    expect(find.text('25 pieces'), findsOneWidget);

    // Brands filter the grid like categories do. The brand bar scrolls
    // sideways, so its pills may start out of view.
    await _tap(tester, find.text('Adidas', skipOffstage: false));
    expect(find.text('2 items'), findsOneWidget);
    await _tap(tester, find.text('Adidas'));
    expect(find.text('25 items'), findsOneWidget);
  });

  testWidgets('add item validation highlights missing fields', (tester) async {
    await _pumpApp(tester, testDependencies());
    await _tap(tester, find.text('Add Clothing').first);
    await _tap(tester, find.text('Save'));

    expect(find.text('A photo is required'), findsOneWidget);
    expect(find.text('Please enter a name'), findsOneWidget);
    expect(find.text('Choose a category'), findsOneWidget);
  });

  testWidgets('a suggested brand fills the brand field', (tester) async {
    await _pumpApp(tester, testDependencies());
    await _tap(tester, find.text('Add Clothing').first);
    // Typing narrows the brand row to matching brands.
    final brandField = find.widgetWithText(TextFormField, 'Brand');
    await tester.enterText(brandField, 'bal');
    await tester.pumpAndSettle();
    expect(find.text('Supreme'), findsNothing);
    await _tap(tester, find.text('Balenciaga'));

    expect(find.widgetWithText(TextFormField, 'Balenciaga'), findsOneWidget);
  });

  testWidgets('full flow: add clothes, build an outfit, plan it and wear it', (
    tester,
  ) async {
    await _pumpApp(tester, testDependencies());

    // Add the first item from Home; saving returns to the wardrobe.
    await _tap(tester, find.text('Add Clothing').first);
    await _addClothing(tester, name: 'White Tee', category: 'Top');
    expect(find.text('Your Wardrobe'), findsOneWidget);
    expect(find.text('White Tee'), findsOneWidget);

    // Add a second item from the wardrobe header.
    await _tap(tester, find.byTooltip('Add clothing'));
    await _addClothing(tester, name: 'Blue Jeans', category: 'Bottom');
    expect(find.text('Blue Jeans'), findsOneWidget);
    expect(find.text('2 pieces'), findsOneWidget);

    // Search filters instantly.
    await tester.enterText(find.byType(TextField).first, 'jeans');
    await tester.pumpAndSettle();
    expect(find.text('White Tee'), findsNothing);
    expect(find.text('Blue Jeans'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();

    // Build an outfit.
    await _tapNav(tester, 'Outfits');
    await _tap(tester, find.text('Create Outfit'));
    expect(find.text('New outfit'), findsOneWidget);

    await _tap(tester, find.widgetWithText(ActionChip, 'Top'));
    await _tap(tester, find.text('White Tee').last);
    await _tap(tester, find.textContaining('Done'));

    await _tap(tester, find.widgetWithText(ActionChip, 'Bottom'));
    await _tap(tester, find.text('Blue Jeans').last);
    await _tap(tester, find.textContaining('Done'));

    await tester.enterText(
      find.widgetWithText(TextField, 'Outfit name'),
      'Everyday Look',
    );
    await _tap(tester, find.text('Save'));

    // The new outfit appears in the Outfits tab.
    expect(find.text('Everyday Look'), findsOneWidget);
    expect(find.text('2 pieces'), findsOneWidget);

    // Plan it for today in the planner, then mark it as worn.
    await _tapNav(tester, 'Planner');
    await _tap(tester, find.text('Plan Outfit'));
    await _tap(tester, find.text('Everyday Look').last);
    expect(find.text('Mark as Worn'), findsOneWidget);

    await _tap(tester, find.text('Mark as Worn'));
    expect(find.text('Undo'), findsOneWidget);

    // Wear statistics are updated everywhere.
    await _tapNav(tester, 'Outfits');
    await _tap(tester, find.text('Everyday Look'));
    expect(find.text('TIME WORN'), findsOneWidget);
    expect(find.text('Worn today'), findsWidgets);

    await _tap(tester, find.text('White Tee'));
    expect(find.text('TIME WORN'), findsOneWidget);
    expect(find.textContaining('Worn 1 time'), findsOneWidget);
  });

  group('accounts', () {
    Future<void> fill(WidgetTester tester, String label, String value) =>
        tester.enterText(find.widgetWithText(TextFormField, label), value);

    Future<void> register(
      WidgetTester tester, {
      required String name,
      required String email,
    }) async {
      await _tap(tester, find.text('Create an account'));
      await fill(tester, 'Name', name);
      await fill(tester, 'Email', email);
      await fill(tester, 'Password', testPassword);
      await fill(tester, 'Confirm password', testPassword);
      await _tap(tester, find.widgetWithText(FilledButton, 'Create account'));
    }

    Future<void> logOut(WidgetTester tester) async {
      await _tapNav(tester, 'Profile');
      await _tap(tester, find.text('Log out'));
      await _tap(tester, find.widgetWithText(TextButton, 'Log out'));
    }

    testWidgets('signed-out users see the login screen', (tester) async {
      await _pumpApp(tester, testDependencies(), signedIn: false);
      expect(find.text('Log in'), findsWidgets);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('register validates input, then opens the wardrobe', (
      tester,
    ) async {
      await _pumpApp(tester, testDependencies(), signedIn: false);
      await _tap(tester, find.text('Create an account'));
      await fill(tester, 'Email', 'nope');
      await fill(tester, 'Password', 'short');
      await fill(tester, 'Confirm password', 'different');
      await _tap(tester, find.widgetWithText(FilledButton, 'Create account'));
      expect(find.text('Please enter your name'), findsOneWidget);
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Use at least 8 characters'), findsOneWidget);
      expect(find.text('Passwords don’t match'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await register(tester, name: 'Jamie Lee', email: 'jamie@example.com');

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.textContaining('Jamie'), findsWidgets);
      await _tapNav(tester, 'Profile');
      expect(find.text('Jamie Lee'), findsOneWidget);
      expect(find.text('jamie@example.com'), findsOneWidget);
    });

    testWidgets('wrong password shows an error; log out keeps the email', (
      tester,
    ) async {
      final deps = testDependencies();
      await _pumpApp(tester, deps);
      await logOut(tester);

      expect(find.text('Log in'), findsWidgets);
      // The last email is prefilled.
      expect(find.text(testEmail), findsOneWidget);

      await fill(tester, 'Password', 'wrong-pass1');
      await _tap(tester, find.widgetWithText(FilledButton, 'Log in'));
      expect(find.text('Incorrect email or password.'), findsOneWidget);

      await fill(tester, 'Password', testPassword);
      await _tap(tester, find.widgetWithText(FilledButton, 'Log in'));
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('each account sees only its own wardrobe', (tester) async {
      await _pumpApp(tester, testDependencies());
      await _tap(tester, find.text('Add Clothing').first);
      await _addClothing(tester, name: 'Alex Coat', category: 'Outerwear');
      expect(find.text('Alex Coat'), findsOneWidget);

      await logOut(tester);
      await register(tester, name: 'Sam', email: 'sam@example.com');
      await _tapNav(tester, 'Wardrobe');
      expect(find.text('Your wardrobe is empty'), findsOneWidget);

      await logOut(tester);
      await fill(tester, 'Email', testEmail);
      await fill(tester, 'Password', testPassword);
      await _tap(tester, find.widgetWithText(FilledButton, 'Log in'));
      await _tapNav(tester, 'Wardrobe');
      expect(find.text('Alex Coat'), findsOneWidget);
    });
  });

  group('AI stylist', () {
    testWidgets('suggests an outfit that can be saved', (tester) async {
      await _pumpApp(
        tester,
        testDependencies(seedSampleData: true, aiStylist: const _FakeStylist()),
        premium: true,
      );
      await _tapNav(tester, 'Outfits');
      await _tap(tester, find.byTooltip('AI stylist'));

      await _tap(tester, find.text('Work'));
      await tester.enterText(find.byType(TextField), 'light rain');
      await _tap(tester, find.text('Suggest outfits'));

      expect(find.text('Rainy Monday'), findsOneWidget);
      expect(find.text('Picked for Work: light rain'), findsOneWidget);

      await _tap(tester, find.text('Save outfit'));
      expect(find.text('Saved'), findsOneWidget);

      await _tap(tester, find.byTooltip('Close'));
      expect(find.text('6 looks'), findsOneWidget);
      expect(find.text('Rainy Monday'), findsOneWidget);
    });

    testWidgets('explains how to turn it on when there is no API key', (
      tester,
    ) async {
      await _pumpApp(tester, testDependencies(), premium: true);
      await _tapNav(tester, 'Outfits');
      await _tap(tester, find.byTooltip('AI stylist'));
      expect(find.text('AI stylist isn’t set up'), findsOneWidget);
    });
  });
}
