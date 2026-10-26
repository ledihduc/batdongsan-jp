import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/data/models/meter_reading_model.dart';
import 'package:house_booking/features/host/billing/providers/meter_reading_provider.dart';
import 'package:house_booking/features/host/billing/widgets/billing_app_bar.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class MeterReadingScreen extends StatefulWidget {
  final int? roomId; // null = list across all rooms
  final String? roomCode;
  const MeterReadingScreen({super.key, this.roomId, this.roomCode});

  @override
  State<MeterReadingScreen> createState() => _MeterReadingScreenState();
}

class _MeterReadingScreenState extends State<MeterReadingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        context.read<MeterReadingProvider>().fetchReadings(roomId: widget.roomId));
  }

  Future<void> _openCreate() async {
    final l = AppLocalizations.of(context);
    if (widget.roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hMeterOpenFromRoomHint)),
      );
      return;
    }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReadingFormSheet(roomId: widget.roomId!),
    );
    if (ok == true && mounted) {
      await context
          .read<MeterReadingProvider>()
          .fetchReadings(roomId: widget.roomId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prov = context.watch<MeterReadingProvider>();
    final title = widget.roomCode != null
        ? l.hMeterTitleRoom(widget.roomCode!)
        : l.hMeterTitle;

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: billingAppBar(title, actions: [
        IconButton(
            tooltip: l.hMeterAddTooltip,
            icon: const Icon(Icons.add), onPressed: _openCreate),
      ]),
      body: Column(
        children: [
          if (prov.isLoading) const LinearProgressIndicator(),
          if (prov.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child:
                  Text(prov.error!, style: HD.caption(color: HD.negative)),
            ),
          Expanded(child: _list(prov.readings)),
        ],
      ),
    );
  }

  Widget _list(List<MeterReadingModel> readings) {
    final l = AppLocalizations.of(context);
    if (readings.isEmpty) {
      return Center(
        child: Text(l.hMeterEmpty, style: HD.body(color: HD.inkMuted)),
      );
    }
    return ListView.separated(
      itemCount: readings.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: HD.hairline),
      itemBuilder: (_, i) {
        final r = readings[i];
        return ListTile(
          tileColor: HD.paperRaised,
          title: Text(r.readingDate, style: HD.bodyBold()),
          subtitle: Text(
              l.hMeterUsageLine(r.electricityKwh.toStringAsFixed(0),
                  r.waterM3.toStringAsFixed(1)),
              style: HD.caption()),
        );
      },
    );
  }
}

class _ReadingFormSheet extends StatefulWidget {
  final int roomId;
  const _ReadingFormSheet({required this.roomId});

  @override
  State<_ReadingFormSheet> createState() => _ReadingFormSheetState();
}

class _ReadingFormSheetState extends State<_ReadingFormSheet> {
  static final _iso = DateFormat('yyyy-MM-dd');
  String _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final _elecCtrl = TextEditingController();
  final _waterCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _elecCtrl.dispose();
    _waterCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_date),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('vi'),
    );
    if (picked == null) return;
    setState(() => _date = _iso.format(picked));
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final elec = double.tryParse(_elecCtrl.text) ?? 0;
    final water = double.tryParse(_waterCtrl.text) ?? 0;
    setState(() => _saving = true);
    final r = await context.read<MeterReadingProvider>().createReading(
          roomId: widget.roomId,
          readingDate: _date,
          electricityKwh: elec,
          waterM3: water,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (r != null) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.read<MeterReadingProvider>().error ??
                l.hMeterSaveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.hMeterFormTitle, style: HD.eyebrow(color: HD.inkMuted)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(
                  labelText: l.hMeterReadingDate,
                  border: const OutlineInputBorder()),
              child: Text(_date),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _elecCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: l.hMeterElectricity,
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _waterCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: l.hMeterWater,
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.hMeterSave),
          ),
        ],
      ),
    );
  }
}
