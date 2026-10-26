// ⏸ DEFERRED U2 (2026-07-14): cụm TENANT chưa chạy end-to-end — backend chưa
// phát JWT tenant (`hasTenantJwt=false`), guard `/tenant/*` redirect về `/`, và
// entry (AuthorityBadgeWidget) chưa nối nav. GIỮ scaffold, KHÔNG xoá. Nối khi
// U2 (login người thuê) go-live. Xem docs/BUSINESS-FLOWS.md §III-G.
/// Tenant: report an operator as not their representative (AC-63).
///
/// Tenant submits a report with reason. Does NOT expose full operator PII —
/// only name + verification status. Backend handles escalation.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class ReportUnauthorizedOperatorScreen extends StatefulWidget {
  const ReportUnauthorizedOperatorScreen({
    super.key,
    required this.delegationId,
  });

  final String delegationId;

  @override
  State<ReportUnauthorizedOperatorScreen> createState() =>
      _ReportUnauthorizedOperatorScreenState();
}

class _ReportUnauthorizedOperatorScreenState
    extends State<ReportUnauthorizedOperatorScreen> {
  final _reasonController = TextEditingController();
  String _selectedReason = 'unknown_person';
  bool _isSubmitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_submitted) {
      return Scaffold(
        backgroundColor: HD.paper,
        appBar: DsAppBar(title: l.tenantReportSubmittedTitle, compact: true),
        body: DsEmptyState(
          icon: Icons.check_circle_outline,
          title: l.tenantReportSubmittedHeadline,
          subtitle: l.tenantReportSubmittedSubtitle,
          actionLabel: l.tenantReportBackHome,
          onAction: () => context.go('/'),
        ),
      );
    }

    final reasonOptions = <(String value, String label)>[
      ('unknown_person', l.tenantReportReasonUnknownPerson),
      ('different_info', l.tenantReportReasonDifferentInfo),
      ('no_notice', l.tenantReportReasonNoNotice),
      ('other', l.tenantReportReasonOther),
    ];

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: l.tenantReportTitle,
        eyebrow: l.tenantReportEyebrow,
        compact: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(HD.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DsCardInset(
              child: Text(
                l.tenantReportDisclosure,
                style: HD.body(color: HD.inkSoft),
              ),
            ),
            const SizedBox(height: HD.s24),
            Text(l.tenantReportReasonLabel, style: HD.bodyBold(color: HD.ink)),
            const SizedBox(height: HD.s12),
            ...reasonOptions.map(
              (opt) => RadioListTile<String>(
                title: Text(opt.$2, style: HD.body(color: HD.ink, size: 14)),
                value: opt.$1,
                groupValue: _selectedReason,
                onChanged: (v) {
                  if (v != null) setState(() => _selectedReason = v);
                },
                activeColor: HD.accent,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: HD.s16),
            DsTextField(
              controller: _reasonController,
              label: l.tenantReportDetailLabel,
              hint: l.tenantReportDetailHint,
              maxLines: 4,
            ),
            const SizedBox(height: HD.s32),
            DsButton(
              label: l.tenantReportSubmitButton,
              icon: Icons.send_outlined,
              expand: true,
              size: DsButtonSize.large,
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      const client = ApiClient();
      await client.post(
        '/api/delegations/${widget.delegationId}/report-unauthorized',
        body: {
          'reason_code': _selectedReason,
          if (_reasonController.text.trim().isNotEmpty)
            'detail': _reasonController.text.trim(),
        },
      );
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitted = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.tenantReportSubmitFailed(e.toString())),
            backgroundColor: HD.negative,
          ),
        );
      }
    }
  }
}
