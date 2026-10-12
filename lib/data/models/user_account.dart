import 'package:all_fits/core/utils/json_reader.dart';
import 'package:all_fits/data/local/password_hasher.dart';

/// The signed-in user as seen by the rest of the app. Never carries
/// credentials.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;
}

/// A locally stored account, including its password hash.
class UserAccount {
  const UserAccount({required this.user, required this.password});

  /// Throws [FormatException] when required fields are missing.
  factory UserAccount.fromJson(JsonMap json) {
    final id = JsonReader.nonEmptyString(json, 'id');
    final email = JsonReader.nonEmptyString(json, 'email');
    final hash = JsonReader.nonEmptyString(json, 'passwordHash');
    final salt = JsonReader.nonEmptyString(json, 'salt');
    final iterations = JsonReader.integer(json, 'iterations');
    if (id == null ||
        email == null ||
        hash == null ||
        salt == null ||
        iterations <= 0) {
      throw const FormatException('Account record is incomplete');
    }
    return UserAccount(
      user: AppUser(
        id: id,
        email: email,
        displayName: JsonReader.nonEmptyString(json, 'displayName') ?? '',
        createdAt:
            JsonReader.date(json, 'createdAt') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      ),
      password: PasswordHash(hash: hash, salt: salt, iterations: iterations),
    );
  }

  final AppUser user;
  final PasswordHash password;

  String get id => user.id;

  JsonMap toJson() => {
    'id': user.id,
    'email': user.email,
    'displayName': user.displayName,
    'createdAt': user.createdAt.toIso8601String(),
    'passwordHash': password.hash,
    'salt': password.salt,
    'iterations': password.iterations,
  };
}
