import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/core/widgets/ds_app_bar.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/marketplace/providers/marketplace_provider.dart';

/// Phase 08 — wrap-around screen invoked from the appointment row that confirms
/// the host wants to convert a viewing appointment into a draft Contract.
class CreateContractFromApptScreen extends StatefulWidget {
  const CreateContractFromApptScreen({
    super.key,
    required this.appointmentId,
    required this.guestName,
    required this.houseTitle,
  });

  final int appointmentId;
  final String guestName;
  final String houseTitle;

  @override
  State<CreateContractFromApptScreen> createState() =>
      _CreateContractFromApptScreenState();
}

class _CreateContractFromApptScreenState
    extends State<CreateContractFromApptScreen> {
  bool _submitting = false;

  Future<void> _confirm() async {
    final l = AppLocalizations.of(context);
    setState(() => _submitting = true);
    final prov = context.read<MarketplaceProvider>();
    final result = await prov.createContractFromAppointment(widget.appointmentId);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(prov.error ?? l.hCreateContractError)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l.hCreateContractCreatedDraft(
            result.contractId,
            result.placeholderTenant ? l.hCreateContractPlaceholderTenant : '',
          ),
        ),
      ),
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: l.hCreateContractTitle,
      ),
      body: ListView(
        padding: const EdgeInsets.all(HD.s20),
        children: [
          Text(l.hCreateContractViewRequestEyebrow, style: HD.eyebrow()),
          const SizedBox(height: HD.s4),
          Text(widget.houseTitle, style: HD.masthead()),
          const SizedBox(height: HD.s24),
          _row(l.hCreateContractGuest, widget.guestName),
          _row(l.hCreateContractRequestCode, '#${widget.appointmentId}'),
          const SizedBox(height: HD.s24),
          Container(
            padding: const EdgeInsets.all(HD.s16),
            decoration: BoxDecoration(
              color: HD.paperRaised,
              border: Border.all(color: HD.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.hCreateContractWhatHappens, style: HD.eyebrow()),
                const SizedBox(height: HD.s8),
                Text(
                  l.hCreateContractWhatHappensBody,
                  style: HD.body(),
                ),
              ],
            ),
          ),
          const SizedBox(height: HD.s32),
          FilledButton(
            onPressed: _submitting ? null : _confirm,
            style: FilledButton.styleFrom(
              backgroundColor: HD.ink,
              padding: const EdgeInsets.symmetric(vertical: HD.s16),
            ),
            child: Text(_submitting
                ? l.hCreateContractCreating
                : l.hCreateContractConfirm),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label.toUpperCase(), style: HD.eyebrow())),
          Expanded(child: Text(value, style: HD.body())),
        ],
      ),
    );
  }
}
