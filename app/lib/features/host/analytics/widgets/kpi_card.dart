import 'package:flutter/material.dart';
import 'package:house_booking/features/host/analytics/widgets/delta_chip.dart';
import 'package:house_booking/features/host/analytics/widgets/goal_progress_bar.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// A single KPI metric card.
///
/// Displays: label (eyebrow), value (tabular), [DeltaChip], optional tap
/// action, optional error indicator, optional goal progress bar (Gross only).
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.deltaPct,
    this.isDeltaPercentagePoint = false,
    this.onTap,
    this.hasError = false,
    this.goalProgress,
    this.goalRevenue,
    this.goalTarget,
  });

  /// Eyebrow label, e.g. "DOANH THU GỘP".
  final String label;

  /// Pre-formatted display value, e.g. "5 tr", "82.4%".
  final String value;

  /// Delta percentage for DeltaChip. Null = prior period was zero.
  final double? deltaPct;

  /// True when delta represents percentage-point (occupancy).
  final bool isDeltaPercentagePoint;

  /// Optional tap callback — used for drill-down (Phase 07).
  final VoidCallback? onTap;

  /// When true, shows a warning icon on the card (partial data error).
  final bool hasError;

  /// Optional goal progress bar (0.0–1.0 clamped). Shown only when non-null.
  final double? goalProgress;

  /// Current gross revenue (for GoalProgressBar label).
  final double? goalRevenue;

  /// Goal target revenue (for GoalProgressBar label).
  final double? goalTarget;

  @override
  Widget build(BuildContext context) {
    // Minimum tap target 44pt per a11y guidelines.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.fromLTRB(HD.s12, HD.s12, HD.s12, HD.s8),
        decoration: BoxDecoration(
          color: HD.paperRaised,
          border: Border.all(color: HD.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label row with optional error icon
            Row(
              children: [
                Expanded(
                  child: Text(label, style: HD.eyebrow()),
                ),
                if (hasError)
                  const Tooltip(
                    message: 'Không thể tải dữ liệu',
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: HD.warning,
                    ),
                  ),
                if (onTap != null && !hasError)
                  const Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: HD.inkMuted,
                  ),
              ],
            ),
            const SizedBox(height: HD.s4),
            // Value
            Text(
              value,
              style: HD.bigNumeral(size: 26),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: HD.s4),
            // Delta chip
            DeltaChip(
              deltaPct: deltaPct,
              isPercentagePoint: isDeltaPercentagePoint,
            ),
            // Optional goal progress bar
            if (goalProgress != null) ...[
              const SizedBox(height: HD.s8),
              GoalProgressBar(
                progress: goalProgress!,
                grossRevenue: goalRevenue,
                goalAmount: goalTarget,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
