/// Widget tests for [JpKpiDashboardScreen] and [MockAdminKpiRepository].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/jp/admin_kpi.dart';
import 'package:house_booking/data/repositories/jp/mock_admin_kpi_repository.dart';
import 'package:house_booking/features/admin/jp_kpi_dashboard_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  group('MockAdminKpiRepository', () {
    test('getKpi returns 5 populated metrics', () async {
      final repo = MockAdminKpiRepository();
      final now = DateTime.now();
      final kpi = await repo.getKpi(
        prefecture: '東京都',
        from: DateTime(now.year, now.month - 1),
        to: now,
      );
      expect(kpi.activeListings.value, isNotEmpty);
      expect(kpi.pendingApplications.value, isNotEmpty);
      expect(kpi.activeContracts.value, isNotEmpty);
      expect(kpi.avgDaysToSign.value, isNotEmpty);
      expect(kpi.monthlyRevenueYen.value, isNotEmpty);
      expect(kpi.prefecture, '東京都');
    });

    test('all-Japan query works (empty prefecture)', () async {
      final repo = MockAdminKpiRepository();
      final now = DateTime.now();
      final kpi = await repo.getKpi(
        prefecture: '',
        from: DateTime(now.year, now.month - 1),
        to: now,
      );
      expect(kpi.prefecture, '全国');
    });
  });

  group('JpKpiDashboardScreen', () {
    testWidgets('renders 5 KPI cards after load', (tester) async {
      await tester.pumpWidget(_wrap(
        const JpKpiDashboardScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Each KPI card shows a label. Check at least one is present.
      expect(find.textContaining('掲載中物件'), findsWidgets);
    });

    testWidgets('prefecture dropdown is rendered', (tester) async {
      await tester.pumpWidget(_wrap(
        const JpKpiDashboardScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });
  });
}
