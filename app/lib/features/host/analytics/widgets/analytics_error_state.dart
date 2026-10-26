import 'package:flutter/material.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Full-screen error state for analytics home screen.
///
/// Shows an icon, error message, and a "Thử lại" outlined button.
class AnalyticsErrorState extends StatelessWidget {
  const AnalyticsErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  /// Human-readable error description.
  final String message;

  /// Called when user taps the retry button.
  final VoidCallback onRetry;

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
            const Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: HD.inkMuted,
            ),
            const SizedBox(height: HD.s16),
            Text(
              'Không thể tải dữ liệu',
              textAlign: TextAlign.center,
              style: HD.sectionTitle(),
            ),
            const SizedBox(height: HD.s8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: HD.body(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: HD.s24),
            OutlinedButton.icon(
              key: const Key('error_retry_btn'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Thử lại'),
              style: OutlinedButton.styleFrom(
                foregroundColor: HD.ink,
                side: const BorderSide(color: HD.ink),
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
}
