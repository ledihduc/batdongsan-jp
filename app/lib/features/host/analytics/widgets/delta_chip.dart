import 'package:flutter/material.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Displays a period-over-period delta percentage.
///
/// AC-02 rules:
/// - null (prior = 0) → muted chip "—"
/// - > 0  → green up arrow + "+X.X%"
/// - < 0  → red down arrow + "X.X%"
/// - 0.0  → muted "0.0%"
class DeltaChip extends StatelessWidget {
  const DeltaChip({
    super.key,
    required this.deltaPct,
    this.isPercentagePoint = false,
  });

  /// The delta percentage value. Null when prior period = 0.
  final double? deltaPct;

  /// When true, appends "pp" suffix instead of "%" to distinguish
  /// percentage-point differences (e.g. occupancy).
  final bool isPercentagePoint;

  @override
  Widget build(BuildContext context) {
    final delta = deltaPct;
    if (delta == null) {
      return _buildChip(
        label: '—',
        color: HD.inkMuted,
        icon: null,
      );
    }
    if (delta > 0) {
      final suffix = isPercentagePoint ? 'pp' : '%';
      return _buildChip(
        label: '+${delta.toStringAsFixed(1)}$suffix',
        color: HD.positive,
        icon: Icons.arrow_upward,
      );
    }
    if (delta < 0) {
      final suffix = isPercentagePoint ? 'pp' : '%';
      return _buildChip(
        label: '${delta.toStringAsFixed(1)}$suffix',
        color: HD.negative,
        icon: Icons.arrow_downward,
      );
    }
    // delta == 0
    final suffix = isPercentagePoint ? 'pp' : '%';
    return _buildChip(
      label: '0.0$suffix',
      color: HD.inkMuted,
      icon: null,
    );
  }

  Widget _buildChip({
    required String label,
    required Color color,
    required IconData? icon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 2),
        ],
        Text(
          label,
          style: HD.caption(color: color).copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
