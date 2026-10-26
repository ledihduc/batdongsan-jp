/// JP legal footer widget — shown on all JP routes.
///
/// Displays legally required links for Japan market operation:
/// - 特定商取引法に基づく表記 (Act on Specified Commercial Transactions)
/// - 利用規約 (Terms of Service)
/// - プライバシーポリシー (Privacy Policy)
/// - APPI 開示請求 (APPI Disclosure Request)
/// - 運営会社情報 (Operator Company Information)
///
/// Mount in _JpAppShell so every JP route shows this footer.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Legal footer for the Japan market.
///
/// Links open in the in-app browser (external URLs) or navigate internally
/// (/settings/privacy for APPI, /help for help center).
/// The operator company info is a placeholder until the legal entity is confirmed.
class DsLegalFooter extends StatelessWidget {
  const DsLegalFooter({super.key});

  static const String _kActUrl =
      'https://ancu365.jp/legal/tokusho';
  static const String _kTermsUrl =
      'https://ancu365.jp/legal/terms';
  static const String _kPrivacyUrl =
      'https://ancu365.jp/legal/privacy';
  static const String _kOperatorUrl =
      'https://ancu365.jp/legal/company';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      color: HD.paperSunken,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: HD.hairline),
          const SizedBox(height: 12),
          // Row 1: 特定商取引法 / 利用規約 / プライバシーポリシー
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _LegalLink(
                label: l10n.legalFooterTokusho,
                onTap: () => _openUrl(_kActUrl),
              ),
              _separator(),
              _LegalLink(
                label: l10n.legalFooterTerms,
                onTap: () => _openUrl(_kTermsUrl),
              ),
              _separator(),
              _LegalLink(
                label: l10n.legalFooterPrivacy,
                onTap: () => _openUrl(_kPrivacyUrl),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Row 2: APPI / 運営会社情報
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _LegalLink(
                label: l10n.legalFooterAppiRequest,
                // APPI disclosure request uses the in-app consent settings screen.
                onTap: () => context.push('/settings/privacy'),
              ),
              _separator(),
              _LegalLink(
                label: l10n.legalFooterOperator,
                onTap: () => _openUrl(_kOperatorUrl),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.legalFooterCopyright,
            style: const TextStyle(
              fontSize: 10,
              color: HD.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _separator() {
    return const Text(
      '|',
      style: TextStyle(fontSize: 11, color: HD.hairlineStrong),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Non-fatal: browser unavailable. User will notice nothing opened.
    }
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: HD.accentDeep,
          decoration: TextDecoration.underline,
          decorationColor: HD.accentDeep,
        ),
      ),
    );
  }
}
