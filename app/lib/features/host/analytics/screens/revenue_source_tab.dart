import 'package:flutter/material.dart';
import 'package:house_booking/features/host/analytics/services/period_helper.dart';
import 'package:house_booking/features/host/analytics/widgets/source_breakdown_chart.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/providers/report_provider.dart';

/// Source breakdown tab — embedded in RevenueTrendScreen's second tab.
///
/// Shows donut chart + legend for the currently selected period.
/// (Not a standalone screen — no separate route needed.)
class RevenueSourceTab extends StatelessWidget {
  const RevenueSourceTab({
    super.key,
    required this.provider,
    required this.period,
    required this.anchorDate,
    required this.onRetry,
  });

  final ReportProvider provider;
  final PeriodType period;
  final DateTime anchorDate;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isLoading = provider.sourceBreakdownLoading;
    final error = provider.sourceBreakdownError;
    final breakdown = provider.sourceBreakdown;

    if (isLoading && breakdown == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && breakdown == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(HD.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, style: HD.body(color: HD.negative), textAlign: TextAlign.center),
              const SizedBox(height: HD.s12),
              OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }

    if (breakdown == null) {
      return const Center(
        child: Text('Chưa có dữ liệu', style: TextStyle(color: HD.inkMuted)),
      );
    }

    return RefreshIndicator(
      color: HD.accent,
      onRefresh: () async => onRetry(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(HD.s16, HD.s16, HD.s16, HD.s56),
        children: [
          if (isLoading) const LinearProgressIndicator(minHeight: 2),
          Row(
            children: [
              Text(
                'Theo nguồn — ${PeriodHelper.displayLabel(period, anchorDate)}',
                style: HD.bodyBold(size: 13),
              ),
            ],
          ),
          const SizedBox(height: HD.s16),
          SourceBreakdownChart(model: breakdown),
        ],
      ),
    );
  }
}
