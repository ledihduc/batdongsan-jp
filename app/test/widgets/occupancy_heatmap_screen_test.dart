/// Widget tests for OccupancyHeatmapScreen.
///
/// Tests: loading skeleton, data state (5 rooms × 31 days),
/// group-view fallback triggers with 31+ rooms.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/data/models/heatmap_cell_model.dart';
import 'package:house_booking/features/host/analytics/screens/occupancy_heatmap_screen.dart';
import 'package:house_booking/features/host/analytics/widgets/heatmap_group_row.dart';
import 'package:house_booking/providers/report_provider.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class MockReportProvider extends Mock implements ReportProvider {}

// ---------------------------------------------------------------------------
// Fixture factories
// ---------------------------------------------------------------------------

OccupancyHeatmapModel _fakeHeatmap({int roomCount = 5, int days = 31}) {
  final rooms = List.generate(roomCount, (i) {
    final cells = List.generate(
      days,
      (d) => HeatmapCell(
        day: d + 1,
        status: d % 4 == 0
            ? HeatmapCellStatus.vacant
            : d % 4 == 1
                ? HeatmapCellStatus.booked
                : d % 4 == 2
                    ? HeatmapCellStatus.paid
                    : HeatmapCellStatus.overdue,
      ),
    );
    return HeatmapRoomRow(
      roomId: i + 1,
      roomName: 'P.${100 + i}',
      buildingName: i < roomCount ~/ 2 ? 'Tòa A' : 'Tòa B',
      cells: cells,
    );
  });
  return OccupancyHeatmapModel(month: '2026-06', days: days, rooms: rooms);
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Future<void> _pumpScreen(
  WidgetTester tester,
  ReportProvider provider,
) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => ChangeNotifierProvider<ReportProvider>.value(
          value: provider,
          child: const OccupancyHeatmapScreen(),
        ),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  await tester.pump();
}

void _stubDefaults(MockReportProvider p) {
  when(() => p.heatmapLoading).thenReturn(false);
  when(() => p.heatmapError).thenReturn(null);
  when(() => p.heatmap).thenReturn(null);
  when(
    () => p.fetchHeatmap(
      month: any(named: 'month'),
      buildingId: any(named: 'buildingId'),
      force: any(named: 'force'),
    ),
  ).thenAnswer((_) async {});
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(DateTime.now());
  });

  group('OccupancyHeatmapScreen — loading state', () {
    testWidgets('loading + no data → shows spinner', (tester) async {
      final p = MockReportProvider();
      _stubDefaults(p);
      when(() => p.heatmapLoading).thenReturn(true);
      when(() => p.heatmap).thenReturn(null);

      await _pumpScreen(tester, p);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('OccupancyHeatmapScreen — data state (5 rooms × 31 days)', () {
    testWidgets('renders data without group-view', (tester) async {
      final p = MockReportProvider();
      _stubDefaults(p);
      when(() => p.heatmap).thenReturn(_fakeHeatmap(roomCount: 5, days: 31));

      await _pumpScreen(tester, p);
      await tester.pumpAndSettle();

      // No group rows because 5 < 30 threshold
      expect(find.byType(HeatmapGroupRow), findsNothing);
    });

    testWidgets('AppBar title visible', (tester) async {
      final p = MockReportProvider();
      _stubDefaults(p);
      when(() => p.heatmap).thenReturn(_fakeHeatmap(roomCount: 5, days: 31));

      await _pumpScreen(tester, p);

      expect(find.text('Lịch occupancy'), findsOneWidget);
    });
  });

  group('OccupancyHeatmapScreen — group-view fallback (31+ rooms)', () {
    testWidgets('group view shown when rooms > 30', (tester) async {
      final p = MockReportProvider();
      _stubDefaults(p);
      when(() => p.heatmap).thenReturn(_fakeHeatmap(roomCount: 31, days: 31));

      await _pumpScreen(tester, p);
      await tester.pumpAndSettle();

      // HeatmapGroupRow should be visible
      expect(find.byType(HeatmapGroupRow), findsWidgets);
    });
  });

  group('OccupancyHeatmapScreen — error state', () {
    testWidgets('error + no data → shows error message + retry', (tester) async {
      final p = MockReportProvider();
      _stubDefaults(p);
      when(() => p.heatmapError).thenReturn('Lỗi mạng');
      when(() => p.heatmap).thenReturn(null);

      await _pumpScreen(tester, p);

      expect(find.text('Lỗi mạng'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
