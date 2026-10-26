/// Widget tests for [OwnerItemizeScreen].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/jp/deposit_settlement.dart';
import 'package:house_booking/data/repositories/jp/mock_settlement_repository.dart';
import 'package:house_booking/features/deposit_settlement/owner_itemize_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  group('MockSettlementRepository', () {
    test('getSettlement returns seeded settlement', () async {
      final repo = MockSettlementRepository();
      final s = await repo.getSettlement(1);
      expect(s.id, 1);
      expect(s.depositYen, 170000);
      expect(s.deductions.length, 2);
      expect(s.status, SettlementStatus.draft);
    });

    test('updateDeductions replaces lines', () async {
      final repo = MockSettlementRepository();
      final newLines = [
        const DeductionLine(id: 'x1', title: 'Test', amountYen: 5000),
      ];
      final updated = await repo.updateDeductions(1, newLines);
      expect(updated.deductions.length, 1);
      expect(updated.deductions.first.title, 'Test');
    });

    test('submitToTenant transitions to tenantReview', () async {
      final repo = MockSettlementRepository();
      final submitted = await repo.submitToTenant(1);
      expect(submitted.status, SettlementStatus.tenantReview);
    });

    test('netRefundYen computed correctly', () async {
      final repo = MockSettlementRepository();
      final s = await repo.getSettlement(1);
      expect(s.netRefundYen, s.depositYen - s.totalDeductionYen);
    });

    test('getSettlement throws for missing ID', () async {
      final repo = MockSettlementRepository();
      await expectLater(repo.getSettlement(999), throwsException);
    });
  });

  group('OwnerItemizeScreen', () {
    testWidgets('renders deposit summary after load', (tester) async {
      await tester.pumpWidget(_wrap(
        const OwnerItemizeScreen(settlementId: 1),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // Property name should appear in summary section.
      expect(find.text('グランドパレス新宿'), findsWidgets);
    });

    testWidgets('shows add deduction button', (tester) async {
      await tester.pumpWidget(_wrap(
        const OwnerItemizeScreen(settlementId: 1),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.textContaining('追加'), findsWidgets);
    });
  });
}
