// ⏸ TODO CHỜ NỐI (DEFERRED U2, 2026-07-14): widget compliance/an toàn cho tenant
// (thấy ai đang đại diện quản lý nhà mình). Hiện CHƯA được mount ở màn nào. GIỮ,
// nối vào tenant home / contract detail khi cổng tenant U2 lên. Không phải dead code.
/// Tenant authority badge — shown on tenant home and contract detail.
///
/// Displays "Đại diện: [Operator] | Chủ: [Owner]" DsChip.
/// On tap → bottom sheet with operator KYC status + "Report unauthorized" button.
/// Covers AC-60, AC-63. NFR-12: NFC-normalize operator/owner names.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:house_booking/core/widgets/ds.dart';

/// Compact authority badge. Shows as a tappable DsChip-style container.
class AuthorityBadgeWidget extends StatelessWidget {
  const AuthorityBadgeWidget({
    super.key,
    required this.operatorName,
    required this.ownerName,
    this.operatorKycVerified = false,
    this.delegationId,
  });

  final String operatorName;
  final String ownerName;
  final bool operatorKycVerified;
  final String? delegationId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetailSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HD.s8,
          vertical: HD.s4,
        ),
        decoration: BoxDecoration(
          color: HD.accentSoft,
          borderRadius: BorderRadius.circular(HD.r4),
          border: Border.all(color: HD.hairlineStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_outlined,
                size: 14, color: HD.accentDeep),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Đại diện: $operatorName | Chủ: $ownerName',
                style: HD.caption(color: HD.accentDeep).copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.info_outline, size: 12, color: HD.accentDeep),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: HD.paperRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(HD.r12),
        ),
      ),
      builder: (ctx) => _AuthorityDetailSheet(
        operatorName: operatorName,
        ownerName: ownerName,
        operatorKycVerified: operatorKycVerified,
        delegationId: delegationId,
      ),
    );
  }
}

class _AuthorityDetailSheet extends StatelessWidget {
  const _AuthorityDetailSheet({
    required this.operatorName,
    required this.ownerName,
    required this.operatorKycVerified,
    this.delegationId,
  });

  final String operatorName;
  final String ownerName;
  final bool operatorKycVerified;
  final String? delegationId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(HD.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: HD.s16),
                decoration: BoxDecoration(
                  color: HD.hairlineStrong,
                  borderRadius: BorderRadius.circular(HD.rPill),
                ),
              ),
            ),
            Text(
              'Thông tin đại diện',
              style: HD.sectionTitle(color: HD.ink, size: 18),
            ),
            const SizedBox(height: HD.s16),
            _InfoRow(
              label: 'Đại lý vận hành',
              value: operatorName,
              verified: operatorKycVerified,
            ),
            const SizedBox(height: HD.s8),
            _InfoRow(
              label: 'Chủ sở hữu',
              value: ownerName,
              verified: true,
            ),
            const SizedBox(height: HD.s24),
            Text(
              'Operator được ủy quyền bởi chủ nhà. Mọi giao dịch được ghi lại '
              'và chủ nhà có thể thu hồi quyền bất kỳ lúc nào.',
              style: HD.body(color: HD.inkSoft),
            ),
            const SizedBox(height: HD.s24),
            DsButton(
              label: 'Báo cáo không phải đại diện của tôi',
              icon: Icons.report_outlined,
              variant: DsButtonVariant.secondary,
              expand: true,
              onPressed: () {
                Navigator.of(context).pop();
                if (delegationId != null) {
                  context.push(
                    '/tenant/report-unauthorized/$delegationId',
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.verified,
  });

  final String label;
  final String value;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: HD.caption(color: HD.inkMuted)),
              Text(value, style: HD.bodyBold(color: HD.ink)),
            ],
          ),
        ),
        if (verified)
          DsStatusPill(
            label: 'Đã xác minh',
            tone: DsStatusTone.positive,
            icon: Icons.check,
            dense: true,
          )
        else
          DsStatusPill(
            label: 'Chờ xác minh',
            tone: DsStatusTone.warning,
            dense: true,
          ),
      ],
    );
  }
}
