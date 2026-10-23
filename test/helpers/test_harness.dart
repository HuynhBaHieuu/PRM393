import 'dart:convert';

import 'package:all_fits/app/app_dependencies.dart';
import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/data/local/image_picker_service.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/local/password_hasher.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/user_account.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';
import 'package:all_fits/data/remote/payos_checkout.dart';
import 'package:all_fits/data/remote/weather_service.dart';
import 'package:all_fits/features/collections/controllers/collection_controller.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/data/repositories/calendar_repository.dart';
import 'package:all_fits/data/repositories/collection_repository.dart';
import 'package:all_fits/data/repositories/outfit_repository.dart';
import 'package:all_fits/data/repositories/wardrobe_repository.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/controllers/outfit_draft.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/wardrobe/controllers/clothing_draft.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// Fixed "now" used across tests: Thursday, 1 October 2026, 09:00.
final DateTime testNow = DateTime(2026, 10, 1, 9);

class SequentialIdGenerator implements IdGenerator {
  int _next = 0;

  @override
  String next() => 'id-${_next++}';
}

class FakeImageStorageService implements ImageStorageService {
  final List<String> saved = [];
  final List<String> deleted = [];
  bool failNextSave = false;

  @override
  Future<String> saveImage(String sourcePath) async {
    if (failNextSave) {
      failNextSave = false;
      throw const InvalidImageException();
    }
    final reference = 'images/${saved.length}.jpg';
    saved.add(reference);
    return reference;
  }

  /// Returning null makes widgets render the illustrated placeholder.
  @override
  String? resolvePath(String reference) => null;

  @override
  Future<void> deleteImage(String reference) async => deleted.add(reference);
}

class FakeImagePickerService implements ImagePickerService {
  String? nextPath = '/fake/photo.jpg';

  @override
  bool get supportsCamera => true;

  @override
  Future<String?> pickImage(ImagePickSource source) async => nextPath;
}

/// Wires real controllers to in-memory storage and fake services.
class TestCloset {
  TestCloset({InMemoryStorageService? storage, DateTime? now})
    : storage = storage ?? InMemoryStorageService(),
      now = now ?? testNow {
    DateTime clock() => this.now;
    wardrobe = WardrobeController(
      repository: LocalWardrobeRepository(this.storage),
      imageStorage: images,
      idGenerator: ids,
      clock: clock,
    );
    outfits = OutfitController(
      repository: LocalOutfitRepository(this.storage),
      idGenerator: ids,
      clock: clock,
    );
    planner = PlannerController(
      repository: LocalCalendarRepository(this.storage),
      idGenerator: ids,
    );
    collections = CollectionController(
      repository: LocalCollectionRepository(this.storage),
      imageStorage: images,
      idGenerator: ids,
      clock: clock,
    );
    closet = ClosetActions(
      wardrobe: wardrobe,
      outfits: outfits,
      planner: planner,
      collections: collections,
      idGenerator: ids,
      clock: clock,
    );
  }

  final InMemoryStorageService storage;
  final FakeImageStorageService images = FakeImageStorageService();
  final SequentialIdGenerator ids = SequentialIdGenerator();
  DateTime now;

  late final WardrobeController wardrobe;
  late final OutfitController outfits;
  late final PlannerController planner;
  late final CollectionController collections;
  late final ClosetActions closet;

  Future<void> load() async {
    await wardrobe.load();
    await outfits.load();
    await planner.load();
    await collections.load();
  }

  Future<String> addItem(
    String name,
    ClothingCategory category, {
    double? price,
  }) async {
    final item = await wardrobe.addItem(
      ClothingDraft(
        name: name,
        category: category,
        price: price,
        newImagePath: '/tmp/$name.jpg',
      ),
    );
    return item.id;
  }

  Future<String> addOutfit(String name, List<String> itemIds) async {
    final outfit = await outfits.createOutfit(
      OutfitDraft(name: name, itemIds: itemIds),
    );
    return outfit.id;
  }
}

AppDependencies testDependencies({
  InMemoryStorageService? storage,
  FakeImagePickerService? picker,
  bool seedSampleData = false,
  AiStylistService aiStylist = const AiStylistService(apiKey: ''),
  WeatherService weather = const FakeWeatherService(),
  PayOSCheckout? payments,
}) {
  return AppDependencies(
    storage: storage ?? InMemoryStorageService(),
    imageStorage: FakeImageStorageService(),
    imagePicker: picker ?? FakeImagePickerService(),
    idGenerator: SequentialIdGenerator(),
    clock: () => testNow,
    seedSampleData: seedSampleData,
    aiStylist: aiStylist,
    weather: weather,
    payments: payments,
    passwordHasher: fastPasswordHasher,
  );
}

/// payOS without a server: hands out [statuses] one check at a time and
/// runs [onPaid] (standing in for the Edge Function) before reporting paid.
class FakePayOSCheckout implements PayOSCheckout {
  FakePayOSCheckout(this.statuses);

  final List<PaymentStatus> statuses;
  Future<void> Function() onPaid = () async {};
  final List<Uri> opened = [];

  static final Uri checkoutUrl = Uri.parse('https://pay.payos.vn/web/test');

  @override
  Future<PayOSOrder> create() async => (orderCode: 1, checkoutUrl: checkoutUrl);

  @override
  Future<void> open(Uri checkoutUrl) async => opened.add(checkoutUrl);

  @override
  Future<PaymentStatus> status(int orderCode) async {
    final status = statuses.removeAt(0);
    if (status == PaymentStatus.paid) await onPaid();
    return status;
  }
}

/// Cheap, synchronous hashing so tests stay fast and need no isolates.
const PasswordHasher fastPasswordHasher = Pbkdf2PasswordHasher(
  iterations: 2,
  runInBackground: false,
);

const String testEmail = 'alex@example.com';
const String testPassword = 'wardrobe123';

/// Registers an account, which also starts its session.
Future<AppUser> registerTestUser(
  AppDependencies deps, {
  String name = 'Alex Morgan',
  String email = testEmail,
  String password = testPassword,
}) {
  return deps.authRepository.register(
    displayName: name,
    email: email,
    password: password,
  );
}

/// Puts [user] on the Premium plan before the app starts.
Future<void> makePremium(AppDependencies deps, AppUser user) =>
    deps.storage.write(
      '${StorageKeys.userScope(user.id)}${StorageKeys.settings}',
      jsonEncode({'plan': 'premium'}),
    );

/// Writes [count] clothing items for [user] before the app starts.
Future<void> seedWardrobe(AppDependencies deps, AppUser user, int count) =>
    deps.storage.write(
      '${StorageKeys.userScope(user.id)}${StorageKeys.clothingItems}',
      jsonEncode([
        for (var i = 0; i < count; i++)
          {
            'id': 'seed-$i',
            'name': 'Piece $i',
            'category': 'tops',
            'imagePath': 'images/seed-$i.jpg',
            'createdAt': testNow.toIso8601String(),
          },
      ]),
    );

const WeatherLocation testCity = WeatherLocation(
  name: 'Oslo',
  country: 'Norway',
  latitude: 59.9,
  longitude: 10.7,
);

/// Answers instantly: [city] always resolves to [testCity].
class FakeWeatherService implements WeatherService {
  const FakeWeatherService({
    this.temperature = 6,
    this.condition = WeatherCondition.rain,
  });

  final double temperature;
  final WeatherCondition condition;

  @override
  Future<WeatherLocation?> findCity(String name) async =>
      name.trim().toLowerCase() == 'oslo' ? testCity : null;

  @override
  Future<WeatherReport> today(WeatherLocation location) async => WeatherReport(
    location: location,
    temperature: temperature,
    high: temperature + 3,
    low: temperature - 3,
    condition: condition,
    rainChance: 80,
    fetchedAt: testNow,
  );
}
