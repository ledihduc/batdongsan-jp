import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/data/models/invoice_model.dart';
import 'package:house_booking/features/host/billing/providers/invoice_provider.dart';
import 'package:house_booking/features/host/billing/widgets/billing_app_bar.dart';
import 'package:house_booking/features/host/billing/widgets/vnd_text.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

class InvoicePayScreen extends StatefulWidget {
  final InvoiceModel invoice;
  const InvoicePayScreen({super.key, required this.invoice});

  @override
  State<InvoicePayScreen> createState() => _InvoicePayScreenState();
}

class _InvoicePayScreenState extends State<InvoicePayScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _method = 'cash';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text =
        widget.invoice.remainingAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hInvPayInvalidAmount)),
      );
      return;
    }
    setState(() => _saving = true);
    final updated = await context.read<InvoiceProvider>().recordPayment(
          widget.invoice.id,
          amount: amount,
          method: _method,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (updated != null) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.read<InvoiceProvider>().error ??
                l.hInvPayRecordFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final inv = widget.invoice;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: billingAppBar(l.hInvPayTitle),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(inv.invoiceNumber, style: HD.sectionTitle()),
          const SizedBox(height: 8),
          Row(children: [
            Text(l.hInvPayRemaining, style: HD.body()),
            VndText(inv.remainingAmount,
                style: HD.bodyBold(color: HD.negative)),
          ]),
          const SizedBox(height: 24),
          _label(l.hInvPayAmountLabel),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          _label(l.hInvPayMethodLabel),
          DropdownButtonFormField<String>(
            initialValue: _method,
            items: [
              DropdownMenuItem(value: 'cash', child: Text(l.hInvPayMethodCash)),
              DropdownMenuItem(
                  value: 'bank_transfer', child: Text(l.hInvPayMethodBank)),
              DropdownMenuItem(value: 'other', child: Text(l.hInvPayMethodOther)),
            ],
            onChanged: (v) => setState(() => _method = v ?? 'cash'),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          _label(l.hInvPayNoteLabel),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.hInvPaySubmit),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: HD.eyebrow(color: HD.inkMuted)),
      );
}
