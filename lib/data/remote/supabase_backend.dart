import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/core/utils/json_reader.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/local/json_collection_store.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/app_settings.dart';
import 'package:all_fits/data/models/subscription_plan.dart';
import 'package:all_fits/data/models/user_account.dart';
import 'package:all_fits/data/repositories/auth_repository.dart';
import 'package:all_fits/data/repositories/settings_repository.dart';

// Server-side storage on Supabase. Tables, row-level security and the photo
// bucket are created by `supabase/schema.sql`.

/// Reads `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` from `assets/env.json`.
/// Returns null when either is missing, so the app keeps storing on device.
({String url, String key})? supabaseConfigFrom(String envJson) {
  try {
    if (jsonDecode(envJson) case final Map<String, dynamic> env) {
      final url = env['SUPABASE_URL'];
      final key = env['SUPABASE_PUBLISHABLE_KEY'];
      if (url is String && key is String && url.isNotEmpty && key.isNotEmpty) {
        return (url: url.trim(), key: key.trim());
      }
    }
  } on FormatException {
    // Fall through: no server configured.
  }
  return null;
}

/// One row per record in [_table]: `(user_id, id, data jsonb)`. Row-level
/// security limits every query to the signed-in user's rows.
class SupabaseCollectionStore<T> implements CollectionStore<T> {
  SupabaseCollectionStore({
    required this._client,
    required this._table,
    required this._userId,
    required this._fromJson,
    required this._toJson,
    required this._idOf,
  });

  final sb.SupabaseClient _client;
  final String _table;
  final String _userId;
  final T Function(JsonMap json) _fromJson;
  final JsonMap Function(T value) _toJson;
  final String Function(T value) _idOf;

  @override
  Future<List<T>> readAll() async {
    final List<JsonMap> rows;
    try {
      rows = await _client.from(_table).select('data').eq('user_id', _userId);
    } catch (error) {
      _log('Failed to read', error);
      throw const StorageException('Your saved data could not be loaded.');
    }
    final values = <T>[];
    for (final row in rows) {
      try {
        values.add(_fromJson(Map<String, dynamic>.from(row['data'] as Map)));
      } catch (error) {
        _log('Skipping malformed record', error);
      }
    }
    return values;
  }

  @override
  Future<void> upsertAll(Iterable<T> values) async {
    final rows = [
      for (final value in values)
        {'user_id': _userId, 'id': _idOf(value), 'data': _toJson(value)},
    ];
    if (rows.isEmpty) return;
    await _write(
      () => _client.from(_table).upsert(rows, onConflict: 'user_id,id'),
    );
  }

  @override
  Future<void> removeIds(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await _write(
      () => _client
          .from(_table)
          .delete()
          .eq('user_id', _userId)
          .inFilter('id', list),
    );
  }

  @override
  Future<void> clear() =>
      _write(() => _client.from(_table).delete().eq('user_id', _userId));

  Future<void> _write(Future<void> Function() request) async {
    try {
      await request();
    } catch (error) {
      _log('Failed to write', error);
      throw const StorageException();
    }
  }

  void _log(String message, Object? error) =>
      developer.log('$message ($_table)', name: 'supabase', error: error);
}

/// One `user_settings` row per user. The plan comes from `subscriptions`,
/// which only the payOS Edge Function writes, never from that row.
class SupabaseSettingsRepository implements SettingsRepository {
  SupabaseSettingsRepository(
    this._client,
    this._userId, {
    this._clock = systemClock,
  });

  static const String table = 'user_settings';

  final sb.SupabaseClient _client;
  final String _userId;
  final Clock _clock;

  @override
  Future<AppSettings> load() async {
    final settings = await _loadRow();
    JsonMap? subscription;
    try {
      subscription = await _client
          .from('subscriptions')
          .select('premium_since, premium_until')
          .eq('user_id', _userId)
          .maybeSingle();
    } catch (error) {
      // E.g. the payOS tables are not set up yet: the plan stays Free.
      developer.log('Subscription unreadable', name: 'supabase', error: error);
    }
    final until = subscription == null
        ? null
        : JsonReader.date(subscription, 'premium_until')?.toLocal();
    final active = until != null && until.isAfter(_clock());
    return settings.copyWith(
      plan: active ? SubscriptionPlan.premium : SubscriptionPlan.free,
      premiumSince: active
          ? JsonReader.date(subscription!, 'premium_since')?.toLocal()
          : null,
      premiumUntil: active ? until : null,
    );
  }

  Future<AppSettings> _loadRow() async {
    final JsonMap? row;
    try {
      row = await _client
          .from(table)
          .select('data')
          .eq('user_id', _userId)
          .maybeSingle();
    } catch (error) {
      // Unlike on device, falling back to defaults here would re-seed sample
      // data and overwrite the real settings on the next save.
      developer.log('Settings unreadable', name: 'supabase', error: error);
      throw const StorageException('Your saved data could not be loaded.');
    }
    try {
      if (row?['data'] case final Map data) {
        return AppSettings.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (error) {
      developer.log('Settings malformed', name: 'supabase', error: error);
    }
    return const AppSettings();
  }

  @override
  Future<void> save(AppSettings settings) async {
    try {
      await _client.from(table).upsert({
        'user_id': _userId,
        'data': settings.toJson(),
      });
    } catch (error) {
      developer.log('Failed to save settings', name: 'supabase', error: error);
      throw const StorageException();
    }
  }
}

/// Supabase Auth. The session itself is persisted by `supabase_flutter`;
/// [_storage] only remembers the last email for prefilling the login form.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth, this._storage);

  /// Deep link the browser opens after Google or Facebook login. Must be listed under
  /// Authentication → URL Configuration → Redirect URLs, and matches the
  /// intent filter in AndroidManifest.xml.
  static const String oauthRedirect = 'com.example.allfits://login-callback';

  final sb.GoTrueClient _auth;
  final LocalStorageService _storage;

  /// Set while a browser login is in flight, so password sign-ins (which also
  /// fire `signedIn`) are not reported on [externalSignIns].
  bool _awaitingOAuth = false;

  @override
  Future<AppUser?> currentUser() async {
    final user = _auth.currentUser;
    return user == null ? null : _toAppUser(user);
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

    _awaitingOAuth = false;
    final response = await _guard(
      () => _auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {'display_name': name},
      ),
    );
    final user = response.user;
    if (response.session == null || user == null) {
      // "Confirm email" is switched on in the Supabase dashboard.
      throw const AuthException(
        'Check your inbox to confirm your email, then sign in.',
      );
    }
    await _rememberEmail(normalizedEmail);
    return _toAppUser(user);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = Validators.normalizeEmail(email);
    _awaitingOAuth = false;
    final response = await _guard(
      () =>
          _auth.signInWithPassword(email: normalizedEmail, password: password),
    );
    final user = response.user;
    if (user == null) throw const AuthException('Incorrect email or password.');
    await _rememberEmail(normalizedEmail);
    return _toAppUser(user);
  }

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  @override
  Future<String?> lastEmail() async {
    try {
      return await _storage.read(StorageKeys.lastEmail);
    } catch (_) {
      return null;
    }
  }

  @override
  bool get supportsSocialLogin => true;

  @override
  Future<void> signInWith(SocialProvider provider) async {
    _awaitingOAuth = true;
    final launched = await _guard(
      () => _auth.signInWithOAuth(
        switch (provider) {
          SocialProvider.google => sb.OAuthProvider.google,
          SocialProvider.facebook => sb.OAuthProvider.facebook,
        },
        redirectTo: oauthRedirect,
        // Lets people with several Google accounts choose one each time.
        queryParams: provider == SocialProvider.google
            ? const {'prompt': 'select_account'}
            : null,
      ),
    );
    if (!launched) {
      _awaitingOAuth = false;
      throw AuthException(
        'Could not open ${provider.label}. Please try again.',
      );
    }
  }

  @override
  Stream<AppUser> get externalSignIns => _auth.onAuthStateChange
      .where(
        (state) =>
            _awaitingOAuth &&
            state.event == sb.AuthChangeEvent.signedIn &&
            state.session != null,
      )
      .map((state) {
        _awaitingOAuth = false;
        return _toAppUser(state.session!.user);
      });

  @override
  bool get passwordResetNeedsCode => true;

  /// Needs `{{ .Token }}` in the Supabase "Reset Password" email template;
  /// the default template only has a link.
  @override
  Future<void> requestPasswordReset(String email) async {
    final normalizedEmail = Validators.normalizeEmail(email);
    final error = Validators.email(normalizedEmail);
    if (error != null) throw ValidationException(error);
    await _guard(() => _auth.resetPasswordForEmail(normalizedEmail));
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String newPassword,
    String? code,
  }) async {
    final error = Validators.newPassword(newPassword);
    if (error != null) throw ValidationException(error);
    final token = code?.trim() ?? '';
    if (token.isEmpty) {
      throw const ValidationException('Enter the code we emailed you');
    }

    _awaitingOAuth = false;
    // The code signs the user in; sign out again either way so they log in
    // with the new password, and a failed update never leaves a session.
    try {
      await _guard(
        () => _auth.verifyOTP(
          type: sb.OtpType.recovery,
          email: Validators.normalizeEmail(email),
          token: token,
        ),
      );
      await _guard(
        () => _auth.updateUser(sb.UserAttributes(password: newPassword)),
      );
    } finally {
      if (_auth.currentSession != null) await _guard(_auth.signOut);
    }
  }

  Future<R> _guard<R>(Future<R> Function() request) async {
    try {
      return await request();
    } on sb.AuthException catch (error) {
      developer.log('Auth failed', name: 'supabase', error: error);
      throw AuthException(switch (error.code) {
        'invalid_credentials' => 'Incorrect email or password.',
        'user_already_exists' => 'An account with this email already exists.',
        'email_not_confirmed' => 'Confirm your email first, then sign in.',
        'otp_expired' => 'That code is wrong or has expired.',
        'same_password' => 'Choose a password different from your old one.',
        'over_email_send_rate_limit' =>
          'Too many emails. Wait a minute and try again.',
        _ => error.message,
      });
    }
  }

  Future<void> _rememberEmail(String email) async {
    try {
      await _storage.write(StorageKeys.lastEmail, email);
    } catch (error) {
      // Only used to prefill the form; never block sign-in on it.
      developer.log('Last email not saved', name: 'auth', error: error);
    }
  }

  static AppUser _toAppUser(sb.User user) => AppUser(
    id: user.id,
    email: user.email ?? '',
    // Email sign-ups store `display_name`; Google and Facebook fill
    // `full_name`/`name`.
    displayName:
        (user.userMetadata?['display_name'] ??
                user.userMetadata?['full_name'] ??
                user.userMetadata?['name'])
            as String? ??
        '',
    createdAt:
        DateTime.tryParse(user.createdAt) ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// Uploads photos to the [bucket] Storage bucket under `<userId>/`. The stored
/// reference is the photo's public URL.
// ponytail: public bucket, so anyone holding a photo's URL can view it (paths
// are random UUIDs). Switch to a private bucket + signed URLs if that matters.
class SupabaseImageStorageService implements ImageStorageService {
  SupabaseImageStorageService(
    this._client, {
    IdGenerator idGenerator = const UuidIdGenerator(),
  }) : _ids = idGenerator;

  static const String bucket = 'wardrobe-images';

  final sb.SupabaseClient _client;
  final IdGenerator _ids;

  @override
  Future<String> saveImage(String sourcePath) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const StorageException('Sign in again to save photos.');
    }
    final source = File(sourcePath);
    final extension = await LocalImageStorageService.validate(source);
    final path = '$userId/${_ids.next()}.$extension';
    try {
      await _client.storage.from(bucket).upload(path, source);
    } catch (error) {
      developer.log('Failed to upload image', name: 'supabase', error: error);
      throw const StorageException('The photo could not be saved.');
    }
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// Only URLs resolve; a device path from before the move to Supabase shows
  /// the placeholder.
  @override
  String? resolvePath(String reference) =>
      reference.startsWith('https://') ? reference : null;

  @override
  Future<void> deleteImage(String reference) async {
    const marker = '/$bucket/';
    final start = reference.indexOf(marker);
    if (start < 0) return;
    try {
      await _client.storage.from(bucket).remove([
        reference.substring(start + marker.length),
      ]);
    } catch (error) {
      // An orphaned photo is harmless; never block the user on cleanup.
      developer.log('Failed to delete image', name: 'supabase', error: error);
    }
  }
}
