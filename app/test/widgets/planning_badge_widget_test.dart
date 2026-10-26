/// Widget tests for PlanningBadge.
///
/// PlanningBadge instantiates PlanningService() directly, which creates real
/// Dio HTTP connections. In headless tests this leaves pending timers.
/// We use `tester.runAsync` for tests that involve the async load path,
/// and test observable behaviours: loading state, (0,0) guard, and silent fail.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/planning/widgets/planning_badge.dart';

void main() {
  group('PlanningBadge', () {
    // -------------------------------------------------------------------------
    // (0, 0) guard — synchronous, no async call, no pending timers
    // -------------------------------------------------------------------------

    testWidgets('returns empty (SizedBox.shrink) for lat=0, lng=0', (tester) async {
      // (0,0) coordinates are the default invalid sentinel — badge must not
      // show a progress indicator or text; it renders SizedBox.shrink.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlanningBadge(lat: 0, lng: 0),
          ),
        ),
      );

      // After pump: _loading is set to false synchronously when lat==0&&lng==0
      await tester.pump();

      // No loading indicator
      expect(find.byType(LinearProgressIndicator), findsNothing);
      // No text containing "Quy hoạch:"
      expect(find.textContaining('Quy hoạch:'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // Initial loading state — use runAsync to handle real async timers
    // -------------------------------------------------------------------------

    testWidgets('shows LinearProgressIndicator while loading (non-zero coords)',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PlanningBadge(lat: 10.77, lng: 106.69),
            ),
          ),
        );

        // Pump once to build widget — initState fires but future not yet done
        await tester.pump();

        // LinearProgressIndicator should be visible immediately.
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });
    });

    // -------------------------------------------------------------------------
    // Error state — service failure renders empty (fail-silently AC-04)
    // -------------------------------------------------------------------------

    testWidgets('renders empty after service throws (fail-silently)', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PlanningBadge(lat: 10.77, lng: 106.69),
            ),
          ),
        );

        // Allow network call to attempt (will fail — no network in test env)
        await Future<void>.delayed(const Duration(seconds: 3));
        await tester.pump();

        // After failure, badge renders empty — no "Quy hoạch:" text visible.
        expect(find.textContaining('Quy hoạch:'), findsNothing);
      });
    });

    // -------------------------------------------------------------------------
    // Layout — loading placeholder dimensions (tested via (0,0) path is faster)
    // The non-zero path requires runAsync; we just test the SizedBox in (0,0).
    // -------------------------------------------------------------------------

    testWidgets('SizedBox.shrink renders after (0,0) guard', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlanningBadge(lat: 0, lng: 0),
          ),
        ),
      );
      await tester.pump();

      // After guard, _loading=false and _parcel=null → SizedBox.shrink
      // Verify no visual content (no text, no progress indicator)
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Quy hoạch:'), findsNothing);
    });
  });
}
