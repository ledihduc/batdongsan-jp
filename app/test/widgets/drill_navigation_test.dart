/// Widget tests for DrillRoomScreen — list renders, tap navigates,
/// DrillProvider state pushed, breadcrumb visible.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/data/models/drill_node_model.dart';
import 'package:house_booking/features/host/analytics/providers/drill_provider.dart';
import 'package:house_booking/features/host/analytics/screens/drill_room_screen.dart';
import 'package:house_booking/features/host/analytics/widgets/breadcrumb.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';
import 'package:house_booking/providers/report_provider.dart';
import '../helpers/pump_app.dart';
import 'package:house_booking/core/widgets/skeleton.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockReportProvider extends Mock implements ReportProvider {}

class MockBuildingProvider extends Mock implements BuildingProvider {}

// ---------------------------------------------------------------------------
// Fake data
// ---------------------------------------------------------------------------

RoomListResponse _fakeRoomList({int count = 3}) {
  return RoomListResponse(
    items: List.generate(
      count,
      (i) => RoomListItem(
        roomId: i + 1,
        roomCode: 'P10${i + 1}',
        roomStatus: 'occupied',
        buildingId: 1,
        buildingName: 'Tòa A',
      ),
    ),
    totalCount: count,
    page: 1,
    pageSize: 50,
  );
}

// ---------------------------------------------------------------------------
// Test helper
// ---------------------------------------------------------------------------

Future<({DrillProvider drill, GoRouter router})> _pumpDrillRoomScreen(
  WidgetTester tester,
  MockReportProvider reportMock,
) async {
  final drill = DrillProvider();
  final building = MockBuildingProvider();
  when(() => building.buildings).thenReturn([]);

  final router = GoRouter(
    initialLocation: '/host/analytics/drill/rooms',
    routes: [
      GoRoute(
        path: '/host/analytics/drill/rooms',
        builder: (ctx, _) => MultiProvider(
          providers: [
            ChangeNotifierProvider<DrillProvider>.value(value: drill),
            ChangeNotifierProvider<ReportProvider>.value(value: reportMock),
            ChangeNotifierProvider<BuildingProvider>.value(value: building),
          ],
          child: const DrillRoomScreen(),
        ),
      ),
      GoRoute(
        path: '/host/analytics',
        builder: (_, __) => const Scaffold(body: Text('AnalyticsHome')),
      ),
      GoRoute(
        path: '/host/analytics/drill/room/:roomId/contracts',
        builder: (_, __) => const Scaffold(body: Text('DrillContractScreen')),
      ),
    ],
  );

  // Màn hình ghi telemetry → phải có Provider<TelemetryService> ở gốc.
  await pumpAppRaw(tester, MaterialApp.router(routerConfig: router));
  // Let initState postFrameCallback fire + fetchDrillRooms complete.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();

  return (drill: drill, router: router);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockReportProvider reportMock;

  setUpAll(() {
    // mocktail fallback registrations — no fallbacks needed for this test.
  });

  setUp(() {
    reportMock = MockReportProvider();
  });

  group('DrillRoomScreen', () {
    testWidgets('renders breadcrumb at top', (tester) async {
      when(() => reportMock.fetchDrillRooms(
            buildingId: any(named: 'buildingId'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer((_) async => _fakeRoomList(count: 2));

      await _pumpDrillRoomScreen(tester, reportMock);
      expect(find.byType(Breadcrumb), findsOneWidget);
    });

    testWidgets('renders room items from provider', (tester) async {
      when(() => reportMock.fetchDrillRooms(
            buildingId: any(named: 'buildingId'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer((_) async => _fakeRoomList(count: 3));

      await _pumpDrillRoomScreen(tester, reportMock);

      expect(find.text('P101'), findsOneWidget);
      expect(find.text('P102'), findsOneWidget);
      expect(find.text('P103'), findsOneWidget);
    });

    testWidgets('tapping room tile pushes level 2 to DrillProvider',
        (tester) async {
      when(() => reportMock.fetchDrillRooms(
            buildingId: any(named: 'buildingId'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer((_) async => _fakeRoomList(count: 1));

      final result = await _pumpDrillRoomScreen(tester, reportMock);

      await tester.tap(find.text('P101'));
      await tester.pumpAndSettle();

      // DrillProvider should be at level 2.
      // Root(0) + L2 pushed by tap → breadcrumb has 2 items.
      expect(result.drill.currentLevel, equals(2));
      expect(result.drill.breadcrumb.length, greaterThanOrEqualTo(2));
    });

    testWidgets('tapping room tile navigates to contract screen',
        (tester) async {
      when(() => reportMock.fetchDrillRooms(
            buildingId: any(named: 'buildingId'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer((_) async => _fakeRoomList(count: 1));

      await _pumpDrillRoomScreen(tester, reportMock);

      await tester.tap(find.text('P101'));
      await tester.pumpAndSettle();

      expect(find.text('DrillContractScreen'), findsOneWidget);
    });

    testWidgets('shows loading indicator before data arrives', (tester) async {
      // Use a Completer so we control when the future completes.
      final completer = Completer<RoomListResponse>();
      when(() => reportMock.fetchDrillRooms(
            buildingId: any(named: 'buildingId'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer((_) => completer.future);

      final drill = DrillProvider();
      final building = MockBuildingProvider();
      when(() => building.buildings).thenReturn([]);

      final router = GoRouter(
        initialLocation: '/host/analytics/drill/rooms',
        routes: [
          GoRoute(
            path: '/host/analytics/drill/rooms',
            builder: (ctx, _) => MultiProvider(
              providers: [
                ChangeNotifierProvider<DrillProvider>.value(value: drill),
                ChangeNotifierProvider<ReportProvider>.value(value: reportMock),
                ChangeNotifierProvider<BuildingProvider>.value(value: building),
              ],
              child: const DrillRoomScreen(),
            ),
          ),
        ],
      );

      // Màn hình ghi telemetry → phải có Provider<TelemetryService> ở gốc.
      await pumpAppRaw(tester, MaterialApp.router(routerConfig: router));
      await tester.pump(); // let initState post-frame callback fire
      await tester.pump(); // one more frame — loading state is set

      // Màn này dùng SKELETON (khung xám nhấp nháy) chứ không phải spinner —
      // giữ nguyên bố cục nên mắt không bị giật khi dữ liệu về.
      expect(find.byType(DsRowSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Complete to avoid pending timers error.
      completer.complete(_fakeRoomList());
      await tester.pumpAndSettle();
    });

    testWidgets('shows error when fetchDrillRooms throws', (tester) async {
      when(() => reportMock.fetchDrillRooms(
            buildingId: any(named: 'buildingId'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          )).thenThrow(Exception('Network error'));

      await _pumpDrillRoomScreen(tester, reportMock);

      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('shows empty state when list is empty', (tester) async {
      when(() => reportMock.fetchDrillRooms(
            buildingId: any(named: 'buildingId'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer((_) async => const RoomListResponse(
            items: [], totalCount: 0, page: 1, pageSize: 50));

      await _pumpDrillRoomScreen(tester, reportMock);

      expect(find.text('Không có phòng nào'), findsOneWidget);
    });
  });
}
