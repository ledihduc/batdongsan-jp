import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/property/providers/contract_provider.dart';

// ---------------------------------------------------------------------------
// Create contract CTA — shown when room is vacant.
// ---------------------------------------------------------------------------

class CreateContractCta extends StatelessWidget {
  const CreateContractCta({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(HD.s20, HD.s16, HD.s20, HD.s16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HD.hairline)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: HD.s12),
          decoration: BoxDecoration(
            color: HD.accent,
            border: Border.all(color: HD.accent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.assignment_outlined,
                  size: 16, color: HD.paperRaised),
              const SizedBox(width: HD.s8),
              Text('LẬP HỢP ĐỒNG MỚI',
                  style: HD.eyebrow(color: HD.paperRaised)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Contract history section — list + drilldown.
// ---------------------------------------------------------------------------

class ContractHistorySection extends StatelessWidget {
  const ContractHistorySection({
    super.key,
    required this.contractProvider,
    required this.onOpen,
  });

  final ContractProvider contractProvider;
  final void Function(int id) onOpen;

  @override
  Widget build(BuildContext context) {
    return Consumer<ContractProvider>(
      builder: (_, cp, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(HD.s20, HD.s20, HD.s20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 22, height: 1, color: HD.accent),
                  const SizedBox(width: HD.s8),
                  Text('LƯU TRỮ HỢP ĐỒNG',
                      style: HD.eyebrow(color: HD.accent)),
                  const Spacer(),
                  Text('[${cp.contracts.length}]',
                      style: HD.tabular(color: HD.inkMuted, size: 12)),
                ],
              ),
              const SizedBox(height: HD.s8),
              if (cp.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: HD.s20),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: HD.ink,
                      strokeWidth: 1.5,
                    ),
                  ),
                )
              else if (cp.contracts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: HD.s16),
                  child: Text('Chưa có hợp đồng nào được lập.',
                      style: HD.body(size: 13, color: HD.inkMuted)),
                )
              else
                Column(
                  children: [
                    for (final c in cp.contracts)
                      _ContractRow(
                        title: c.primaryTenant?.tenant.fullName ??
                            'Hợp đồng #${c.id}',
                        period: '${c.startDate} → ${c.endDate}',
                        status: c.status,
                        onTap: () => onOpen(c.id),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ContractRow extends StatelessWidget {
  const _ContractRow({
    required this.title,
    required this.period,
    required this.status,
    required this.onTap,
  });

  final String title;
  final String period;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      'active' => HD.positive,
      'draft' => HD.inkMuted,
      'terminated' => HD.negative,
      'pending' => HD.warning,
      _ => HD.inkMuted,
    };
    final label = switch (status) {
      'active' => 'ĐANG HIỆU LỰC',
      'draft' => 'NHÁP',
      'terminated' => 'ĐÃ CHẤM DỨT',
      'pending' => 'CHỜ XÉT',
      _ => status.toUpperCase(),
    };
    return InkWell(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 0, vertical: HD.s12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: HD.hairline)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: HD.bodyBold(size: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: HD.s8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration:
                            BoxDecoration(border: Border.all(color: tone)),
                        child: Text(label,
                            style: HD.eyebrow(color: tone)
                                .copyWith(fontSize: 9)),
                      ),
                    ],
                  ),
                  const SizedBox(height: HD.s4),
                  Text(period,
                      style: HD.tabular(color: HD.inkMuted, size: 12)),
                ],
              ),
            ),
            const SizedBox(width: HD.s8),
            const Icon(Icons.arrow_outward,
                size: 16, color: HD.inkMuted),
          ],
        ),
      ),
    );
  }
}
