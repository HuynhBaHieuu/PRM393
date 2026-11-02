import 'package:all_fits/core/l10n/l10n.dart';
import 'package:all_fits/core/utils/date_helpers.dart';

/// Lightweight formatting helpers in the app's language (see [L10n]).
abstract final class AppFormatters {
  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ];
  static const List<String> _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', //
    'Sunday',
  ];
  static const List<String> _viWeekdays = [
    'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', //
    'Chủ Nhật',
  ];
  static const List<String> _viWeekdaysShort = [
    'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN', //
  ];
  static const int _shortLength = 3;
  static const int _recentDayWindow = 7;
  static const int _morningEndHour = 12;
  static const int _afternoonEndHour = 18;

  static bool get _vi => L10n.isVietnamese;

  /// "October", or "Tháng 10".
  static String monthName(DateTime date) =>
      _vi ? 'Tháng ${date.month}' : _months[date.month - 1];

  /// "Oct", or "thg 10".
  static String monthShort(DateTime date) => _vi
      ? 'thg ${date.month}'
      : _months[date.month - 1].substring(0, _shortLength);

  static String weekdayName(DateTime date) =>
      (_vi ? _viWeekdays : _weekdays)[date.weekday - 1];

  /// "Thu", or "T5".
  static String weekdayShort(DateTime date) => _vi
      ? _viWeekdaysShort[date.weekday - 1]
      : _weekdays[date.weekday - 1].substring(0, _shortLength);

  /// "Mon", "Tue"… (or "T2"…"CN") starting from [firstWeekday].
  static List<String> weekdayShortNames({int firstWeekday = DateTime.monday}) {
    return List.generate(DateHelpers.daysPerWeek, (i) {
      final index = (firstWeekday - 1 + i) % DateHelpers.daysPerWeek;
      return _vi
          ? _viWeekdaysShort[index]
          : _weekdays[index].substring(0, _shortLength);
    });
  }

  /// Weekday labels starting from [firstWeekday]: one letter, or "T2"…"CN".
  static List<String> weekdayInitials({int firstWeekday = DateTime.monday}) {
    return List.generate(DateHelpers.daysPerWeek, (i) {
      final index = (firstWeekday - 1 + i) % DateHelpers.daysPerWeek;
      return _vi ? _viWeekdaysShort[index] : _weekdays[index].substring(0, 1);
    });
  }

  /// "Oct 1" for the current year, "Oct 1, 2025" otherwise ("1/10",
  /// "1/10/2025" in Vietnamese).
  static String shortDate(DateTime date, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final sameYear = date.year == reference.year;
    if (_vi) {
      final base = '${date.day}/${date.month}';
      return sameYear ? base : '$base/${date.year}';
    }
    final base = '${monthShort(date)} ${date.day}';
    return sameYear ? base : '$base, ${date.year}';
  }

  /// "Thursday, October 1"
  static String longDate(DateTime date) => _vi
      ? '${weekdayName(date)}, ${date.day} tháng ${date.month}'
      : '${weekdayName(date)}, ${monthName(date)} ${date.day}';

  /// "Thu, October 1, 2026"
  static String fullDate(DateTime date) => _vi
      ? '${weekdayShort(date)}, ${date.day} tháng ${date.month}, ${date.year}'
      : '${weekdayShort(date)}, ${monthName(date)} ${date.day}, ${date.year}';

  /// "October 2026"
  static String monthYear(DateTime date) => _vi
      ? '${monthName(date)}, ${date.year}'
      : '${monthName(date)} ${date.year}';

  /// "Today", "Yesterday", "3 days ago", "In 2 days" or a short date.
  static String relativeDay(DateTime date, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = DateHelpers.daysBetween(reference, date);
    if (diff == 0) return tr('Today');
    if (diff == -1) return tr('Yesterday');
    if (diff == 1) return tr('Tomorrow');
    if (diff < 0 && -diff < _recentDayWindow) {
      return tr('{0} days ago', [-diff]);
    }
    if (diff > 0 && diff < _recentDayWindow) return tr('In {0} days', [diff]);
    return shortDate(date, now: reference);
  }

  /// "now", "5m", "3h", "2d", then a short date: how long ago a comment or
  /// like was left.
  static String timeAgo(DateTime date, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(date);
    if (diff.inMinutes < 1) return tr('now');
    if (diff.inHours < 1) return tr('{0}m', [diff.inMinutes]);
    if (diff.inDays < 1) return tr('{0}h', [diff.inHours]);
    if (diff.inDays < _recentDayWindow) return tr('{0}d', [diff.inDays]);
    return shortDate(date.toLocal(), now: reference);
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

  /// "1 item", "3 items". Vietnamese has no plural: "3 món".
  static String count(int value, String singular, [String? plural]) {
    if (_vi) return '$value ${tr(singular)}';
    final noun = value == 1 ? singular : (plural ?? '${singular}s');
    return '$value $noun';
  }

  static String wearCount(int count) => count == 0
      ? tr('Not worn yet')
      : tr('Worn {0}', [AppFormatters.count(count, 'time')]);

  static String greeting(DateTime now) {
    if (now.hour < _morningEndHour) return tr('Good morning');
    if (now.hour < _afternoonEndHour) return tr('Good afternoon');
    return tr('Good evening');
  }

  static String initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }
}
