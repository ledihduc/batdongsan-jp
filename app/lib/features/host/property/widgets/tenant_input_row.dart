import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';

/// Immutable data class holding one tenant row's state.
///
/// Owner (ContractFormScreen) allocates one [TenantRowData] per tenant,
/// keyed by [uuid] so that removing a middle row never reuses a State
/// that holds stale controllers. The [uuid] value is a caller-provided
/// stable string (e.g. a monotonic counter stringified). Callers must
/// call [dispose()] when removing the row from the list.
class TenantRowData {
  final String uuid;
  final TextEditingController fullNameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController cccdNumberCtrl;
  bool isPrimary;
  String? cccdFrontUrl;
  String? cccdBackUrl;

  TenantRowData({
    required this.uuid,
    bool initialPrimary = false,
  })  : fullNameCtrl = TextEditingController(),
        phoneCtrl = TextEditingController(),
        cccdNumberCtrl = TextEditingController(),
        isPrimary = initialPrimary;

  /// Release Flutter resources. Call when row is removed from the list.
  void dispose() {
    fullNameCtrl.dispose();
    phoneCtrl.dispose();
    cccdNumberCtrl.dispose();
  }

  /// Snapshot of this row as a map suitable for the contract API payload.
  Map<String, dynamic> toMap() => {
        'full_name': fullNameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'is_primary': isPrimary,
        if (cccdNumberCtrl.text.trim().isNotEmpty)
          'cccd_number': cccdNumberCtrl.text.trim(),
        if (cccdFrontUrl != null) 'cccd_front_path': cccdFrontUrl,
        if (cccdBackUrl != null) 'cccd_back_path': cccdBackUrl,
      };
}

/// Stateless widget for one tenant row.
///
/// All mutable state lives in [TenantRowData] held by the parent.
/// [onChanged] is called on every field edit so the parent can rebuild.
/// [onPickCccdFront]/[onPickCccdBack] are triggered by the upload buttons.
class TenantInputRow extends StatelessWidget {
  final TenantRowData data;
  final int displayIndex;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  final VoidCallback? onPickCccdFront;
  final VoidCallback? onPickCccdBack;

  const TenantInputRow({
    required Key key,
    required this.data,
    required this.displayIndex,
    required this.canRemove,
    required this.onChanged,
    this.onRemove,
    this.onPickCccdFront,
    this.onPickCccdBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Text(
                  'Người thuê ${displayIndex + 1}',
                  style: HD.bodyBold(size: 13),
                ),
                const Spacer(),
                if (canRemove)
                  DsIconButton(
                    icon: Icons.remove_circle_outline,
                    size: 20,
                    color: HD.negative,
                    tooltip: 'Xoá',
                    onPressed: onRemove,
                  ),
              ],
            ),
            const SizedBox(height: HD.s8),

            // Full name
            DsTextField(
              controller: data.fullNameCtrl,
              label: 'Họ tên *',
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: HD.s8),

            // Phone
            DsTextField(
              controller: data.phoneCtrl,
              label: 'Số điện thoại',
              keyboardType: TextInputType.phone,
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: HD.s8),

            // CCCD number
            DsTextField(
              controller: data.cccdNumberCtrl,
              label: 'Số CCCD',
              keyboardType: TextInputType.number,
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: HD.s8),

            // CCCD photo buttons
            if (onPickCccdFront != null || onPickCccdBack != null)
              Row(
                children: [
                  Expanded(
                    child: _photoButton(
                      label: 'CCCD mặt trước',
                      url: data.cccdFrontUrl,
                      onTap: onPickCccdFront,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _photoButton(
                      label: 'CCCD mặt sau',
                      url: data.cccdBackUrl,
                      onTap: onPickCccdBack,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 4),

            // Primary toggle
            Row(
              children: [
                Checkbox(
                  value: data.isPrimary,
                  onChanged: (v) {
                    data.isPrimary = v ?? false;
                    onChanged();
                  },
                ),
                Text('Người đại diện (chịu tiền)',
                    style: HD.body(size: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoButton({
    required String label,
    required String? url,
    required VoidCallback? onTap,
  }) {
    final uploaded = url != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: uploaded
              ? HD.positive.withValues(alpha: 0.07)
              : HD.paperSunken,
          border: Border.all(
            color: uploaded
                ? HD.positive
                : HD.hairline,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              uploaded
                  ? Icons.check_circle_outline
                  : Icons.add_photo_alternate_outlined,
              size: 20,
              color: uploaded
                  ? HD.positive
                  : HD.inkMuted,
            ),
            const SizedBox(height: 4),
            Text(
              uploaded ? 'Đã tải' : label,
              textAlign: TextAlign.center,
              style: HD.caption(
                color: uploaded ? HD.positive : HD.inkMuted,
              ).copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
