/// Renewal confirm bottom sheet — final confirmation before committing to renewal.
///
/// Shows 更新料 total + submit button.
/// Returns true if the renewal was confirmed successfully.
///
/// Route: n/a (modal, push-based via showRenewalConfirmSheet).
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/renewal.dart';
import 'package:house_booking/domain/repositories/jp/i_renewal_repository.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Shows renewal confirm sheet and returns true if confirmed.
Future<bool> showRenewalConfirmSheet(
  BuildContext context, {
  required JpRenewal renewal,
  required IRenewalRepository repository,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RenewalConfirmSheet(
      renewal: renewal,
      repository: repository,
    ),
  );
  return result ?? false;
}

class RenewalConfirmSheet extends StatefulWidget {
  const RenewalConfirmSheet({
    super.key,
    required this.renewal,
    required this.repository,
  });

  final JpRenewal renewal;
  final IRenewalRepository repository;

  @override
  State<RenewalConfirmSheet> createState() => _RenewalConfirmSheetState();
}

class _RenewalConfirmSheetState extends State<RenewalConfirmSheet> {
  bool _confirming = false;

  static final _yenFormat = NumberFormat('#,###', 'ja_JP');

  String _formatYen(int v) => '¥${_yenFormat.format(v)}';

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    try {
      await widget.repository.confirmRenewal(widget.renewal.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _confirming = false);
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
          Text(l.jp_renewal_confirm_title, style: HD.masthead(size: 18)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: HD.paperRaised,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: HD.hairline),
            ),
            child: Column(
              children: [
                _SummaryRow(
                  label: l.jp_renewal_property,
                  value: widget.renewal.propertyName,
                ),
                const SizedBox(height: 8),
                _SummaryRow(
                  label: l.jp_koushinryo,
                  value: _formatYen(widget.renewal.totalFeeYen),
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: HD.accentTint,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HD.accent.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: HD.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l.jp_renewal_confirm_notice, style: HD.caption()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          DsButton(
            label: l.jp_renewal_confirm_submit,
            variant: DsButtonVariant.primary,
            size: DsButtonSize.large,
            expand: true,
            isLoading: _confirming,
            onPressed: _confirming ? null : _confirm,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: HD.body(size: 13).copyWith(color: HD.inkSoft)),
        Text(
          value,
          style: HD.body(size: 13).copyWith(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
