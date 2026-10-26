/// Widget tests for [TenantReviewScreen].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/jp/deposit_settlement.dart';
import 'package:house_booking/data/repositories/jp/mock_settlement_repository.dart';
import 'package:house_booking/features/deposit_settlement/tenant_review_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  group('MockSettlementRepository (tenant side)', () {
    test('acceptSettlement transitions to tenantAccepted', () async {
      final repo = MockSettlementRepository();
      await repo.submitToTenant(1); // move to tenantReview first.
      final accepted = await repo.acceptSettlement(1);
      expect(accepted.status, SettlementStatus.tenantAccepted);
    });

    test('disputeSettlement transitions to tenantDisputed with reason', () async {
      final repo = MockSettlementRepository();
      final disputed = await repo.disputeSettlement(1, 'クロス補修は通常損耗です');
      expect(disputed.status, SettlementStatus.tenantDisputed);
      expect(disputed.disputeReason, contains('クロス'));
    });
  });

  group('TenantReviewScreen', () {
    testWidgets('renders deposit amount after load', (tester) async {
      await tester.pumpWidget(_wrap(
        const TenantReviewScreen(settlementId: 1),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // Net refund row should be visible.
      expect(find.textContaining('返金'), findsWidgets);
    });

    testWidgets('shows accept and dispute CTAs for tenantReview status', (tester) async {
      // Seed repo in tenantReview state. tester.runAsync escapes fake clock so
      // the mock's Future.delayed can actually fire during setup.
      final repo = MockSettlementRepository();
      await tester.runAsync(() async {
        await repo.submitToTenant(1);
      });

      await tester.pumpWidget(_wrap(
        TenantReviewScreen(settlementId: 1, repository: repo),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.textContaining('同意'), findsWidgets);
      expect(find.textContaining('異議'), findsWidgets);
    });

    testWidgets('does not show CTAs when already accepted', (tester) async {
      final repo = MockSettlementRepository();
      await tester.runAsync(() async {
        await repo.acceptSettlement(1);
      });

      await tester.pumpWidget(_wrap(
        TenantReviewScreen(settlementId: 1, repository: repo),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // CTAs hidden after accept.
      expect(find.text('精算内容に同意する'), findsNothing);
    });
  });
}
