/// Deposit settlement — tenant review screen (敷金精算 入居者確認).
///
/// Tenant views itemized deductions in read-only mode.
/// CTA: accept (triggers refund invoice) or dispute (free-text reason).
///
/// Route: /settlements/:id/review (GoRoute, JP-gated).
/// Provider: none — [ISettlementRepository] injected by constructor.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/deposit_settlement.dart';
import 'package:house_booking/data/repositories/jp/mock_settlement_repository.dart';
import 'package:house_booking/domain/repositories/jp/i_settlement_repository.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Route: /settlements/:id/review
class TenantReviewScreen extends StatefulWidget {
  const TenantReviewScreen({
    super.key,
    required this.settlementId,
    this.repository,
  });

  final int settlementId;
  final ISettlementRepository? repository;

  @override
  State<TenantReviewScreen> createState() => _TenantReviewScreenState();
}

class _TenantReviewScreenState extends State<TenantReviewScreen> {
  late final ISettlementRepository _repo;
  JpDepositSettlement? _settlement;
  bool _loading = true;
  bool _actioning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MockSettlementRepository();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await _repo.getSettlement(widget.settlementId);
      if (mounted) setState(() { _settlement = s; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _accept() async {
    setState(() => _actioning = true);
    try {
      final updated = await _repo.acceptSettlement(widget.settlementId);
      if (mounted) {
        setState(() { _settlement = updated; _actioning = false; });
        AppFeedback.success(context, '精算内容に同意しました。返金手続きを開始します。');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actioning = false);
        AppFeedback.error(context, e.toString());
      }
    }
  }

  Future<void> _showDisputeSheet() async {
    final settlement = _settlement;
    if (settlement == null) return;
    final reason = await showTenantDisputeSheet(context);
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _actioning = true);
    try {
      final updated = await _repo.disputeSettlement(settlement.id, reason);
      if (mounted) {
        setState(() { _settlement = updated; _actioning = false; });
        AppFeedback.success(context, '異議申立を受け付けました。');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actioning = false);
        AppFeedback.error(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        eyebrow: l.jp_settlement_eyebrow,
        title: l.jp_settlement_tenant_title,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : _error != null
              ? DsErrorState(message: _error!, onRetry: _load)
              : _settlement == null
                  ? const SizedBox.shrink()
                  : _TenantReviewBody(
                      settlement: _settlement!,
                      onAccept: _actioning ? null : _accept,
                      onDispute: _actioning ? null : _showDisputeSheet,
                      actioning: _actioning,
                      l: l,
                    ),
    );
  }
}

class _TenantReviewBody extends StatelessWidget {
  const _TenantReviewBody({
    required this.settlement,
    required this.onAccept,
    required this.onDispute,
    required this.actioning,
    required this.l,
  });

  final JpDepositSettlement settlement;
  final VoidCallback? onAccept;
  final VoidCallback? onDispute;
  final bool actioning;
  final AppLocalizations l;

  static final _yenFormat = NumberFormat('#,###', 'ja_JP');
  String _formatYen(int v) => '¥${_yenFormat.format(v)}';

  bool get _isResolved =>
      settlement.status == SettlementStatus.tenantAccepted ||
      settlement.status == SettlementStatus.tenantDisputed ||
      settlement.status == SettlementStatus.completed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Status banner
              if (_isResolved) _StatusBanner(status: settlement.status, l: l),
              if (_isResolved) const SizedBox(height: 12),
              // Deposit summary
              DsFormSection(
                title: l.jp_settlement_deposit_summary,
                children: [
                  _InfoRow(label: l.jp_settlement_property, value: settlement.propertyName),
                  _InfoRow(label: l.jp_settlement_room, value: settlement.roomNumber),
                  _InfoRow(label: l.jp_shikikin, value: _formatYen(settlement.depositYen)),
                ],
              ),
              const SizedBox(height: 8),
              // Deduction list (read-only)
              DsFormSection(
                title: l.jp_settlement_deductions,
                children: settlement.deductions.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(l.jp_settlement_no_deductions, style: HD.body()),
                        ),
                      ]
                    : settlement.deductions
                        .map((d) => _DeductionReadOnlyCard(
                              line: d,
                              formatYen: _formatYen,
                            ))
                        .toList(),
              ),
              const SizedBox(height: 8),
              // Net refund total
              _NetRefundCard(
                depositYen: settlement.depositYen,
                netRefund: settlement.netRefundYen,
                formatYen: _formatYen,
                l: l,
              ),
              // Dispute reason (if any)
              if (settlement.disputeReason != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HD.warningTint,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: HD.warning.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.jp_settlement_dispute_reason_label, style: HD.eyebrow()),
                      const SizedBox(height: 6),
                      Text(settlement.disputeReason!, style: HD.body(size: 13)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
        // Sticky CTAs (only when tenant_review state)
        if (!_isResolved)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DsButton(
                    label: l.jp_settlement_accept_cta,
                    variant: DsButtonVariant.primary,
                    size: DsButtonSize.large,
                    expand: true,
                    isLoading: actioning,
                    onPressed: onAccept,
                  ),
                  const SizedBox(height: 8),
                  DsButton(
                    label: l.jp_settlement_dispute_cta,
                    variant: DsButtonVariant.ghost,
                    size: DsButtonSize.large,
                    expand: true,
                    onPressed: onDispute,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DeductionReadOnlyCard extends StatelessWidget {
  const _DeductionReadOnlyCard({required this.line, required this.formatYen});

  final DeductionLine line;
  final String Function(int) formatYen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  line.title,
                  style: HD.body(size: 14).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                formatYen(line.amountYen),
                style: HD.body(size: 14).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (line.note != null) ...[
            const SizedBox(height: 4),
            Text(line.note!, style: HD.caption()),
          ],
          if (line.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: line.photoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    line.photoUrls[i],
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 60,
                      height: 60,
                      color: HD.paperSunken,
                      child: const Icon(Icons.broken_image_outlined,
                          size: 20, color: HD.inkMuted),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, required this.l});

  final SettlementStatus status;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final isAccepted = status == SettlementStatus.tenantAccepted ||
        status == SettlementStatus.completed;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAccepted ? HD.positiveTint : HD.warningTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAccepted
              ? HD.positive.withOpacity(0.3)
              : HD.warning.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAccepted ? Icons.check_circle_outline : Icons.report_outlined,
            color: isAccepted ? HD.positive : HD.warning,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isAccepted
                  ? l.jp_settlement_status_accepted
                  : l.jp_settlement_status_disputed,
              style: HD.body(size: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetRefundCard extends StatelessWidget {
  const _NetRefundCard({
    required this.depositYen,
    required this.netRefund,
    required this.formatYen,
    required this.l,
  });

  final int depositYen;
  final int netRefund;
  final String Function(int) formatYen;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final refundColor = netRefund >= 0 ? HD.positive : HD.accent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HD.hairlineStrong),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.jp_shikikin, style: HD.body(size: 13).copyWith(color: HD.inkSoft)),
              Text(formatYen(depositYen), style: HD.body(size: 13)),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: HD.hairline),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.jp_settlement_net_refund,
                style: HD.body(size: 15).copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                formatYen(netRefund),
                style: HD.body(size: 15).copyWith(
                  fontWeight: FontWeight.bold,
                  color: refundColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: HD.body(size: 13).copyWith(color: HD.inkSoft)),
          Text(value, style: HD.body(size: 13)),
        ],
      ),
    );
  }
}

/// Shows a free-text dispute sheet and returns the reason string (or null if cancelled).
Future<String?> showTenantDisputeSheet(BuildContext context) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _TenantDisputeSheet(),
  );
}

class _TenantDisputeSheet extends StatefulWidget {
  const _TenantDisputeSheet();

  @override
  State<_TenantDisputeSheet> createState() => _TenantDisputeSheetState();
}

class _TenantDisputeSheetState extends State<_TenantDisputeSheet> {
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
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
          Text(l.jp_settlement_dispute_title, style: HD.masthead(size: 18)),
          const SizedBox(height: 8),
          Text(l.jp_settlement_dispute_description, style: HD.body(size: 13).copyWith(color: HD.inkSoft)),
          const SizedBox(height: 16),
          DsTextField(
            controller: _reasonCtrl,
            label: l.jp_settlement_dispute_reason_label,
            hint: '例：クロス補修費は通常損耗であり、原状回復義務の範囲外と考えます',
            maxLines: 4,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          DsButton(
            label: l.jp_settlement_dispute_submit,
            variant: DsButtonVariant.primary,
            size: DsButtonSize.large,
            expand: true,
            onPressed: _reasonCtrl.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(_reasonCtrl.text.trim()),
          ),
        ],
      ),
    );
  }
}
