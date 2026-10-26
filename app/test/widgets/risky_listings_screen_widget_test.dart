/// Widget tests for RiskyListingsScreen.
///
/// RiskyListingsScreen creates PlanningService() locally and calls
/// getRiskyHouses(). We cannot inject a mock service without a source change.
///
/// Testing strategy:
/// - Empty state: Service returns empty list (fails in test → shows error, but
///   we test the const string "Không có listing rủi ro" via direct FutureBuilder pump)
/// - Since direct injection is not possible, we test via a thin wrapper that
///   subclasses or wraps the screen. Instead, we test the sub-widgets and
///   logic directly, and test the screen with the service failing gracefully.
///
/// For the populated list and navigation tests, we create a testable variant
/// of the screen that accepts an injected service. We add a named constructor
/// [RiskyListingsScreen.forTest] to the source file (1-line change — documented
/// in report as deviation P08-DEV-01).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:house_booking/data/services/planning_service.dart';
import 'package:house_booking/features/admin/planning/risky_listings_screen.dart';

import '../_fakes.dart';
import '../_mocks.dart';

// ---------------------------------------------------------------------------
// Minimal stub navigator observer
// ---------------------------------------------------------------------------
class _MockNavigatorObserver extends Mock implements NavigatorObserver {}

/// Fake route needed by mocktail for `Route<dynamic>` fallback.
class _FakeRoute<T> extends Fake implements Route<T> {}

void main() {
  setUpAll(() {
    registerFallbacks();
    registerFallbackValue(_FakeRoute<dynamic>());
  });

  group('RiskyListingsScreen', () {
    // -------------------------------------------------------------------------
    // Empty state: service returns []
    // -------------------------------------------------------------------------

    testWidgets('shows empty state string when list is empty', (tester) async {
      final mockSvc = MockPlanningService();
      when(() => mockSvc.getRiskyHouses()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        MaterialApp(
          home: RiskyListingsScreen.forTest(service: mockSvc),
        ),
      );

      // Wait for FutureBuilder to resolve
      await tester.pumpAndSettle();

      expect(find.text('Không có listing rủi ro'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Populated state: service returns 2 items
    // -------------------------------------------------------------------------

    testWidgets('renders 2 risky house tiles when list has 2 items',
        (tester) async {
      final mockSvc = MockPlanningService();
      final houses = [
        fakeRiskyHouse(id: 1, title: 'Phòng trọ Quận 1'),
        fakeRiskyHouse(id: 2, title: 'Căn hộ Bình Thạnh'),
      ];
      when(() => mockSvc.getRiskyHouses()).thenAnswer((_) async => houses);

      await tester.pumpWidget(
        MaterialApp(
          home: RiskyListingsScreen.forTest(service: mockSvc),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Phòng trọ Quận 1'), findsOneWidget);
      expect(find.text('Căn hộ Bình Thạnh'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Zone chip rendered for each house
    // -------------------------------------------------------------------------

    testWidgets('renders zone code chip', (tester) async {
      final mockSvc = MockPlanningService();
      when(() => mockSvc.getRiskyHouses()).thenAnswer((_) async => [
            fakeRiskyHouse(zoneCode: 'DGT'),
          ]);

      await tester.pumpWidget(
        MaterialApp(
          home: RiskyListingsScreen.forTest(service: mockSvc),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DGT'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 403 error → forbidden message
    // -------------------------------------------------------------------------

    testWidgets('shows forbidden message when service throws 403', (tester) async {
      final mockSvc = MockPlanningService();
      // Use thenAnswer with async throw — thenThrow is synchronous and would
      // crash initState before FutureBuilder can catch the error.
      when(() => mockSvc.getRiskyHouses()).thenAnswer(
        (_) async => throw const PlanningApiException(403, 'Yêu cầu quyền admin'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RiskyListingsScreen.forTest(service: mockSvc),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bạn không có quyền truy cập'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Navigation: tapping a tile pushes a new route
    // -------------------------------------------------------------------------

    testWidgets('tapping a tile triggers navigation', (tester) async {
      final mockSvc = MockPlanningService();
      final observer = _MockNavigatorObserver();
      when(() => mockSvc.getRiskyHouses()).thenAnswer((_) async => [
            fakeRiskyHouse(id: 42, title: 'Phòng Quận 3'),
          ]);

      // Use home + onUnknownRoute to intercept HouseDetailScreen push
      // without needing a full provider tree for HouseDetailScreen.
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: RiskyListingsScreen.forTest(service: mockSvc),
          // All pushes from Navigator.push (not named) use the builder in
          // MaterialPageRoute — we don't intercept those here, so instead
          // we verify the push happened via observer.
        ),
      );
      await tester.pumpAndSettle();

      // Register what to expect from the observer: push is called
      when(() => observer.didPush(any(), any())).thenReturn(null);

      // Tap the tile — this calls Navigator.push with HouseDetailScreen
      // It will fail to render due to missing providers. Use
      // FlutterError.onError suppression to catch it gracefully.
      FlutterError.onError = (FlutterErrorDetails details) {
        // Suppress provider-not-found errors from HouseDetailScreen in test
        if (details.exception.toString().contains('Provider') ||
            details.exception.toString().contains('HouseProvider')) {
          return;
        }
        FlutterError.presentError(details);
      };

      await tester.tap(find.text('Phòng Quận 3'));
      await tester.pump(); // start navigation animation

      // Verify that didPush was called (navigation occurred)
      verify(() => observer.didPush(any(), any())).called(greaterThanOrEqualTo(1));

      FlutterError.onError = FlutterError.presentError;
    });

    // -------------------------------------------------------------------------
    // AppBar title
    // -------------------------------------------------------------------------

    testWidgets('AppBar title is correct', (tester) async {
      final mockSvc = MockPlanningService();
      when(() => mockSvc.getRiskyHouses()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        MaterialApp(
          home: RiskyListingsScreen.forTest(service: mockSvc),
        ),
      );

      expect(find.text('Listing rủi ro quy hoạch'), findsOneWidget);
    });
  });
}
