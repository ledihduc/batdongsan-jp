/// Phase 04 — unit tests for Zalo deep-link helper.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/utils/zalo_deep_link.dart';

void main() {
  group('normaliseVnPhone', () {
    test('+84 prefix → 0xxxxxxxxx', () {
      expect(normaliseVnPhone('+84912345678'), '0912345678');
    });

    test('84 prefix → 0xxxxxxxxx', () {
      expect(normaliseVnPhone('84912345678'), '0912345678');
    });

    test('local 0xxxxxxxxx unchanged', () {
      expect(normaliseVnPhone('0912345678'), '0912345678');
    });

    test('strips spaces and dashes', () {
      expect(normaliseVnPhone('0912 345 678'), '0912345678');
      expect(normaliseVnPhone('091-234-5678'), '0912345678');
    });

    test('bare 9-digit fallback prepends 0', () {
      expect(normaliseVnPhone('912345678'), '0912345678');
    });
  });

  group('buildZaloShareLink', () {
    test('produces zalo.me URL with quoted body', () {
      final url = buildZaloShareLink(
          '+84912345678', 'Hoá đơn tháng 7 đã sẵn sàng');
      expect(url, startsWith('https://zalo.me/0912345678?body='));
      // Vietnamese diacritics must be percent-encoded
      expect(url, contains('%C3%A1'));
    });

    test('handles ASCII-only message (form-urlencoded space=+)', () {
      final url = buildZaloShareLink('0912345678', 'Hello world');
      expect(url, 'https://zalo.me/0912345678?body=Hello+world');
    });
  });
}
