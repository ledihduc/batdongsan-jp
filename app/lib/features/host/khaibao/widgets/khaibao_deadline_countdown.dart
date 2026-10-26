import 'dart:async';
import 'package:flutter/material.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Live "Còn Xh Ym" / "Quá hạn Xh" countdown text.
/// Ticks every 60s — cheap; no animation chain.
class KhaiBaoDeadlineCountdown extends StatefulWidget {
  final DateTime checkInAt;
  final int deadlineHours;

  const KhaiBaoDeadlineCountdown({
    super.key,
    required this.checkInAt,
    this.deadlineHours = 12,
  });

  @override
  State<KhaiBaoDeadlineCountdown> createState() =>
      _KhaiBaoDeadlineCountdownState();
}

class _KhaiBaoDeadlineCountdownState extends State<KhaiBaoDeadlineCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deadline =
        widget.checkInAt.add(Duration(hours: widget.deadlineHours));
    final diff = deadline.difference(DateTime.now());
    final isOverdue = diff.isNegative;
    final abs = diff.abs();
    final h = abs.inHours;
    final m = abs.inMinutes.remainder(60);
    final label = isOverdue ? 'Quá hạn ${h}h ${m}p' : 'Còn ${h}h ${m}p';
    final color = isOverdue ? HD.negative : HD.warning;
    return Text(label, style: HD.tabular(color: color, size: 12));
  }
}
