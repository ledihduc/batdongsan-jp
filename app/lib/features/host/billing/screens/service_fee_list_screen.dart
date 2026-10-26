import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/service_fee_model.dart';
import 'package:house_booking/features/host/billing/providers/service_fee_provider.dart';
import 'package:house_booking/features/host/billing/widgets/billing_app_bar.dart';
import 'package:house_booking/features/host/billing/widgets/vnd_text.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';

class ServiceFeeListScreen extends StatefulWidget {
  const ServiceFeeListScreen({super.key});

  @override
  State<ServiceFeeListScreen> createState() => _ServiceFeeListScreenState();
}

class _ServiceFeeListScreenState extends State<ServiceFeeListScreen> {
  int? _buildingFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<BuildingProvider>().fetchBuildings();
      await context
          .read<ServiceFeeProvider>()
          .fetchServiceFees(buildingId: _buildingFilter);
    });
  }

  Future<void> _openCreate() async {
    final l = AppLocalizations.of(context);
    final buildings = context.read<BuildingProvider>().buildings;
    if (buildings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hFeeCreateBuildingFirst)),
      );
      return;
    }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateFeeSheet(
        buildings: buildings.map((b) => (b.id, b.name)).toList(),
      ),
    );
    if (ok == true && mounted) {
      await context
          .read<ServiceFeeProvider>()
          .fetchServiceFees(buildingId: _buildingFilter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prov = context.watch<ServiceFeeProvider>();
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: billingAppBar(l.hFeeTitle, actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: _openCreate),
      ]),
      body: _body(prov),
    );
  }

  Widget _body(ServiceFeeProvider prov) {
    if (prov.isLoading && prov.serviceFees.isEmpty) {
      return const Center(child: DsRowSkeleton());
    }
    if (prov.error != null && prov.serviceFees.isEmpty) {
      return DsErrorState(
        message: prov.error!,
        onRetry: () => context.read<ServiceFeeProvider>().fetchServiceFees(buildingId: _buildingFilter),
      );
    }
    return _list(prov.serviceFees);
  }

  Widget _list(List<ServiceFeeModel> fees) {
    final l = AppLocalizations.of(context);
    if (fees.isEmpty) {
      return DsEmptyState(
        icon: Icons.receipt_outlined,
        title: l.hFeeEmptyTitle,
        subtitle: l.hFeeEmptySubtitle,
      );
    }
    return ListView.separated(
      itemCount: fees.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: HD.hairline),
      itemBuilder: (_, i) {
        final f = fees[i];
        return ListTile(
          tileColor: HD.paperRaised,
          title: Text(f.name, style: HD.bodyBold()),
          subtitle: Text(
              '${f.billingCycle == 'monthly' ? l.hFeeMonthly : l.hFeeOneTime} • ${f.isActive ? l.hFeeActive : l.hFeeInactive}',
              style: HD.caption()),
          trailing: VndText(f.unitPrice, style: HD.tabular()),
          onTap: () => _toggleActive(f),
        );
      },
    );
  }

  Future<void> _toggleActive(ServiceFeeModel f) async {
    await context
        .read<ServiceFeeProvider>()
        .updateServiceFee(f.id, isActive: !f.isActive);
  }
}

class _CreateFeeSheet extends StatefulWidget {
  final List<(int, String)> buildings;
  const _CreateFeeSheet({required this.buildings});

  @override
  State<_CreateFeeSheet> createState() => _CreateFeeSheetState();
}

class _CreateFeeSheetState extends State<_CreateFeeSheet> {
  int? _buildingId;
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  String _cycle = 'monthly';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.buildings.isNotEmpty) _buildingId = widget.buildings.first.$1;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (_buildingId == null || _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hFeeEnterNameBuilding)),
      );
      return;
    }
    setState(() => _saving = true);
    final f = await context.read<ServiceFeeProvider>().createServiceFee(
          buildingId: _buildingId!,
          name: _nameCtrl.text.trim(),
          unitPrice: double.tryParse(_priceCtrl.text) ?? 0,
          billingCycle: _cycle,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (f != null) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                context.read<ServiceFeeProvider>().error ?? l.hFeeSaveFailed)),
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
          Text(l.hFeeCreateTitle, style: HD.eyebrow(color: HD.inkMuted)),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _buildingId,
            items: widget.buildings
                .map((b) => DropdownMenuItem<int>(
                      value: b.$1,
                      child: Text(b.$2),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _buildingId = v),
            decoration: InputDecoration(
                labelText: l.hFeeBuilding, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
                labelText: l.hFeeServiceName,
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: l.hFeeUnitPrice,
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _cycle,
            items: [
              DropdownMenuItem(value: 'monthly', child: Text(l.hFeeMonthly)),
              DropdownMenuItem(value: 'one_time', child: Text(l.hFeeOneTime)),
            ],
            onChanged: (v) => setState(() => _cycle = v ?? 'monthly'),
            decoration: InputDecoration(
                labelText: l.hFeeCycle, border: const OutlineInputBorder()),
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
                : Text(l.hFeeSave),
          ),
        ],
      ),
    );
  }
}
