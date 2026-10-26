/// Owner-side approval inbox — pending approvals list + 1-tap approve/reject.
///
/// Biometric prompt for ≥ 50M VND actions (AC-29b). Covers AC-25, AC-26, AC-29.
/// NFR-11: approval decision is optimistic; failure shows error + keeps item.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/approval_request_model.dart';
import 'package:house_booking/providers/approval_provider.dart';
import 'package:house_booking/features/host/approvals/approval_card_widget.dart';
import 'package:house_booking/features/host/approvals/biometric_confirm_widget.dart';

class ApprovalInboxScreen extends StatefulWidget {
  const ApprovalInboxScreen({super.key});

  @override
  State<ApprovalInboxScreen> createState() => _ApprovalInboxScreenState();
}

class _ApprovalInboxScreenState extends State<ApprovalInboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<ApprovalProvider>();
      auth.fetch('');
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: l.hApprovalInboxTitle,
        eyebrow: l.hApprovalInboxEyebrow,
      ),
      body: const _ApprovalBody(),
    );
  }
}

class _ApprovalBody extends StatelessWidget {
  const _ApprovalBody();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prov = context.watch<ApprovalProvider>();

    if (prov.isLoading && prov.pendingApprovals.isEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(HD.s16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: HD.s12),
        itemBuilder: (_, __) => const DsSkeleton(height: 120),
      );
    }

    if (prov.pendingApprovals.isEmpty) {
      return DsEmptyState(
        icon: Icons.check_circle_outline,
        title: l.hApprovalEmptyTitle,
        subtitle: l.hApprovalEmptySubtitle,
      );
    }

    return RefreshIndicator(
      color: HD.accent,
      onRefresh: () => prov.fetch(''),
      child: ListView.separated(
        padding: const EdgeInsets.all(HD.s16),
        itemCount: prov.pendingApprovals.length,
        separatorBuilder: (_, __) => const SizedBox(height: HD.s12),
        itemBuilder: (context, index) {
          final approval = prov.pendingApprovals[index];
          return ApprovalCardWidget(
            approval: approval,
            onApprove: () => _handleApprove(context, approval),
            onReject: () => _handleReject(context, approval),
          );
        },
      ),
    );
  }

  Future<void> _handleApprove(
      BuildContext context, ApprovalRequestModel approval) async {
    final l = AppLocalizations.of(context);
    final prov = context.read<ApprovalProvider>();

    bool biometricVerified = false;

    // AC-29b: biometric prompt for ≥ 50M VND.
    if (approval.requiresBiometric) {
      final verified = await BiometricConfirmWidget.authenticate(
        context,
        reason: l.hApprovalBiometricReason(
            _formatAmount(approval.amountVnd ?? 0)),
      );
      if (!context.mounted) return;
      if (!verified) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.hApprovalBiometricRequired),
            backgroundColor: HD.negative,
          ),
        );
        return;
      }
      biometricVerified = true;
    }

    final ok = await prov.approveRequest(
      approval.id,
      biometricVerified: biometricVerified,
    );
    if (!context.mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.hApprovalApproveSuccess),
          backgroundColor: HD.positive,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(prov.error ?? l.hApprovalApproveFailed),
          backgroundColor: HD.negative,
        ),
      );
    }
  }

  Future<void> _handleReject(
      BuildContext context, ApprovalRequestModel approval) async {
    final l = AppLocalizations.of(context);
    final reason = await _promptRejectionReason(context);
    if (!context.mounted) return;

    final prov = context.read<ApprovalProvider>();
    final ok = await prov.rejectRequest(approval.id, reason: reason);
    if (!context.mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hApprovalRejectSuccess)),
      );
    }
  }

  Future<String?> _promptRejectionReason(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => DsDialog(
        title: l.hApprovalRejectReasonTitle,
        body: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: l.hApprovalRejectReasonHint,
          ),
          maxLines: 3,
        ),
        actions: [
          DsButton(
            label: l.hApprovalSkip,
            variant: DsButtonVariant.secondary,
            onPressed: () => Navigator.of(ctx).pop(null),
          ),
          DsButton(
            label: l.hApprovalReject,
            variant: DsButtonVariant.destructive,
            onPressed: () =>
                Navigator.of(ctx).pop(ctrl.text.trim()),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M₫';
    }
    return '${amount.toStringAsFixed(0)}₫';
  }
}
