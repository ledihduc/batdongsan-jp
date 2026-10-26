import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/data/models/heatmap_cell_model.dart';
import 'package:house_booking/features/host/analytics/providers/drill_provider.dart';
import 'package:house_booking/features/host/analytics/widgets/color_palette.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Shows a modal bottom sheet with detail for a tapped heatmap cell.
///
/// Data available from HeatmapCell: day, status.
/// Room-level data: roomName, buildingName.
///
/// Note: tenant name, contract ID, and invoice info are NOT in the heatmap
/// model (Phase 04 scope). Those would require a separate detail endpoint
/// (Phase 07). Currently shows status + room info only.
void showHeatmapCellDetail({
  required BuildContext context,
  required HeatmapRoomRow room,
  required HeatmapCell cell,
  required String monthLabel,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: HD.paperRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => HeatmapCellDetailSheet(
      room: room,
      cell: cell,
      monthLabel: monthLabel,
    ),
  );
}

/// Bottom sheet content for a heatmap cell tap.
class HeatmapCellDetailSheet extends StatelessWidget {
  const HeatmapCellDetailSheet({
    super.key,
    required this.room,
    required this.cell,
    required this.monthLabel,
  });

  final HeatmapRoomRow room;
  final HeatmapCell cell;
  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    final statusColor = OccupancyPalette.statusToColor(cell.status);
    final statusLabel = _statusLabel(cell.status);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(HD.s20, HD.s20, HD.s20, HD.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: HD.s16),
                decoration: BoxDecoration(
                  color: HD.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Room name + building
            Text(room.roomName, style: HD.bodyBold(size: 18)),
            const SizedBox(height: HD.s4),
            Text(room.buildingName, style: HD.caption()),
            const SizedBox(height: HD.s16),
            // Date + status row
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: HD.inkMuted),
                const SizedBox(width: HD.s8),
                Text('Ngày ${cell.day} $monthLabel', style: HD.body(size: 14)),
              ],
            ),
            const SizedBox(height: HD.s12),
            // Status chip
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HD.s12,
                    vertical: HD.s4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    border: Border.all(color: statusColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: HD.s8),
                      Text(statusLabel, style: HD.bodyBold(size: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: HD.s16),
            // Drill CTA — navigate to level 2 contracts for this room.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Close the bottom sheet first.
                  Navigator.of(context).pop();
                  // Push drill level 2 with this room.
                  context.read<DrillProvider>().pushLevel(
                    level: 2,
                    title: room.roomName,
                    params: {'roomId': room.roomId},
                  );
                  context.go(
                    '/host/analytics/drill/room/${room.roomId}/contracts',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: HD.ink,
                  foregroundColor: HD.paperRaised,
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Xem chi tiết phòng →'),
              ),
            ),
            const SizedBox(height: HD.s8),
            // Dismiss
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(HeatmapCellStatus status) {
    switch (status) {
      case HeatmapCellStatus.vacant:
        return 'Phòng trống';
      case HeatmapCellStatus.booked:
        return 'Đã đặt';
      case HeatmapCellStatus.paid:
        return 'Đã thanh toán';
      case HeatmapCellStatus.overdue:
        return 'Quá hạn';
    }
  }
}
