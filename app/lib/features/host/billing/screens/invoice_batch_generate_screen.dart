import 'package:flutter/material.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/features/host/billing/providers/invoice_provider.dart';
import 'package:house_booking/features/host/billing/widgets/billing_app_bar.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';

/// Generate-batch screen — select building + month, POST generate-batch.
/// Returns the number of invoices created via Navigator.pop.
class InvoiceBatchGenerateScreen extends StatefulWidget {
  const InvoiceBatchGenerateScreen({super.key});

  @override
  State<InvoiceBatchGenerateScreen> createState() =>
      _InvoiceBatchGenerateScreenState();
}

class _InvoiceBatchGenerateScreenState
    extends State<InvoiceBatchGenerateScreen> {
  int? _buildingId;
  String? _month; // YYYY-MM
  // Để TRỐNG, cố ý. Điền sẵn 3500/15000 nghĩa là mọi lô đều ghi đè giá riêng
  // của từng phòng — giá khai ở phòng có cũng như không. Trống = hỏi từng phòng.
  final _elecCtrl = TextEditingController();
  final _waterCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BuildingProvider>().fetchBuildings();
    });
  }

  @override
  void dispose() {
    _elecCtrl.dispose();
    _waterCtrl.dispose();
    super.dispose();
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
    setState(() =>
        _month = '${picked.year}-${picked.month.toString().padLeft(2, '0')}');
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (_buildingId == null || _month == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hInvBatchSelectRequired)),
      );
      return;
    }
    setState(() => _submitting = true);
    final created = await context.read<InvoiceProvider>().generateBatch(
          buildingId: _buildingId!,
          month: _month!,
          electricityUnitPrice: double.tryParse(_elecCtrl.text.trim()),
          waterUnitPrice: double.tryParse(_waterCtrl.text.trim()),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (created != null) {
      Navigator.pop(context, created.length);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                context.read<InvoiceProvider>().error ??
                    l.hInvBatchCreateFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final buildings = context.watch<BuildingProvider>().buildings;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: billingAppBar(l.hInvBatchTitle),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _label(l.hInvBatchBuildingLabel),
          DropdownButtonFormField<int>(
            initialValue: _buildingId,
            items: buildings
                .map((b) => DropdownMenuItem<int>(
                      value: b.id,
                      child: Text(b.name),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _buildingId = v),
            decoration: const InputDecoration(border: OutlineInputBorder()),
            hint: Text(l.hInvBatchSelectBuilding),
          ),
          const SizedBox(height: 16),
          _label(l.hInvBatchMonthLabel),
          GestureDetector(
            onTap: _pickMonth,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: HD.hairline),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 16),
                  const SizedBox(width: 8),
                  Text(_month ?? l.hInvBatchSelectMonth,
                      style: HD.body(
                          color: _month != null ? HD.ink : HD.inkMuted)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _label(l.hInvBatchElecPriceLabel),
          TextField(
            controller: _elecCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Bỏ trống = theo giá từng phòng',
            ),
          ),
          const SizedBox(height: 12),
          _label(l.hInvBatchWaterPriceLabel),
          TextField(
            controller: _waterCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Bỏ trống = theo giá từng phòng',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.hInvBatchGenerateButton),
          ),
          const SizedBox(height: 12),
          Text(
            l.hInvBatchHelpText,
            style: HD.caption(color: HD.inkMuted),
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
