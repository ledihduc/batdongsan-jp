/// Unit tests for FilterCodec — round-trip, malformed input, URL safety.
library;

import 'dart:convert';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/host/analytics/providers/drill_provider.dart';
import 'package:house_booking/features/host/analytics/services/filter_codec.dart';

void main() {
  group('FilterCodec.encode', () {
    test('empty filter encodes to empty string', () {
      expect(FilterCodec.encode(const FilterState.empty()), equals(''));
    });

    test('filter with only default values encodes to empty string', () {
      const state = FilterState(buildingIds: [], sourceIds: []);
      expect(FilterCodec.encode(state), equals(''));
    });

    test('buildingIds are included in encoded output', () {
      const state = FilterState(buildingIds: [1, 2, 3]);
      final encoded = FilterCodec.encode(state);
      expect(encoded, isNotEmpty);
      // Decode raw to verify content.
      final decoded = jsonDecode(utf8.decode(base64Url.decode(_pad(encoded))))
          as Map<String, dynamic>;
      expect(decoded['b'], equals([1, 2, 3]));
    });

    test('sourceIds are included in encoded output', () {
      const state = FilterState(sourceIds: [10, 20]);
      final encoded = FilterCodec.encode(state);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(_pad(encoded))))
          as Map<String, dynamic>;
      expect(decoded['s'], equals([10, 20]));
    });

    test('roomType is included in encoded output', () {
      const state = FilterState(roomType: 'Homestay');
      final encoded = FilterCodec.encode(state);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(_pad(encoded))))
          as Map<String, dynamic>;
      expect(decoded['rt'], equals('Homestay'));
    });

    test('dateRange is included in encoded output', () {
      final state = FilterState(
        dateRange: DateTimeRange(
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 6, 30),
        ),
      );
      final encoded = FilterCodec.encode(state);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(_pad(encoded))))
          as Map<String, dynamic>;
      expect(decoded['ds'], isNotNull);
      expect(decoded['de'], isNotNull);
    });

    test('output contains only URL-safe characters (no +, /, =)', () {
      const state = FilterState(buildingIds: [1, 2], roomType: 'Phòng trọ');
      final encoded = FilterCodec.encode(state);
      // base64Url uses - and _ instead of + and /; no padding in our output.
      expect(encoded.contains('+'), isFalse);
      expect(encoded.contains('/'), isFalse);
    });
  });

  group('FilterCodec.decode', () {
    test('empty string decodes to empty FilterState', () {
      final state = FilterCodec.decode('');
      expect(state.isEmpty, isTrue);
    });

    test('malformed base64 returns empty FilterState', () {
      final state = FilterCodec.decode('!!!not-valid-base64!!!');
      expect(state.isEmpty, isTrue);
    });

    test('valid base64 but invalid JSON returns empty FilterState', () {
      final state =
          FilterCodec.decode(base64Url.encode(utf8.encode('not json')));
      expect(state.isEmpty, isTrue);
    });

    test('valid JSON but missing keys returns empty FilterState', () {
      final encoded = base64Url.encode(utf8.encode('{}'));
      final state = FilterCodec.decode(encoded);
      expect(state.isEmpty, isTrue);
    });

    test('round-trip: empty FilterState', () {
      const original = FilterState.empty();
      final decoded = FilterCodec.decode(FilterCodec.encode(original));
      expect(decoded.isEmpty, isTrue);
    });

    test('round-trip: buildingIds only', () {
      const original = FilterState(buildingIds: [1, 2, 3]);
      final encoded = FilterCodec.encode(original);
      final decoded = FilterCodec.decode(encoded);
      expect(decoded.buildingIds, equals([1, 2, 3]));
      expect(decoded.sourceIds, isEmpty);
    });

    test('round-trip: sourceIds only', () {
      const original = FilterState(sourceIds: [5, 6]);
      final decoded = FilterCodec.decode(FilterCodec.encode(original));
      expect(decoded.sourceIds, equals([5, 6]));
    });

    test('round-trip: roomType only', () {
      const original = FilterState(roomType: 'Homestay');
      final decoded = FilterCodec.decode(FilterCodec.encode(original));
      expect(decoded.roomType, equals('Homestay'));
    });

    test('round-trip: dateRange only', () {
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 6, 30);
      final original = FilterState(
          dateRange: DateTimeRange(start: start, end: end));
      final decoded = FilterCodec.decode(FilterCodec.encode(original));
      expect(decoded.dateRange, isNotNull);
      // Compare date parts (ISO round-trip may lose sub-second precision).
      expect(decoded.dateRange!.start.year, equals(2026));
      expect(decoded.dateRange!.start.month, equals(1));
      expect(decoded.dateRange!.end.month, equals(6));
    });

    test('round-trip: all fields set', () {
      final original = FilterState(
        buildingIds: [1, 2],
        sourceIds: [10],
        roomType: 'Phòng trọ',
        dateRange: DateTimeRange(
          start: DateTime(2026, 3, 1),
          end: DateTime(2026, 5, 31),
        ),
      );
      final decoded = FilterCodec.decode(FilterCodec.encode(original));
      expect(decoded.buildingIds, equals([1, 2]));
      expect(decoded.sourceIds, equals([10]));
      expect(decoded.roomType, equals('Phòng trọ'));
      expect(decoded.dateRange, isNotNull);
    });

    test('decode with missing padding is tolerant', () {
      // Manually create encoded without padding.
      const state = FilterState(buildingIds: [7]);
      final encoded = FilterCodec.encode(state);
      // Try without padding (base64Url.decode handles _addPadding internally).
      final decoded = FilterCodec.decode(encoded);
      expect(decoded.buildingIds, equals([7]));
    });

    test('date range with inverted start/end is re-ordered defensively', () {
      // Encode a JSON with ds > de to test the order-fix branch.
      final map = {
        'ds': DateTime(2026, 12, 31).toIso8601String(),
        'de': DateTime(2026, 1, 1).toIso8601String(),
      };
      final encoded = base64Url.encode(utf8.encode(jsonEncode(map)));
      final state = FilterCodec.decode(encoded);
      expect(state.dateRange, isNotNull);
      // start should be <= end after decode.
      expect(
        state.dateRange!.start.isBefore(state.dateRange!.end) ||
            state.dateRange!.start == state.dateRange!.end,
        isTrue,
      );
    });
  });
}

// Helper: add base64 padding.
String _pad(String s) {
  final rem = s.length % 4;
  if (rem == 0) return s;
  return s + ('=' * (4 - rem));
}
