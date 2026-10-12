import 'package:all_fits/core/utils/date_helpers.dart';

/// Lightweight, locale-independent formatting helpers.
abstract final class AppFormatters {
  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ];
  static const List<String> _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', //
    'Sunday',
  ];
  static const int _shortLength = 3;
  static const int _recentDayWindow = 7;
  static const int _morningEndHour = 12;
  static const int _afternoonEndHour = 18;

  static String monthName(DateTime date) => _months[date.month - 1];

  static String monthShort(DateTime date) =>
      monthName(date).substring(0, _shortLength);

  static String weekdayName(DateTime date) => _weekdays[date.weekday - 1];

  /// One-letter weekday labels starting from [firstWeekday].
  static List<String> weekdayInitials({int firstWeekday = DateTime.monday}) {
    return List.generate(DateHelpers.daysPerWeek, (i) {
      final index = (firstWeekday - 1 + i) % DateHelpers.daysPerWeek;
      return _weekdays[index].substring(0, 1);
    });
  }

  /// "Oct 1" for the current year, "Oct 1, 2025" otherwise.
  static String shortDate(DateTime date, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final base = '${monthShort(date)} ${date.day}';
    return date.year == reference.year ? base : '$base, ${date.year}';
  }

  /// "Thursday, October 1"
  static String longDate(DateTime date) =>
      '${weekdayName(date)}, ${monthName(date)} ${date.day}';

  /// "October 2026"
  static String monthYear(DateTime date) => '${monthName(date)} ${date.year}';

  /// "Today", "Yesterday", "3 days ago", "In 2 days" or a short date.
  static String relativeDay(DateTime date, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = DateHelpers.daysBetween(reference, date);
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    if (diff < 0 && -diff < _recentDayWindow) return '${-diff} days ago';
    if (diff > 0 && diff < _recentDayWindow) return 'In $diff days';
    return shortDate(date, now: reference);
  }

  /// "$45" or "$45.50", with thousands separators.
  static String price(double value, String currencySymbol) {
    final isWhole = value == value.roundToDouble();
    final fixed = value.toStringAsFixed(isWhole ? 0 : 2);
    final parts = fixed.split('.');
    final grouped = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final decimals = parts.length > 1 ? '.${parts[1]}' : '';
    return '$currencySymbol$grouped$decimals';
  }

  /// "1 item", "3 items".
  static String count(int value, String singular, [String? plural]) {
    final noun = value == 1 ? singular : (plural ?? '${singular}s');
    return '$value $noun';
  }

  static String wearCount(int count) => count == 0
      ? 'Not worn yet'
      : 'Worn ${AppFormatters.count(count, 'time')}';

  static String greeting(DateTime now) {
    if (now.hour < _morningEndHour) return 'Good morning';
    if (now.hour < _afternoonEndHour) return 'Good afternoon';
    return 'Good evening';
  }

  static String initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }
}
