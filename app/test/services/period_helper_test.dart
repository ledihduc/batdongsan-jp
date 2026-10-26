/// Unit tests for PeriodHelper — period navigation, cross-year, leap-year.
///
/// Covers: formatPeriodKey, shift (month/year), displayLabel, parseKey,
/// cross-year month boundary, and leap Feb 29 → Feb 28 clamp.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/host/analytics/services/period_helper.dart';

void main() {
  group('PeriodHelper.formatPeriodKey', () {
    test('month → YYYY-MM with zero-padded month', () {
      final dt = DateTime(2026, 7, 15);
      expect(
        PeriodHelper.formatPeriodKey(PeriodType.month, dt),
        equals('2026-07'),
      );
    });

    test('month in October → 10 (no double-pad)', () {
      final dt = DateTime(2026, 10, 1);
      expect(
        PeriodHelper.formatPeriodKey(PeriodType.month, dt),
        equals('2026-10'),
      );
    });

    test('year → YYYY only', () {
      final dt = DateTime(2026, 7, 15);
      expect(
        PeriodHelper.formatPeriodKey(PeriodType.year, dt),
        equals('2026'),
      );
    });
  });

  group('PeriodHelper.shift — month', () {
    test('positive delta advances month', () {
      final base = DateTime(2026, 5, 15);
      final shifted = PeriodHelper.shift(PeriodType.month, base, 2);
      expect(shifted.year, equals(2026));
      expect(shifted.month, equals(7));
      expect(shifted.day, equals(15));
    });

    test('negative delta goes back month', () {
      final base = DateTime(2026, 3, 10);
      final shifted = PeriodHelper.shift(PeriodType.month, base, -2);
      expect(shifted.year, equals(2026));
      expect(shifted.month, equals(1));
    });

    test('cross-year: Dec 2025 + 1 month → Jan 2026', () {
      final base = DateTime(2025, 12, 15);
      final shifted = PeriodHelper.shift(PeriodType.month, base, 1);
      expect(shifted.year, equals(2026));
      expect(shifted.month, equals(1));
      expect(shifted.day, equals(15));
    });

    test('cross-year backward: Jan 2026 - 1 → Dec 2025', () {
      final base = DateTime(2026, 1, 20);
      final shifted = PeriodHelper.shift(PeriodType.month, base, -1);
      expect(shifted.year, equals(2025));
      expect(shifted.month, equals(12));
    });

    test('leap year: Feb 29 2024 + 1 month → Mar 29 2024', () {
      final base = DateTime(2024, 2, 29);
      final shifted = PeriodHelper.shift(PeriodType.month, base, 1);
      expect(shifted.month, equals(3));
      expect(shifted.day, equals(29));
    });

    test('leap day clamp: Feb 29 2024 + 12 months → Feb 28 2025 (AC-06)', () {
      final base = DateTime(2024, 2, 29);
      final shifted = PeriodHelper.shift(PeriodType.month, base, 12);
      expect(shifted.year, equals(2025));
      expect(shifted.month, equals(2));
      // 2025 is not a leap year — day clamped to 28
      expect(shifted.day, equals(28));
    });

    test('delta=0 returns same period', () {
      final base = DateTime(2026, 6, 1);
      final shifted = PeriodHelper.shift(PeriodType.month, base, 0);
      expect(shifted.year, equals(2026));
      expect(shifted.month, equals(6));
    });
  });

  group('PeriodHelper.shift — year', () {
    test('positive delta advances year', () {
      final base = DateTime(2025, 7, 15);
      final shifted = PeriodHelper.shift(PeriodType.year, base, 1);
      expect(shifted.year, equals(2026));
      expect(shifted.month, equals(7));
      expect(shifted.day, equals(15));
    });

    test('negative delta goes back year', () {
      final base = DateTime(2026, 4, 10);
      final shifted = PeriodHelper.shift(PeriodType.year, base, -2);
      expect(shifted.year, equals(2024));
    });

    test('leap day clamp: Feb 29 2024 + 1 year → Feb 28 2025', () {
      final base = DateTime(2024, 2, 29);
      final shifted = PeriodHelper.shift(PeriodType.year, base, 1);
      expect(shifted.year, equals(2025));
      expect(shifted.month, equals(2));
      expect(shifted.day, equals(28));
    });

    test('Feb 28 2025 + 1 year → Feb 28 2026 (not leap)', () {
      final base = DateTime(2025, 2, 28);
      final shifted = PeriodHelper.shift(PeriodType.year, base, 1);
      expect(shifted.year, equals(2026));
      expect(shifted.month, equals(2));
      expect(shifted.day, equals(28));
    });
  });

  group('PeriodHelper.displayLabel', () {
    test('month returns Tháng M/YYYY', () {
      final dt = DateTime(2026, 7, 1);
      expect(
        PeriodHelper.displayLabel(PeriodType.month, dt),
        equals('Tháng 7/2026'),
      );
    });

    test('month January no leading zero in label', () {
      final dt = DateTime(2026, 1, 1);
      expect(
        PeriodHelper.displayLabel(PeriodType.month, dt),
        equals('Tháng 1/2026'),
      );
    });

    test('year returns Năm YYYY', () {
      final dt = DateTime(2026, 6, 1);
      expect(
        PeriodHelper.displayLabel(PeriodType.year, dt),
        equals('Năm 2026'),
      );
    });
  });

  group('PeriodHelper.parseKey', () {
    test('month key → first day of month', () {
      final dt = PeriodHelper.parseKey(PeriodType.month, '2026-07');
      expect(dt.year, equals(2026));
      expect(dt.month, equals(7));
      expect(dt.day, equals(1));
    });

    test('year key → January 1', () {
      final dt = PeriodHelper.parseKey(PeriodType.year, '2026');
      expect(dt.year, equals(2026));
      expect(dt.month, equals(1));
      expect(dt.day, equals(1));
    });
  });
}
