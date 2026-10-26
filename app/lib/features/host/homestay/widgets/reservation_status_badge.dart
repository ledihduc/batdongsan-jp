import 'package:flutter/material.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Phase 07 — reservation status pill matching HD editorial style.
class ReservationStatusBadge extends StatelessWidget {
  const ReservationStatusBadge({super.key, required this.status});

  final String status;

  ({String label, Color color}) get _config {
    switch (status) {
      case 'pending':
        return (label: 'Chờ duyệt', color: HD.warning);
      case 'approved':
        return (label: 'Đã duyệt', color: HD.positive);
      case 'rejected':
        return (label: 'Từ chối', color: HD.negative);
      case 'checked_in':
        return (label: 'Đã check-in', color: HD.accent);
      case 'checked_out':
        return (label: 'Đã trả phòng', color: HD.inkMuted);
      case 'cancelled':
        return (label: 'Đã hủy', color: HD.inkMuted);
      case 'no_show':
        return (label: 'Vắng mặt', color: HD.negative);
      default:
        return (label: status, color: HD.inkMuted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: cfg.color, width: 1),
        color: HD.paperRaised,
      ),
      child: Text(
        cfg.label.toUpperCase(),
        style: HD.eyebrow(color: cfg.color),
      ),
    );
  }
}
