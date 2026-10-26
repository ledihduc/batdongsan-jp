import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/data/models/invoice_model.dart';
import 'package:house_booking/features/host/billing/providers/invoice_provider.dart';
import 'package:house_booking/features/host/billing/screens/credit_note_form_screen.dart';
import 'package:house_booking/features/host/billing/screens/invoice_pay_screen.dart';
import 'package:house_booking/features/host/billing/widgets/billing_app_bar.dart';
import 'package:house_booking/features/host/billing/widgets/invoice_status_chip.dart';
import 'package:house_booking/features/host/billing/widgets/vnd_text.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/l10n/app_localizations.dart';

const _categoryLabels = <String, String>{
  'rent': 'Tiền thuê',
  'electricity': 'Điện',
  'water': 'Nước',
  'service': 'Dịch vụ',
  'deposit_refund': 'Hoàn cọc',
  'damage_deduction': 'Khấu trừ hư hỏng',
  'adjustment': 'Điều chỉnh',
};

class InvoiceDetailScreen extends StatefulWidget {
  final int invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  InvoiceModel? _inv;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final inv =
        await context.read<InvoiceProvider>().fetchInvoice(widget.invoiceId);
    if (mounted) setState(() => _inv = inv);
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    final upd =
        await context.read<InvoiceProvider>().sendInvoice(widget.invoiceId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (upd != null) _inv = upd;
    });
    if (upd != null) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hInvDetSentSuccess)),
      );
    }
  }

  Future<void> _openPay() async {
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => InvoicePayScreen(invoice: _inv!)),
    );
    if (paid == true) _reload();
  }

  Future<void> _openCreditNote() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CreditNoteFormScreen(invoice: _inv!)),
    );
  }

  Future<void> _openPublicLink() async {
    if (_inv?.publicToken == null) return;
    final url = '${ApiConfig.baseUrl}/public/invoices/${_inv!.publicToken}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hInvDetCannotOpen(url))),
      );
    }
  }

  Future<void> _shareZalo() async {
    final url =
        await context.read<InvoiceProvider>().fetchZaloLink(widget.invoiceId);
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      // Fallback — share via system share sheet
      await Share.share(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final inv = _inv;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: billingAppBar(l.hInvDetTitle),
      body: inv == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Text(inv.invoiceNumber, style: HD.sectionTitle()),
                  const Spacer(),
                  InvoiceStatusChip(inv.status),
                ]),
                const SizedBox(height: 8),
                Text(l.hInvDetPeriod(inv.periodStart, inv.periodEnd),
                    style: HD.caption(color: HD.inkMuted)),
                Text(l.hInvDetDue(inv.dueDate),
                    style: HD.caption(color: HD.inkMuted)),
                const Divider(height: 28, color: HD.hairline),
                Text(l.hInvDetDetails, style: HD.eyebrow(color: HD.inkMuted)),
                const SizedBox(height: 8),
                ...inv.lineItems.map(_lineRow),
                const Divider(height: 28, color: HD.hairline),
                _totalsRow(l.hInvDetTotal, inv.totalAmount, bold: true),
                _totalsRow(l.hInvDetCollected, inv.paidAmount),
                _totalsRow(l.hInvDetRemaining, inv.remainingAmount,
                    color: inv.remainingAmount > 0 ? HD.negative : HD.positive),
                const SizedBox(height: 24),
                _actions(inv),
              ],
            ),
    );
  }

  Widget _lineRow(InvoiceLineItem li) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_categoryLabels[li.category] ?? li.category,
                    style: HD.body()),
                if (li.description.isNotEmpty)
                  Text(li.description,
                      style: HD.caption(color: HD.inkMuted)),
              ],
            ),
          ),
          VndText(li.amount, style: HD.tabular(color: HD.ink)),
        ],
      ),
    );
  }

  Widget _totalsRow(String label, double amount,
      {bool bold = false, Color? color}) {
    final style = bold
        ? HD.bodyBold(color: color ?? HD.ink)
        : HD.body(color: color ?? HD.ink);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          VndText(amount, style: HD.tabular(color: color ?? HD.ink)),
        ],
      ),
    );
  }

  Widget _actions(InvoiceModel inv) {
    final l = AppLocalizations.of(context);
    final canSend = inv.isDraft;
    final canPay = inv.isSent || inv.isOverdue;
    final canCredit = inv.isPaid;
    final canShareLink = inv.publicToken != null;
    final children = <Widget>[];
    if (canSend) {
      children.add(ElevatedButton(
        onPressed: _busy ? null : _send,
        child: Text(l.hInvDetSendInvoice),
      ));
    }
    if (canPay) {
      children.add(ElevatedButton(
        onPressed: _busy ? null : _openPay,
        child: Text(l.hInvDetRecordPayment),
      ));
    }
    if (canShareLink) {
      children.add(OutlinedButton.icon(
        icon: const Icon(Icons.open_in_new),
        onPressed: _openPublicLink,
        label: Text(l.hInvDetOpenPublicLink),
      ));
      children.add(OutlinedButton.icon(
        icon: const Icon(Icons.chat_bubble_outline),
        onPressed: _shareZalo,
        label: Text(l.hInvDetRemindZalo),
      ));
    }
    if (canCredit) {
      children.add(TextButton(
        onPressed: _openCreditNote,
        child: Text(l.hInvDetCreditNote),
      ));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children
            .map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 8), child: w))
            .toList());
  }
}
