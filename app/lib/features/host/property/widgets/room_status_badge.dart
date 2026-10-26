import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';

/// Colored badge showing room status: vacant | occupied | maintenance.
class RoomStatusBadge extends StatelessWidget {
  final String status;

  const RoomStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon) = _config(status);
    return DsStatusPill(label: label, tone: tone, icon: icon, dense: true);
  }

  static (String, DsStatusTone, IconData) _config(String status) {
    switch (status) {
      case 'vacant':
        return ('Trống', DsStatusTone.positive, Icons.check_circle_outline);
      case 'occupied':
        return ('Đang thuê', DsStatusTone.accent, Icons.people_outline);
      case 'maintenance':
        return ('Đang sửa', DsStatusTone.warning, Icons.build_outlined);
      default:
        return (status, DsStatusTone.neutral, Icons.info_outline);
    }
  }
}
