/// Owner-side screen: invite a new operator to manage a property.
///
/// Flow:
/// 1. Sole-ownership attestation check (AC-64) — shown first time per building
/// 2. Enter operator email + role preset
/// 3. Set approval thresholds (5 inputs via ThresholdConfigWidget, AC-31b)
/// 4. Confirm + send invitation
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/data/models/operator_delegation_model.dart';
import 'package:house_booking/providers/delegation_provider.dart';
import 'package:house_booking/features/host/delegation/threshold_config_widget.dart';
import 'package:house_booking/features/host/onboarding/sole_ownership_attestation_dialog.dart';

class DelegationInviteScreen extends StatefulWidget {
  const DelegationInviteScreen({
    super.key,
    this.buildingId,
  });

  /// Optional building to attest sole ownership for before inviting.
  final String? buildingId;

  @override
  State<DelegationInviteScreen> createState() =>
      _DelegationInviteScreenState();
}

class _DelegationInviteScreenState extends State<DelegationInviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  String _rolePreset = 'operator_full';
  DelegationThresholds _thresholds = const DelegationThresholds();
  bool _isSending = false;
  bool _attestationPassed = false;

  @override
  void initState() {
    super.initState();
    // Show attestation dialog if building is provided and not yet attested.
    if (widget.buildingId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          _checkSoleOwnershipAttestation());
    } else {
      _attestationPassed = true;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _checkSoleOwnershipAttestation() async {
    if (!mounted) return;
    final passed = await SoleOwnershipAttestationDialog.show(
      context,
      buildingId: widget.buildingId!,
    );
    if (!mounted) return;
    if (passed == true) {
      setState(() => _attestationPassed = true);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_attestationPassed) {
      return const Scaffold(
        backgroundColor: HD.paper,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final l = AppLocalizations.of(context);
    final roleOptions = <(String, String)>[
      ('operator_full', l.hDelegInvRoleOperatorFull),
      ('accountant', l.hDelegInvRoleAccountant),
      ('viewer', l.hDelegInvRoleViewer),
    ];

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: l.hDelegInvTitle,
        eyebrow: l.hDelegInvEyebrow,
        compact: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(HD.s20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsFormSection(
                title: l.hDelegInvOperatorInfo,
                children: [
                  DsTextField(
                    controller: _emailController,
                    label: l.hDelegInvOperatorEmail,
                    hint: 'operator@email.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                  ),
                ],
              ),
              const SizedBox(height: HD.s24),
              DsFormSection(
                title: l.hDelegInvPermissions,
                children: [
                  ...roleOptions.map(
                    (opt) => RadioListTile<String>(
                      title: Text(opt.$2, style: HD.body(color: HD.ink)),
                      value: opt.$1,
                      groupValue: _rolePreset,
                      onChanged: (v) {
                        if (v != null) setState(() => _rolePreset = v);
                      },
                      activeColor: HD.accent,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: HD.s24),
              DsFormSection(
                title: l.hDelegInvThresholds,
                children: [
                  ThresholdConfigWidget(
                    initial: _thresholds,
                    onChanged: (t) => setState(() => _thresholds = t),
                  ),
                ],
              ),
              const SizedBox(height: HD.s32),
              DsButton(
                label: l.hDelegInvSend,
                icon: Icons.send_outlined,
                expand: true,
                size: DsButtonSize.large,
                isLoading: _isSending,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final l = AppLocalizations.of(context);
    if (value == null || value.trim().isEmpty) {
      return l.hDelegInvEmailRequired;
    }
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return l.hDelegInvEmailInvalid;
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSending = true);

    final prov = context.read<DelegationProvider>();
    final invitation = await prov.sendInvitation(
      operatorEmail: _emailController.text.trim(),
      rolePreset: _rolePreset,
      thresholds: _thresholds,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    final l = AppLocalizations.of(context);
    if (invitation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.hDelegInvSendSuccess),
          backgroundColor: HD.positive,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(prov.error ?? l.hDelegInvSendFailed),
          backgroundColor: HD.negative,
        ),
      );
    }
  }
}
