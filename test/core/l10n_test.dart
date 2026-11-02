import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/l10n/l10n.dart';
import 'package:all_fits/core/l10n/vi.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_photo.dart';
import 'package:all_fits/data/models/weather.dart';

void main() {
  tearDown(() => L10n.current = AppLanguage.en);

  group('tr', () {
    test('English returns the source text with its values filled in', () {
      expect(tr('Settings'), 'Settings');
      expect(tr('Weather in {0}', ['Hanoi']), 'Weather in Hanoi');
      expect(tr('Back|photo'), 'Back');
    });

    test('Vietnamese translates and fills in values', () {
      L10n.current = AppLanguage.vi;
      expect(tr('Settings'), 'Cài đặt');
      expect(tr('Weather in {0}', ['Hà Nội']), 'Thời tiết ở Hà Nội');
      expect(tr('Back'), 'Quay lại');
      expect(tr('Back|photo'), 'Mặt sau');
    });

    test('text without a translation stays in English', () {
      L10n.current = AppLanguage.vi;
      expect(tr('Not translated {0}', [1]), 'Not translated 1');
      expect(tr('Untranslated|sense'), 'Untranslated');
    });

    test('every translation keeps the placeholders of its English text', () {
      final placeholder = RegExp(r'\{\d+\}');
      Set<String> placeholders(String s) =>
          placeholder.allMatches(s).map((m) => m[0]!).toSet();
      final broken = [
        for (final MapEntry(:key, :value) in vietnamese.entries)
          if (!placeholders(key).containsAll(placeholders(value))) key,
      ];
      expect(broken, isEmpty);
    });

    test('errors are shown in the app language', () {
      L10n.current = AppLanguage.vi;
      expect(
        describeError(const NotFoundException()),
        'Món đồ này không còn nữa.',
      );
      expect(
        describeError(StateError('x')),
        'Đã xảy ra lỗi. Vui lòng thử lại.',
      );
    });

    test('data labels follow the language', () {
      expect(ClothingCategory.tops.label, 'Tops');
      L10n.current = AppLanguage.vi;
      expect(ClothingCategory.tops.label, 'Áo');
      expect(PhotoKind.back.label, 'Mặt sau');
      expect(WeatherCondition.clear.label, 'Trời quang');
    });
  });

  group('Vietnamese formatting', () {
    // Thursday, 1 October 2026.
    final date = DateTime(2026, 10, 1);

    setUp(() => L10n.current = AppLanguage.vi);

    test('dates', () {
      expect(AppFormatters.shortDate(date, now: date), '1/10');
      expect(AppFormatters.shortDate(date, now: DateTime(2027)), '1/10/2026');
      expect(AppFormatters.longDate(date), 'Thứ Năm, 1 tháng 10');
      expect(AppFormatters.monthYear(date), 'Tháng 10, 2026');
      expect(AppFormatters.weekdayShort(date), 'T5');
      expect(AppFormatters.weekdayShortNames(firstWeekday: DateTime.sunday), [
        'CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', //
      ]);
    });

    test('relative days and time ago', () {
      expect(AppFormatters.relativeDay(date, now: date), 'Hôm nay');
      expect(
        AppFormatters.relativeDay(date, now: DateTime(2026, 10, 4)),
        '3 ngày trước',
      );
      expect(
        AppFormatters.timeAgo(date, now: date.add(const Duration(minutes: 5))),
        '5 phút',
      );
    });

    test('counts have no plural', () {
      expect(AppFormatters.count(1, 'piece'), '1 món');
      expect(AppFormatters.count(3, 'outfit'), '3 outfit');
      expect(AppFormatters.wearCount(2), 'Đã mặc 2 lần');
    });
  });
}
