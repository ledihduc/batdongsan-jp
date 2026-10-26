import 'package:flutter/material.dart';
import 'package:house_booking/features/host/analytics/widgets/color_palette.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Width of the sticky room-name column (dp).
const double kRoomColWidth = 96;

/// Height of each room row (dp) — matches ListView.builder itemExtent for perf.
const double kRowHeight = 28;

/// Width of each day cell (dp).
const double kCellWidth = 28;

/// Height of the day header row (dp).
const double kHeaderHeight = 32;

// ---------------------------------------------------------------------------
// DayHeader — sticky day number row (1..N).
// ---------------------------------------------------------------------------

class HeatmapDayHeader extends StatelessWidget {
  const HeatmapDayHeader({super.key, required this.daysInMonth});

  final int daysInMonth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kHeaderHeight,
      child: Row(
        children: [
          // Corner cell
          Container(
            width: kRoomColWidth,
            height: kHeaderHeight,
            color: HD.hairline,
            alignment: Alignment.center,
            child: Text(
              'Phòng',
              style: HD.caption(color: HD.inkSoft).copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
          // Day labels
          ...List.generate(daysInMonth, (i) => SizedBox(
                width: kCellWidth,
                height: kHeaderHeight,
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: HD.caption().copyWith(fontSize: 9),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Legend — color key bar at the bottom.
// ---------------------------------------------------------------------------

class HeatmapLegend extends StatelessWidget {
  const HeatmapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: HD.paperRaised,
        padding: const EdgeInsets.symmetric(horizontal: HD.s12, vertical: HD.s8),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _LegendChip(color: OccupancyPalette.vacant, label: 'Trống', bordered: true),
            _LegendChip(color: OccupancyPalette.booked, label: 'Đã đặt'),
            _LegendChip(color: OccupancyPalette.paid, label: 'Đã trả'),
            _LegendChip(color: OccupancyPalette.overdue, label: 'Quá hạn'),
          ],
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.label,
    this.bordered = false,
  });

  final Color color;
  final String label;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            border: bordered ? Border.all(color: HD.hairline) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: HD.caption()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ErrorView — inline error state.
// ---------------------------------------------------------------------------

class HeatmapErrorView extends StatelessWidget {
  const HeatmapErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HD.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                style: HD.body(color: HD.negative),
                textAlign: TextAlign.center),
            const SizedBox(height: HD.s12),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
