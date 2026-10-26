import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/data/models/analytics_summary_model.dart';
import 'package:house_booking/features/host/analytics/services/currency_formatter.dart';
import 'package:house_booking/features/host/analytics/services/period_helper.dart';
import 'package:house_booking/features/host/analytics/widgets/goal_progress_bar.dart';
import 'package:house_booking/features/host/analytics/widgets/kpi_card.dart';
import 'package:house_booking/features/host/analytics/widgets/period_swiper.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/analytics/providers/drill_provider.dart';
import 'package:house_booking/providers/host_profile_provider.dart';
import 'package:house_booking/core/telemetry/telemetry_service.dart';

// ---------------------------------------------------------------------------
// Data view — rendered when summary is available.
// ---------------------------------------------------------------------------

class AnalyticsDataView extends StatelessWidget {
  const AnalyticsDataView({
    super.key,
    required this.summary,
    required this.period,
    required this.anchorDate,
    required this.currentPeriodStart,
    required this.onShift,
    required this.statusBadges,
  });

  final AnalyticsSummaryModel summary;
  final PeriodType period;
  final DateTime anchorDate;
  final DateTime currentPeriodStart;
  final void Function(int) onShift;
  final Widget statusBadges;

  @override
  Widget build(BuildContext context) {
    final kpis = summary.kpis;
    final deltas = summary.deltas;
    final goal = context.read<HostProfileProvider>().profile?.monthlyRevenueGoal;

    // Compute goal progress for Gross card (AC-18)
    double? goalProgress;
    if (goal != null && goal > 0) {
      goalProgress = (kpis.grossRevenue / goal).clamp(0.0, 1.0);
    }

    return PeriodSwiper(
      period: period,
      anchorDate: anchorDate,
      currentPeriodStart: currentPeriodStart,
      onShift: onShift,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          HD.s12, HD.s4, HD.s12, HD.s56,
        ),
        children: [
          statusBadges,
          AnalyticsKpiGrid(
            kpis: kpis,
            deltas: deltas,
            goalProgress: goalProgress,
            goal: goal,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KPI grid — 2-column layout.
// ---------------------------------------------------------------------------

class AnalyticsKpiGrid extends StatelessWidget {
  const AnalyticsKpiGrid({
    super.key,
    required this.kpis,
    required this.deltas,
    this.goalProgress,
    this.goal,
  });

  final KpiBlock kpis;
  final DeltaBlock deltas;
  final double? goalProgress;
  final double? goal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Row 1: Gross + Net
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: KpiCard(
                key: const Key('kpi_gross'),
                label: 'DOANH THU GỘP',
                value: CurrencyFormatter.format(
                  kpis.grossRevenue,
                  abbreviated: true,
                ),
                deltaPct: deltas.grossRevenuePct,
                goalProgress: goalProgress,
                goalRevenue: kpis.grossRevenue,
                goalTarget: goal,
                // Phase 06: wire tap → trend screen (gross mode)
                onTap: () {
                  Provider.of<TelemetryService>(context, listen: false)
                      .track('kpi_drilled', props: {'kpi': 'gross'});
                  context.go('/host/analytics/trend');
                },
              ),
            ),
            const SizedBox(width: HD.s8),
            Expanded(
              child: KpiCard(
                key: const Key('kpi_net'),
                label: 'DOANH THU THỰC',
                value: CurrencyFormatter.format(
                  kpis.netRevenue,
                  abbreviated: true,
                ),
                deltaPct: deltas.netRevenuePct,
                onTap: () {
                  Provider.of<TelemetryService>(context, listen: false)
                      .track('kpi_drilled', props: {'kpi': 'net'});
                  context.read<DrillProvider>().reset();
                  context.go('/host/analytics/drill/rooms');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: HD.s8),
        // Row 2: Occupancy + ADR
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: KpiCard(
                key: const Key('kpi_occupancy'),
                label: 'TỶ LỆ LẤP ĐẦY',
                value: CurrencyFormatter.formatPct(kpis.occupancyPct),
                deltaPct: deltas.occupancyPctDiff,
                isDeltaPercentagePoint: true,
                // Phase 06: wire tap → heatmap screen
                onTap: () {
                  Provider.of<TelemetryService>(context, listen: false)
                      .track('kpi_drilled', props: {'kpi': 'occupancy'});
                  context.go('/host/analytics/heatmap');
                },
              ),
            ),
            const SizedBox(width: HD.s8),
            Expanded(
              child: KpiCard(
                key: const Key('kpi_adr'),
                label: 'ADR',
                value: CurrencyFormatter.format(kpis.adr, abbreviated: true),
                onTap: () {
                  Provider.of<TelemetryService>(context, listen: false)
                      .track('kpi_drilled', props: {'kpi': 'adr'});
                  context.read<DrillProvider>().reset();
                  context.go('/host/analytics/drill/rooms');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: HD.s8),
        // Row 3: Booking Pace (full width)
        KpiCard(
          key: const Key('kpi_booking_pace'),
          label: 'ĐẶT PHÒNG MỚI',
          value: kpis.bookingPace.toString(),
          onTap: () {
            Provider.of<TelemetryService>(context, listen: false)
                .track('kpi_drilled', props: {'kpi': 'delta'});
            context.read<DrillProvider>().reset();
            context.go('/host/analytics/drill/rooms');
          },
        ),
        // Goal CTA when no goal set (shown below booking pace)
        if (goalProgress == null) ...[
          const SizedBox(height: HD.s8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HD.s4),
            child: Row(
              children: [
                const GoalSetCta(),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
