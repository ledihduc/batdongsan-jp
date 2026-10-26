import 'package:flutter/material.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Confirmation dialog for hard-deleting a revenue source.
///
/// Returns `true` via [Navigator.pop] when user confirms, `false` on cancel.
///
/// Usage:
/// ```dart
/// final confirmed = await showDialog<bool>(
///   context: context,
///   builder: (_) => const DeleteConfirmDialog(),
/// );
/// if (confirmed == true) { ... }
/// ```
class DeleteConfirmDialog extends StatelessWidget {
  const DeleteConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: HD.paperRaised,
      title: Text('Xoá vĩnh viễn nguồn?', style: HD.sectionTitle()),
      content: Text(
        'Hành động này KHÔNG thể hoàn tác.',
        style: HD.body().copyWith(fontWeight: FontWeight.w600),
      ),
      actions: [
        TextButton(
          key: const Key('delete_cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          key: const Key('delete_confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: HD.negative,
            foregroundColor: Colors.white,
          ),
          child: const Text('Xoá'),
        ),
      ],
    );
  }
}
