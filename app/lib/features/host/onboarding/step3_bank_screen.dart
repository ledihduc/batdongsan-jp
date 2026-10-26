import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/features/guest/guest_shell.dart';
import 'package:house_booking/features/host/onboarding/widgets/onboarding_stepper.dart';
import 'package:house_booking/core/widgets/labeled_text_field.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/host_profile_provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Host onboarding Step 3 — Bank account info.
///
/// On submit: PATCH /api/host/profile with bank fields.
/// Then reloads AuthProvider (so role='host' is reflected in the UI).
class HostOnboardingStep3Screen extends StatefulWidget {
  const HostOnboardingStep3Screen({super.key});

  @override
  State<HostOnboardingStep3Screen> createState() => _HostOnboardingStep3ScreenState();
}

class _HostOnboardingStep3ScreenState extends State<HostOnboardingStep3Screen> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();

  static const _banks = [
    'Vietcombank',
    'VietinBank',
    'BIDV',
    'Techcombank',
    'MB Bank',
    'ACB',
    'VPBank',
    'TPBank',
    'Sacombank',
    'HDBank',
    'SHB',
    'OCB',
    'MSB',
    'Khác',
  ];

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountHolderCtrl.dispose();
    _taxIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final profileProvider = context.read<HostProfileProvider>();

    final ok = await profileProvider.updateProfile(
      bankName: _bankNameCtrl.text.trim(),
      bankAccountNumber: _accountNumberCtrl.text.trim(),
      bankAccountHolder: _accountHolderCtrl.text.trim().toUpperCase(),
      taxId: _taxIdCtrl.text.trim().isEmpty ? null : _taxIdCtrl.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      // Bootstrap auth so the new role='host' JWT is reflected in AuthProvider
      await context.read<AuthProvider>().bootstrap();
      if (!mounted) return;

      // New hosts land in Host mode at slot 0 (Tổng quan). Persist the mode
      // so subsequent app starts also boot into the host shell.
      // Chế độ persona ĐÃ BỎ (một shell duy nhất cho mọi tài khoản), nên
      // không còn gì để ghi nhớ ở đây. Hoàn tất onboarding chủ nhà giờ chỉ đổi
      // `role` ở backend; công cụ quản lý nhà hiện ra ngay trong tab Cá nhân.
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const GuestShell()),
        (route) => false,
      );
    } else {
      AppFeedback.error(context,
          profileProvider.error ?? AppLocalizations.of(context).hStep3SaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HostProfileProvider>();
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        eyebrow: l.hStep3Eyebrow,
        title: l.hStep3Title,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(HD.s20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OnboardingStepper(currentStep: 3),
              const SizedBox(height: HD.s16),
              Text(
                l.hStep3ReceivingAccount,
                textAlign: TextAlign.center,
                style: HD.sectionTitle(size: 20),
              ),
              const SizedBox(height: HD.s4),
              Text(
                l.hStep3Subtitle,
                textAlign: TextAlign.center,
                style: HD.body(size: 12, color: HD.inkMuted),
              ),
              const SizedBox(height: HD.s24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.hStep3BankLabel.toUpperCase(),
                      style: HD.eyebrow(color: HD.inkSoft)),
                  const SizedBox(height: HD.s8),
                  DropdownButtonFormField<String>(
                    style: HD.body(size: 15, color: HD.ink),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: HD.paperRaised,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: HD.s16, vertical: HD.s12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(HD.r8),
                        borderSide: const BorderSide(color: HD.hairline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(HD.r8),
                        borderSide: const BorderSide(color: HD.hairline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(HD.r8),
                        borderSide:
                            const BorderSide(color: HD.accent, width: 1.5),
                      ),
                    ),
                    hint: Text(l.hStep3BankHint,
                        style: HD.body(size: 14, color: HD.inkMuted)),
                    items: _banks
                        .map((b) =>
                            DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    validator: (v) =>
                        v == null ? l.hStep3BankRequired : null,
                    onChanged: (v) {
                      if (v != null) _bankNameCtrl.text = v;
                    },
                  ),
                ],
              ),
              const SizedBox(height: HD.s16),
              LabeledTextField(
                label: l.hStep3AccountNumber,
                controller: _accountNumberCtrl,
                hint: '1234567890',
                isRequired: true,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return l.hStep3AccountNumberRequired;
                  }
                  if (v.trim().length < 6) return l.hStep3AccountNumberInvalid;
                  return null;
                },
              ),
              const SizedBox(height: HD.s16),
              LabeledTextField(
                label: l.hStep3AccountHolder,
                controller: _accountHolderCtrl,
                hint: 'NGUYEN VAN A',
                isRequired: true,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l.hStep3AccountHolderRequired
                    : null,
              ),
              const SizedBox(height: HD.s16),
              LabeledTextField(
                label: l.hStep3TaxId,
                controller: _taxIdCtrl,
                hint: '0123456789',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: HD.s32),
              DsButton(
                label: l.hStep3SubmitButton,
                variant: DsButtonVariant.primary,
                size: DsButtonSize.large,
                expand: true,
                icon: Icons.check_circle_outline,
                isLoading: provider.isLoading,
                onPressed: provider.isLoading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
