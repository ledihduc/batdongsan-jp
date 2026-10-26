import 'package:house_booking/features/guest/short_stay/short_stay_bookings_screen.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_operations_role.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds_app_bar.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/homestay/screens/pricing_rules_list_screen.dart';
import 'package:house_booking/features/host/homestay/screens/reservation_list_screen.dart';
import 'package:house_booking/features/host/homestay/screens/unified_calendar_screen.dart';

/// Phase 07 — 3-tab homestay surface: Lịch / Đặt phòng / Quy tắc giá.
class HomestayHomeScreen extends StatelessWidget {
  const HomestayHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: HD.paper,
        appBar: DsAppBar(
          title: 'Homestay',
          titleAsSerif: true,
          bottom: TabBar(
            labelColor: HD.ink,
            unselectedLabelColor: HD.inkMuted,
            indicatorColor: HD.accent,
            tabs: const [
              Tab(text: 'Ngắn hạn'),
              Tab(text: 'Lịch'),
              Tab(text: 'Đặt phòng'),
              Tab(text: 'Giá phòng'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ShortStayBookingsScreen(
              operations: true,
              operationsRole: ShortStayOperationsRole.owner,
            ),
            UnifiedCalendarScreen(),
            ReservationListScreen(),
            PricingRulesListScreen(),
          ],
        ),
      ),
    );
  }
}
