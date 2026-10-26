import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/features/host/analytics/screens/revenue_source_tab.dart';
import 'package:house_booking/features/host/analytics/services/period_helper.dart';
import 'package:house_booking/features/host/analytics/services/tz_helper.dart';
import 'package:house_booking/features/host/analytics/widgets/trend_chart.dart';
import 'package:house_booking/core/widgets/ds_app_bar.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/providers/report_provider.dart';

/// Revenue trend screen — dual-line chart (current vs prior period).
///
/// Route: /host/analytics/trend
/// Features:
///   - Toggle Gross / Net (AC-04, US-10)
///   - Toggle Month / Year period
///   - Source breakdown donut embedded in second tab (US-06)
class RevenueTrendScreen extends StatefulWidget {
  const RevenueTrendScreen({super.key});

  @override
  State<RevenueTrendScreen> createState() => _RevenueTrendScreenState();
}

class _RevenueTrendScreenState extends State<RevenueTrendScreen>
    with SingleTickerProviderStateMixin {
  PeriodType _period = PeriodType.month;
  bool _showNet = false;
  late DateTime _anchorDate;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _anchorDate = TzHelper.hcmStartOfMonth(TzHelper.hcmNow());
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool force = false}) async {
    if (!mounted) return;
    final provider = context.read<ReportProvider>();
    await Future.wait([
      provider.fetchTrend(period: _period, anchor: _anchorDate, force: force),
      provider.fetchSourceBreakdown(
        period: _period,
        date: _anchorDate,
        force: force,
      ),
    ]);
  }

  void _onPeriodToggle(PeriodType newPeriod) {
    if (newPeriod == _period) return;
    final now = TzHelper.hcmNow();
    setState(() {
      _period = newPeriod;
      _anchorDate = newPeriod == PeriodType.month
          ? TzHelper.hcmStartOfMonth(now)
          : DateTime(now.year, 1, 1);
    });
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: 'Doanh thu theo thời gian',
        titleAsSerif: true,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: HD.bodyBold(size: 13),
          unselectedLabelStyle: HD.body(size: 13),
          labelColor: HD.ink,
          unselectedLabelColor: HD.inkMuted,
          indicatorColor: HD.accent,
          indicatorWeight: 2,
          tabs: const [
            Tab(text: 'Xu hướng'),
            Tab(text: 'Theo nguồn'),
          ],
        ),
      ),
      body: Consumer<ReportProvider>(
        builder: (context, provider, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _TrendTab(
                provider: provider,
                period: _period,
                showNet: _showNet,
                anchorDate: _anchorDate,
                onNetToggle: (v) => setState(() => _showNet = v),
                onPeriodToggle: _onPeriodToggle,
                onRetry: () => _fetch(force: true),
              ),
              RevenueSourceTab(
                provider: provider,
                period: _period,
                anchorDate: _anchorDate,
                onRetry: () => _fetch(force: true),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trend tab — chart + controls.
// ---------------------------------------------------------------------------

class _TrendTab extends StatelessWidget {
  const _TrendTab({
    required this.provider,
    required this.period,
    required this.showNet,
    required this.anchorDate,
    required this.onNetToggle,
    required this.onPeriodToggle,
    required this.onRetry,
  });

  final ReportProvider provider;
  final PeriodType period;
  final bool showNet;
  final DateTime anchorDate;
  final ValueChanged<bool> onNetToggle;
  final ValueChanged<PeriodType> onPeriodToggle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isLoading = provider.trendLoading;
    final error = provider.trendError;
    final trend = provider.trend;

    // Loading: no cached data
    if (isLoading && trend == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error: no cached data
    if (error != null && trend == null) {
      return _ErrorView(message: error, onRetry: onRetry);
    }

    if (trend == null) {
      return const Center(
        child: Text('Chưa có dữ liệu', style: TextStyle(color: HD.inkMuted)),
      );
    }

    return RefreshIndicator(
      color: HD.accent,
      onRefresh: () async => onRetry(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s16, HD.s56),
        children: [
          // Stale loading indicator
          if (isLoading)
            const LinearProgressIndicator(minHeight: 2),
          // Period + gross/net toggles
          _Controls(
            period: period,
            showNet: showNet,
            onNetToggle: onNetToggle,
            onPeriodToggle: onPeriodToggle,
          ),
          const SizedBox(height: HD.s16),
          // Chart card
          Container(
            height: 260,
            padding: const EdgeInsets.fromLTRB(HD.s4, HD.s12, HD.s12, HD.s8),
            decoration: BoxDecoration(
              color: HD.paperRaised,
              border: Border.all(color: HD.hairline),
            ),
            child: TrendChart(
              model: trend,
              showNet: showNet,
              period: period,
            ),
          ),
          const SizedBox(height: HD.s12),
          TrendChartLegend(showNet: showNet),
          const SizedBox(height: HD.s20),
          // Period label
          Center(
            child: Text(
              PeriodHelper.displayLabel(period, anchorDate),
              style: HD.caption(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Controls row — period type + gross/net segmented buttons.
// ---------------------------------------------------------------------------

class _Controls extends StatelessWidget {
  const _Controls({
    required this.period,
    required this.showNet,
    required this.onNetToggle,
    required this.onPeriodToggle,
  });

  final PeriodType period;
  final bool showNet;
  final ValueChanged<bool> onNetToggle;
  final ValueChanged<PeriodType> onPeriodToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Period type
        _SegmentGroup<PeriodType>(
          value: period,
          options: const [
            (PeriodType.month, 'Tháng'),
            (PeriodType.year, 'Năm'),
          ],
          onChanged: onPeriodToggle,
        ),
        const Spacer(),
        // Gross / Net
        _SegmentGroup<bool>(
          value: showNet,
          options: const [
            (false, 'Gộp'),
            (true, 'Thực'),
          ],
          onChanged: onNetToggle,
        ),
      ],
    );
  }
}

class _SegmentGroup<T> extends StatelessWidget {
  const _SegmentGroup({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((opt) {
        final isActive = opt.$1 == value;
        return GestureDetector(
          onTap: () => onChanged(opt.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: HD.s12, vertical: HD.s4),
            decoration: BoxDecoration(
              color: isActive ? HD.ink : HD.paperRaised,
              border: Border.all(color: isActive ? HD.ink : HD.hairline),
              borderRadius: options.indexOf(opt) == 0
                  ? const BorderRadius.horizontal(left: Radius.circular(2))
                  : const BorderRadius.horizontal(right: Radius.circular(2)),
            ),
            child: Text(
              opt.$2,
              style: HD.caption(color: isActive ? HD.paperRaised : HD.inkSoft)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Error view (inline, not full screen).
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HD.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: HD.body(color: HD.negative), textAlign: TextAlign.center),
            const SizedBox(height: HD.s12),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
