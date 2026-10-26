/// Personal data deletion confirmation modal.
///
/// Requires the user to type "DELETE" before submitting.
/// Shows the 30-day cooling-off notice prominently.
///
/// Shown via [showDataDeleteConfirmationSheet] from ConsentSettingsScreen.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/domain/repositories/jp/i_consent_repository.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Shows the deletion confirmation sheet.
/// Returns true if deletion request was submitted.
Future<bool> showDataDeleteConfirmationSheet(
  BuildContext context,
  IConsentRepository repository,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        DataDeleteConfirmationSheet(repository: repository),
  );
  return result ?? false;
}

class DataDeleteConfirmationSheet extends StatefulWidget {
  const DataDeleteConfirmationSheet({super.key, required this.repository});

  final IConsentRepository repository;

  @override
  State<DataDeleteConfirmationSheet> createState() =>
      _DataDeleteConfirmationSheetState();
}

class _DataDeleteConfirmationSheetState
    extends State<DataDeleteConfirmationSheet> {
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;
  bool get _typedCorrectly =>
      _confirmCtrl.text.trim().toUpperCase() == 'DELETE';

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_typedCorrectly) return;
    setState(() => _submitting = true);
    try {
      await widget.repository.requestDeletion();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        AppFeedback.error(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad + 24),
      decoration: const BoxDecoration(
        color: HD.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Warning header
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: HD.accent, size: 28),
              const SizedBox(width: 10),
              Text(l.data_delete_title,
                  style: HD.masthead(size: 18)),
            ],
          ),
          const SizedBox(height: 12),
          // Warning message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: HD.accent.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HD.accent.withOpacity(0.25)),
            ),
            child: Text(l.data_delete_warning,
                style: HD.body(size: 13)),
          ),
          const SizedBox(height: 12),
          // Cooling-off notice
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: HD.paperRaised,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: HD.inkMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l.data_delete_cool_off,
                      style: HD.caption()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Typed confirmation input
          Text(l.data_delete_confirm, style: HD.body()),
          const SizedBox(height: 8),
          DsTextField(
            controller: _confirmCtrl,
            label: '',
            hint: l.data_delete_type_hint,
            onChanged: (_) => setState(() {}),
            validator: (v) =>
                (v?.trim().toUpperCase() ?? '') != 'DELETE'
                    ? l.data_delete_type_error
                    : null,
          ),
          const SizedBox(height: 20),
          DsButton(
            label: l.data_delete_submit,
            variant: DsButtonVariant.primary,
            size: DsButtonSize.large,
            expand: true,
            isLoading: _submitting,
            onPressed: (_typedCorrectly && !_submitting) ? _submit : null,
          ),
        ],
      ),
    );
  }
}
