import 'package:flutter/material.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Phase 07 — VND price formatted with serif numeral + small caption.
class PriceTag extends StatelessWidget {
  const PriceTag({
    super.key,
    required this.amount,
    this.caption,
    this.size = 28,
  });

  final double amount;
  final String? caption;
  final double size;

  String _format(double v) {
    if (v >= 1_000_000) {
      final m = v / 1_000_000;
      return m % 1 == 0 ? '${m.toStringAsFixed(0)}M' : '${m.toStringAsFixed(1)}M';
    }
    if (v >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (caption != null) Text(caption!.toUpperCase(), style: HD.eyebrow()),
        Text(_format(amount), style: HD.bigNumeral(size: size)),
        Text('VND / đêm', style: HD.caption()),
      ],
    );
  }
}
