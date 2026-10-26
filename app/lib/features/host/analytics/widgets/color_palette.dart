import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:house_booking/data/models/heatmap_cell_model.dart';
import 'package:house_booking/core/widgets/ds.dart';

/// Color-blind safe palette for occupancy heatmap cells.
///
/// Palette design:
/// - Uses color + pattern to distinguish all 4 states (WCAG 1.4.1)
/// - "Overdue" uses diagonal stripe pattern (visible in greyscale)
/// - Color values match Phase 00 wireframe spec
class OccupancyPalette {
  OccupancyPalette._();

  // ── Cell background colors ─────────────────────────────────────────────────

  /// Vacant — very light grey / white
  static const Color vacant = Color(0xFFFFFFFF);

  /// Booked — light blue
  static const Color booked = Color(0xFFE3F2FD);

  /// Paid / checked-in — dark blue
  static const Color paid = Color(0xFF42A5F5);

  /// Overdue — red base (stripe overlay added via painter)
  static const Color overdue = Color(0xFFE57373);

  /// Cell border colour
  static const Color cellBorder = HD.hairline;

  // ── A11y pattern characters (color-blind fallback) ─────────────────────────

  /// A11y characters for greyscale/color-blind users.
  static const Map<HeatmapCellStatus, String> patternChar = {
    HeatmapCellStatus.vacant: '',
    HeatmapCellStatus.booked: '/',
    HeatmapCellStatus.paid: '+',
    HeatmapCellStatus.overdue: '!',
  };

  // ── Main API ───────────────────────────────────────────────────────────────

  /// Returns the background color for [status].
  static Color statusToColor(HeatmapCellStatus status) {
    switch (status) {
      case HeatmapCellStatus.vacant:
        return vacant;
      case HeatmapCellStatus.booked:
        return booked;
      case HeatmapCellStatus.paid:
        return paid;
      case HeatmapCellStatus.overdue:
        return overdue;
    }
  }

  /// Returns the a11y character overlay for [status].
  static String statusToChar(HeatmapCellStatus status) =>
      patternChar[status] ?? '';

  /// True when this status requires a stripe overlay (greyscale visible).
  static bool needsStripe(HeatmapCellStatus status) =>
      status == HeatmapCellStatus.overdue;

  /// Returns a [CustomPainter] that draws diagonal stripes for overdue cells.
  /// For other statuses returns null (no overlay needed).
  static CustomPainter? stripePainterFor(HeatmapCellStatus status) {
    if (!needsStripe(status)) return null;
    return const _DiagonalStripePainter();
  }

  /// Accessible semantic label for a cell.
  static String semanticsLabel(String roomName, int day, HeatmapCellStatus status) {
    final stateLabel = _stateLabel(status);
    return '$roomName ngày $day: $stateLabel';
  }

  static String _stateLabel(HeatmapCellStatus status) {
    switch (status) {
      case HeatmapCellStatus.vacant:
        return 'trống';
      case HeatmapCellStatus.booked:
        return 'đã đặt';
      case HeatmapCellStatus.paid:
        return 'đã thanh toán';
      case HeatmapCellStatus.overdue:
        return 'quá hạn';
    }
  }
}

// ---------------------------------------------------------------------------
// _DiagonalStripePainter — diagonal white stripe overlay for overdue cells.
// Stripes remain distinguishable in greyscale screenshots (AC-08).
// ---------------------------------------------------------------------------

class _DiagonalStripePainter extends CustomPainter {
  const _DiagonalStripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const stripeWidth = 2.0;
    const stripeGap = 5.0;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = stripeWidth
      ..style = PaintingStyle.stroke;

    // Draw diagonal lines from top-left to bottom-right
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    final count = (diagonal / (stripeWidth + stripeGap)).ceil() + 2;

    for (int i = -count; i <= count; i++) {
      final offset = i * (stripeWidth + stripeGap);
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
