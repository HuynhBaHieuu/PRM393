abstract final class DateHelpers {
  static const int daysPerWeek = 7;
  static const int calendarWeeks = 6;

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  /// Stable `yyyy-MM-dd` key that is independent of time zones.
  static String toKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime? fromKey(String? key) {
    if (key == null) return null;
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime(y, m, d);
  }

  /// Whole calendar days from [from] to [to] (negative if [to] is earlier).
  /// Uses UTC so daylight-saving changes don't skew the result.
  static int daysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  static DateTime firstDayOfMonth(DateTime date) =>
      DateTime(date.year, date.month);

  static DateTime addMonths(DateTime date, int months) =>
      DateTime(date.year, date.month + months);

  static DateTime addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  /// The 42 days (6 weeks) shown in a month grid, starting on [firstWeekday].
  static List<DateTime> calendarDays(
    DateTime month, {
    int firstWeekday = DateTime.monday,
  }) {
    final first = firstDayOfMonth(month);
    final offset = (first.weekday - firstWeekday) % daysPerWeek;
    final start = addDays(first, -offset);
    return List.generate(
      daysPerWeek * calendarWeeks,
      (index) => addDays(start, index),
    );
  }

  static DateTime? latest(Iterable<DateTime?> dates) {
    DateTime? result;
    for (final date in dates) {
      if (date != null && (result == null || date.isAfter(result))) {
        result = date;
      }
    }
    return result;
  }
}
