/// Widget tests for TrendChart.
///
/// Tests: 2 series rendered, toggle showNet swaps data source,
/// tooltip text formatting via TrendChartLegend label.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/trend_bucket_model.dart';
import 'package:house_booking/features/host/analytics/services/period_helper.dart';
import 'package:house_booking/features/host/analytics/widgets/trend_chart.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

RevenueTrendModel _fakeModel() => const RevenueTrendModel(
      periods: [
        '2025-07', '2025-08', '2025-09', '2025-10', '2025-11', '2025-12',
        '2026-01', '2026-02', '2026-03', '2026-04', '2026-05', '2026-06',
      ],
      current: [1e6, 2e6, 1.5e6, 3e6, 2e6, 4e6, 3e6, 5e6, 4e6, 6e6, 5e6, 7e6],
      currentNet: [9e5, 1.8e6, 1.35e6, 2.7e6, 1.8e6, 3.6e6, 2.7e6, 4.5e6, 3.6e6, 5.4e6, 4.5e6, 6.3e6],
      prior: [5e5, 1e6, 8e5, 1.5e6, 1e6, 2e6, 1.5e6, 2.5e6, 2e6, 3e6, 2.5e6, 3.5e6],
      priorNet: [4.5e5, 9e5, 7.2e5, 1.35e6, 9e5, 1.8e6, 1.35e6, 2.25e6, 1.8e6, 2.7e6, 2.25e6, 3.15e6],
    );

Widget _pumpChart({
  required RevenueTrendModel model,
  bool showNet = false,
  PeriodType period = PeriodType.month,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 300,
        child: TrendChart(
          model: model,
          showNet: showNet,
          period: period,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TrendChart — rendering', () {
    testWidgets('renders LineChart widget', (tester) async {
      await tester.pumpWidget(_pumpChart(model: _fakeModel()));
      await tester.pump();

      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('renders 2 line series (current + prior)', (tester) async {
      await tester.pumpWidget(_pumpChart(model: _fakeModel()));
      await tester.pump();

      // LineChart is rendered — data has 2 bars confirmed via model construction
      // Direct bar count assertion: find LineChartBarData via LineChart
      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.lineBarsData.length, equals(2));
    });

    testWidgets('gross mode uses current series (non-net)', (tester) async {
      final model = _fakeModel();
      await tester.pumpWidget(_pumpChart(model: model, showNet: false));
      await tester.pump();

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      // Current bar (index 0) first spot y == current[0]
      expect(lineChart.data.lineBarsData[0].spots.first.y, equals(model.current[0]));
    });

    testWidgets('net mode uses currentNet series', (tester) async {
      final model = _fakeModel();
      await tester.pumpWidget(_pumpChart(model: model, showNet: true));
      await tester.pump();

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      // Current bar (index 0) first spot y == currentNet[0]
      expect(lineChart.data.lineBarsData[0].spots.first.y, equals(model.currentNet[0]));
    });

    testWidgets('prior series in gross mode uses prior (not priorNet)', (tester) async {
      final model = _fakeModel();
      await tester.pumpWidget(_pumpChart(model: model, showNet: false));
      await tester.pump();

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      // Prior bar (index 1) first spot y == prior[0]
      expect(lineChart.data.lineBarsData[1].spots.first.y, equals(model.prior[0]));
    });

    testWidgets('net toggle: prior bar uses priorNet in net mode', (tester) async {
      final model = _fakeModel();
      await tester.pumpWidget(_pumpChart(model: model, showNet: true));
      await tester.pump();

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.lineBarsData[1].spots.first.y, equals(model.priorNet[0]));
    });

    testWidgets('12 spots per series', (tester) async {
      final model = _fakeModel();
      await tester.pumpWidget(_pumpChart(model: model));
      await tester.pump();

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.lineBarsData[0].spots.length, equals(12));
      expect(lineChart.data.lineBarsData[1].spots.length, equals(12));
    });
  });

  group('TrendChart — empty model', () {
    testWidgets('renders without crash for empty model', (tester) async {
      const emptyModel = RevenueTrendModel(
        periods: [],
        current: [],
        currentNet: [],
        prior: [],
        priorNet: [],
      );
      await tester.pumpWidget(_pumpChart(model: emptyModel));
      await tester.pump();

      expect(find.byType(LineChart), findsOneWidget);
    });
  });

  group('TrendChartLegend', () {
    testWidgets('gross mode shows correct labels', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TrendChartLegend(showNet: false),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Gộp kỳ này'), findsOneWidget);
      expect(find.text('Gộp kỳ trước'), findsOneWidget);
    });

    testWidgets('net mode shows net labels', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TrendChartLegend(showNet: true),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Thực kỳ này'), findsOneWidget);
      expect(find.text('Thực kỳ trước'), findsOneWidget);
    });
  });
}
