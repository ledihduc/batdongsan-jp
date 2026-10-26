/// Widget tests for KpiCard — label, value, delta chip, tap, error icon.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/host/analytics/widgets/kpi_card.dart';
import 'package:house_booking/features/host/analytics/widgets/delta_chip.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('KpiCard', () {
    testWidgets('renders label and formatted value', (tester) async {
      await _pump(
        tester,
        const KpiCard(
          label: 'DOANH THU GỘP',
          value: '5 tr',
        ),
      );
      expect(find.text('DOANH THU GỘP'), findsOneWidget);
      expect(find.text('5 tr'), findsOneWidget);
    });

    testWidgets('renders DeltaChip with positive delta', (tester) async {
      await _pump(
        tester,
        const KpiCard(
          label: 'DOANH THU GỘP',
          value: '5 tr',
          deltaPct: 12.5,
        ),
      );
      expect(find.byType(DeltaChip), findsOneWidget);
      expect(find.text('+12.5%'), findsOneWidget);
    });

    testWidgets('renders DeltaChip with null delta → shows "—"',
        (tester) async {
      await _pump(
        tester,
        const KpiCard(
          label: 'DOANH THU GỘP',
          value: '5 tr',
          deltaPct: null,
        ),
      );
      expect(find.byType(DeltaChip), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('tap callback fires on tap', (tester) async {
      var tapped = false;
      await _pump(
        tester,
        KpiCard(
          label: 'ADR',
          value: '800k',
          onTap: () => tapped = true,
        ),
      );
      await tester.tap(find.byType(KpiCard));
      expect(tapped, isTrue);
    });

    testWidgets('no tap callback — no chevron icon', (tester) async {
      await _pump(
        tester,
        const KpiCard(label: 'ADR', value: '800k'),
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('onTap set → shows chevron icon', (tester) async {
      await _pump(
        tester,
        KpiCard(label: 'ADR', value: '800k', onTap: () {}),
      );
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('hasError=true → warning icon visible', (tester) async {
      await _pump(
        tester,
        const KpiCard(
          label: 'ĐẶT PHÒNG MỚI',
          value: '—',
          hasError: true,
        ),
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('hasError=false → no warning icon', (tester) async {
      await _pump(
        tester,
        const KpiCard(
          label: 'ĐẶT PHÒNG MỚI',
          value: '12',
        ),
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('goalProgress shows GoalProgressBar', (tester) async {
      await _pump(
        tester,
        const KpiCard(
          label: 'DOANH THU GỘP',
          value: '5 tr',
          goalProgress: 0.65,
          goalRevenue: 5000000,
          goalTarget: 7692307,
        ),
      );
      // Progress bar indicator should be present
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // Goal label contains "mục tiêu"
      expect(find.textContaining('mục tiêu'), findsOneWidget);
    });

    testWidgets('no goalProgress → no progress bar', (tester) async {
      await _pump(
        tester,
        const KpiCard(label: 'DOANH THU GỘP', value: '5 tr'),
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('minimum tap target is at least 44pt height', (tester) async {
      await _pump(
        tester,
        const KpiCard(label: 'ADR', value: '800k'),
      );
      final box = tester.getSize(find.byType(KpiCard));
      expect(box.height, greaterThanOrEqualTo(44));
    });

    testWidgets('1.25M formats via CurrencyFormatter abbreviated',
        (tester) async {
      // Verify "1,25 tr" renders (CurrencyFormatter integration)
      // The card takes pre-formatted string from parent — just verifies passthrough.
      await _pump(
        tester,
        const KpiCard(label: 'DOANH THU GỘP', value: '1,25 tr'),
      );
      expect(find.text('1,25 tr'), findsOneWidget);
    });
  });
}
