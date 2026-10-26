import 'package:flutter/material.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// ADR tab — placeholder until Phase 07 (Homestay Core) ships.
/// Average Daily Rate requires the reservation table introduced in homestay.
class AdrReportScreen extends StatelessWidget {
  const AdrReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hotel_outlined, size: 48, color: HD.inkMuted),
            const SizedBox(height: 16),
            Text('Báo cáo ADR',
                style: HD.sectionTitle(), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Average Daily Rate sẽ kích hoạt sau khi tính năng Homestay (Phase 07) phát hành.',
              style: HD.body(color: HD.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
