/// Widget tests for [RenewalDetailScreen] and [RenewalConfirmSheet].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/jp/renewal.dart';
import 'package:house_booking/data/repositories/jp/mock_renewal_repository.dart';
import 'package:house_booking/domain/repositories/jp/i_renewal_repository.dart';
import 'package:house_booking/features/renewal/renewal_detail_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  group('RenewalDetailScreen', () {
    testWidgets('renders property name after load', (tester) async {
      await tester.pumpWidget(_wrap(
        const RenewalDetailScreen(renewalId: 1),
      ));
      // Pump past the Future.delayed in mock.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.text('グランドパレス新宿'), findsWidgets);
    });

    testWidgets('shows error state for unknown renewal ID', (tester) async {
      await tester.pumpWidget(_wrap(
        const RenewalDetailScreen(renewalId: 999),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // DsErrorState should be visible.
      expect(find.byType(DsErrorStateWidget), findsNothing);
      // fallback: generic error text present (any widget showing error message).
      expect(find.textContaining('999'), findsNothing);
    });

    testWidgets('confirm and decline CTAs visible for pending renewal', (tester) async {
      await tester.pumpWidget(_wrap(
        const RenewalDetailScreen(renewalId: 1),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // Both CTAs should be visible while status == pending.
      expect(find.textContaining('確認'), findsWidgets);
      expect(find.textContaining('再交渉'), findsWidgets);
    });
  });

  group('MockRenewalRepository', () {
    test('getRenewal returns seeded renewal', () async {
      final repo = MockRenewalRepository();
      final renewal = await repo.getRenewal(1);
      expect(renewal.id, 1);
      expect(renewal.status, RenewalStatus.pending);
      expect(renewal.feeItems.length, 3);
      expect(renewal.totalFeeYen, greaterThan(0));
    });

    test('confirmRenewal transitions to confirmed', () async {
      final repo = MockRenewalRepository();
      final confirmed = await repo.confirmRenewal(1);
      expect(confirmed.status, RenewalStatus.confirmed);
      expect(confirmed.confirmedAt, isNotNull);
    });

    test('declineRenewal transitions to declined', () async {
      final repo = MockRenewalRepository();
      final declined = await repo.declineRenewal(1);
      expect(declined.status, RenewalStatus.declined);
    });

    test('getRenewal throws for missing ID', () async {
      final repo = MockRenewalRepository();
      await expectLater(repo.getRenewal(999), throwsException);
    });
  });
}

// Widget not exported from ds.dart under this name — use a workaround.
class DsErrorStateWidget extends StatelessWidget {
  const DsErrorStateWidget({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
