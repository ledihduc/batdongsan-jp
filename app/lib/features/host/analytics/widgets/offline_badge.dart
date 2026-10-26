import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Pill badge shown when [ReportProvider.offline] is true.
///
/// Displays last successful fetch time formatted as HH:mm.
/// Tap shows a SnackBar prompting the user to reconnect.
class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key, required this.lastFetchAt});

  /// Timestamp of the last successful fetch. May be null if never fetched.
  final DateTime? lastFetchAt;

  @override
  Widget build(BuildContext context) {
    final timeLabel = lastFetchAt != null
        ? 'Offline — dữ liệu lúc ${DateFormat.Hm().format(lastFetchAt!)}'
        : 'Offline';

    return GestureDetector(
      onTap: () => _showSnackBar(context),
      child: Container(
        key: const Key('offline_badge'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: HD.warning,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              timeLabel,
              style: HD.eyebrow(color: Colors.white).copyWith(
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: Key('offline_snackbar'),
        content: Text('Đang offline — kết nối lại để cập nhật'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}
