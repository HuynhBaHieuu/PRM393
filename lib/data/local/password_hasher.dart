import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// A salted password hash and the parameters needed to verify it.
class PasswordHash {
  const PasswordHash({
    required this.hash,
    required this.salt,
    required this.iterations,
  });

  final String hash;
  final String salt;
  final int iterations;
}

abstract interface class PasswordHasher {
  Future<PasswordHash> hash(String password);

  Future<bool> verify(String password, PasswordHash stored);
}

/// PBKDF2-HMAC-SHA256 with a random 16-byte salt per password.
class Pbkdf2PasswordHasher implements PasswordHasher {
  const Pbkdf2PasswordHasher({
    this.iterations = defaultIterations,
    this.runInBackground = true,
  });

  static const int defaultIterations = 50000;
  static const int _saltLength = 16;

  final int iterations;

  /// Derives keys on a background isolate so the UI stays responsive.
  final bool runInBackground;

  @override
  Future<PasswordHash> hash(String password) async {
    final random = Random.secure();
    final salt = base64Encode(
      List<int>.generate(_saltLength, (_) => random.nextInt(256)),
    );
    return PasswordHash(
      hash: await _derive(password, salt, iterations),
      salt: salt,
      iterations: iterations,
    );
  }

  @override
  Future<bool> verify(String password, PasswordHash stored) async {
    final candidate = await _derive(password, stored.salt, stored.iterations);
    return _constantTimeEquals(candidate, stored.hash);
  }

  Future<String> _derive(String password, String salt, int rounds) {
    if (!runInBackground) {
      return Future.value(_pbkdf2(password, salt, rounds));
    }
    return Isolate.run(() => _pbkdf2(password, salt, rounds));
  }

  /// Single-block PBKDF2: the 32-byte output equals one SHA-256 block.
  static String _pbkdf2(String password, String salt, int rounds) {
    final hmac = Hmac(sha256, utf8.encode(password));
    var block = hmac.convert([...base64Decode(salt), 0, 0, 0, 1]).bytes;
    final result = List<int>.of(block);
    for (var i = 1; i < rounds; i++) {
      block = hmac.convert(block).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= block[j];
      }
    }
    return base64Encode(result);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
