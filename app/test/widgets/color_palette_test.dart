/// Unit tests for OccupancyPalette color mapping.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/heatmap_cell_model.dart';
import 'package:house_booking/features/host/analytics/widgets/color_palette.dart';

void main() {
  group('OccupancyPalette.statusToColor', () {
    test('vacant → white (#FFFFFF)', () {
      expect(
        OccupancyPalette.statusToColor(HeatmapCellStatus.vacant),
        equals(const Color(0xFFFFFFFF)),
      );
    });

    test('booked → light blue (#E3F2FD)', () {
      expect(
        OccupancyPalette.statusToColor(HeatmapCellStatus.booked),
        equals(const Color(0xFFE3F2FD)),
      );
    });

    test('paid → dark blue (#42A5F5)', () {
      expect(
        OccupancyPalette.statusToColor(HeatmapCellStatus.paid),
        equals(const Color(0xFF42A5F5)),
      );
    });

    test('overdue → red (#E57373)', () {
      expect(
        OccupancyPalette.statusToColor(HeatmapCellStatus.overdue),
        equals(const Color(0xFFE57373)),
      );
    });
  });

  group('OccupancyPalette.statusToChar', () {
    test('vacant → empty string', () {
      expect(OccupancyPalette.statusToChar(HeatmapCellStatus.vacant), equals(''));
    });

    test('booked → "/"', () {
      expect(OccupancyPalette.statusToChar(HeatmapCellStatus.booked), equals('/'));
    });

    test('paid → "+"', () {
      expect(OccupancyPalette.statusToChar(HeatmapCellStatus.paid), equals('+'));
    });

    test('overdue → "!"', () {
      expect(OccupancyPalette.statusToChar(HeatmapCellStatus.overdue), equals('!'));
    });
  });

  group('OccupancyPalette.needsStripe', () {
    test('only overdue needs stripe', () {
      expect(OccupancyPalette.needsStripe(HeatmapCellStatus.overdue), isTrue);
      expect(OccupancyPalette.needsStripe(HeatmapCellStatus.vacant), isFalse);
      expect(OccupancyPalette.needsStripe(HeatmapCellStatus.booked), isFalse);
      expect(OccupancyPalette.needsStripe(HeatmapCellStatus.paid), isFalse);
    });
  });

  group('OccupancyPalette.stripePainterFor', () {
    test('overdue → returns non-null painter', () {
      expect(
        OccupancyPalette.stripePainterFor(HeatmapCellStatus.overdue),
        isNotNull,
      );
    });

    test('non-overdue → returns null', () {
      expect(
        OccupancyPalette.stripePainterFor(HeatmapCellStatus.vacant),
        isNull,
      );
      expect(
        OccupancyPalette.stripePainterFor(HeatmapCellStatus.booked),
        isNull,
      );
      expect(
        OccupancyPalette.stripePainterFor(HeatmapCellStatus.paid),
        isNull,
      );
    });
  });

  group('OccupancyPalette.semanticsLabel', () {
    test('returns readable Vietnamese label with room, day, status', () {
      final label = OccupancyPalette.semanticsLabel('P.101', 5, HeatmapCellStatus.booked);
      expect(label, contains('P.101'));
      expect(label, contains('5'));
      expect(label, contains('đã đặt'));
    });

    test('overdue status → quá hạn label', () {
      final label = OccupancyPalette.semanticsLabel('P.202', 15, HeatmapCellStatus.overdue);
      expect(label, contains('quá hạn'));
    });
  });
}
