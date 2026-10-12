import 'dart:developer' as developer;

import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/data/local/json_collection_store.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/local/password_hasher.dart';
import 'package:all_fits/data/models/user_account.dart';

/// Authentication contract. The local implementation keeps accounts on the
/// device; a Firebase or Supabase implementation can replace it later
/// without changes to the UI.
abstract interface class AuthRepository {
  /// The user from the persisted session, or null when signed out.
  Future<AppUser?> currentUser();

  /// Creates an account and signs it in.
  Future<AppUser> register({
    required String displayName,
    required String email,
    required String password,
  });

  Future<AppUser> signIn({required String email, required String password});

  Future<void> signOut();

  /// The email last used to sign in on this device, for prefilling.
  Future<String?> lastEmail();
}

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(
    this._storage, {
    required this._hasher,
    IdGenerator idGenerator = const UuidIdGenerator(),
    this._clock = systemClock,
  }) : _ids = idGenerator,
       _accounts = JsonCollectionStore<UserAccount>(
         storage: _storage,
         key: StorageKeys.accounts,
         fromJson: UserAccount.fromJson,
         toJson: (account) => account.toJson(),
         idOf: (account) => account.id,
       );

  static const String _invalidCredentials = 'Incorrect email or password.';

  final LocalStorageService _storage;
  final PasswordHasher _hasher;
  final IdGenerator _ids;
  final Clock _clock;
  final JsonCollectionStore<UserAccount> _accounts;

  @override
  Future<AppUser?> currentUser() async {
    final String? userId;
    try {
      userId = await _storage.read(StorageKeys.session);
    } catch (error) {
      developer.log('Session unreadable', name: 'auth', error: error);
      return null;
    }
    if (userId == null || userId.isEmpty) return null;
    final account = (await _accounts.readAll())
        .where((a) => a.id == userId)
        .firstOrNull;
    if (account == null) {
      // The account was removed or its record is corrupt: sign out cleanly.
      await _clearSession();
      return null;
    }
    return account.user;
  }

  @override
  Future<AppUser> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final name = displayName.trim();
    final normalizedEmail = Validators.normalizeEmail(email);
    final error =
        Validators.requiredName(name, subject: 'your name') ??
        Validators.email(normalizedEmail) ??
        Validators.newPassword(password);
    if (error != null) throw ValidationException(error);

    if (await _findByEmail(normalizedEmail) != null) {
      throw const AuthException('An account with this email already exists.');
    }

    final account = UserAccount(
      user: AppUser(
        id: _ids.next(),
        email: normalizedEmail,
        displayName: name,
        createdAt: _clock(),
      ),
      password: await _hasher.hash(password),
    );
    await _accounts.upsertAll([account]);
    await _startSession(account.user);
    return account.user;
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final account = await _findByEmail(Validators.normalizeEmail(email));
    if (account == null || !await _hasher.verify(password, account.password)) {
      throw const AuthException(_invalidCredentials);
    }
    await _startSession(account.user);
    return account.user;
  }

  @override
  Future<void> signOut() => _clearSession();

  @override
  Future<String?> lastEmail() async {
    try {
      return await _storage.read(StorageKeys.lastEmail);
    } catch (_) {
      return null;
    }
  }

  Future<UserAccount?> _findByEmail(String normalizedEmail) async {
    final accounts = await _accounts.readAll();
    return accounts.where((a) => a.user.email == normalizedEmail).firstOrNull;
  }

  Future<void> _startSession(AppUser user) async {
    try {
      await _storage.write(StorageKeys.session, user.id);
      await _storage.write(StorageKeys.lastEmail, user.email);
    } catch (error) {
      developer.log('Failed to save session', name: 'auth', error: error);
      throw const StorageException('Could not sign you in. Please try again.');
    }
  }

  Future<void> _clearSession() async {
    try {
      await _storage.remove(StorageKeys.session);
    } catch (error) {
      developer.log('Failed to clear session', name: 'auth', error: error);
      throw const StorageException('Could not sign you out. Please try again.');
    }
  }
}
