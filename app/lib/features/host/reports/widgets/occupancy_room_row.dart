import 'package:flutter/material.dart';
import 'package:house_booking/data/models/occupancy_report_model.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// One row in the occupancy report table — building + room + status pill.
class OccupancyRoomRow extends StatelessWidget {
  final OccupancyRow row;

  const OccupancyRoomRow({super.key, required this.row});

  Color get _statusColor {
    switch (row.status) {
      case 'occupied':
        return HD.positive;
      case 'maintenance':
        return HD.warning;
      default:
        return HD.inkMuted;
    }
  }

  String get _statusLabel {
    switch (row.status) {
      case 'occupied':
        return 'ĐANG THUÊ';
      case 'maintenance':
        return 'BẢO TRÌ';
      default:
        return 'TRỐNG';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HD.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.roomCode, style: HD.bodyBold(size: 13)),
                const SizedBox(height: 2),
                Text(row.buildingName,
                    style: HD.caption(color: HD.inkMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              _statusLabel,
              style: HD.eyebrow(color: Colors.white).copyWith(fontSize: 9.5),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              '${row.occupiedPct.toStringAsFixed(0)}%',
              style: HD.tabular(size: 13),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
