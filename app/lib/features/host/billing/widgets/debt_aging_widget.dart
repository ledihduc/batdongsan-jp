import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/features/host/billing/providers/invoice_provider.dart';
import 'package:house_booking/features/host/billing/widgets/vnd_text.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Dashboard widget — compact 3-bucket aging summary.
/// Tapping the card navigates to the full debt-aging screen.
class DebtAgingWidget extends StatelessWidget {
  final VoidCallback? onTap;
  const DebtAgingWidget({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final report = context.watch<InvoiceProvider>().debtAging;
    if (report == null || report.totalUnpaid == 0) {
      return const SizedBox.shrink();
    }

    final buckets = {for (final b in report.buckets) b.bucket: b};
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HD.paperRaised,
          border: Border.all(color: HD.hairline),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CÔNG NỢ', style: HD.eyebrow(color: HD.inkMuted)),
            const SizedBox(height: 6),
            VndText(report.totalUnpaid,
                style: HD.bigNumeral(color: HD.negative, size: 28)),
            const SizedBox(height: 12),
            Row(
              children: [
                _cell('0–30', buckets['0-30']?.totalAmount ?? 0),
                const _Divider(),
                _cell('30–60', buckets['30-60']?.totalAmount ?? 0),
                const _Divider(),
                _cell('>60', buckets['>60']?.totalAmount ?? 0),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String label, double amount) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: HD.eyebrow(color: HD.inkMuted).copyWith(fontSize: 9)),
          const SizedBox(height: 4),
          VndText(amount,
              showCurrency: false,
              style: HD.tabular(color: HD.ink).copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: HD.hairline);
}
