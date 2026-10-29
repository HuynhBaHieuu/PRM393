abstract final class Validators {
  static const int maxNameLength = 60;
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
    if (text.isEmpty) return 'Please enter your email';
    if (text.length > maxEmailLength || !_emailPattern.hasMatch(text)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Rules for choosing a new password.
  static String? newPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Please choose a password';
    if (text.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters';
    }
    if (text.length > maxPasswordLength) {
      return 'Keep it under $maxPasswordLength characters';
    }
    if (!_letter.hasMatch(text) || !_digit.hasMatch(text)) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  static String? requiredPassword(String? value) =>
      (value ?? '').isEmpty ? 'Please enter your password' : null;

  static String? confirmPassword(String? value, String password) {
    if ((value ?? '').isEmpty) return 'Please confirm your password';
    return value == password ? null : 'Passwords don’t match';
  }

  static String? requiredName(String? value, {String subject = 'a name'}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter $subject';
    if (text.length > maxNameLength) {
      return 'Keep it under $maxNameLength characters';
    }
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
      return 'Use at least $minUsernameLength characters';
    }
    if (text.length > maxUsernameLength) {
      return 'Keep it under ${maxUsernameLength + 1} characters';
    }
    if (!_usernamePattern.hasMatch(text)) {
      return 'Use lowercase letters, numbers, _ and . only';
    }
    return null;
  }

  static String? optionalName(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > maxNameLength) {
      return 'Keep it under $maxNameLength characters';
    }
    return null;
  }

  /// Accepts an empty value or a web address such as "shop.com/item".
  static String? optionalLink(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length > maxLinkLength) return 'That link is too long';
    final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
    final host = uri?.host ?? '';
    if (text.contains(RegExp(r'\s')) || !host.contains('.')) {
      return 'Enter a valid web address';
    }
    return null;
  }

  static String? optionalPrice(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final price = parsePrice(text);
    if (price == null) return 'Enter a valid price';
    if (price < 0) return 'Price can’t be negative';
    if (price > maxPrice) return 'That price looks too high';
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
