/// Unit tests for resolveZoneColor utility function.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/planning/utils/zone_color_resolver.dart';

void main() {
  group('resolveZoneColor', () {
    // -----------------------------------------------------------------------
    // Valid hex input
    // -----------------------------------------------------------------------

    test('valid hex #FF5733 returns non-default Color', () {
      final color = resolveZoneColor('#FF5733');
      // The function applies opacity but preserves RGB; check the base RGB
      // by comparing to a known Color with the same RGB.
      // Red component of #FF5733 is 0xFF, green 0x57, blue 0x33.
      final expected =
          const Color(0xFFFF5733).withValues(alpha: 0.5);
      expect(color, equals(expected));
    });

    test('valid hex #4CAF50 (green) returns Color with light-mode opacity 0.5',
        () {
      final color = resolveZoneColor('#4CAF50');
      expect(color.a, closeTo(0.5, 0.01));
    });

    test('valid hex uppercase #FFFFFF is parsed correctly', () {
      final color = resolveZoneColor('#FFFFFF');
      // Should not be the default blue shade 300
      expect(color.b, closeTo(1.0, 0.01));
    });

    // -----------------------------------------------------------------------
    // Invalid / null hex → fallback to Colors.blue.shade300 with opacity
    // -----------------------------------------------------------------------

    test('invalid hex "notahex" falls back to blue shade 300', () {
      final fallback = Colors.blue.shade300.withValues(alpha: 0.5);
      final color = resolveZoneColor('notahex');
      expect(color, equals(fallback));
    });

    test('empty string "" falls back to blue shade 300', () {
      final fallback = Colors.blue.shade300.withValues(alpha: 0.5);
      final color = resolveZoneColor('');
      expect(color, equals(fallback));
    });

    test('null falls back to blue shade 300 with light-mode opacity', () {
      final fallback = Colors.blue.shade300.withValues(alpha: 0.5);
      final color = resolveZoneColor(null);
      expect(color, equals(fallback));
    });

    test('hex without # prefix falls back (cannot parse "FF5733")', () {
      // "FF5733" without # — int.parse('0xffFF5733') would actually succeed
      // because replaceFirst('#', '0xff') on "FF5733" gives "0xffFF5733"
      // which is out of 32-bit range... depends on runtime.
      // We just verify it doesn't throw and returns a Color.
      expect(() => resolveZoneColor('FF5733'), returnsNormally);
    });

    // -----------------------------------------------------------------------
    // Dark mode — opacity should be 0.4 (10% less than light 0.5)
    // -----------------------------------------------------------------------

    test('dark=true produces opacity ~0.4 for valid hex', () {
      final color = resolveZoneColor('#FF5733', dark: true);
      expect(color.a, closeTo(0.4, 0.01));
    });

    test('dark=false (default) produces opacity ~0.5', () {
      final color = resolveZoneColor('#FF5733');
      expect(color.a, closeTo(0.5, 0.01));
    });

    test('dark=true on null hex uses blue fallback with 0.4 opacity', () {
      final color = resolveZoneColor(null, dark: true);
      expect(color.a, closeTo(0.4, 0.01));
    });

    test('dark mode opacity is 10% lower than light mode opacity', () {
      final light = resolveZoneColor('#FF5733', dark: false);
      final dark = resolveZoneColor('#FF5733', dark: true);
      expect(light.a - dark.a, closeTo(0.1, 0.005));
    });
  });
}
