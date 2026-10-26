import 'dart:convert';

import 'package:flutter/material.dart' show DateTimeRange;

import 'package:house_booking/features/host/analytics/providers/drill_provider.dart';

/// Encodes/decodes [FilterState] to/from a URL-safe base64 JSON string.
///
/// Only non-default keys are included in the encoded output to minimise URL
/// length per the architecture spec.
///
/// Decoding is fully defensive — any malformed or partial input returns
/// [FilterState.empty()].
class FilterCodec {
  FilterCodec._();

  /// Encode [state] → compact base64(json) string.
  ///
  /// Empty filter encodes to empty string ''.
  static String encode(FilterState state) {
    if (state.isEmpty) return '';
    final map = <String, dynamic>{};
    if (state.buildingIds.isNotEmpty) {
      map['b'] = state.buildingIds;
    }
    if (state.sourceIds.isNotEmpty) {
      map['s'] = state.sourceIds;
    }
    if (state.dateRange != null) {
      map['ds'] = state.dateRange!.start.toIso8601String();
      map['de'] = state.dateRange!.end.toIso8601String();
    }
    if (state.roomType != null && state.roomType!.isNotEmpty) {
      map['rt'] = state.roomType;
    }
    if (map.isEmpty) return '';
    final json = jsonEncode(map);
    // base64Url produces URL-safe output (+/ → -_); no padding needed for URLs.
    return base64Url.encode(utf8.encode(json));
  }

  /// Decode [encoded] → [FilterState].
  ///
  /// Returns [FilterState.empty()] on any parse error (malformed base64,
  /// invalid JSON, wrong types, etc.).
  static FilterState decode(String encoded) {
    if (encoded.isEmpty) return const FilterState.empty();
    try {
      // Add padding if missing (base64Url requires multiple of 4 chars).
      final padded = _addPadding(encoded);
      final jsonBytes = base64Url.decode(padded);
      final jsonStr = utf8.decode(jsonBytes);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      final buildingIds = _parseIntList(map['b']);
      final sourceIds = _parseIntList(map['s']);
      final dateRangeStart = _parseDateTime(map['ds']);
      final dateRangeEnd = _parseDateTime(map['de']);
      final roomType = map['rt'] as String?;

      DateTimeRange? dateRange;
      if (dateRangeStart != null && dateRangeEnd != null) {
        // Ensure start <= end to avoid DateTimeRange assertion failure.
        final start = dateRangeStart.isBefore(dateRangeEnd)
            ? dateRangeStart
            : dateRangeEnd;
        final end = dateRangeStart.isBefore(dateRangeEnd)
            ? dateRangeEnd
            : dateRangeStart;
        dateRange = DateTimeRange(start: start, end: end);
      }

      return FilterState(
        buildingIds: buildingIds,
        sourceIds: sourceIds,
        dateRange: dateRange,
        roomType: roomType,
      );
    } catch (_) {
      // Any error → degrade gracefully to empty filter.
      return const FilterState.empty();
    }
  }

  static String _addPadding(String s) {
    final remainder = s.length % 4;
    if (remainder == 0) return s;
    return s + ('=' * (4 - remainder));
  }

  static List<int> _parseIntList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw.whereType<num>().map((n) => n.toInt()).toList();
    }
    return const [];
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}
