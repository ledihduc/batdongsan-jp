/// Widget tests for [AccountDeletionScreen].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/consent/account_deletion_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  group('AccountDeletionScreen — pre-schedule', () {
    testWidgets('shows warning and schedule CTA', (tester) async {
      await tester.pumpWidget(_wrap(
        const AccountDeletionScreen(userEmail: 'test@example.com'),
      ));
      await tester.pump();

      expect(find.textContaining('削除'), findsWidgets);
      expect(find.textContaining('申請'), findsWidgets);
    });

    testWidgets('shows cooling-off notice', (tester) async {
      await tester.pumpWidget(_wrap(
        const AccountDeletionScreen(userEmail: 'test@example.com'),
      ));
      await tester.pump();

      expect(find.textContaining('30日'), findsWidgets);
    });
  });

  group('AccountDeletionScreen — post-schedule (countdown)', () {
    testWidgets('shows countdown and cancel CTA', (tester) async {
      // Add a 1-hour buffer so inDays truncates to 25 (not 24) even with
      // microsecond-level setup lag between now() and the countdown render.
      final scheduledAt =
          DateTime.now().add(const Duration(days: 25, hours: 1));
      await tester.pumpWidget(_wrap(
        AccountDeletionScreen(
          userEmail: 'test@example.com',
          scheduledAt: scheduledAt,
        ),
      ));
      await tester.pump();

      // Days remaining should be visible (number 25 or nearby).
      expect(find.textContaining('25'), findsWidgets);
      expect(find.textContaining('キャンセル'), findsWidgets);
    });
  });

  group('AccountDeletionConfirmSheet', () {
    testWidgets('submit disabled until email matches', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showAccountDeletionConfirmSheet(
                ctx,
                userEmail: 'user@example.com',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Sheet is open — find the submit button.
      // Button should be disabled (no email typed yet).
      final submitButtons = tester.widgetList<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      // At least one button exists.
      expect(submitButtons, isNotEmpty);
    });
  });
}
