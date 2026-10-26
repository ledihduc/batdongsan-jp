import 'package:flutter/material.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Phase 07 — display the rigid 24h cancel policy (BA D10) attached to a
/// reservation. The policy snapshot is the *contract* between host and
/// guest at the moment of booking — never changes after creation.
class CancelPolicyDisplay extends StatelessWidget {
  const CancelPolicyDisplay({super.key, this.snapshot});

  /// Raw JSON snapshot string from server, or null to show the default v1
  /// human-readable policy.
  final String? snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(HD.s16),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CHÍNH SÁCH HUỶ', style: HD.eyebrow()),
          const SizedBox(height: HD.s8),
          Text(
            'Linh hoạt 24h cố định (v1)',
            style: HD.bodyBold(),
          ),
          const SizedBox(height: HD.s8),
          _row('Trước 24h check-in', 'Hoàn 100%', HD.positive),
          _row('Trong 24h trước check-in', 'Hoàn 50%', HD.warning),
          _row('Sau khi đã check-in', 'Không hoàn', HD.negative),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: HD.body(size: 13))),
          Text(value, style: HD.bodyBold(size: 13, color: color)),
        ],
      ),
    );
  }
}
