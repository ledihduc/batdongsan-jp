/// Unit tests for BboxGuard — verifies the Vietnam bounding box logic.
///
/// Bbox constants (from bbox_guard.dart):
///   minLat=8.0, maxLat=23.5, minLng=102.0, maxLng=110.0
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/planning/utils/bbox_guard.dart';

void main() {
  group('BboxGuard.isInsideVN', () {
    // -----------------------------------------------------------------------
    // Inside Vietnam — must return true
    // -----------------------------------------------------------------------

    test('Ha Noi (21.03, 105.85) is inside', () {
      expect(BboxGuard.isInsideVN(21.03, 105.85), isTrue);
    });

    test('Da Nang (16.05, 108.20) is inside', () {
      expect(BboxGuard.isInsideVN(16.05, 108.20), isTrue);
    });

    test('HCMC Bến Thành (10.77, 106.70) is inside', () {
      expect(BboxGuard.isInsideVN(10.77, 106.70), isTrue);
    });

    test('An Giang (10.52, 105.13) is inside', () {
      expect(BboxGuard.isInsideVN(10.52, 105.13), isTrue);
    });

    test('Sa Pa (22.34, 103.84) is inside', () {
      expect(BboxGuard.isInsideVN(22.34, 103.84), isTrue);
    });

    // -----------------------------------------------------------------------
    // Outside Vietnam — must return false
    // -----------------------------------------------------------------------

    test('Bangkok (13.75, 100.50) is outside', () {
      expect(BboxGuard.isInsideVN(13.75, 100.50), isFalse);
    });

    test('Singapore (1.35, 103.82) is outside (too south)', () {
      expect(BboxGuard.isInsideVN(1.35, 103.82), isFalse);
    });

    test('Hong Kong (22.30, 114.17) is outside (too east)', () {
      expect(BboxGuard.isInsideVN(22.30, 114.17), isFalse);
    });

    test('zero coordinates (0.0, 0.0) is outside', () {
      // Default invalid coordinates from house detail must be rejected.
      expect(BboxGuard.isInsideVN(0.0, 0.0), isFalse);
    });

    // -----------------------------------------------------------------------
    // Boundary edge cases — exactly on the boundary counts as inside
    // -----------------------------------------------------------------------

    test('exact minLat boundary (8.0, 105.0) is inside (inclusive)', () {
      expect(BboxGuard.isInsideVN(8.0, 105.0), isTrue);
    });

    test('exact maxLat boundary (23.5, 105.0) is inside (inclusive)', () {
      expect(BboxGuard.isInsideVN(23.5, 105.0), isTrue);
    });

    test('just below minLat (7.99, 105.0) is outside', () {
      expect(BboxGuard.isInsideVN(7.99, 105.0), isFalse);
    });

    test('just above maxLat (23.51, 105.0) is outside', () {
      expect(BboxGuard.isInsideVN(23.51, 105.0), isFalse);
    });

    test('just left of minLng (15.0, 101.99) is outside', () {
      expect(BboxGuard.isInsideVN(15.0, 101.99), isFalse);
    });

    test('just right of maxLng (15.0, 110.01) is outside', () {
      expect(BboxGuard.isInsideVN(15.0, 110.01), isFalse);
    });
  });
}
