import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/features/host/billing/providers/invoice_provider.dart';
import 'package:house_booking/features/host/billing/widgets/vnd_text.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Dashboard widget — surfaces overdue invoices needing tenant reminder.
class NeedsReminderWidget extends StatelessWidget {
  final void Function(int invoiceId)? onTapItem;
  const NeedsReminderWidget({super.key, this.onTapItem});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<InvoiceProvider>().needsReminder;
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        border: Border.all(color: HD.hairline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('CẦN NHẮC THUÊ', style: HD.eyebrow(color: HD.inkMuted)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: HD.accent,
                child: Text('${items.length}',
                    style: HD.eyebrow(color: Colors.white).copyWith(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.take(3).map((it) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: InkWell(
                  onTap: () => onTapItem?.call(it.invoiceId),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${it.roomCode} • ${it.tenantName}',
                                style: HD.body()),
                            Text('Trễ ${it.daysOverdue} ngày',
                                style: HD.caption(color: HD.negative)),
                          ],
                        ),
                      ),
                      VndText(it.amountDue,
                          style: HD.tabular(color: HD.ink)),
                    ],
                  ),
                ),
              )),
          if (items.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('… và ${items.length - 3} hoá đơn khác',
                  style: HD.caption(color: HD.inkMuted)),
            ),
        ],
      ),
    );
  }
}
