import 'package:flutter/material.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/invoice_model.dart';
import 'package:house_booking/features/host/billing/providers/invoice_provider.dart';
import 'package:house_booking/features/host/billing/screens/invoice_detail_screen.dart';
import 'package:house_booking/features/host/billing/widgets/billing_app_bar.dart';
import 'package:house_booking/features/host/billing/widgets/vnd_text.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

class DebtAgingScreen extends StatefulWidget {
  const DebtAgingScreen({super.key});

  @override
  State<DebtAgingScreen> createState() => _DebtAgingScreenState();
}

class _DebtAgingScreenState extends State<DebtAgingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<InvoiceProvider>().fetchDebtAging();
      await context.read<InvoiceProvider>().fetchNeedsReminder();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prov = context.watch<InvoiceProvider>();
    final report = prov.debtAging;
    final reminders = prov.needsReminder;

    if (prov.isLoading && report == null) {
      return Scaffold(
        backgroundColor: HD.paper,
        appBar: billingAppBar(l.hDebtAgingTitle),
        body: const Center(child: DsRowSkeleton()),
      );
    }
    if (prov.error != null && report == null) {
      return Scaffold(
        backgroundColor: HD.paper,
        appBar: billingAppBar(l.hDebtAgingTitle),
        body: DsErrorState(
          message: prov.error!,
          onRetry: () async {
            await prov.fetchDebtAging();
            await prov.fetchNeedsReminder();
          },
        ),
      );
    }
    if (report == null) {
      return Scaffold(
        backgroundColor: HD.paper,
        appBar: billingAppBar(l.hDebtAgingTitle),
        body: DsEmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: l.hDebtAgingEmptyTitle,
        ),
      );
    }

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: billingAppBar(l.hDebtAgingTitle),
      body: RefreshIndicator(
              onRefresh: () async {
                await prov.fetchDebtAging();
                await prov.fetchNeedsReminder();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(l.hDebtAgingTotal, style: HD.eyebrow(color: HD.inkMuted)),
                  const SizedBox(height: 8),
                  VndText(report.totalUnpaid,
                      style: HD.bigNumeral(color: HD.negative, size: 36)),
                  const Divider(height: 32, color: HD.hairline),
                  Text(l.hDebtAgingByBucket, style: HD.eyebrow(color: HD.inkMuted)),
                  const SizedBox(height: 12),
                  ...report.buckets.map(_bucketTile),
                  if (reminders.isNotEmpty) ...[
                    const Divider(height: 32, color: HD.hairline),
                    Text(l.hDebtAgingNeedsReminder(reminders.length),
                        style: HD.eyebrow(color: HD.inkMuted)),
                    const SizedBox(height: 12),
                    ...reminders.map(_reminderTile),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _bucketTile(DebtAgingBucket b) {
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        border: Border.all(color: HD.hairline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.hDebtAgingBucketDays(b.bucket), style: HD.body()),
                Text(l.hDebtAgingInvoiceCount(b.count),
                    style: HD.caption(color: HD.inkMuted)),
              ],
            ),
          ),
          VndText(b.totalAmount,
              style: HD.tabular(color: HD.ink).copyWith(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _reminderTile(NeedsReminderItem it) {
    final l = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${it.roomCode} • ${it.tenantName}', style: HD.body()),
      subtitle: Text(l.hDebtAgingOverdue(it.daysOverdue, it.tenantPhone),
          style: HD.caption(color: HD.inkMuted)),
      trailing: VndText(it.amountDue, style: HD.tabular(color: HD.negative)),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                InvoiceDetailScreen(invoiceId: it.invoiceId)),
      ),
    );
  }
}
