import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/reports/widgets/period_selector.dart';
import 'package:house_booking/providers/report_provider.dart';
// RevenueBreakdownTable removed in Phase 06 — replaced by SourceBreakdownChart
// in /host/analytics/trend (tab "Theo nguồn").

/// Revenue tab — period picker + breakdown table + CSV export.
class RevenueReportScreen extends StatefulWidget {
  const RevenueReportScreen({super.key});

  @override
  State<RevenueReportScreen> createState() => _RevenueReportScreenState();
}

// ---------------------------------------------------------------------------
// Minimal summary row widget (replaces RevenueBreakdownTable for v1 screen).
// ---------------------------------------------------------------------------

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final formatted = value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: HD.body(size: 13))),
          Text('$formatted ₫', style: HD.tabular(size: 13)),
        ],
      ),
    );
  }
}

class _RevenueReportScreenState extends State<RevenueReportScreen>
    with AutomaticKeepAliveClientMixin {
  String _period = 'month';
  late String _date;
  bool _exporting = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    await context
        .read<ReportProvider>()
        .fetchRevenue(period: _period, date: _date);
  }

  Future<void> _exportCsv() async {
    if (_exporting) return;
    final l = AppLocalizations.of(context);
    setState(() => _exporting = true);
    try {
      final monthStr = _period == 'month' ? _date : '$_date-01';
      final bytes =
          await context.read<ReportProvider>().downloadInvoicesCsv(month: monthStr);
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.hRevReportExportFailed)),
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/invoices-$monthStr.csv');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: l.hRevReportInvoiceSubject(monthStr),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context);
    final prov = context.watch<ReportProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: PeriodSelector(
            period: _period,
            date: _date,
            onPeriodChanged: (p) => setState(() => _period = p),
            onDateChanged: (d) {
              setState(() => _date = d);
              _refresh();
            },
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
                // RevenueBreakdownTable removed (Phase 06).
                // New analytics view is at /host/analytics/trend.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (prov.revenue != null) ...[
                        _SummaryRow(
                          label: l.hRevReportTotalRevenue,
                          value: prov.revenue!.total,
                        ),
                        _SummaryRow(
                          label: l.hRevReportGrossRevenue,
                          value: prov.revenue!.gross,
                        ),
                        _SummaryRow(
                          label: l.hRevReportNetRevenue,
                          value: prov.revenue!.net,
                        ),
                      ] else
                        Center(
                          child: Text(l.hRevReportNoData,
                              style: HD.body(color: HD.inkMuted)),
                        ),
                      const SizedBox(height: HD.s16),
                      // CTA to new analytics
                      TextButton.icon(
                        onPressed: () => context.go('/host/analytics'),
                        icon: const Icon(Icons.bar_chart_rounded, size: 18),
                        label: Text(l.hRevReportViewNewStats),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_period == 'month')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      onPressed: _exporting ? null : _exportCsv,
                      icon: _exporting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_outlined),
                      label: Text(_exporting
                          ? l.hRevReportExporting
                          : l.hRevReportExportCsv),
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
