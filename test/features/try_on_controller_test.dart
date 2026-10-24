import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/subscription_plan.dart';
import 'package:all_fits/data/models/try_on.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';
import 'package:all_fits/features/try_on/try_on_controller.dart';

/// Answers try-ons with a fixed picture, records what it was sent, and can
/// fail or wait on demand.
class _FakeService extends AiStylistService {
  _FakeService() : super(apiKey: 'key', baseUrl: 'https://x/openai');

  Object? failWith;
  Completer<void>? hold;
  ({List<int>? person, List<int>? body, int pieces, String bodyType})? sent;

  @override
  Future<Uint8List> tryOn({
    List<int>? person,
    List<int>? body,
    required List<List<int>> pieces,
    String bodyType = '',
    String appearance = '',
    String scene = '',
    String notes = '',
    bool highQuality = false,
    Future<void>? cancel,
  }) async {
    sent = (
      person: person,
      body: body,
      pieces: pieces.length,
      bodyType: bodyType,
    );
    await hold?.future;
    if (failWith case final error?) throw error;
    return Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1]);
  }
}

/// References are plain file paths.
class _FileImages implements ImageStorageService {
  final List<String> saved = [];
  final List<String> deleted = [];

  @override
  Future<String> saveImage(String sourcePath) async {
    final reference = 'saved-${saved.length}';
    saved.add(reference);
    return reference;
  }

  @override
  String? resolvePath(String reference) => reference;

  @override
  Future<void> deleteImage(String reference) async => deleted.add(reference);
}

void main() {
  late Directory dir;
  late _FakeService service;
  late _FileImages images;
  late InMemoryStorageService storage;
  late List<ClothingItem> items;
  var now = DateTime(2026, 10, 24, 9);
  var ids = 0;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tryon_test');
    service = _FakeService();
    images = _FileImages();
    storage = InMemoryStorageService();
    now = DateTime(2026, 10, 24, 9);
    ids = 0;
    File piece(String name) =>
        File('${dir.path}/$name')..writeAsBytesSync([0xFF, 0xD8, name.length]);
    items = [
      for (final (index, name) in ['tee.jpg', 'jeans.jpg'].indexed)
        ClothingItem(
          id: 'item$index',
          name: name,
          category: ClothingCategory.tops,
          createdAt: now,
          updatedAt: now,
          imagePath: piece(name).path,
        ),
    ];
  });

  tearDown(() => dir.delete(recursive: true));

  TryOnController open() => TryOnController(
    storage: storage,
    images: images,
    service: service,
    idGenerator: _Ids(() => 'r${ids++}'),
    clock: () => now,
    tempDirectory: () async => dir,
  );

  Future<String> selfie() async {
    final file = File('${dir.path}/me.jpg');
    await file.writeAsBytes([0xFF, 0xD8, 42]);
    return file.path;
  }

  const request = TryOnRequest(itemIds: ['item0', 'item1'], outfitId: 'o1');

  test('Free gets one try-on ever; a failed one is not counted', () async {
    final tryOn = open();
    await tryOn.load();
    await tryOn.setSelfie(await selfie());
    expect(tryOn.creditsLeft(SubscriptionPlan.free), AppConfig.freeTryOns);

    service.failWith = const AiException('busy');
    await expectLater(
      tryOn.generate(request, items, plan: SubscriptionPlan.free),
      throwsA(isA<AiException>()),
    );
    expect(tryOn.creditsLeft(SubscriptionPlan.free), 1);
    expect(tryOn.results, isEmpty);

    service.failWith = null;
    final result = await tryOn.generate(
      request,
      items,
      plan: SubscriptionPlan.free,
    );
    expect(result!.outfitId, 'o1');
    expect(result.itemIds, ['item0', 'item1']);
    expect(service.sent!.person, [0xFF, 0xD8, 42]);
    expect(service.sent!.pieces, 2);
    expect(tryOn.creditsLeft(SubscriptionPlan.free), 0);
    await expectLater(
      tryOn.generate(request, items, plan: SubscriptionPlan.free),
      throwsA(isA<PlanLimitException>()),
    );

    // Saved, and the count survives a restart.
    final reopened = open();
    await reopened.load();
    expect(reopened.resultsForOutfit('o1').single.photo, result.photo);
    expect(reopened.creditsLeft(SubscriptionPlan.free), 0);
    expect(
      reopened.creditsLeft(SubscriptionPlan.premium),
      AppConfig.premiumTryOnsPerMonth - 1,
    );
  });

  test('Premium credits come back each month', () async {
    final tryOn = open();
    await tryOn.load();
    await tryOn.setSelfie(await selfie());
    await tryOn.generate(request, items, plan: SubscriptionPlan.premium);
    expect(
      tryOn.creditsLeft(SubscriptionPlan.premium),
      AppConfig.premiumTryOnsPerMonth - 1,
    );
    now = DateTime(2026, 11, 1);
    expect(
      tryOn.creditsLeft(SubscriptionPlan.premium),
      AppConfig.premiumTryOnsPerMonth,
    );
  });

  test('an AI model needs no photo and uses the body type', () async {
    final tryOn = open();
    await tryOn.load();
    await tryOn.setBodyType(
      const BodyType(BodyGender.male, BodySize.l, LegLength.long),
    );
    await tryOn.generate(
      const TryOnRequest(itemIds: ['item0'], wearer: TryOnWearer.model),
      items.take(1).toList(),
      plan: SubscriptionPlan.premium,
    );
    expect(service.sent!.person, isNull);
    expect(service.sent!.body, isNull);
    expect(service.sent!.bodyType, 'a man with a fuller build and long legs');

    await expectLater(
      tryOn.generate(request, items, plan: SubscriptionPlan.premium),
      throwsA(isA<AiException>()),
      reason: 'wearing it yourself needs a photo',
    );
  });

  test('cancelling saves nothing and keeps the credit', () async {
    final tryOn = open();
    await tryOn.load();
    await tryOn.setSelfie(await selfie());
    service.hold = Completer();
    final pending = tryOn.generate(request, items, plan: SubscriptionPlan.free);
    await Future<void>.delayed(Duration.zero);
    expect(tryOn.isGenerating, isTrue);
    tryOn.cancel();
    service.hold!.complete();

    expect(await pending, isNull);
    expect(tryOn.isGenerating, isFalse);
    expect(tryOn.results, isEmpty);
    expect(images.deleted, images.saved);
    expect(tryOn.creditsLeft(SubscriptionPlan.free), 1);
  });

  test('tells the app when no screen is watching', () async {
    final tryOn = open();
    await tryOn.load();
    await tryOn.setSelfie(await selfie());
    TryOnResult? noticed;
    tryOn.onBackgroundResult = (result) => noticed = result;

    tryOn.watch();
    await tryOn.generate(request, items, plan: SubscriptionPlan.premium);
    expect(noticed, isNull);

    tryOn.unwatch();
    final result = await tryOn.generate(
      request,
      items,
      plan: SubscriptionPlan.premium,
    );
    expect(noticed, same(result));
  });

  test('replacing or deleting photos removes the old ones', () async {
    final tryOn = open();
    await tryOn.load();
    await tryOn.setSelfie('a.jpg');
    await tryOn.setSelfie('b.jpg');
    await tryOn.setBodyPhoto('body.jpg');
    await tryOn.setBodyPhoto(null);
    await tryOn.setAppearance('  glasses, short beard ');
    await tryOn.consent();
    expect(images.deleted, ['a.jpg', 'body.jpg']);

    final reopened = open();
    await reopened.load();
    expect(reopened.profile.selfiePhoto, 'b.jpg');
    expect(reopened.profile.bodyPhoto, isNull);
    expect(reopened.profile.consented, isTrue);
    expect(reopened.profile.appearance, 'glasses, short beard');
  });
}

class _Ids implements IdGenerator {
  _Ids(this._next);

  final String Function() _next;

  @override
  String next() => _next();
}
