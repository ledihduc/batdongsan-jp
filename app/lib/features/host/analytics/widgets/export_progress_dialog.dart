import 'package:flutter/material.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Non-dismissible progress dialog shown while the TT200 export is in-flight.
///
/// Show via:
/// ```dart
/// showDialog(
///   context: context,
///   barrierDismissible: false,
///   builder: (_) => const ExportProgressDialog(),
/// );
/// ```
class ExportProgressDialog extends StatelessWidget {
  const ExportProgressDialog({super.key, this.progress});

  /// Optional progress value in [0.0, 1.0]. Null = indeterminate.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent back-button dismissal while export is running.
      canPop: false,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            LinearProgressIndicator(
              key: const Key('export_progress_indicator'),
              value: progress,
              backgroundColor: HD.hairline,
              color: HD.ink,
              minHeight: 4,
            ),
            const SizedBox(height: 16),
            Text(
              'Đang tạo file TT200...',
              style: HD.caption(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
