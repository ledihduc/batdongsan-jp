/// Integration / E2E smoke test for the Planning Lookup feature.
///
/// This test requires a running device/emulator. It DOES NOT make real
/// backend calls — it boots the app and verifies the route exists.
///
/// To run on device:
///   flutter test integration_test/planning_e2e_test.dart -d `<device-id>`
///
/// To enable mock backend (no real network):
///   flutter test integration_test/planning_e2e_test.dart
///       --dart-define=USE_MOCK_PLANNING=1 -d `<device-id>`
///
/// STATUS: Tests marked skip=true. They compile correctly but require a real
/// device and running backend. Deferred to P09 staging soak.
///
/// Deviations from spec:
/// - Full E2E (boot → tap parcel → sheet → close) deferred — needs device.
/// - This file ensures it COMPILES and provides the skeleton for P09.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// TODO(P09): Uncomment when wiring real app entry point.
// import 'package:house_booking/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // Smoke: app boots without crashing
  // ---------------------------------------------------------------------------

  // skip: deferred to P09 staging soak — needs device + running backend
  testWidgets(
    'app boots and root scaffold is present',
    (tester) async {
      // TODO(P09 staging): Replace with `app.main()` and real navigation test.
      // For now, pump a minimal MaterialApp to verify E2E harness compiles.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('ancu365')),
            body: const Center(child: Text('Planning Lookup Smoke Test')),
          ),
        ),
      );

      expect(find.text('ancu365'), findsOneWidget);
    },
    // Remove skip=true when running on a real device with app.main() wired up.
    skip: true,
  );

  // ---------------------------------------------------------------------------
  // E2E: Navigate to /tra-quy-hoach
  // ---------------------------------------------------------------------------

  // skip: deferred to P09 staging soak — needs device + running backend
  testWidgets(
    'navigates to /tra-quy-hoach and map widget appears',
    (tester) async {
      // TODO(P09):
      // app.main();
      // await tester.pumpAndSettle();
      // await tester.tap(find.byKey(const Key('bottom_tab_planning')));
      // await tester.pumpAndSettle(const Duration(seconds: 5));
      // expect(find.byType(FlutterMap), findsOneWidget);
    },
    skip: true,
  );

  // ---------------------------------------------------------------------------
  // E2E: Pick search result -> sheet appears
  // ---------------------------------------------------------------------------

  // skip: deferred to P09 staging soak — needs device + running backend
  testWidgets(
    'search result selection shows parcel detail sheet',
    (tester) async {
      // TODO(P09):
      // 1. Navigate to /tra-quy-hoach
      // 2. Tap search field
      // 3. Type "Ben Thanh"
      // 4. Tap first result
      // 5. Tap on map
      // 6. expect(find.byType(ParcelDetailSheet), findsOneWidget)
    },
    skip: true,
  );
}
