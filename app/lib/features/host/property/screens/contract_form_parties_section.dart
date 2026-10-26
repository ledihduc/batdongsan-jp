import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/host/property/widgets/tenant_input_row.dart';

/// Parties section for contract form — host/tenant/witness fields.

class ContractFormTenantsSection extends StatelessWidget {
  const ContractFormTenantsSection({
    super.key,
    required this.tenantRows,
    required this.primaryCount,
    required this.onAddTenant,
    required this.onChanged,
    required this.onRemove,
    required this.onPickCccdFront,
    required this.onPickCccdBack,
  });

  final List<TenantRowData> tenantRows;
  final int primaryCount;
  final VoidCallback onAddTenant;
  final void Function(int index) onChanged;
  final void Function(int index) onRemove;
  final void Function(TenantRowData row) onPickCccdFront;
  final void Function(TenantRowData row) onPickCccdBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Người thuê', style: HD.bodyBold()),
            DsButton(
              label: 'Thêm',
              icon: Icons.person_add_outlined,
              variant: DsButtonVariant.ghost,
              size: DsButtonSize.compact,
              onPressed: onAddTenant,
            ),
          ],
        ),
        if (primaryCount != 1)
          Padding(
            padding: const EdgeInsets.only(bottom: HD.s8),
            child: Text(
              primaryCount == 0
                  ? 'Vui lòng chọn 1 người đại diện'
                  : 'Chỉ được 1 người đại diện',
              style: HD.caption(color: HD.warning).copyWith(fontSize: 12),
            ),
          ),
        const SizedBox(height: HD.s8),

        // Tenant rows — keyed by UUID so removing a middle row is safe (C4)
        ...tenantRows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return TenantInputRow(
            key: ValueKey(row.uuid),
            data: row,
            displayIndex: i,
            canRemove: tenantRows.length > 1,
            onChanged: () => onChanged(i),
            onRemove: tenantRows.length > 1 ? () => onRemove(i) : null,
            onPickCccdFront: () => onPickCccdFront(row),
            onPickCccdBack: () => onPickCccdBack(row),
          );
        }),
      ],
    );
  }
}
