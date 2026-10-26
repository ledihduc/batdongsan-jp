/// Renewal detail screen — tenant views upcoming lease renewal (更新).
///
/// Shows contract summary, 更新料 breakdown, and confirm/decline CTA.
/// Opened via notification tap (renewal type) with [renewalId].
///
/// Route: /renewals/:id (GoRoute, JP-gated).
/// Provider: none — [IRenewalRepository] injected by constructor.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/renewal.dart';
import 'package:house_booking/data/repositories/jp/mock_renewal_repository.dart';
import 'package:house_booking/domain/repositories/jp/i_renewal_repository.dart';
import 'package:house_booking/features/renewal/renewal_confirm_sheet.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Route: /renewals/:id
class RenewalDetailScreen extends StatefulWidget {
  const RenewalDetailScreen({
    super.key,
    required this.renewalId,
    this.repository,
  });

  final int renewalId;
  final IRenewalRepository? repository;

  @override
  State<RenewalDetailScreen> createState() => _RenewalDetailScreenState();
}

class _RenewalDetailScreenState extends State<RenewalDetailScreen> {
  late final IRenewalRepository _repo;
  JpRenewal? _renewal;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MockRenewalRepository();
    _load();
  }

  Future<void> _load() async {
    try {
      final renewal = await _repo.getRenewal(widget.renewalId);
      if (mounted) setState(() { _renewal = renewal; _loading = false; });
    } catch (_) {
      // Keep the error message generic — never leak internal IDs or exception
      // detail into user-facing UI.
      if (mounted) {
        setState(() {
          _error = '更新情報を取得できませんでした。';
          _loading = false;
        });
      }
    }
  }

  Future<void> _onConfirm() async {
    final renewal = _renewal;
    if (renewal == null) return;
    final confirmed = await showRenewalConfirmSheet(
      context,
      renewal: renewal,
      repository: _repo,
    );
    if (confirmed && mounted) {
      await _load();
      AppFeedback.success(context, '更新を確認しました');
    }
  }

  Future<void> _onDecline() async {
    final renewal = _renewal;
    if (renewal == null) return;
    try {
      final updated = await _repo.declineRenewal(renewal.id);
      if (mounted) {
        setState(() => _renewal = updated);
        AppFeedback.success(context, '再交渉のご要望を受け付けました');
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(eyebrow: l.jp_renewal_eyebrow, title: l.jp_renewal_title),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : _error != null
              ? DsErrorState(message: _error!, onRetry: _load)
              : _renewal == null
                  ? const SizedBox.shrink()
                  : _RenewalBody(
                      renewal: _renewal!,
                      onConfirm: _onConfirm,
                      onDecline: _onDecline,
                      l: l,
                    ),
    );
  }
}

class _RenewalBody extends StatelessWidget {
  const _RenewalBody({
    required this.renewal,
    required this.onConfirm,
    required this.onDecline,
    required this.l,
  });

  final JpRenewal renewal;
  final VoidCallback onConfirm;
  final VoidCallback onDecline;
  final AppLocalizations l;

  static final _dateFormat = DateFormat('yyyy年M月d日');
  static final _yenFormat = NumberFormat('#,###', 'ja_JP');

  String _formatYen(int v) => '¥${_yenFormat.format(v)}';
  String _formatDate(DateTime d) => _dateFormat.format(d);

  @override
  Widget build(BuildContext context) {
    final isPending = renewal.status == RenewalStatus.pending;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Status banner
              if (renewal.status != RenewalStatus.pending)
                _StatusBanner(status: renewal.status, l: l),
              if (renewal.status != RenewalStatus.pending)
                const SizedBox(height: 12),
              // Contract summary card
              DsFormSection(
                title: l.jp_renewal_contract_summary,
                children: [
                  _InfoRow(label: l.jp_renewal_property, value: renewal.propertyName),
                  _InfoRow(label: l.jp_renewal_room, value: renewal.roomNumber),
                  _InfoRow(
                    label: l.jp_renewal_current_term_end,
                    value: _formatDate(renewal.currentTermEnd),
                  ),
                  _InfoRow(
                    label: l.jp_renewal_new_term_end,
                    value: _formatDate(renewal.newTermEnd),
                  ),
                  _InfoRow(
                    label: l.jp_monthly_rent,
                    value: _formatYen(renewal.monthlyRentYen),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 更新料 breakdown
              DsFormSection(
                title: l.jp_koushinryo,
                children: [
                  ...renewal.feeItems.map(
                    (item) => _InfoRow(
                      label: item.label,
                      value: _formatYen(item.amountYen),
                    ),
                  ),
                  const Divider(height: 24, color: HD.hairline),
                  _InfoRow(
                    label: l.jp_renewal_total_fee,
                    value: _formatYen(renewal.totalFeeYen),
                    bold: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        // Sticky CTA bar
        if (isPending)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DsButton(
                    label: l.jp_renewal_confirm_cta,
                    variant: DsButtonVariant.primary,
                    size: DsButtonSize.large,
                    expand: true,
                    onPressed: onConfirm,
                  ),
                  const SizedBox(height: 8),
                  DsButton(
                    label: l.jp_renewal_decline_cta,
                    variant: DsButtonVariant.ghost,
                    size: DsButtonSize.large,
                    expand: true,
                    onPressed: onDecline,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, required this.l});

  final RenewalStatus status;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final isConfirmed = status == RenewalStatus.confirmed;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isConfirmed ? HD.positiveTint : HD.warningTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isConfirmed
              ? HD.positive.withOpacity(0.3)
              : HD.warning.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConfirmed ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: isConfirmed ? HD.positive : HD.warning,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isConfirmed ? l.jp_renewal_status_confirmed : l.jp_renewal_status_declined,
              style: HD.body(size: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
      ),
    );
  }
}
