import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/data/models/invoice_model.dart';
import 'package:house_booking/features/host/billing/providers/invoice_provider.dart';
import 'package:house_booking/features/host/billing/widgets/billing_app_bar.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class CreditNoteFormScreen extends StatefulWidget {
  final InvoiceModel invoice;
  const CreditNoteFormScreen({super.key, required this.invoice});

  @override
  State<CreditNoteFormScreen> createState() => _CreditNoteFormScreenState();
}

class _CreditNoteFormScreenState extends State<CreditNoteFormScreen> {
  static final _iso = DateFormat('yyyy-MM-dd');
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String _issuedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_issuedDate),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('vi'),
    );
    if (picked == null) return;
    setState(() => _issuedDate = _iso.format(picked));
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hCreditNoteInvalidAmount)),
      );
      return;
    }
    setState(() => _saving = true);
    final note = await context.read<InvoiceProvider>().issueCreditNote(
          widget.invoice.id,
          amount: amount,
          reason: _reasonCtrl.text.trim(),
          issuedDate: _issuedDate,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (note != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hCreditNoteCreated)),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                context.read<InvoiceProvider>().error ?? l.hCreditNoteFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final inv = widget.invoice;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: billingAppBar(l.hCreditNoteTitle),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(inv.invoiceNumber, style: HD.sectionTitle()),
          const SizedBox(height: 4),
          Text(
            l.hCreditNoteDescription,
            style: HD.caption(color: HD.inkMuted),
          ),
          const SizedBox(height: 24),
          _label(l.hCreditNoteAmountLabel),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          _label(l.hCreditNoteIssuedDateLabel),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: HD.hairline),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 16),
                const SizedBox(width: 8),
                Text(_issuedDate, style: HD.body()),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          _label(l.hCreditNoteReasonLabel),
          TextField(
            controller: _reasonCtrl,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            maxLines: 3,
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
                : Text(l.hCreditNoteSubmit),
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
