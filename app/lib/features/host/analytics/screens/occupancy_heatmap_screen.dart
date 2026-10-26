import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/features/host/analytics/services/period_helper.dart';
import 'package:house_booking/features/host/analytics/services/tz_helper.dart';
import 'package:house_booking/core/widgets/ds_app_bar.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/providers/report_provider.dart';

import 'occupancy_heatmap_widgets.dart';
import 'occupancy_heatmap_grid_views.dart';

/// Threshold above which group-view is activated (AC-08).
const int _kGroupViewThreshold = 30;

/// Occupancy heatmap screen — room × day matrix.
///
/// Route: /host/analytics/heatmap
/// Features:
///   - Month picker + optional building filter
///   - InteractiveViewer for pinch + pan
///   - Virtualized via ListView.builder (vertical) + horizontal scroll per row
///   - Sticky first column with room names
///   - Auto group-view when rooms > [_kGroupViewThreshold] (AC-08)
///   - Tap cell → HeatmapCellDetailSheet (US-09)
class OccupancyHeatmapScreen extends StatefulWidget {
  const OccupancyHeatmapScreen({super.key});

  @override
  State<OccupancyHeatmapScreen> createState() => _OccupancyHeatmapScreenState();
}

class _OccupancyHeatmapScreenState extends State<OccupancyHeatmapScreen> {
  late DateTime _anchorDate;

  /// Vertical scroll controller — shared between grid ListView and sticky col.
  final ScrollController _verticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _anchorDate = TzHelper.hcmStartOfMonth(TzHelper.hcmNow());
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool force = false}) async {
    if (!mounted) return;
    await context.read<ReportProvider>().fetchHeatmap(
          month: _anchorDate,
          force: force,
        );
  }

  void _onMonthShift(int delta) {
    setState(() {
      _anchorDate = PeriodHelper.shift(PeriodType.month, _anchorDate, delta);
    });
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: 'Lịch occupancy',
        titleAsSerif: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _MonthBar(
            anchorDate: _anchorDate,
            onShift: _onMonthShift,
          ),
        ),
      ),
      body: Consumer<ReportProvider>(
        builder: (context, provider, _) {
          if (provider.heatmapLoading && provider.heatmap == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.heatmapError != null && provider.heatmap == null) {
            return HeatmapErrorView(
              message: provider.heatmapError!,
              onRetry: () => _fetch(force: true),
            );
          }
          if (provider.heatmap == null) {
            return const Center(
              child: Text('Chưa có dữ liệu', style: TextStyle(color: HD.inkMuted)),
            );
          }
          final heatmap = provider.heatmap!;
          final useGroupView = heatmap.rooms.length > _kGroupViewThreshold;

          return Column(
            children: [
              if (provider.heatmapLoading)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: useGroupView
                    ? HeatmapGroupView(
                        heatmap: heatmap,
                        anchorDate: _anchorDate,
                      )
                    : HeatmapGridView(
                        heatmap: heatmap,
                        anchorDate: _anchorDate,
                        verticalController: _verticalController,
                      ),
              ),
              const HeatmapLegend(),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MonthBar — month navigation header.
// ---------------------------------------------------------------------------

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.anchorDate, required this.onShift});

  final DateTime anchorDate;
  final void Function(int) onShift;

  bool get _isCurrentMonth {
    final now = TzHelper.hcmNow();
    return anchorDate.year == now.year && anchorDate.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HD.s8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Tháng trước',
            onPressed: () => onShift(-1),
            icon: const Icon(Icons.chevron_left),
            color: HD.ink,
            iconSize: 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          Expanded(
            child: Center(
              child: Text(
                PeriodHelper.displayLabel(PeriodType.month, anchorDate),
                style: HD.bodyBold(size: 14),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Tháng sau',
            onPressed: _isCurrentMonth ? null : () => onShift(1),
            icon: Icon(
              Icons.chevron_right,
              color: _isCurrentMonth ? HD.inkMuted : HD.ink,
            ),
            iconSize: 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }
}
