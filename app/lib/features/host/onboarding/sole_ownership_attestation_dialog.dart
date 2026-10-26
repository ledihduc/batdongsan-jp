/// Sole-ownership attestation dialog (AC-64).
///
/// Shown exactly once when owner first tries to invite an operator.
/// Blocks delegation creation if owner cannot confirm sole ownership.
/// YES → persists sole_ownership_attested_at via API → proceeds.
/// NO → shows v1 limitation message → blocks.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/providers/delegation_provider.dart';

class SoleOwnershipAttestationDialog extends StatefulWidget {
  const SoleOwnershipAttestationDialog({
    super.key,
    required this.buildingId,
  });

  final String buildingId;

  /// Shows the dialog. Returns true if attestation passed, false if not.
  static Future<bool?> show(
    BuildContext context, {
    required String buildingId,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          SoleOwnershipAttestationDialog(buildingId: buildingId),
    );
  }

  @override
  State<SoleOwnershipAttestationDialog> createState() =>
      _SoleOwnershipAttestationDialogState();
}

class _SoleOwnershipAttestationDialogState
    extends State<SoleOwnershipAttestationDialog> {
  bool _tosAccepted = false;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return DsDialog(
      title: 'Xác nhận chủ sở hữu',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tài sản này có đăng ký dưới tên duy nhất của bạn (sổ đỏ chính chủ)?',
            style: HD.body(color: HD.inkSoft),
          ),
          const SizedBox(height: HD.s16),
          DsCardInset(
            child: Text(
              'Phiên bản v1 chỉ hỗ trợ tài sản chính chủ (một chủ sở hữu). '
              'Tính năng đồng sở hữu sẽ ra mắt trong v2 Q4 2026.',
              style: HD.caption(color: HD.inkMuted),
            ),
          ),
          const SizedBox(height: HD.s16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _tosAccepted,
                onChanged: (v) =>
                    setState(() => _tosAccepted = v ?? false),
                activeColor: HD.accent,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _tosAccepted = !_tosAccepted),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Tôi xác nhận tài sản thuộc quyền sở hữu duy nhất của '
                      'tôi và đồng ý với điều khoản miễn trừ trách nhiệm.',
                      style: HD.body(color: HD.inkSoft, size: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        DsButton(
          label: 'Không — hủy',
          variant: DsButtonVariant.secondary,
          onPressed: _isProcessing
              ? null
              : () => Navigator.of(context).pop(false),
        ),
        DsButton(
          label: 'Có — xác nhận',
          isLoading: _isProcessing,
          onPressed: (_tosAccepted && !_isProcessing) ? _confirm : null,
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    setState(() => _isProcessing = true);
    try {
      final prov = context.read<DelegationProvider>();
      final ok = await prov.attestSoleOwnership(widget.buildingId);
      if (!mounted) return;
      Navigator.of(context).pop(ok);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: HD.negative,
          ),
        );
      }
    }
  }
}
