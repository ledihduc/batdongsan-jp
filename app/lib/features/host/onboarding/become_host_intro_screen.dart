import 'package:flutter/material.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/core/widgets/ds_app_bar.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/onboarding/step1_info_screen.dart'
    show HostOnboardingStep1Screen;

/// Editorial "Trở thành chủ nhà" intro — appears when a guest taps the
/// upgrade CTA on the profile tab. Shows the benefits + a single primary
/// action that opens the existing onboarding flow.
class BecomeHostIntroScreen extends StatelessWidget {
  const BecomeHostIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: l.hIntroAppBarTitle,
        titleAsSerif: false,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Masthead(),
          const _BenefitsSection(),
          const SizedBox(height: HD.s24),
          _CtaSection(onStart: () => _start(context)),
          const SizedBox(height: HD.s40),
        ],
      ),
    );
  }

  void _start(BuildContext context) {
    // pushReplacement (not push) is INTENTIONAL: this intro is a marketing
    // splash, not part of the onboarding form. Once the user commits ("BẮT
    // ĐẦU ĐĂNG KÝ"), backing out of Step 1 should return to Profile — not
    // re-show the splash they just dismissed. If they want the splash back
    // they tap the "Trở thành chủ nhà" CTA on Profile again.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HostOnboardingStep1Screen()),
    );
  }
}

class _Masthead extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HD.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(HD.s20, HD.s24, HD.s20, HD.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 22, height: 1, color: HD.accent),
              const SizedBox(width: HD.s8),
              Text(l.hIntroEyebrow, style: HD.eyebrow(color: HD.accent)),
            ],
          ),
          const SizedBox(height: HD.s12),
          Text(
            l.hIntroHeadline,
            style: HD.mastheadItalic(color: HD.ink).copyWith(fontSize: 38),
          ),
          const SizedBox(height: HD.s12),
          Text(
            l.hIntroSubtitle,
            style: HD.body(size: 13, color: HD.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _BenefitsSection extends StatelessWidget {
  const _BenefitsSection();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = <(String, String, String)>[
      ('01', l.hIntroBenefit1Title, l.hIntroBenefit1Body),
      ('02', l.hIntroBenefit2Title, l.hIntroBenefit2Body),
      ('03', l.hIntroBenefit3Title, l.hIntroBenefit3Body),
      ('04', l.hIntroBenefit4Title, l.hIntroBenefit4Body),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(HD.s20, HD.s24, HD.s20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 14, height: 1, color: HD.inkMuted),
              const SizedBox(width: HD.s8),
              Text(l.hIntroBenefitsLabel,
                  style: HD.eyebrow(color: HD.inkMuted)),
            ],
          ),
          const SizedBox(height: HD.s8),
          for (var i = 0; i < items.length; i++) ...[
            _BenefitRow(
              index: items[i].$1,
              title: items[i].$2,
              body: items[i].$3,
            ),
            if (i < items.length - 1) const HDHairline(),
          ],
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.index,
    required this.title,
    required this.body,
  });

  final String index;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HD.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text(index,
                style: HD.bigNumeral(color: HD.accent).copyWith(fontSize: 22)),
          ),
          const SizedBox(width: HD.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: HD.bodyBold(size: 14)),
                const SizedBox(height: HD.s4),
                Text(body, style: HD.body(size: 12, color: HD.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CtaSection extends StatelessWidget {
  const _CtaSection({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HD.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onStart,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: HD.s16),
              decoration: BoxDecoration(
                color: HD.accent,
                border: Border.all(color: HD.accent),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l.hIntroCta,
                      style: HD.eyebrow(color: HD.paperRaised)
                          .copyWith(fontSize: 12, letterSpacing: 1.8)),
                  const SizedBox(width: HD.s8),
                  const Icon(Icons.arrow_forward,
                      size: 14, color: HD.paperRaised),
                ],
              ),
            ),
          ),
          const SizedBox(height: HD.s12),
          Text(
            l.hIntroCtaNote,
            textAlign: TextAlign.center,
            style: HD.body(size: 11, color: HD.inkMuted),
          ),
        ],
      ),
    );
  }
}
