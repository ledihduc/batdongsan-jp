import 'package:flutter/material.dart';
import 'package:house_booking/data/models/heatmap_cell_model.dart';
import 'package:house_booking/features/host/analytics/widgets/color_palette.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Aggregated group row for a building when room count > 30.
///
/// Shows building name + average occupancy percentage.
/// Tap to expand → callback to host screen which shows a filtered modal.
class HeatmapGroupRow extends StatelessWidget {
  const HeatmapGroupRow({
    super.key,
    required this.buildingName,
    required this.rooms,
    required this.daysInMonth,
    required this.onExpand,
    this.rowHeight = 44.0,
  });

  final String buildingName;
  final List<HeatmapRoomRow> rooms;
  final int daysInMonth;
  final VoidCallback onExpand;

  /// Row height — 44pt for a11y tap target per AC-08 groupRow requirement.
  final double rowHeight;

  /// Compute average occupancy % across all rooms.
  double get _avgOccupancyPct {
    if (rooms.isEmpty || daysInMonth == 0) return 0;
    int totalOccupied = 0;
    int totalCells = 0;
    for (final room in rooms) {
      totalOccupied += room.cells
          .where((c) => c.status != HeatmapCellStatus.vacant)
          .length;
      totalCells += daysInMonth;
    }
    return totalCells == 0 ? 0 : (totalOccupied / totalCells) * 100;
  }

  /// Color representing average occupancy (range: vacant → paid).
  Color get _avgColor {
    final pct = _avgOccupancyPct;
    if (pct >= 80) return OccupancyPalette.paid;
    if (pct >= 40) return OccupancyPalette.booked;
    return OccupancyPalette.vacant;
  }

  @override
  Widget build(BuildContext context) {
    final pct = _avgOccupancyPct;

    return Semantics(
      label: '$buildingName — ${pct.toStringAsFixed(0)}% đã đặt. Nhấn để xem chi tiết.',
      button: true,
      child: GestureDetector(
        onTap: onExpand,
        child: Container(
          height: rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: HD.s12),
          decoration: BoxDecoration(
            color: HD.paperRaised,
            border: Border(
              bottom: BorderSide(color: HD.hairline),
            ),
          ),
          child: Row(
            children: [
              // Color swatch showing avg occupancy
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _avgColor,
                  border: Border.all(color: HD.hairline),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: HD.s8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(buildingName, style: HD.bodyBold(size: 13)),
                    Text(
                      '${rooms.length} phòng · ${pct.toStringAsFixed(0)}% lấp đầy',
                      style: HD.caption(),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: HD.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
