import 'package:flutter/material.dart';
import '../host_dashboard_tokens.dart';

/// Editorial status badge — thin rectangle, no glow, no rounded blobs.
/// Reads like a stamp on a paper document.
class HDStatusPill extends StatelessWidget {
  const HDStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.dot = true,
  });

  final String label;
  final Color color;
  final bool dot;

  /// Factory for house status strings used across the codebase.
  factory HDStatusPill.house(String status) {
    switch (status) {
      case 'approved':
        return HDStatusPill(label: 'Đang đăng', color: HD.positive);
      case 'pending':
        return HDStatusPill(label: 'Chờ admin duyệt', color: HD.warning);
      case 'rejected':
        return HDStatusPill(label: 'Bị từ chối', color: HD.negative);
      default:
        return HDStatusPill(label: status, color: HD.inkMuted);
    }
  }

  factory HDStatusPill.appointment(String status) {
    switch (status) {
      case 'pending':
        return HDStatusPill(label: 'Chờ duyệt', color: HD.warning);
      case 'doi_gio':
        return HDStatusPill(label: 'Chờ khách chọn giờ', color: HD.svcAmber);
      case 'approved':
        return HDStatusPill(label: 'Đã duyệt', color: HD.positive);
      case 'rejected':
        return HDStatusPill(label: 'Từ chối', color: HD.negative);
      case 'cancelled':
        return HDStatusPill(label: 'Đã hủy', color: HD.inkMuted);
      case 'completed':
        return HDStatusPill(label: 'Đã xem phòng', color: HD.accent);
      case 'awaiting_guest':
        return HDStatusPill(label: 'Chờ khách xác nhận', color: HD.warning);
      case 'locked':
        return HDStatusPill(label: 'Đã chốt', color: HD.positive);
      case 'lost':
        return HDStatusPill(label: 'Đã có người chốt', color: HD.negative);
      default:
        return HDStatusPill(label: status, color: HD.inkMuted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 5, height: 5, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: HD
                .eyebrow(color: color)
                .copyWith(fontSize: 9.5, letterSpacing: 1.0),
          ),
        ],
      ),
    );
  }
}
