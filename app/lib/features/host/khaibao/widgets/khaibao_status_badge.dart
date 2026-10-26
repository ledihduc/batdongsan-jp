import 'package:flutter/material.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Small colored badge for KhaiBaoTamTru.status.
class KhaiBaoStatusBadge extends StatelessWidget {
  final String status;
  const KhaiBaoStatusBadge(this.status, {super.key});

  static const _labels = <String, String>{
    'pending': 'CHƯA KHAI',
    'declared': 'ĐÃ KHAI',
    'overdue': 'QUÁ HẠN',
    'skipped': 'BỎ QUA',
  };

  static Color _bg(String s) {
    switch (s) {
      case 'declared':
        return HD.positive;
      case 'overdue':
        return HD.negative;
      case 'skipped':
        return HD.inkMuted;
      default:
        return HD.warning; // pending
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bg(status),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        _labels[status] ?? status.toUpperCase(),
        style: HD
            .eyebrow(color: Colors.white)
            .copyWith(fontSize: 10, letterSpacing: 1.0),
      ),
    );
  }
}
