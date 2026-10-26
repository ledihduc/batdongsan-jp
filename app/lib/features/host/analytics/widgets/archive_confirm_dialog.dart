import 'package:flutter/material.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Confirmation dialog for archiving a revenue source.
///
/// Returns `true` via [Navigator.pop] when user confirms, `false` on cancel.
///
/// Usage:
/// ```dart
/// final confirmed = await showDialog<bool>(
///   context: context,
///   builder: (_) => const ArchiveConfirmDialog(),
/// );
/// if (confirmed == true) { ... }
/// ```
class ArchiveConfirmDialog extends StatelessWidget {
  const ArchiveConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: HD.paperRaised,
      title: Text('Lưu trữ nguồn?', style: HD.sectionTitle()),
      content: Text(
        'Vẫn giữ data lịch sử, ẩn khỏi dropdown tạo mới.',
        style: HD.body(),
      ),
      actions: [
        TextButton(
          key: const Key('archive_cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          key: const Key('archive_confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: HD.warning,
            foregroundColor: Colors.white,
          ),
          child: const Text('Lưu trữ'),
        ),
      ],
    );
  }
}
