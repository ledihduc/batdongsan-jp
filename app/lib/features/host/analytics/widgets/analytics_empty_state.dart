import 'package:flutter/material.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/billing/screens/invoice_list_screen.dart';

/// Empty state for hosts with no revenue data in the selected period (US-11b).
///
/// CTA navigates to /host/billing (invoice creation) or /host/property
/// if billing route does not exist. Both routes are Navigator.push-style
/// in current codebase so we use Navigator here as fallback.
class AnalyticsEmptyState extends StatelessWidget {
  const AnalyticsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HD.s32,
          vertical: HD.s40,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_chart_outlined_rounded,
              size: 64,
              color: HD.inkMuted,
            ),
            const SizedBox(height: HD.s16),
            Text(
              'Chưa có doanh thu trong kỳ này',
              textAlign: TextAlign.center,
              style: HD.sectionTitle(),
            ),
            const SizedBox(height: HD.s8),
            Text(
              'Tạo hoá đơn đầu tiên hoặc thêm phòng để bắt đầu theo dõi doanh thu.',
              textAlign: TextAlign.center,
              style: HD.body(),
            ),
            const SizedBox(height: HD.s24),
            ElevatedButton.icon(
              key: const Key('empty_cta_btn'),
              onPressed: () => _onTap(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Tạo invoice đầu tiên'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HD.ink,
                foregroundColor: HD.paperRaised,
                padding: const EdgeInsets.symmetric(
                  horizontal: HD.s24,
                  vertical: HD.s12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    // Mở màn Hoá đơn (nơi tạo invoice). Billing dùng điều hướng push-based, KHÔNG
    // có route go_router '/host/billing' → trước đây go() tới route không tồn tại
    // khiến hiện trang "no routes for location". Dùng Navigator.push cho đúng.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InvoiceListScreen()),
    );
  }
}
