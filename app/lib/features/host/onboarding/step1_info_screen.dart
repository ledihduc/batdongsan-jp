import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/features/host/onboarding/step2_cccd_screen.dart';
import 'package:house_booking/features/host/onboarding/widgets/onboarding_stepper.dart';
import 'package:house_booking/core/widgets/labeled_text_field.dart';
import 'package:house_booking/providers/host_profile_provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Host onboarding Step 1 — Basic info (name, DOB, address, phone).
///
/// In Phase 02 scope, this is a UI-only step: info is not sent to the backend
/// separately (the User model already holds name/phone). The step collects
/// acknowledgement before proceeding to CCCD.
class HostOnboardingStep1Screen extends StatefulWidget {
  const HostOnboardingStep1Screen({super.key});

  @override
  State<HostOnboardingStep1Screen> createState() => _HostOnboardingStep1ScreenState();
}

class _HostOnboardingStep1ScreenState extends State<HostOnboardingStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    // Ensure HostProfile exists (idempotent: upgrades guest→host AND creates
    // profile row if missing for existing hosts).
    final ok = await context.read<HostProfileProvider>().upgradeToHost();
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!ok) {
      final l = AppLocalizations.of(context);
      AppFeedback.error(
        context,
        context.read<HostProfileProvider>().error ?? l.hStep1InitError,
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HostOnboardingStep2Screen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        eyebrow: l.hStep1Eyebrow,
        title: l.hStep1Title,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(HD.s20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OnboardingStepper(currentStep: 1),
              const SizedBox(height: HD.s16),
              Text(
                l.hStep1SectionTitle,
                textAlign: TextAlign.center,
                style: HD.sectionTitle(size: 20),
              ),
              const SizedBox(height: HD.s4),
              Text(
                l.hStep1Subtitle,
                textAlign: TextAlign.center,
                style: HD.body(size: 12, color: HD.inkMuted),
              ),
              const SizedBox(height: HD.s24),
              LabeledTextField(
                label: l.hStep1NameLabel,
                controller: _nameCtrl,
                hint: l.hStep1NameHint,
                isRequired: true,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l.hStep1NameError : null,
              ),
              const SizedBox(height: 16),
              LabeledTextField(
                label: l.hStep1PhoneLabel,
                controller: _phoneCtrl,
                hint: '0912345678',
                isRequired: true,
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().length < 9)
                    ? l.hStep1PhoneError
                    : null,
              ),
              const SizedBox(height: 16),
              LabeledTextField(
                label: l.hStep1DobLabel,
                controller: _dobCtrl,
                hint: 'DD/MM/YYYY',
                isRequired: false,
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: 16),
              LabeledTextField(
                label: l.hStep1AddressLabel,
                controller: _addressCtrl,
                hint: l.hStep1AddressHint,
                isRequired: true,
                maxLines: 2,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l.hStep1AddressError
                    : null,
              ),
              const SizedBox(height: HD.s32),
              DsButton(
                label: l.hStep1Next,
                variant: DsButtonVariant.primary,
                size: DsButtonSize.large,
                expand: true,
                isLoading: _submitting,
                onPressed: _submitting ? null : _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
