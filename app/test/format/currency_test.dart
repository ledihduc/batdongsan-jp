/// Unit tests for [formatPrice] in lib/core/format/currency.dart.
///
/// Verifies locale-aware formatting for ja_JP and vi_VN.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/format/currency.dart';

void main() {
  group('formatPrice — Japanese yen (ja_JP)', () {
    test('formats integer amount with ¥ prefix and comma thousands', () {
      expect(formatPrice(1000, locale: 'ja_JP'), '¥1,000');
    });

    test('formats zero', () {
      expect(formatPrice(0, locale: 'ja_JP'), '¥0');
    });

    test('formats large amount', () {
      expect(formatPrice(1234567, locale: 'ja_JP'), '¥1,234,567');
    });

    test('truncates decimal (no decimals for yen)', () {
      expect(formatPrice(1000.9, locale: 'ja_JP'), '¥1,001');
    });

    test('locale "ja" (without region) also uses yen format', () {
      expect(formatPrice(500, locale: 'ja'), '¥500');
    });
  });

  group('formatPrice — Vietnamese dong (vi_VN)', () {
    test('formats integer amount with ₫ suffix and dot thousands', () {
      expect(formatPrice(1000, locale: 'vi_VN'), '1.000 ₫');
    });

    test('formats zero', () {
      expect(formatPrice(0, locale: 'vi_VN'), '0 ₫');
    });

    test('formats large amount', () {
      expect(formatPrice(1234567, locale: 'vi_VN'), '1.234.567 ₫');
    });

    test('default locale (null) uses vi_VN formatting', () {
      expect(formatPrice(1000), '1.000 ₫');
    });
  });
}
