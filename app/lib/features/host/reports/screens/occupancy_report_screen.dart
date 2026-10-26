import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/reports/widgets/occupancy_room_row.dart';
import 'package:house_booking/providers/report_provider.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Occupancy tab — month picker + average gauge + per-room status list.
class OccupancyReportScreen extends StatefulWidget {
  const OccupancyReportScreen({super.key});

  @override
  State<OccupancyReportScreen> createState() => _OccupancyReportScreenState();
}

class _OccupancyReportScreenState extends State<OccupancyReportScreen>
    with AutomaticKeepAliveClientMixin {
  late String _month;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    await context.read<ReportProvider>().fetchOccupancy(month: _month);
  }

  String _shiftMonth(int delta) {
    final parts = _month.split('-');
    var y = int.tryParse(parts.first) ?? DateTime.now().year;
    var m = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
    m += delta;
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    while (m < 1) {
      m += 12;
      y -= 1;
    }
    return '$y-${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context);
    final prov = context.watch<ReportProvider>();
    final report = prov.occupancy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () {
                  setState(() => _month = _shiftMonth(-1));
                  _refresh();
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: HD.hairline),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_month, style: HD.bodyBold(size: 13)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () {
                  setState(() => _month = _shiftMonth(1));
                  _refresh();
                },
              ),
            ],
          ),
        ),
        if (prov.isLoading) const LinearProgressIndicator(),
        if (prov.error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(prov.error!, style: HD.caption(color: HD.negative)),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (report != null) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    color: HD.paperRaised,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.hOccReportOccupancyRate,
                                  style: HD.eyebrow(color: HD.inkMuted)),
                              const SizedBox(height: 4),
                              Text(
                                '${report.buildingAvgPct.toStringAsFixed(1)}%',
                                style: HD.bigNumeral(size: 40),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          l.hOccReportRoomsCount(report.roomCount),
                          style: HD.caption(color: HD.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(l.hOccReportByRoom,
                        style: HD.eyebrow(color: HD.inkMuted)),
                  ),
                  const SizedBox(height: 8),
                  for (final row in report.byRoom)
                    OccupancyRoomRow(row: row),
                ] else
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(l.hOccReportNoData,
                          style: HD.body(color: HD.inkMuted)),
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
