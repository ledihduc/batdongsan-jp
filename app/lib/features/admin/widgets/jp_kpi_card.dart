/// JP KPI card widget — wraps DsKpiCard with JP-specific delta tone logic.
///
/// Used in JpKpiDashboardScreen to display 5 metrics.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/admin_kpi.dart';

class JpKpiCard extends StatelessWidget {
  const JpKpiCard({
    super.key,
    required this.label,
    required this.metric,
    required this.icon,
  });

  final String label;
  final KpiMetric metric;
  final IconData icon;

  DsStatusTone get _tone {
    final positive = metric.deltaPositive;
    if (positive == null) return DsStatusTone.neutral;
    return positive ? DsStatusTone.positive : DsStatusTone.negative;
  }

  @override
  Widget build(BuildContext context) {
    return DsKpiCard(
      label: label,
      value: metric.value,
      unit: metric.unit,
      delta: metric.delta,
      deltaTone: _tone,
      subtitle: metric.subtitle,
      icon: icon,
    );
  }
}
