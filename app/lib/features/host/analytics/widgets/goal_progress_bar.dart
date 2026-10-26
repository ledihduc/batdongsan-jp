import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:house_booking/features/host/analytics/services/currency_formatter.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Linear goal progress bar for the Gross Revenue KPI card (AC-18).
///
/// When [progress] is provided, shows:
/// - Linear progress indicator (0.0–1.0, clamped)
/// - Label: "X% mục tiêu"
///
/// When goal is not set (goalAmount null passed from parent with progress=0.0),
/// caller should NOT pass this widget — instead use null goalProgress in KpiCard
/// and let the parent handle the CTA rendering.
///
/// Note: GoalCTA "Đặt mục tiêu" navigates to /host/settings if it exists;
/// otherwise shows a SnackBar. Route /host/settings is stubbed here for
/// Phase 10 Settings implementation gap — tracked as tech debt.
class GoalProgressBar extends StatelessWidget {
  const GoalProgressBar({
    super.key,
    required this.progress,
    this.grossRevenue,
    this.goalAmount,
  });

  /// Progress value 0.0–1.0 (caller must clamp).
  final double progress;

  /// Optional: current gross for label display.
  final double? grossRevenue;

  /// Optional: goal amount for label display.
  final double? goalAmount;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).clamp(0.0, 100.0);
    final label = CurrencyFormatter.formatPct(pct, decimals: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: HD.hairline,
            valueColor: const AlwaysStoppedAnimation<Color>(HD.accent),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: HD.s4),
        Row(
          children: [
            Text(
              '$label mục tiêu',
              style: HD.caption(color: HD.inkSoft),
            ),
            if (goalAmount != null) ...[
              const Spacer(),
              Text(
                CurrencyFormatter.format(goalAmount!, abbreviated: true),
                style: HD.caption(color: HD.inkMuted),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Fallback CTA when no goal is set.
///
/// Shown inline in the Gross KPI card slot when monthlyRevenueGoal is null.
/// Navigates to /host/settings (Phase 10 gap — see GoalProgressBar doc above).
class GoalSetCta extends StatelessWidget {
  const GoalSetCta({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flag_outlined, size: 12, color: HD.accent),
          const SizedBox(width: HD.s4),
          Text(
            'Đặt mục tiêu',
            style: HD.caption(color: HD.accent).copyWith(
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }

  void _onTap(BuildContext context) {
    // Phase 10 gap: /host/settings does not exist yet.
    // TECH DEBT: Replace SnackBar with GoRouter.of(context).go('/host/settings')
    // once Phase 10 Settings screen is implemented.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tính năng Settings goal sẽ có trong bản tới'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Keep for Phase 10 — activate when route exists.
  // ignore: unused_element
  void _navigateToSettings(BuildContext context) {
    GoRouter.of(context).go('/host/settings');
  }
}
