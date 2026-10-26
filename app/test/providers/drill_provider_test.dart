/// Unit tests for DrillProvider — breadcrumb, level navigation, filter.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:house_booking/features/host/analytics/providers/drill_provider.dart';

void main() {
  group('DrillProvider — breadcrumb', () {
    late DrillProvider provider;

    setUp(() => provider = DrillProvider());

    test('starts with root breadcrumb (level 0, Tổng quan)', () {
      expect(provider.breadcrumb.length, equals(1));
      expect(provider.breadcrumb.first.level, equals(0));
      expect(provider.breadcrumb.first.title, equals('Tổng quan'));
      expect(provider.currentLevel, equals(0));
    });

    test('pushLevel adds item to breadcrumb', () {
      provider.pushLevel(level: 1, title: 'Phòng 101', params: {'roomId': 5});
      expect(provider.breadcrumb.length, equals(2));
      expect(provider.breadcrumb.last.title, equals('Phòng 101'));
      expect(provider.breadcrumb.last.level, equals(1));
      expect(provider.breadcrumb.last.params['roomId'], equals(5));
      expect(provider.currentLevel, equals(1));
    });

    test('pushLevel advances to level 2 correctly', () {
      provider.pushLevel(level: 1, title: 'Phòng 101');
      provider.pushLevel(level: 2, title: 'HĐ #42', params: {'contractId': 42});
      expect(provider.breadcrumb.length, equals(3));
      expect(provider.currentLevel, equals(2));
    });

    test('pushLevel from level 1 → level 2 truncates forward history at level 1', () {
      provider.pushLevel(level: 1, title: 'Phòng 101');
      provider.pushLevel(level: 2, title: 'HĐ #42');
      provider.pushLevel(level: 3, title: 'Nguyễn A');
      // Navigate back to level 1, then push again → should replace 2 and 3
      provider.pushLevel(level: 2, title: 'HĐ #99');
      expect(provider.breadcrumb.length, equals(3));
      expect(provider.breadcrumb.last.title, equals('HĐ #99'));
      expect(provider.currentLevel, equals(2));
    });

    test('popToLevel truncates breadcrumb correctly', () {
      provider.pushLevel(level: 1, title: 'Phòng 101');
      provider.pushLevel(level: 2, title: 'HĐ #42');
      provider.pushLevel(level: 3, title: 'Nguyễn A');

      provider.popToLevel(1);
      expect(provider.breadcrumb.length, equals(2));
      expect(provider.breadcrumb.last.level, equals(1));
      expect(provider.currentLevel, equals(1));
    });

    test('popToLevel to root (0) leaves only root item', () {
      provider.pushLevel(level: 1, title: 'Phòng 101');
      provider.pushLevel(level: 2, title: 'HĐ #42');

      provider.popToLevel(0);
      expect(provider.breadcrumb.length, equals(1));
      expect(provider.breadcrumb.first.level, equals(0));
      expect(provider.currentLevel, equals(0));
    });

    test('popToLevel with out-of-bounds index is a no-op', () {
      provider.pushLevel(level: 1, title: 'Phòng 101');
      final before = provider.breadcrumb.length;
      provider.popToLevel(99);
      expect(provider.breadcrumb.length, equals(before));
    });

    test('reset clears breadcrumb to root and resets level', () {
      provider.pushLevel(level: 1, title: 'Phòng 101');
      provider.pushLevel(level: 2, title: 'HĐ #42');

      provider.reset();
      expect(provider.breadcrumb.length, equals(1));
      expect(provider.breadcrumb.first.level, equals(0));
      expect(provider.currentLevel, equals(0));
    });

    test('reset also clears filter', () {
      final range = DateTimeRange(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 12, 31),
      );
      provider.updateFilter(FilterState(dateRange: range, buildingIds: [1]));
      provider.reset();
      expect(provider.filter.isEmpty, isTrue);
    });

    test('pushLevel notifies listeners', () {
      var notified = false;
      provider.addListener(() => notified = true);
      provider.pushLevel(level: 1, title: 'Phòng');
      expect(notified, isTrue);
    });

    test('popToLevel notifies listeners', () {
      provider.pushLevel(level: 1, title: 'Phòng');
      var notified = false;
      provider.addListener(() => notified = true);
      provider.popToLevel(0);
      expect(notified, isTrue);
    });
  });

  group('DrillProvider — filter', () {
    late DrillProvider provider;

    setUp(() => provider = DrillProvider());

    test('initial filter is empty', () {
      expect(provider.filter.isEmpty, isTrue);
    });

    test('updateFilter updates state and notifies', () {
      var notified = false;
      provider.addListener(() => notified = true);

      provider.updateFilter(const FilterState(buildingIds: [1, 2]));
      expect(provider.filter.buildingIds, equals([1, 2]));
      expect(notified, isTrue);
    });

    test('clearFilter resets to empty and notifies', () {
      provider.updateFilter(const FilterState(buildingIds: [1]));
      var notified = false;
      provider.addListener(() => notified = true);

      provider.clearFilter();
      expect(provider.filter.isEmpty, isTrue);
      expect(notified, isTrue);
    });
  });

  group('FilterState', () {
    test('empty() is isEmpty', () {
      expect(const FilterState.empty().isEmpty, isTrue);
    });

    test('non-empty buildingIds makes isEmpty false', () {
      expect(const FilterState(buildingIds: [1]).isEmpty, isFalse);
    });

    test('non-empty sourceIds makes isEmpty false', () {
      expect(const FilterState(sourceIds: [2]).isEmpty, isFalse);
    });

    test('roomType set makes isEmpty false', () {
      expect(const FilterState(roomType: 'Homestay').isEmpty, isFalse);
    });

    test('dateRange set makes isEmpty false', () {
      final state = FilterState(
        dateRange: DateTimeRange(
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 6, 1),
        ),
      );
      expect(state.isEmpty, isFalse);
    });

    test('copyWith preserves unchanged fields', () {
      const original = FilterState(
        buildingIds: [1],
        sourceIds: [2],
        roomType: 'Homestay',
      );
      final updated = original.copyWith(buildingIds: [3, 4]);
      expect(updated.buildingIds, equals([3, 4]));
      expect(updated.sourceIds, equals([2]));
      expect(updated.roomType, equals('Homestay'));
    });

    test('copyWith clearDateRange removes dateRange', () {
      final state = FilterState(
        dateRange: DateTimeRange(
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 6, 1),
        ),
      );
      final cleared = state.copyWith(clearDateRange: true);
      expect(cleared.dateRange, isNull);
    });

    test('copyWith clearRoomType removes roomType', () {
      const state = FilterState(roomType: 'Homestay');
      final cleared = state.copyWith(clearRoomType: true);
      expect(cleared.roomType, isNull);
    });

    test('equality works correctly', () {
      const a = FilterState(buildingIds: [1, 2], roomType: 'Homestay');
      const b = FilterState(buildingIds: [1, 2], roomType: 'Homestay');
      const c = FilterState(buildingIds: [1], roomType: 'Homestay');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
