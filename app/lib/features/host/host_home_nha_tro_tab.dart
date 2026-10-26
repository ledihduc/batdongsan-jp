import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'host_home_khaibao_banner.dart';
import 'package:house_booking/features/host/billing/providers/invoice_provider.dart';
import 'package:house_booking/features/host/billing/screens/debt_aging_screen.dart';
import 'package:house_booking/features/host/billing/screens/invoice_list_screen.dart';
import 'package:house_booking/features/host/billing/screens/invoice_detail_screen.dart';
import 'package:house_booking/features/host/billing/screens/service_fee_list_screen.dart';
import 'package:house_booking/features/host/billing/screens/invoice_batch_generate_screen.dart';
import 'package:house_booking/features/host/billing/screens/meter_reading_screen.dart';
import 'package:house_booking/features/host/billing/screens/batch_reminder_screen.dart';
import 'package:house_booking/features/host/billing/widgets/debt_aging_widget.dart';
import 'package:house_booking/features/host/billing/widgets/needs_reminder_widget.dart';
import 'package:house_booking/features/host/khaibao/providers/khaibao_provider.dart';
import 'package:house_booking/features/host/khaibao/screens/khaibao_list_screen.dart';
import 'package:house_booking/features/host/homestay/screens/homestay_home_screen.dart';
import 'package:house_booking/features/host/leads/leads_screen.dart';
import 'package:house_booking/features/host/marketplace/screens/sync_status_screen.dart';
import 'package:house_booking/features/host/reports/screens/reports_home_screen.dart';
import 'package:house_booking/features/host/lich_phong/lich_phong_screen.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';
import 'package:house_booking/features/host/property/screens/building_list_screen.dart';
import 'package:house_booking/providers/dashboard_provider.dart';
import 'package:house_booking/providers/report_provider.dart';

import 'dashboard/host_dashboard_tokens.dart';
import 'dashboard/widgets/action_items_section.dart';

// ── Tab 2: Nhà trọ ───────────────────────────────────────────────────────────

class HostHomeNhaTroTab extends StatefulWidget {
  const HostHomeNhaTroTab({super.key});

  @override
  State<HostHomeNhaTroTab> createState() => _HostHomeNhaTroTabState();
}

class _HostHomeNhaTroTabState extends State<HostHomeNhaTroTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final inv = context.read<InvoiceProvider>();
      await inv.fetchDebtAging();
      await inv.fetchNeedsReminder();
      if (!mounted) return;
      await context.read<KhaiBaoProvider>().fetchSummary();
      if (!mounted) return;
      await context.read<DashboardProvider>().fetchActionItems();
      if (!mounted) return;
      // KPI "Đã thu" + "Tỉ lệ lấp đầy" (Đợt 4-ext) — fetch tháng hiện tại.
      final now = DateTime.now();
      final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final report = context.read<ReportProvider>();
      await report.fetchRevenue(period: 'month', date: ym);
      if (!mounted) return;
      await report.fetchOccupancy(month: ym);
    });
  }

  void _openReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReportsHomeScreen()),
    );
  }

  void _openKhaiBao({bool overdue = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KhaiBaoListScreen(openOnOverdue: overdue),
      ),
    );
  }

  void _openInvoices() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InvoiceListScreen()),
    );
  }

  void _openDebtAging() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DebtAgingScreen()),
    );
  }

  void _openServiceFees() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ServiceFeeListScreen()),
    );
  }

  void _openLichPhong() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LichPhongScreen()),
    );
  }

  void _openHomestay() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HomestayHomeScreen()),
    );
  }

  void _openMarketplaceSync() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SyncStatusScreen()),
    );
  }

  void _openLeads() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LeadsScreen()),
    );
  }

  void _openInvoiceById(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: id)),
    );
  }

  void _openBatchInvoice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InvoiceBatchGenerateScreen()),
    );
  }

  void _openMeter() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MeterReadingScreen()),
    );
  }

  void _openBatchReminder() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BatchReminderScreen()),
    );
  }

  static String _fmtVndShort(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(v >= 1e10 ? 0 : 1)} tỷ';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(v >= 1e7 ? 0 : 1)} tr';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  /// Dải KPI 3 ô — Đã thu · Còn nợ · Tỉ lệ lấp đầy (3 số quan trọng nhất).
  Widget _kpiBar3(double collected, double unpaid, double occupancyPct) {
    final l = AppLocalizations.of(context);
    Widget cell(
      String label,
      String value,
      VoidCallback onTap, {
      Color? color,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color ?? HD.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: HD.eyebrow().copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HD.hairline)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cell(
              l.hHomeRoomsKpiCollected,
              '${_fmtVndShort(collected)} đ',
              _openReports,
            ),
            const VerticalDivider(width: 1, color: HD.hairline),
            cell(
              l.hHomeRoomsKpiUnpaid,
              '${_fmtVndShort(unpaid)} đ',
              _openDebtAging,
              color: unpaid > 0 ? HD.negative : HD.ink,
            ),
            const VerticalDivider(width: 1, color: HD.hairline),
            cell(
              l.hHomeRoomsKpiOccupancy,
              '${occupancyPct.toStringAsFixed(0)}%',
              _openReports,
            ),
          ],
        ),
      ),
    );
  }

  /// Thanh thao tác nhanh — 4 việc chủ trọ làm thường xuyên (backend đã sẵn).
  Widget _quickActions() {
    final l = AppLocalizations.of(context);
    Widget action(IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: HD.accentTint,
                  child: Icon(icon, color: HD.accent, size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: HD.ink),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Row(
        children: [
          action(
            Icons.receipt_long,
            l.hHomeRoomsQuickCreateInvoice,
            _openBatchInvoice,
          ),
          action(Icons.bolt_outlined, l.hHomeRoomsQuickMeter, _openMeter),
          action(
            Icons.notifications_active_outlined,
            l.hHomeRoomsQuickReminder,
            _openBatchReminder,
          ),
          action(
            Icons.insights_outlined,
            l.hHomeRoomsQuickReports,
            _openReports,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
    child: Text(text, style: HD.eyebrow()),
  );

  /// Menu tile có phân cấp — thay lưới nút phẳng để giảm tải nhận thức.
  Widget _menuTile(
    IconData icon,
    String title,
    String? subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: HD.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: HD.ink,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle, style: HD.caption()),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: HD.inkMuted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buildingProvider = context.watch<BuildingProvider>();

    return Container(
      color: HD.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(HD.s20, HD.s16, HD.s20, HD.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TÀI SẢN CHO THUÊ', style: HD.eyebrow(color: HD.accent)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        'Quản lý tòa nhà, phòng và người thuê của bạn.',
                        style: HD.body(size: 13, color: HD.inkMuted),
                      ),
                    ),
                    // "Phòng nào bận đến bao giờ" là câu chủ nhà bị hỏi mỗi lần
                    // nhấc máy. Danh sách toà bên dưới không trả lời được — nó
                    // chỉ có cờ còn/hết. Để nút ngay đây thay vì chôn trong một
                    // lớp menu nữa.
                    TextButton.icon(
                      onPressed: _openLichPhong,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.event_available_outlined, size: 17),
                      label: const Text('Lịch phòng'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: buildingProvider),
              ],
              child: const BuildingListScreen(),
            ),
          ),
        ],
      ),
    );
  }
}
