// ⏸ TODO CHỜ NỐI (2026-07-14): dialog tuân thủ pháp lý cho operator-doanh-nghiệp
// (tài khoản dùng chung). `showIfNeeded(...)` hiện CHƯA có caller — cần gọi trong
// onboarding operator khi luồng uỷ quyền go-live. GIỮ, không xoá (scaffold pháp lý).
/// Shared-login disclosure dialog (AC-66).
///
/// Shown exactly once to operator-doanh-nghiệp on first login after invite accept.
/// Three disclosure points, requires explicit acknowledgment.
/// Persists acknowledgment timestamp via API.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/delegation_provider.dart';

class SharedLoginDisclosureDialog extends StatefulWidget {
  const SharedLoginDisclosureDialog({
    super.key,
    required this.delegationId,
  });

  final String delegationId;

  /// Shows the dialog. Returns true when user acknowledges.
  static Future<bool?> showIfNeeded(
    BuildContext context, {
    required String delegationId,
    required bool alreadyAcknowledged,
  }) async {
    if (alreadyAcknowledged) return true;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          SharedLoginDisclosureDialog(delegationId: delegationId),
    );
  }

  @override
  State<SharedLoginDisclosureDialog> createState() =>
      _SharedLoginDisclosureDialogState();
}

class _SharedLoginDisclosureDialogState
    extends State<SharedLoginDisclosureDialog> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DsDialog(
      title: l.opDiscloseTitle,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.opDiscloseBody,
            style: HD.body(color: HD.inkSoft),
          ),
          const SizedBox(height: HD.s16),
          _DisclosurePoint(
            icon: Icons.history_outlined,
            text: l.opDisclosePointAudit,
          ),
          const SizedBox(height: HD.s12),
          _DisclosurePoint(
            icon: Icons.lock_outline,
            text: l.opDisclosePointPassword,
          ),
          const SizedBox(height: HD.s12),
          _DisclosurePoint(
            icon: Icons.people_outline,
            text: l.opDisclosePointRbac,
          ),
        ],
      ),
      actions: [
        DsButton(
          label: l.opDiscloseAcknowledge,
          icon: Icons.check,
          expand: true,
          isLoading: _isProcessing,
          onPressed: _acknowledge,
        ),
      ],
    );
  }

  Future<void> _acknowledge() async {
    setState(() => _isProcessing = true);
    try {
      final prov = context.read<DelegationProvider>();
      await prov.acknowledgeSharedLoginDisclosure(widget.delegationId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).opDiscloseAckError('$e')),
            backgroundColor: HD.negative,
          ),
        );
      }
    }
  }
}

class _DisclosurePoint extends StatelessWidget {
  const _DisclosurePoint({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: HD.accent),
        const SizedBox(width: HD.s8),
        Expanded(
          child: Text(text, style: HD.body(color: HD.inkSoft, size: 13)),
        ),
      ],
    );
  }
}
