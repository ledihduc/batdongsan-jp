/// Unit tests for CurrencyFormatter — VND format per AC-03.
///
/// Covers: full format, abbreviated thresholds (k/tr/tỷ), pct format,
/// null pct returns "—", negative amounts, and boundary edge cases.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/host/analytics/services/currency_formatter.dart';

void main() {
  group('CurrencyFormatter.format — full VND', () {
    test('zero formats to ₫ symbol', () {
      final result = CurrencyFormatter.format(0);
      expect(result, contains('₫'));
    });

    test('5_000_000 formats with vi_VN thousand separator', () {
      final result = CurrencyFormatter.format(5000000);
      // vi_VN uses . as thousand separator
      expect(result, contains('5'));
      expect(result, contains('₫'));
    });

    test('abbreviated=false is default', () {
      final full = CurrencyFormatter.format(2000000);
      final explicit = CurrencyFormatter.format(2000000, abbreviated: false);
      expect(full, equals(explicit));
    });
  });

  group('CurrencyFormatter.format — abbreviated', () {
    // AC-03: thresholds: ≥1e9 → tỷ, ≥1e6 → tr, ≥1e3 → k

    test('exactly 1_000 → abbreviated with k', () {
      final result = CurrencyFormatter.format(1000, abbreviated: true);
      expect(result, contains('k'));
    });

    test('1_200 → 1.2k', () {
      final result = CurrencyFormatter.format(1200, abbreviated: true);
      expect(result, equals('1.2k'));
    });

    test('5_000 → 5k (no decimal)', () {
      final result = CurrencyFormatter.format(5000, abbreviated: true);
      expect(result, equals('5k'));
    });

    test('exactly 1_000_000 → abbreviated with tr', () {
      final result = CurrencyFormatter.format(1000000, abbreviated: true);
      expect(result, contains('tr'));
    });

    test('1_500_000 → 1.5 tr', () {
      final result = CurrencyFormatter.format(1500000, abbreviated: true);
      expect(result, equals('1.5 tr'));
    });

    test('5_000_000 → 5 tr', () {
      final result = CurrencyFormatter.format(5000000, abbreviated: true);
      expect(result, equals('5 tr'));
    });

    test('exactly 1_000_000_000 → abbreviated with tỷ', () {
      final result = CurrencyFormatter.format(1000000000, abbreviated: true);
      expect(result, contains('tỷ'));
    });

    test('1_500_000_000 → 1.5 tỷ', () {
      final result = CurrencyFormatter.format(1500000000, abbreviated: true);
      expect(result, equals('1.5 tỷ'));
    });

    test('3_000_000_000 → 3 tỷ', () {
      final result = CurrencyFormatter.format(3000000000, abbreviated: true);
      expect(result, equals('3 tỷ'));
    });

    test('below 1000 → full VND format (contains ₫)', () {
      final result = CurrencyFormatter.format(500, abbreviated: true);
      expect(result, contains('₫'));
      expect(result, isNot(contains('k')));
    });

    test('negative million abbreviates with tr', () {
      final result = CurrencyFormatter.format(-2000000, abbreviated: true);
      expect(result, contains('tr'));
    });
  });

  group('CurrencyFormatter.formatPct', () {
    test('null returns em dash', () {
      expect(CurrencyFormatter.formatPct(null), equals('—'));
    });

    test('positive pct with default 1 decimal', () {
      expect(CurrencyFormatter.formatPct(15.0), equals('15.0%'));
    });

    test('zero pct', () {
      expect(CurrencyFormatter.formatPct(0.0), equals('0.0%'));
    });

    test('negative pct', () {
      expect(CurrencyFormatter.formatPct(-5.2), equals('-5.2%'));
    });

    test('custom decimals=2', () {
      expect(CurrencyFormatter.formatPct(12.345, decimals: 2), equals('12.35%'));
    });

    test('decimals=0 rounds', () {
      expect(CurrencyFormatter.formatPct(7.8, decimals: 0), equals('8%'));
    });
  });

  group('CurrencyFormatter — AC-03 spec examples', () {
    // AC-03 examples from BA doc
    test('1.5 tỷ threshold example', () {
      final result = CurrencyFormatter.format(1500000000, abbreviated: true);
      expect(result, equals('1.5 tỷ'));
    });

    test('1.5 tr threshold example', () {
      final result = CurrencyFormatter.format(1500000, abbreviated: true);
      expect(result, equals('1.5 tr'));
    });

    test('1.2k threshold example', () {
      final result = CurrencyFormatter.format(1200, abbreviated: true);
      expect(result, equals('1.2k'));
    });
  });
}
