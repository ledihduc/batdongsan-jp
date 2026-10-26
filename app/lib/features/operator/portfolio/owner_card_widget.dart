/// Owner card widget shown in the operator portfolio list.
///
/// Displays: owner name/avatar, property count, MTD revenue, pending action count.
/// Lazy thumbnail loading via cached_network_image (NFR-09 performance target).
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/operator_delegation_model.dart';

class OwnerCardWidget extends StatelessWidget {
  const OwnerCardWidget({
    super.key,
    required this.delegation,
    required this.onTap,
  });

  final OperatorDelegationModel delegation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DsCard(
      onTap: delegation.isActive ? onTap : null,
      padding: const EdgeInsets.all(HD.s16),
      child: Row(
        children: [
          _avatar(),
          const SizedBox(width: HD.s12),
          Expanded(child: _info()),
          const SizedBox(width: HD.s8),
          _trailing(),
        ],
      ),
    );
  }

  Widget _avatar() {
    final avatarUrl = delegation.ownerAvatarUrl;
    return CircleAvatar(
      radius: 28,
      backgroundColor: HD.accentSoft,
      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
          ? CachedNetworkImageProvider(avatarUrl)
          : null,
      child: avatarUrl == null || avatarUrl.isEmpty
          ? Text(
              _initials(delegation.ownerName ?? 'N'),
              style: HD.bodyBold(color: HD.accent),
            )
          : null,
    );
  }

  Widget _info() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (delegation.isPaused)
          Padding(
            padding: const EdgeInsets.only(bottom: HD.s4),
            child: DsStatusPill(
              label: 'Tạm dừng',
              tone: DsStatusTone.warning,
              dense: true,
            ),
          ),
        Text(
          delegation.ownerName ?? 'Chủ nhà',
          style: HD.bodyBold(color: HD.ink),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          '${delegation.propertyCount} tài sản',
          style: HD.caption(color: HD.inkMuted),
        ),
        if (delegation.mtdRevenueVnd > 0)
          Text(
            'MTD: ${_formatVnd(delegation.mtdRevenueVnd)}',
            style: HD.caption(color: HD.inkMuted),
          ),
      ],
    );
  }

  Widget _trailing() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (delegation.pendingApprovalCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: HD.negativeTint,
              borderRadius: BorderRadius.circular(HD.rPill),
            ),
            child: Text(
              '${delegation.pendingApprovalCount} chờ duyệt',
              style: HD.caption(color: HD.negative).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (delegation.isActive)
          const Padding(
            padding: EdgeInsets.only(top: HD.s8),
            child: Icon(
              Icons.chevron_right,
              color: HD.inkMuted,
              size: 20,
            ),
          ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatVnd(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M₫';
    }
    return '${amount.toStringAsFixed(0)}₫';
  }
}
