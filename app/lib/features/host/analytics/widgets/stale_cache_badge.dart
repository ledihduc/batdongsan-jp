import 'package:flutter/material.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Pill badge shown when cached analytics data is 5+ minutes old (AC-17).
///
/// Stateless — caller is responsible for the staleness check.
class StaleCacheBadge extends StatelessWidget {
  const StaleCacheBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('stale_cache_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: HD.hairline,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time,
            size: 13,
            color: HD.inkSoft,
          ),
          const SizedBox(width: 4),
          Text(
            'Dữ liệu có thể cũ đến 5 phút',
            style: HD.eyebrow(color: HD.inkSoft).copyWith(
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
