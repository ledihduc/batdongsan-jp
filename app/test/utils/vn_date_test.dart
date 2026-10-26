/// Unit tests for vn_date.dart — Vietnamese date format helpers.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/utils/vn_date.dart';

void main() {
  group('formatVnDate', () {
    test('Sunday 2026-06-28 → "Chủ nhật, 28/06/2026"', () {
      expect(formatVnDate('2026-06-28'), 'Chủ nhật, 28/06/2026');
    });

    test('Monday 2026-06-29 → "Thứ 2, 29/06/2026"', () {
      expect(formatVnDate('2026-06-29'), 'Thứ 2, 29/06/2026');
    });

    test('Saturday 2026-07-04 → "Thứ 7, 04/07/2026"', () {
      expect(formatVnDate('2026-07-04'), 'Thứ 7, 04/07/2026');
    });

    test('withWeekday: false → "28/06/2026"', () {
      expect(formatVnDate('2026-06-28', withWeekday: false), '28/06/2026');
    });

    test('invalid input → returns raw string', () {
      expect(formatVnDate('not-a-date'), 'not-a-date');
    });

    test('single-digit day/month padded', () {
      expect(formatVnDate('2026-01-05', withWeekday: false), '05/01/2026');
    });
  });

  group('formatVnDateTime', () {
    test('DateTime(2026,6,28,9,12) → "28/06/2026 09:12"', () {
      expect(formatVnDateTime(DateTime(2026, 6, 28, 9, 12)), '28/06/2026 09:12');
    });

    test('midnight → "01/01/2026 00:00"', () {
      expect(formatVnDateTime(DateTime(2026, 1, 1, 0, 0)), '01/01/2026 00:00');
    });

    test('late evening → "31/12/2025 23:59"', () {
      expect(formatVnDateTime(DateTime(2025, 12, 31, 23, 59)),
          '31/12/2025 23:59');
    });
  });
}
