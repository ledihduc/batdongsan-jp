import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/data/models/analytics_summary_model.dart';
import 'package:house_booking/features/host/analytics/services/period_helper.dart';
import 'package:house_booking/features/host/analytics/services/tz_helper.dart';
import 'package:house_booking/features/host/analytics/widgets/analytics_empty_state.dart';
import 'package:house_booking/features/host/analytics/widgets/analytics_error_state.dart';
import 'package:house_booking/features/host/analytics/widgets/analytics_skeleton.dart';
import 'package:house_booking/features/host/analytics/widgets/export_button.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/core/widgets/ds_app_bar.dart';
import 'package:house_booking/providers/report_provider.dart';
import 'package:house_booking/core/telemetry/telemetry_service.dart';

import 'analytics_kpi_cards.dart';
import 'analytics_filters_bar.dart';

/// Analytics home screen — 5 KPI cards + period swiper (AC-14 deep link).
///
/// Deep link: /host/analytics
/// Auth: covered by existing GoRouter redirect on /host* prefix.
class AnalyticsHomeScreen extends StatefulWidget {
  const AnalyticsHomeScreen({super.key});

  @override
  State<AnalyticsHomeScreen> createState() => _AnalyticsHomeScreenState();
}

class _AnalyticsHomeScreenState extends State<AnalyticsHomeScreen> {
  PeriodType _period = PeriodType.month;
  late DateTime _anchorDate;

  @override
  void initState() {
    super.initState();
    _anchorDate = TzHelper.hcmStartOfMonth(TzHelper.hcmNow());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      // Track analytics screen open (AC §11.2 #1 — BA Leader telemetry requirement).
      Provider.of<TelemetryService>(context, listen: false).track(
        'analytics_opened',
        props: {'period': _period == PeriodType.month ? 'month' : 'year'},
      );
    });
  }

  Future<void> _refresh({bool force = false}) async {
    if (!mounted) return;
    await context.read<ReportProvider>().fetchAnalyticsSummary(
          period: _period,
          date: _anchorDate,
          force: force,
        );
  }

  void _onShift(int delta) {
    setState(() {
      _anchorDate = PeriodHelper.shift(_period, _anchorDate, delta);
    });
    _refresh();
  }

  void _onTogglePeriod(PeriodType newPeriod) {
    if (newPeriod == _period) return;
    final now = TzHelper.hcmNow();
    setState(() {
      _period = newPeriod;
      _anchorDate = newPeriod == PeriodType.month
          ? TzHelper.hcmStartOfMonth(now)
          : DateTime(now.year, 1, 1);
    });
    _refresh();
  }

  /// Returns "YYYY-MM" string from [date], used for the export endpoint period param.
  static String _formatYearMonth(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

  DateTime get _currentPeriodStart {
    final now = TzHelper.hcmNow();
    return _period == PeriodType.month
        ? TzHelper.hcmStartOfMonth(now)
        : DateTime(now.year, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: 'Thống kê doanh thu',
        actions: [
          ExportButton(
            period: _formatYearMonth(_anchorDate),
          ),
          AnalyticsPeriodToggle(
            current: _period,
            onToggle: _onTogglePeriod,
          ),
          const SizedBox(width: HD.s8),
        ],
      ),
      body: Consumer<ReportProvider>(
        builder: (context, provider, _) {
          final isLoading = provider.summaryLoading;
          final error = provider.summaryError;
          final summary = provider.summary;

          // Loading: no cached data yet → show skeleton
          if (isLoading && summary == null) {
            return const AnalyticsSkeleton();
          }

          // Error: no cached data → show full error state
          if (error != null && summary == null) {
            return AnalyticsErrorState(
              message: error,
              onRetry: () => _refresh(force: true),
            );
          }

          // Build badge row once so both data and empty paths share it.
          final badges = AnalyticsStatusBadgeRow(
            offline: provider.offline,
            lastFetchAt: provider.lastSuccessfulFetchAt,
          );

          // Empty: data present but zero activity
          if (summary != null && _isEmpty(summary)) {
            return RefreshIndicator(
              color: HD.accent,
              onRefresh: () => _refresh(force: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    badges,
                    // Period header only (no swipe area needed on empty state)
                    AnalyticsPeriodHeaderBar(
                      period: _period,
                      anchorDate: _anchorDate,
                      currentPeriodStart: _currentPeriodStart,
                      onShift: _onShift,
                    ),
                    const AnalyticsEmptyState(),
                  ],
                ),
              ),
            );
          }

          // Data available
          if (summary != null) {
            return RefreshIndicator(
              color: HD.accent,
              onRefresh: () => _refresh(force: true),
              child: AnalyticsDataView(
                summary: summary,
                period: _period,
                anchorDate: _anchorDate,
                currentPeriodStart: _currentPeriodStart,
                onShift: _onShift,
                statusBadges: badges,
              ),
            );
          }

          // Fallback (shouldn't happen — covers loading with null summary first time)
          return const AnalyticsSkeleton();
        },
      ),
    );
  }

  bool _isEmpty(AnalyticsSummaryModel summary) =>
      summary.kpis.grossRevenue == 0 && summary.kpis.bookingPace == 0;
}
