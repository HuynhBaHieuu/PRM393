import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/app.dart';
import 'package:all_fits/app/app_dependencies.dart';
import 'package:all_fits/app/app_material_app.dart';
import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit_slot.dart';
import 'package:all_fits/data/models/user_account.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';
import 'package:all_fits/data/repositories/auth_repository.dart';
import 'package:all_fits/features/auth/controllers/auth_controller.dart';
import 'package:all_fits/features/auth/screens/login_screen.dart';
import 'package:all_fits/features/collections/widgets/collection_cards.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/screens/swipe_outfit_screen.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cards.dart';
import 'package:all_fits/features/stylist/screens/stylist_screen.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/wardrobe/widgets/clothing_tile.dart';
import 'package:all_fits/navigation/app_navigation.dart';

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
  find.descendant(of: find.byType(AppBottomBar), matching: find.text(label)),
);

/// Opens Clothes, Outfits or Planner inside the Profile tab.
Future<void> _openTab(WidgetTester tester, String label) async {
  await _tapNav(tester, 'Profile');
  await _tap(tester, find.widgetWithText(Tab, label));
}

Future<void> _openAccount(WidgetTester tester) async {
  await _tapNav(tester, 'Profile');
  await _tap(tester, find.byTooltip('Account'));
}

/// Picks an option from the central "+" sheet.
Future<void> _create(WidgetTester tester, String option) async {
  await _tap(tester, find.byTooltip('Create'));
  await _tap(tester, find.text(option));
}

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

/// Answers instantly with one outfit made of the first three items, and
/// fails once when asked to.
class _FakeStylist extends AiStylistService {
  _FakeStylist() : super(apiKey: 'fake');

  bool failNext = false;

  @override
  Future<StylistMessage> reply({
    required List<ClothingItem> wardrobe,
    required List<StylistMessage> history,
    WeatherReport? weather,
    String? Function(String photo)? resolvePhoto,
  }) async {
    if (failNext) {
      failNext = false;
      throw const AiException('The AI service is busy right now.');
    }
    final asked = history.last;
    if (asked.photo != null) {
      return StylistMessage.stylist('Nice photo: ${asked.text}');
    }
    if (asked.itemIds.isNotEmpty) {
      final names = [
        for (final item in wardrobe)
          if (asked.itemIds.contains(item.id)) item.name,
      ];
      return StylistMessage.stylist('Attached: ${names.join(', ')}');
    }
    return StylistMessage.stylist(
      'You said: ${asked.text}',
      outfits: [
        OutfitSuggestion(
          name: 'Rainy Monday',
          itemIds: [for (final item in wardrobe.take(3)) item.id],
          reason: 'Message ${history.length} of the chat.',
        ),
      ],
    );
  }
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

    await _openTab(tester, 'Clothes');
    expect(find.text('Your wardrobe is empty'), findsOneWidget);

    await _openTab(tester, 'Outfits');
    expect(find.text('No outfits yet'), findsOneWidget);

    await _openTab(tester, 'Planner');
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Nothing planned'), findsOneWidget);

    await _openAccount(tester);
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

    await _openTab(tester, 'Clothes');
    expect(find.text('25 items'), findsOneWidget);

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
    expect(find.bySemanticsLabel('White Tee'), findsOneWidget);

    // Add a second item from the + button.
    await _create(tester, 'Add clothes');
    await _addClothing(tester, name: 'Blue Jeans', category: 'Bottom');
    expect(find.bySemanticsLabel('Blue Jeans'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);

    // Search filters instantly.
    await tester.enterText(find.byType(TextField).first, 'jeans');
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('White Tee'), findsNothing);
    expect(find.bySemanticsLabel('Blue Jeans'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();

    // Build an outfit.
    await _openTab(tester, 'Outfits');
    await _tap(tester, find.text('Create Outfit'));
    expect(find.text('New outfit'), findsOneWidget);

    await _tap(tester, find.widgetWithText(ActionChip, 'Top'));
    await _tap(tester, find.bySemanticsLabel('White Tee').last);
    await _tap(tester, find.textContaining('Done'));

    await _tap(tester, find.widgetWithText(ActionChip, 'Bottom'));
    await _tap(tester, find.bySemanticsLabel('Blue Jeans').last);
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
    await _openTab(tester, 'Planner');
    await _tap(tester, find.text('Plan Outfit'));
    await _tap(tester, find.text('Everyday Look').last);
    expect(find.text('Mark as Worn'), findsOneWidget);

    await _tap(tester, find.text('Mark as Worn'));
    expect(find.text('Undo'), findsOneWidget);

    // Wear statistics are updated everywhere.
    await _openTab(tester, 'Outfits');
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

    /// The login screen is prefilled with the new account's email.
    Future<void> logIn(WidgetTester tester) async {
      await fill(tester, 'Password', testPassword);
      await _tap(tester, find.widgetWithText(FilledButton, 'Log in'));
    }

    Future<void> logOut(WidgetTester tester) async {
      await _openAccount(tester);
      await _tap(tester, find.text('Log out'));
      await _tap(tester, find.widgetWithText(TextButton, 'Log out'));
    }

    testWidgets('signed-out users see the login screen', (tester) async {
      await _pumpApp(tester, testDependencies(), signedIn: false);
      expect(find.text('Log in'), findsWidgets);
      expect(find.byType(AppBottomBar), findsNothing);
      // Google and Facebook need the Supabase server.
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Continue with Facebook'), findsNothing);
    });

    testWidgets('Google login opens the browser and signs in on return', (
      tester,
    ) async {
      final repository = _FakeSocialAuth();
      final auth = AuthController(repository: repository);
      addTearDown(auth.dispose);
      await auth.init();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: auth,
          child: const AppMaterialApp(home: LoginScreen()),
        ),
      );
      expect(find.text('Continue with Facebook'), findsOneWidget);

      await _tap(tester, find.text('Continue with Google'));
      expect(repository.opened, [SocialProvider.google]);
      expect(auth.status, AuthStatus.signedOut);

      repository.returnFromBrowser();
      await tester.pumpAndSettle();
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.user!.displayName, 'Gia Bao');
    });

    testWidgets('register validates input, then returns to log in', (
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

      expect(find.byType(AppBottomBar), findsNothing);
      expect(find.text('Account created. Log in to continue.'), findsOneWidget);
      expect(find.text('jamie@example.com'), findsOneWidget);

      await logIn(tester);
      expect(find.byType(AppBottomBar), findsOneWidget);
      expect(find.textContaining('Jamie'), findsWidgets);
      await _openAccount(tester);
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
      expect(find.byType(AppBottomBar), findsOneWidget);
    });

    testWidgets('each account sees only its own wardrobe', (tester) async {
      await _pumpApp(tester, testDependencies());
      await _tap(tester, find.text('Add Clothing').first);
      await _addClothing(tester, name: 'Alex Coat', category: 'Outerwear');
      expect(find.bySemanticsLabel('Alex Coat'), findsOneWidget);

      await logOut(tester);
      await register(tester, name: 'Sam', email: 'sam@example.com');
      await logIn(tester);
      await _openTab(tester, 'Clothes');
      expect(find.text('Your wardrobe is empty'), findsOneWidget);

      await logOut(tester);
      await fill(tester, 'Email', testEmail);
      await fill(tester, 'Password', testPassword);
      await _tap(tester, find.widgetWithText(FilledButton, 'Log in'));
      await _openTab(tester, 'Clothes');
      expect(find.bySemanticsLabel('Alex Coat'), findsOneWidget);
    });
  });

  testWidgets('swipe rows to pick pieces, then save them as an outfit', (
    tester,
  ) async {
    await _pumpApp(tester, testDependencies(seedSampleData: true));
    await _create(tester, 'Swipe outfit');

    final screen = tester.element(find.byType(SwipeOutfitScreen));
    final wardrobe = screen.read<WardrobeController>();
    // The builder names a new outfit "Outfit N" when the name is left empty.
    final name = 'Outfit ${screen.read<OutfitController>().outfits.length + 1}';
    List<ClothingItem> piecesFor(OutfitSlot slot) => [
      for (final item in wardrobe.activeItems)
        if (OutfitSlot.forCategory(item.category) == slot) item,
    ];
    final tops = piecesFor(OutfitSlot.top);
    final bottoms = piecesFor(OutfitSlot.bottom);
    final shoes = piecesFor(OutfitSlot.shoes);

    // Swipe the top row one piece left; pick the third shoe from the tray.
    await tester.drag(
      find.descendant(
        of: find.byKey(const ValueKey(OutfitSlot.top)),
        matching: find.byType(PageView),
      ),
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.widgetWithText(SelectablePill, 'Shoes'));
    await _tap(
      tester,
      find.descendant(
        of: find.byType(ListView).last,
        matching: find.bySemanticsLabel(shoes[2].name),
      ),
    );

    await _tap(tester, find.byTooltip('Next'));
    expect(find.text('New outfit'), findsOneWidget);
    await _tap(tester, find.text('Save'));

    // Saving closes the swiper and shows the outfit in the Outfits tab.
    expect(find.byType(SwipeOutfitScreen), findsNothing);
    await _tap(tester, find.text(name));
    expect(find.text('3 pieces'), findsWidgets);
    expect(find.text(tops[1].name), findsOneWidget);
    expect(find.text(bottoms[0].name), findsOneWidget);
    expect(find.text(shoes[2].name), findsOneWidget);
  });

  testWidgets('swipe rows filter by subcategory and can be turned on', (
    tester,
  ) async {
    await _pumpApp(tester, testDependencies(seedSampleData: true));
    await _create(tester, 'Swipe outfit');
    Finder inTray(String name) => find.descendant(
      of: find.byType(ListView).last,
      matching: find.bySemanticsLabel(name),
    );

    // Tops is the first row, so its pieces fill the tray.
    expect(inTray('Black Graphic Tee'), findsOneWidget);
    await _tap(tester, find.text('Hoodies'));
    expect(inTray('Black Graphic Tee'), findsNothing);
    expect(inTray('Campaign Logo Hoodie'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('All'),
      find.byType(PillBar).last,
      const Offset(200, 0),
    );
    await _tap(tester, find.text('All'));
    expect(inTray('Black Graphic Tee'), findsOneWidget);

    expect(find.byType(PageView), findsNWidgets(3));
    await _tap(tester, find.byTooltip('Rows'));
    await _tap(tester, find.widgetWithText(SwitchListTile, 'Outerwear'));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsNWidgets(4));
    expect(find.widgetWithText(SelectablePill, 'Outerwear'), findsOneWidget);
  });

  group('AI stylist', () {
    testWidgets('chats, retries a failed message and saves an outfit', (
      tester,
    ) async {
      final stylist = _FakeStylist();
      await _pumpApp(
        tester,
        testDependencies(seedSampleData: true, aiStylist: stylist),
        premium: true,
      );
      await _create(tester, 'AI Stylist');
      expect(find.textContaining('How can I help you'), findsOneWidget);

      // A quick start sends its question.
      final (_, workPrompt) = StylistScreen.prompts.first;
      await _tap(tester, find.widgetWithText(ActionChip, 'Work'));
      expect(find.text(workPrompt), findsOneWidget);
      expect(find.text('You said: $workPrompt'), findsOneWidget);
      expect(find.text('Rainy Monday'), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing);

      // A follow-up carries the whole conversation; a failure can be retried.
      stylist.failNext = true;
      await tester.enterText(find.byType(TextField), 'Other shoes');
      await _tap(tester, find.byTooltip('Send'));
      expect(find.text('The AI service is busy right now.'), findsOneWidget);
      await _tap(tester, find.text('Try again'));
      expect(find.text('You said: Other shoes'), findsOneWidget);
      expect(find.text('Message 3 of the chat.'), findsOneWidget);

      // Attached pieces go with the next message.
      await _tap(tester, find.byTooltip('Attach'));
      await _tap(tester, find.text('Clothes'));
      final wardrobe = tester
          .element(find.byType(StylistScreen))
          .read<WardrobeController>();
      final piece = wardrobe.activeItems.first;
      await _tap(tester, find.bySemanticsLabel(piece.name).last);
      await _tap(tester, find.textContaining('Done'));
      expect(find.byTooltip('Remove ${piece.name}'), findsOneWidget);
      await _tap(tester, find.byTooltip('Send'));
      expect(find.text(StylistScreen.attachPrompt), findsOneWidget);
      expect(find.text('Attached: ${piece.name}'), findsOneWidget);

      // So does a photo; it shows in the chat.
      await _tap(tester, find.byTooltip('Attach'));
      await _tap(tester, find.text('Library'));
      expect(find.byTooltip('Remove photo'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Match this');
      await _tap(tester, find.byTooltip('Send'));
      expect(find.text('Nice photo: Match this'), findsOneWidget);
      expect(find.bySemanticsLabel('Photo'), findsOneWidget);

      // A new chat starts empty; the history reopens the old one.
      await _tap(tester, find.byTooltip('New chat'));
      expect(find.textContaining('How can I help you'), findsOneWidget);
      await _tap(tester, find.byTooltip('Chat history'));
      expect(find.text(workPrompt), findsOneWidget);
      await _tap(tester, find.text(workPrompt));
      expect(find.text('You said: Other shoes'), findsOneWidget);

      await _tap(tester, find.text('Save outfit').last);
      expect(find.text('Saved'), findsOneWidget);

      await _tap(tester, find.byTooltip('Back'));
      await _openTab(tester, 'Outfits');
      expect(find.text('Rainy Monday'), findsOneWidget);
    });

    testWidgets('asks for more clothes when the wardrobe is too small', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        testDependencies(aiStylist: _FakeStylist()),
        premium: true,
      );
      await _create(tester, 'AI Stylist');
      expect(find.text('Add a few clothes first'), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing);

      await _tap(tester, find.text('Add clothes'));
      expect(find.text('Add clothing'), findsOneWidget);
    });

    testWidgets('explains how to turn it on when there is no API key', (
      tester,
    ) async {
      await _pumpApp(tester, testDependencies(), premium: true);
      await _create(tester, 'AI Stylist');
      expect(find.text('AI stylist isn’t set up'), findsOneWidget);
    });
  });

  group('collections', () {
    testWidgets('create one, fill it with pieces and an outfit, delete it', (
      tester,
    ) async {
      await _pumpApp(tester, testDependencies(seedSampleData: true));
      await _openTab(tester, 'Collections');
      expect(find.text('No collections yet'), findsOneWidget);

      await _tap(tester, find.text('New collection'));
      await tester.enterText(find.byType(TextField), 'Beach');
      await _tap(tester, find.text('Create'));
      // Opens the new, empty collection.
      expect(find.widgetWithText(AppBar, 'Beach'), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);

      await _tap(tester, find.byTooltip('Add'));
      await _tap(tester, find.byType(ClothingTile).at(0));
      await _tap(tester, find.byType(ClothingTile).at(1));
      await _tap(tester, find.text('Outfits (0)'));
      await _tap(tester, find.byType(OutfitCard).first);
      await _tap(tester, find.text('Done · 3 selected'));
      expect(find.text('2 pieces · 1 outfit'), findsOneWidget);

      await _tap(tester, find.byTooltip('Back'));
      expect(find.widgetWithText(CollectionCard, 'Beach'), findsOneWidget);
      expect(find.text('2 pieces · 1 outfit'), findsOneWidget);

      await tester.longPress(find.widgetWithText(CollectionCard, 'Beach'));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Delete'));
      await _tap(tester, find.widgetWithText(TextButton, 'Delete'));
      expect(find.text('No collections yet'), findsOneWidget);

      // Its clothes are still in the wardrobe.
      await _openTab(tester, 'Clothes');
      expect(find.text('25 items'), findsOneWidget);
    });

    testWidgets('add a piece to a new collection from its detail screen', (
      tester,
    ) async {
      await _pumpApp(tester, testDependencies(seedSampleData: true));
      await _openTab(tester, 'Clothes');
      await _tap(tester, find.byType(ClothingTile).first);
      await _tap(tester, find.byTooltip('More'));
      await _tap(tester, find.text('Add to collection'));

      await _tap(tester, find.text('New collection'));
      await tester.enterText(find.byType(TextField), 'Wishlist');
      await _tap(tester, find.text('Create'));
      final tile = find.widgetWithText(CheckboxListTile, 'Wishlist');
      expect(tester.widget<CheckboxListTile>(tile).value, isTrue);

      await _tap(tester, find.text('Done'));
      expect(find.text('In 1 collection'), findsOneWidget);

      await _tap(tester, find.byTooltip('Back'));
      await _openTab(tester, 'Collections');
      expect(find.text('1 piece'), findsOneWidget);
    });

    testWidgets('the Free plan holds three collections', (tester) async {
      final deps = testDependencies();
      final user = await registerTestUser(deps);
      await deps.storage.write(
        '${StorageKeys.userScope(user.id)}${StorageKeys.collections}',
        jsonEncode([
          for (final name in ['Beach', 'Work', 'Wishlist'])
            {'id': name, 'name': name, 'createdAt': '2026-10-01T09:00:00'},
        ]),
      );
      // registerTestUser already started the session.
      await _pumpApp(tester, deps, signedIn: false);
      await _openTab(tester, 'Collections');
      expect(find.text('3 of 3 collections on Free'), findsOneWidget);

      await _tap(tester, find.text('New collection'));
      expect(find.text('Collection limit reached'), findsOneWidget);
      expect(find.text('New collection'), findsOneWidget);
    });
  });
}

/// Supabase-like auth whose browser login finishes on [returnFromBrowser].
class _FakeSocialAuth implements AuthRepository {
  final List<SocialProvider> opened = [];
  final StreamController<AppUser> _signIns = StreamController.broadcast();

  void returnFromBrowser() => _signIns.add(
    AppUser(
      id: 'google-user',
      email: 'bao@example.com',
      displayName: 'Gia Bao',
      createdAt: testNow,
    ),
  );

  @override
  bool get supportsSocialLogin => true;

  @override
  Future<void> signInWith(SocialProvider provider) async =>
      opened.add(provider);

  @override
  Stream<AppUser> get externalSignIns => _signIns.stream;

  @override
  Future<AppUser?> currentUser() async => null;

  @override
  Future<String?> lastEmail() async => null;

  @override
  Future<AppUser> register({
    required String displayName,
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AppUser> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}
