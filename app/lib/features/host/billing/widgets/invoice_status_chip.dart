import 'package:flutter/material.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// InvoiceStatusChip — small colored badge matching backend status enum.
class InvoiceStatusChip extends StatelessWidget {
  final String status;
  const InvoiceStatusChip(this.status, {super.key});

  static const _labels = <String, String>{
    'draft': 'NHÁP',
    'sent': 'ĐÃ GỬI',
    'paid': 'ĐÃ THU',
    'overdue': 'QUÁ HẠN',
    'cancelled': 'ĐÃ HUỶ',
  };

  static Color _bg(String s) {
    switch (s) {
      case 'paid':
        return HD.positive;
      case 'overdue':
        return HD.negative;
      case 'cancelled':
        return HD.inkMuted;
      case 'sent':
        return HD.warning;
      default:
        return HD.hairline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = status == 'draft' ? HD.ink : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bg(status),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        _labels[status] ?? status.toUpperCase(),
        style: HD.eyebrow(color: fg).copyWith(fontSize: 10, letterSpacing: 1.0),
      ),
    );
  }
}
