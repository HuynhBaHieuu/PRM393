import 'package:all_fits/core/l10n/l10n.dart';

abstract final class Validators {
  static const int maxNameLength = 60;

  /// Clothing names run longer: shops name pieces like "Áo Thun Cổ Tròn
  /// FlexFit™ Vải Single Co Giãn In Typography Phom Vừa F3 - The Weekend".
  static const int maxItemNameLength = 120;
  static const int maxTagLength = 24;
  static const int maxNotesLength = 500;
  static const int maxLinkLength = 2000;
  static const double maxPrice = 10000000;
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int maxEmailLength = 254;

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp _letter = RegExp('[A-Za-z]');
  static final RegExp _digit = RegExp('[0-9]');

  /// Lower-cased and trimmed, so emails compare case-insensitively.
  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return tr('Please enter your email');
    if (text.length > maxEmailLength || !_emailPattern.hasMatch(text)) {
      return tr('Enter a valid email address');
    }
    return null;
  }

  /// Rules for choosing a new password.
  static String? newPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return tr('Please choose a password');
    if (text.length < minPasswordLength) {
      return tr('Use at least {0} characters', [minPasswordLength]);
    }
    if (text.length > maxPasswordLength) {
      return tr('Keep it under {0} characters', [maxPasswordLength]);
    }
    if (!_letter.hasMatch(text) || !_digit.hasMatch(text)) {
      return tr('Include at least one letter and one number');
    }
    return null;
  }

  static String? requiredPassword(String? value) =>
      (value ?? '').isEmpty ? tr('Please enter your password') : null;

  static String? confirmPassword(String? value, String password) {
    if ((value ?? '').isEmpty) return tr('Please confirm your password');
    return value == password ? null : tr('Passwords don’t match');
  }

  static String? requiredName(
    String? value, {
    String? subject,
    int max = maxNameLength,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return tr('Please enter {0}', [subject ?? tr('a name')]);
    if (text.length > max) return tr('Keep it under {0} characters', [max]);
    return null;
  }

  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 20;
  static const int maxBioLength = 150;
  static final RegExp _usernamePattern = RegExp(r'^[a-z0-9_.]+$');

  /// Same rule as the `profiles.username` check in supabase/schema.sql.
  static String? username(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < minUsernameLength) {
      return tr('Use at least {0} characters', [minUsernameLength]);
    }
    if (text.length > maxUsernameLength) {
      return tr('Keep it under {0} characters', [maxUsernameLength + 1]);
    }
    if (!_usernamePattern.hasMatch(text)) {
      return tr('Use lowercase letters, numbers, _ and . only');
    }
    return null;
  }

  static String? optionalName(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > maxNameLength) {
      return tr('Keep it under {0} characters', [maxNameLength]);
    }
    return null;
  }

  /// Accepts an empty value or a web address such as "shop.com/item".
  static String? optionalLink(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length > maxLinkLength) return tr('That link is too long');
    final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
    final host = uri?.host ?? '';
    if (text.contains(RegExp(r'\s')) || !host.contains('.')) {
      return tr('Enter a valid web address');
    }
    return null;
  }

  static String? optionalPrice(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final price = parsePrice(text);
    if (price == null) return tr('Enter a valid price');
    if (price < 0) return tr('Price can’t be negative');
    if (price > maxPrice) return tr('That price looks too high');
    return null;
  }

  /// Accepts "45", "45.5", "1,200.00" and "45,5".
  static double? parsePrice(String? value) {
    var text = value?.trim().replaceAll(' ', '') ?? '';
    if (text.isEmpty) return null;
    if (text.contains(',') && !text.contains('.')) {
      final decimals = text.split(',').last;
      text = decimals.length <= 2
          ? text.replaceAll(',', '.')
          : text.replaceAll(',', '');
    } else {
      text = text.replaceAll(',', '');
    }
    final parsed = double.tryParse(text);
    return parsed != null && parsed.isFinite ? parsed : null;
  }
}
