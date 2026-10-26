import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds_app_bar.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/reports/screens/adr_report_screen.dart';
import 'package:house_booking/features/host/reports/screens/occupancy_report_screen.dart';
import 'package:house_booking/features/host/reports/screens/revenue_report_screen.dart';

/// Reports home — 3-tab orchestrator: Doanh thu / Lấp đầy / ADR.
class ReportsHomeScreen extends StatelessWidget {
  const ReportsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: HD.paper,
        appBar: DsAppBar(
          title: 'Báo cáo',
          titleAsSerif: true,
          bottom: TabBar(
            indicatorColor: HD.accent,
            labelColor: HD.ink,
            unselectedLabelColor: HD.inkMuted,
            labelStyle: HD.bodyBold(size: 13),
            unselectedLabelStyle: HD.body(size: 13),
            tabs: const [
              Tab(text: 'Doanh thu'),
              Tab(text: 'Lấp đầy'),
              Tab(text: 'ADR'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            RevenueReportScreen(),
            OccupancyReportScreen(),
            AdrReportScreen(),
          ],
        ),
      ),
    );
  }
}
