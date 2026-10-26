import 'package:flutter/material.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// VN-style money text — 1.234.567 đ, sign-aware.
class VndText extends StatelessWidget {
  final double amount;
  final TextStyle? style;
  final bool showCurrency;

  const VndText(this.amount,
      {super.key, this.style, this.showCurrency = true});

  static String format(double v) {
    final s = v.abs().toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    final sign = v < 0 ? '-' : '';
    return '$sign${buf.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final txt = showCurrency ? '${format(amount)} đ' : format(amount);
    return Text(txt, style: style ?? HD.tabular(color: HD.ink));
  }
}
