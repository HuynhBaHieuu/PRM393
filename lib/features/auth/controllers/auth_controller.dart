import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'package:all_fits/data/models/user_account.dart';
import 'package:all_fits/data/repositories/auth_repository.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Tracks who is signed in. The app shows the auth screens or the user's
/// wardrobe based on [status].
class AuthController extends ChangeNotifier {
  AuthController({required this._repository, this._onRegistered});

  final AuthRepository _repository;

  /// Runs after an account is created, before its session starts.
  final Future<void> Function(AppUser user)? _onRegistered;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  String? _lastEmail;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get lastEmail => _lastEmail;

  /// Restores the previous session, if any.
  Future<void> init() async {
    try {
      _user = await _repository.currentUser();
      _lastEmail = await _repository.lastEmail();
    } catch (error) {
      developer.log('Session restore failed', name: 'auth', error: error);
      _user = null;
    }
    _setStatus();
  }

  /// Creates the account but leaves the user signed out, so they log in
  /// with it next. Returns the normalized email for prefilling the form.
  Future<String> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final user = await _repository.register(
      displayName: displayName,
      email: email,
      password: password,
    );
    await _onRegistered?.call(user);
    // Both backends start a session on sign-up; end it.
    await _repository.signOut();
    _lastEmail = user.email;
    return user.email;
  }

  Future<void> signIn({required String email, required String password}) async {
    _signedIn(await _repository.signIn(email: email, password: password));
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _user = null;
    _setStatus();
  }

  void _signedIn(AppUser user) {
    _user = user;
    _lastEmail = user.email;
    _setStatus();
  }

  void _setStatus() {
    _status = _user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    notifyListeners();
  }
}
