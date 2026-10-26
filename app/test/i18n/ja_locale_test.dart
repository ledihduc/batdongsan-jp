/// Tests that the ja locale loads without throwing and basic keys are present.
///
/// Verifies that app_ja.arb was correctly parsed and AppLocalizations
/// can be instantiated for the 'ja' locale.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JA locale', () {
    test('AppLocalizations supports ja locale', () {
      expect(
        AppLocalizations.supportedLocales,
        contains(const Locale('ja')),
      );
    });

    testWidgets('ja locale loads without throwing', (tester) async {
      late AppLocalizations l10n;
      bool threw = false;

      try {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                l10n = AppLocalizations.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pump();
      } catch (e) {
        threw = true;
      }

      expect(threw, isFalse, reason: 'ja locale should load without exception');
      // Verify a known key is present and non-empty.
      expect(l10n.appTitle, isNotEmpty);
    });

    testWidgets('priming keys are present in ja locale', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      // Priming keys must exist (even with TODO:JA prefix — they're non-empty).
      expect(l10n.primingBtnEnable, isNotEmpty);
      expect(l10n.primingBtnContinue, isNotEmpty);
      expect(l10n.primingBtnCancel, isNotEmpty);
      expect(l10n.primingTrustNoSpam, isNotEmpty);
    });
  });
}
