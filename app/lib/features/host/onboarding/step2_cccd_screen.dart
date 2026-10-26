import 'package:image_picker/image_picker.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/features/host/onboarding/step3_bank_screen.dart';
import 'package:house_booking/features/host/onboarding/widgets/onboarding_stepper.dart';
import 'package:house_booking/features/host/onboarding/widgets/cccd_uploader.dart';
import 'package:house_booking/providers/host_profile_provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Host onboarding Step 2 — CCCD (national ID card) front + back upload.
class HostOnboardingStep2Screen extends StatefulWidget {
  const HostOnboardingStep2Screen({super.key});

  @override
  State<HostOnboardingStep2Screen> createState() => _HostOnboardingStep2ScreenState();
}

class _HostOnboardingStep2ScreenState extends State<HostOnboardingStep2Screen> {
  XFile? _front;
  XFile? _back;

  Future<void> _upload() async {
    final l = AppLocalizations.of(context);
    if (_front == null && _back == null) {
      AppFeedback.warning(context, l.hStep2WarnAtLeastOne);
      return;
    }

    final provider = context.read<HostProfileProvider>();
    final ok = await provider.uploadCccd(front: _front, back: _back);

    if (!mounted) return;
    if (ok) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HostOnboardingStep3Screen()),
      );
    } else {
      AppFeedback.error(context, provider.error ?? l.hStep2UploadFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = context.watch<HostProfileProvider>();

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        eyebrow: l.hStep2Eyebrow,
        title: l.hStep2Title,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(HD.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const OnboardingStepper(currentStep: 2),
            const SizedBox(height: HD.s16),
            Text(
              l.hStep2Heading,
              textAlign: TextAlign.center,
              style: HD.sectionTitle(size: 20),
            ),
            const SizedBox(height: HD.s4),
            Text(
              l.hStep2Subtitle,
              textAlign: TextAlign.center,
              style: HD.body(size: 12, color: HD.inkMuted),
            ),
            const SizedBox(height: HD.s24),
            CccdUploader(
              label: l.hStep2FrontLabel,
              isUploaded: provider.profile?.cccdFrontUploaded ?? false,
              onImageSelected: (file) => setState(() => _front = file),
            ),
            const SizedBox(height: HD.s20),
            CccdUploader(
              label: l.hStep2BackLabel,
              isUploaded: provider.profile?.cccdBackUploaded ?? false,
              onImageSelected: (file) => setState(() => _back = file),
            ),
            const SizedBox(height: HD.s12),
            Container(
              padding: const EdgeInsets.all(HD.s12),
              decoration: BoxDecoration(
                color: HD.warningTint,
                borderRadius: BorderRadius.circular(HD.r8),
                border: Border.all(color: HD.warning.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline, size: 16, color: HD.warning),
                  const SizedBox(width: HD.s8),
                  Expanded(
                    child: Text(
                      l.hStep2SecurityNote,
                      style: HD.caption(color: HD.warning),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: HD.s32),
            DsButton(
              label: l.hStep2Next,
              variant: DsButtonVariant.primary,
              size: DsButtonSize.large,
              expand: true,
              isLoading: provider.isLoading,
              onPressed: provider.isLoading ? null : _upload,
            ),
          ],
        ),
      ),
    );
  }
}
