/// Approval card widget — single approval request row in the inbox list.
///
/// Shows: operator name, action type, amount, SLA timer, approve/reject buttons.
library;

import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/approval_request_model.dart';

class ApprovalCardWidget extends StatelessWidget {
  const ApprovalCardWidget({
    super.key,
    required this.approval,
    required this.onApprove,
    required this.onReject,
  });

  final ApprovalRequestModel approval;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final isHighValue = (approval.amountVnd ?? 0) >= 50000000;

    return DsCard(
      padding: const EdgeInsets.all(HD.s16),
      borderColor: isHighValue ? HD.warning : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      approval.actionType.displayLabel(),
                      style: HD.bodyBold(color: HD.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Operator: ${approval.operatorName ?? "Không rõ"}',
                      style: HD.caption(color: HD.inkMuted),
                    ),
                    if (approval.amountVnd != null)
                      Text(
                        _formatAmount(approval.amountVnd!),
                        style: HD.bodyBold(color: HD.ink, size: 16),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isHighValue)
                    DsStatusPill(
                      label: '≥ 50M',
                      tone: DsStatusTone.warning,
                      icon: Icons.fingerprint,
                      dense: true,
                    ),
                  const SizedBox(height: 4),
                  if (approval.slaExpiresAt != null)
                    _SlaTimer(expiresAt: approval.slaExpiresAt!),
                ],
              ),
            ],
          ),
          if (approval.actionDescription != null) ...[
            const SizedBox(height: HD.s8),
            DsCardInset(
              child: Text(
                approval.actionDescription!,
                style: HD.caption(color: HD.inkSoft),
              ),
            ),
          ],
          if (approval.ownerNotifiedAt != null) ...[
            const SizedBox(height: HD.s8),
            Text(
              'Đã thông báo qua ${approval.ownerNotificationChannel ?? "email"} '
              'lúc ${_formatTime(approval.ownerNotifiedAt!)}',
              style: HD.caption(color: HD.inkMuted),
            ),
          ],
          const SizedBox(height: HD.s16),
          Row(
            children: [
              Expanded(
                child: DsButton(
                  label: 'Từ chối',
                  variant: DsButtonVariant.secondary,
                  onPressed: onReject,
                  size: DsButtonSize.compact,
                ),
              ),
              const SizedBox(width: HD.s12),
              Expanded(
                child: DsButton(
                  label: isHighValue ? 'Phê duyệt ✓' : 'Phê duyệt',
                  onPressed: onApprove,
                  size: DsButtonSize.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(2)}B₫';
    }
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M₫';
    }
    return '${amount.toStringAsFixed(0)}₫';
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _SlaTimer extends StatelessWidget {
  const _SlaTimer({required this.expiresAt});

  final DateTime expiresAt;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remaining = expiresAt.difference(now);

    if (remaining.isNegative) {
      return DsStatusPill(
        label: 'Đã hết hạn',
        tone: DsStatusTone.negative,
        dense: true,
      );
    }

    final hours = remaining.inHours;
    final label = hours < 6
        ? '${hours}h ${remaining.inMinutes % 60}m'
        : '${hours}h còn lại';

    return DsStatusPill(
      label: label,
      tone: hours < 6 ? DsStatusTone.negative : DsStatusTone.warning,
      icon: Icons.timer_outlined,
      dense: true,
    );
  }
}
