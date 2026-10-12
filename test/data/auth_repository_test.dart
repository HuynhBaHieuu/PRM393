import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/app/app_dependencies.dart';
import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/local/password_hasher.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/repositories/auth_repository.dart';
import 'package:all_fits/data/repositories/wardrobe_repository.dart';
import 'package:all_fits/features/wardrobe/controllers/clothing_draft.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

import '../helpers/test_harness.dart';

String _hex(String hex) => base64Encode([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

void main() {
  group('Pbkdf2PasswordHasher', () {
    const hasher = Pbkdf2PasswordHasher(runInBackground: false);
    final salt = base64Encode(utf8.encode('salt'));

    // Published PBKDF2-HMAC-SHA256 test vectors (P="password", S="salt").
    test('matches known test vectors', () async {
      for (final (iterations, expected) in [
        (1, '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b'),
        (
          4096,
          'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
        ),
      ]) {
        final stored = PasswordHash(
          hash: _hex(expected),
          salt: salt,
          iterations: iterations,
        );
        expect(await hasher.verify('password', stored), isTrue);
        expect(await hasher.verify('Password', stored), isFalse);
      }
    });

    test('uses a fresh salt for every hash', () async {
      const fast = Pbkdf2PasswordHasher(iterations: 2, runInBackground: false);
      final a = await fast.hash('same-password1');
      final b = await fast.hash('same-password1');
      expect(a.salt, isNot(b.salt));
      expect(a.hash, isNot(b.hash));
      expect(await fast.verify('same-password1', a), isTrue);
    });
  });

  group('LocalAuthRepository', () {
    late InMemoryStorageService storage;
    late AuthRepository repo;

    AuthRepository newRepo() => LocalAuthRepository(
      storage,
      hasher: fastPasswordHasher,
      idGenerator: SequentialIdGenerator(),
      clock: () => testNow,
    );

    setUp(() {
      storage = InMemoryStorageService();
      repo = newRepo();
    });

    test('register normalizes email, signs in and never stores the '
        'password', () async {
      final user = await repo.register(
        displayName: '  Alex  ',
        email: '  Alex@Example.COM ',
        password: testPassword,
      );
      expect(user.email, 'alex@example.com');
      expect(user.displayName, 'Alex');
      expect((await repo.currentUser())?.id, user.id);
      expect(
        storage.values[StorageKeys.accounts],
        isNot(contains(testPassword)),
      );
    });

    test('rejects a duplicate email regardless of case', () async {
      await repo.register(
        displayName: 'A',
        email: testEmail,
        password: testPassword,
      );
      expect(
        () => repo.register(
          displayName: 'B',
          email: testEmail.toUpperCase(),
          password: 'another123',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('validates registration input', () async {
      expect(
        () => repo.register(
          displayName: 'A',
          email: 'not-an-email',
          password: testPassword,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => repo.register(
          displayName: 'A',
          email: testEmail,
          password: 'short1',
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => repo.register(
          displayName: 'A',
          email: testEmail,
          password: 'nodigitshere',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('sign in checks the password; sign out clears the session', () async {
      await repo.register(
        displayName: 'A',
        email: testEmail,
        password: testPassword,
      );
      await repo.signOut();
      expect(await repo.currentUser(), isNull);

      await expectLater(
        repo.signIn(email: testEmail, password: 'wrong-pass1'),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        repo.signIn(email: 'nobody@example.com', password: testPassword),
        throwsA(isA<AuthException>()),
      );

      final user = await repo.signIn(
        email: 'ALEX@example.com',
        password: testPassword,
      );
      expect(user.email, testEmail);
      expect(await repo.lastEmail(), testEmail);
    });

    test('session survives an app restart', () async {
      final user = await repo.register(
        displayName: 'A',
        email: testEmail,
        password: testPassword,
      );
      expect((await newRepo().currentUser())?.id, user.id);
    });

    test('a session pointing at a missing account signs out', () async {
      await storage.write(StorageKeys.session, 'ghost');
      expect(await repo.currentUser(), isNull);
      expect(storage.values.containsKey(StorageKeys.session), isFalse);
    });

    test('malformed account records are skipped', () async {
      await repo.register(
        displayName: 'A',
        email: testEmail,
        password: testPassword,
      );
      final accounts =
          jsonDecode(storage.values[StorageKeys.accounts]!) as List;
      await storage.write(
        StorageKeys.accounts,
        jsonEncode([
          ...accounts,
          {'id': 'broken'},
          'junk',
        ]),
      );
      final user = await newRepo().signIn(
        email: testEmail,
        password: testPassword,
      );
      expect(user.email, testEmail);
    });
  });

  group('per-user data', () {
    test('each account has its own wardrobe', () async {
      final deps = testDependencies();
      Future<WardrobeController> wardrobeFor(String userId) async {
        final controller = WardrobeController(
          repository: deps.repositoriesFor(userId).wardrobe,
          imageStorage: FakeImageStorageService(),
          idGenerator: SequentialIdGenerator(),
          clock: () => testNow,
        );
        await controller.load();
        return controller;
      }

      final alex = await wardrobeFor('alex');
      await alex.addItem(
        const ClothingDraft(
          name: 'Tee',
          category: ClothingCategory.tops,
          newImagePath: '/tmp/tee.jpg',
        ),
      );

      expect((await wardrobeFor('sam')).allItems, isEmpty);
      expect((await wardrobeFor('alex')).allItems.single.name, 'Tee');
    });

    test('data from before accounts existed goes to the first account '
        'only', () async {
      final storage = InMemoryStorageService();
      final legacy = TestCloset(storage: storage);
      await legacy.load();
      await legacy.addItem('Old Coat', ClothingCategory.outerwear);

      final deps = testDependencies(storage: storage);
      await deps.adoptLegacyData('first');
      await deps.adoptLegacyData('second');

      Future<List<String>> namesFor(String userId) async =>
          (await deps.repositoriesFor(userId).wardrobe.fetchAll())
              .map((i) => i.name)
              .toList();
      expect(await namesFor('first'), ['Old Coat']);
      expect(await namesFor('second'), isEmpty);
      expect(storage.values.containsKey(StorageKeys.clothingItems), isFalse);
      // The legacy repository no longer sees anything.
      expect(await LocalWardrobeRepository(storage).fetchAll(), isEmpty);
    });
  });

  test('AppDependencies wires a working auth repository', () async {
    final deps = testDependencies();
    expect(deps, isA<AppDependencies>());
    final user = await registerTestUser(deps);
    expect((await deps.authRepository.currentUser())?.id, user.id);
  });
}
