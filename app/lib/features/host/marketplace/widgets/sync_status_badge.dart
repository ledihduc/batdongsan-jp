import 'package:flutter/material.dart';

import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Phase 08 — pill badge for marketplace sync state.
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key, required this.badge});

  /// One of: synced | out_of_sync | not_listed | pending | hidden.
  final String badge;

  ({String label, Color color, Color fg}) _spec() {
    switch (badge) {
      case 'synced':
        return (label: 'Đã đăng', color: HD.positive, fg: Colors.white);
      case 'out_of_sync':
        return (label: 'Lệch giá', color: HD.warning, fg: Colors.white);
      case 'pending':
        return (label: 'Chờ duyệt', color: HD.accent, fg: Colors.white);
      case 'hidden':
        return (label: 'Đã ẩn', color: HD.inkMuted, fg: Colors.white);
      case 'not_listed':
      default:
        return (label: 'Chưa đăng', color: HD.hairline, fg: HD.ink);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _spec();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: HD.s8, vertical: 3),
      decoration: BoxDecoration(color: s.color),
      child: Text(
        s.label.toUpperCase(),
        style: HD.eyebrow(color: s.fg).copyWith(fontSize: 10),
      ),
    );
  }
}
