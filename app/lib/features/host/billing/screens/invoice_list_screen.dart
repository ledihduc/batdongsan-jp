import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/data/models/invoice_model.dart';
import 'package:house_booking/features/host/billing/providers/invoice_provider.dart';
import 'package:house_booking/features/host/billing/screens/invoice_batch_generate_screen.dart';
import 'package:house_booking/features/host/billing/screens/invoice_detail_screen.dart';
import 'package:house_booking/features/host/billing/widgets/billing_app_bar.dart';
import 'package:house_booking/features/host/billing/widgets/invoice_status_chip.dart';
import 'package:house_booking/features/host/billing/widgets/vnd_text.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  String? _statusFilter;
  String? _monthFilter; // YYYY-MM

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    await context.read<InvoiceProvider>().fetchInvoices(
          status: _statusFilter,
          month: _monthFilter,
        );
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2024, 1),
      lastDate: DateTime(now.year + 1, 12),
      locale: const Locale('vi'),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null) return;
    setState(() => _monthFilter =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}');
    _reload();
  }

  Future<void> _openBatchGenerate() async {
    final created = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const InvoiceBatchGenerateScreen()),
    );
    if (created != null && mounted) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hInvListCreatedCount(created))),
      );
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = context.watch<InvoiceProvider>();
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: billingAppBar(l.hInvListTitle, actions: [
        IconButton(
            tooltip: l.hInvListBatchCreate,
            icon: const Icon(Icons.add_box_outlined),
            onPressed: _openBatchGenerate),
      ]),
      body: Column(
        children: [
          _filterBar(),
          if (provider.isLoading) const LinearProgressIndicator(),
          if (provider.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(provider.error!,
                  style: HD.caption(color: HD.negative)),
            ),
          Expanded(child: _list(provider.invoices)),
        ],
      ),
    );
  }

  Widget _filterBar() {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: HD.hairline))),
      child: Row(
        children: [
          _chip(l.hInvListFilterAll, _statusFilter == null, () {
            setState(() => _statusFilter = null);
            _reload();
          }),
          const SizedBox(width: 6),
          _chip(l.hInvListStatusDraft, _statusFilter == 'draft', () {
            setState(() => _statusFilter = 'draft');
            _reload();
          }),
          const SizedBox(width: 6),
          _chip(l.hInvListStatusSent, _statusFilter == 'sent', () {
            setState(() => _statusFilter = 'sent');
            _reload();
          }),
          const SizedBox(width: 6),
          _chip(l.hInvListStatusPaid, _statusFilter == 'paid', () {
            setState(() => _statusFilter = 'paid');
            _reload();
          }),
          const Spacer(),
          GestureDetector(
            onTap: _pickMonth,
            child: Row(children: [
              const Icon(Icons.calendar_month_outlined, size: 14),
              const SizedBox(width: 4),
              Text(_monthFilter ?? l.hInvListAllMonths, style: HD.caption()),
              if (_monthFilter != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    setState(() => _monthFilter = null);
                    _reload();
                  },
                  child: const Icon(Icons.close, size: 14),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? HD.ink : Colors.transparent,
          border: Border.all(color: selected ? HD.ink : HD.hairline),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label,
            style: HD.caption(color: selected ? Colors.white : HD.ink)),
      ),
    );
  }

  Widget _list(List<InvoiceModel> invoices) {
    final l = AppLocalizations.of(context);
    if (invoices.isEmpty) {
      return Center(
        child: Text(l.hInvListEmpty, style: HD.body(color: HD.inkMuted)),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        itemCount: invoices.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: HD.hairline),
        itemBuilder: (_, i) {
          final inv = invoices[i];
          return ListTile(
            tileColor: HD.paperRaised,
            title: Row(
              children: [
                Text(inv.invoiceNumber, style: HD.bodyBold()),
                const Spacer(),
                InvoiceStatusChip(inv.status),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.hInvListPeriod(inv.periodStart, inv.periodEnd),
                      style: HD.caption(color: HD.inkMuted)),
                  const SizedBox(height: 2),
                  VndText(inv.totalAmount,
                      style: HD.tabular(color: HD.ink)),
                ],
              ),
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoiceDetailScreen(invoiceId: inv.id),
                ),
              );
              if (mounted) _reload();
            },
          );
        },
      ),
    );
  }
}
