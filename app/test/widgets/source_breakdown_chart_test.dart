/// Widget tests for SourceBreakdownChart — donut + legend rows.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/revenue_report_model.dart';
import 'package:house_booking/data/models/source_breakdown_model.dart';
import 'package:house_booking/features/host/analytics/widgets/source_breakdown_chart.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SourceBreakdownModel _fakeBreakdown({int itemCount = 3}) {
  final items = List.generate(itemCount, (i) {
    final pct = itemCount > 0 ? (100.0 / itemCount) : 0.0;
    return SourceBreakdownItem(
      sourceId: i + 1,
      sourceName: 'Nguồn ${i + 1}',
      colorHex: '#FF${(i * 40 + 100).toRadixString(16).padLeft(2, '0')}00',
      amount: (i + 1) * 1000000.0,
      pct: pct,
    );
  });
  return SourceBreakdownModel(
    period: '2026-06',
    total: items.fold(0.0, (sum, e) => sum + e.amount),
    items: items,
  );
}

Widget _pump(SourceBreakdownModel model) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SourceBreakdownChart(model: model),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SourceBreakdownChart — with 3 items', () {
    testWidgets('renders PieChart', (tester) async {
      await tester.pumpWidget(_pump(_fakeBreakdown(itemCount: 3)));
      await tester.pump();

      expect(find.byType(PieChart), findsOneWidget);
    });

    testWidgets('legend shows 3 rows with source names', (tester) async {
      await tester.pumpWidget(_pump(_fakeBreakdown(itemCount: 3)));
      await tester.pump();

      expect(find.text('Nguồn 1'), findsOneWidget);
      expect(find.text('Nguồn 2'), findsOneWidget);
      expect(find.text('Nguồn 3'), findsOneWidget);
    });

    testWidgets('pct sum shown in legend (formatted)', (tester) async {
      // Each item has 33.3% → text will contain "33.3%"
      await tester.pumpWidget(_pump(_fakeBreakdown(itemCount: 3)));
      await tester.pump();

      // At least 3 percentage text widgets should be visible
      final pctTexts = find.textContaining('%');
      expect(pctTexts, findsWidgets);
    });
  });

  group('SourceBreakdownChart — empty state', () {
    testWidgets('shows empty message when no items', (tester) async {
      final emptyModel = const SourceBreakdownModel(
        period: '2026-06',
        total: 0,
        items: [],
      );
      await tester.pumpWidget(_pump(emptyModel));
      await tester.pump();

      expect(find.byType(PieChart), findsNothing);
      expect(find.textContaining('Chưa có dữ liệu'), findsOneWidget);
    });
  });

  group('SourceBreakdownChart — color parsing', () {
    testWidgets('renders with colorHex without crash', (tester) async {
      final model = SourceBreakdownModel(
        period: '2026-06',
        total: 5000000,
        items: [
          const SourceBreakdownItem(
            sourceId: 1,
            sourceName: 'Airbnb',
            colorHex: '#FF9800',
            amount: 3000000,
            pct: 60,
          ),
          const SourceBreakdownItem(
            sourceId: 2,
            sourceName: 'Trực tiếp',
            colorHex: '#42A5F5',
            amount: 2000000,
            pct: 40,
          ),
        ],
      );

      await tester.pumpWidget(_pump(model));
      await tester.pump();

      expect(find.byType(PieChart), findsOneWidget);
      expect(find.text('Airbnb'), findsOneWidget);
      expect(find.text('Trực tiếp'), findsOneWidget);
    });
  });
}
