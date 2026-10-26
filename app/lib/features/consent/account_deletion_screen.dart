/// Account deletion schedule screen (アカウント削除).
///
/// Shows 30-day countdown from schedule date + cancel CTA.
/// After 2-step email-retype confirmation, schedules deletion.
///
/// Route: /settings/account-deletion (GoRoute, JP-gated).
/// Provider: none — [IConsentRepository] injected by constructor.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/repositories/jp/mock_consent_repository.dart';
import 'package:house_booking/domain/repositories/jp/i_consent_repository.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Route: /settings/account-deletion
class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({
    super.key,
    this.repository,
    // User email injected so the confirm step can validate the typed value.
    this.userEmail,
    // If non-null, deletion is already scheduled at this date.
    this.scheduledAt,
  });

  final IConsentRepository? repository;
  final String? userEmail;
  final DateTime? scheduledAt;

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  late final IConsentRepository _repo;
  bool _scheduled = false;
  DateTime? _scheduledAt;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MockConsentRepository();
    _scheduled = widget.scheduledAt != null;
    _scheduledAt = widget.scheduledAt;
  }

  Future<void> _requestDeletion() async {
    // Open 2-step email confirm sheet before proceeding.
    final confirmed = await showAccountDeletionConfirmSheet(
      context,
      userEmail: widget.userEmail ?? '',
    );
    if (!confirmed || !mounted) return;

    try {
      await _repo.requestDeletion();
      if (mounted) {
        setState(() {
          _scheduled = true;
          _scheduledAt = DateTime.now().add(const Duration(days: 30));
        });
        AppFeedback.success(context, 'アカウント削除を申請しました。30日後に実行されます。');
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, e.toString());
    }
  }

  Future<void> _cancelDeletion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l.jp_deletion_cancel_confirm_title),
          content: Text(l.jp_deletion_cancel_confirm_body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l.jp_deletion_cancel_no),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l.jp_deletion_cancel_yes,
                  style: const TextStyle(color: HD.positive)),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    // MVP: cancellation calls requestDeletion is not ideal — real BE has DELETE endpoint.
    // For mock, we just reset state.
    setState(() {
      _scheduled = false;
      _scheduledAt = null;
    });
    AppFeedback.success(context, '削除申請をキャンセルしました。');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        eyebrow: l.jp_deletion_eyebrow,
        title: l.jp_deletion_title,
      ),
      body: _scheduled
          ? _ScheduledView(
              scheduledAt: _scheduledAt!,
              onCancel: _cancelDeletion,
              l: l,
            )
          : _ConfirmView(onRequestDeletion: _requestDeletion, l: l),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pre-deletion: warning + schedule CTA
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmView extends StatelessWidget {
  const _ConfirmView({required this.onRequestDeletion, required this.l});

  final VoidCallback onRequestDeletion;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.warning_amber_rounded, size: 48, color: HD.accent),
        const SizedBox(height: 16),
        Text(
          l.jp_deletion_title,
          style: HD.masthead(size: 20),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(l.jp_deletion_warning, style: HD.body()),
        const SizedBox(height: 16),
        _BulletPoint(text: l.jp_deletion_bullet_data),
        _BulletPoint(text: l.jp_deletion_bullet_contracts),
        _BulletPoint(text: l.jp_deletion_bullet_irreversible),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: HD.paperRaised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: HD.hairline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 16, color: HD.inkMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.jp_deletion_cooloff_notice, style: HD.caption()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        DsButton(
          label: l.jp_deletion_schedule_cta,
          variant: DsButtonVariant.primary,
          size: DsButtonSize.large,
          expand: true,
          onPressed: onRequestDeletion,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post-schedule: countdown + cancel
// ─────────────────────────────────────────────────────────────────────────────

class _ScheduledView extends StatelessWidget {
  const _ScheduledView({
    required this.scheduledAt,
    required this.onCancel,
    required this.l,
  });

  final DateTime scheduledAt;
  final VoidCallback onCancel;
  final AppLocalizations l;

  int get _daysRemaining {
    final diff = scheduledAt.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysRemaining;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: HD.warningTint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HD.warning.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              const Icon(Icons.hourglass_top_rounded,
                  size: 40, color: HD.warning),
              const SizedBox(height: 12),
              Text(
                '$days',
                style: HD.masthead(size: 48).copyWith(color: HD.accent),
              ),
              Text(
                l.jp_deletion_days_remaining,
                style: HD.body(size: 13).copyWith(color: HD.inkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(l.jp_deletion_scheduled_notice, style: HD.body()),
        const SizedBox(height: 8),
        Text(
          l.jp_deletion_support_contact,
          style: HD.body(size: 13).copyWith(color: HD.inkSoft),
        ),
        const SizedBox(height: 32),
        DsButton(
          label: l.jp_deletion_cancel_cta,
          variant: DsButtonVariant.primary,
          size: DsButtonSize.large,
          expand: true,
          onPressed: onCancel,
        ),
      ],
    );
  }
}

class _BulletPoint extends StatelessWidget {
  const _BulletPoint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: HD.accent),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: HD.body(size: 14))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2-step email confirm sheet
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a sheet requiring the user to retype their email before proceeding.
/// Returns true if confirmed.
Future<bool> showAccountDeletionConfirmSheet(
  BuildContext context, {
  required String userEmail,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AccountDeletionConfirmSheet(userEmail: userEmail),
  );
  return result ?? false;
}

class _AccountDeletionConfirmSheet extends StatefulWidget {
  const _AccountDeletionConfirmSheet({required this.userEmail});

  final String userEmail;

  @override
  State<_AccountDeletionConfirmSheet> createState() =>
      _AccountDeletionConfirmSheetState();
}

class _AccountDeletionConfirmSheetState
    extends State<_AccountDeletionConfirmSheet> {
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  bool get _emailMatches =>
      _emailCtrl.text.trim().toLowerCase() ==
      widget.userEmail.trim().toLowerCase();

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
          Text(l.jp_deletion_confirm_sheet_title, style: HD.masthead(size: 18)),
          const SizedBox(height: 8),
          Text(l.jp_deletion_confirm_sheet_body, style: HD.body(size: 13)),
          const SizedBox(height: 16),
          DsTextField(
            controller: _emailCtrl,
            label: l.jp_deletion_confirm_email_label,
            hint: l.jp_deletion_confirm_email_hint,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
            validator: (_) =>
                _emailMatches ? null : l.jp_deletion_confirm_email_error,
          ),
          const SizedBox(height: 20),
          DsButton(
            label: l.jp_deletion_confirm_submit,
            variant: DsButtonVariant.primary,
            size: DsButtonSize.large,
            expand: true,
            onPressed: _emailMatches
                ? () => Navigator.of(context).pop(true)
                : null,
          ),
        ],
      ),
    );
  }
}
