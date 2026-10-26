/// Widget tests for Breadcrumb — renders segments, truncation, tap.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/features/host/analytics/providers/drill_provider.dart';
import 'package:house_booking/features/host/analytics/widgets/breadcrumb.dart';

// Minimal router needed for context.go() calls in Breadcrumb.
GoRouter _makeRouter(DrillProvider drillProvider) {
  return GoRouter(
    initialLocation: '/host/analytics',
    routes: [
      GoRoute(
        path: '/host/analytics',
        builder: (ctx, _) => ChangeNotifierProvider<DrillProvider>.value(
          value: drillProvider,
          child: const Scaffold(body: Breadcrumb()),
        ),
      ),
      GoRoute(
        path: '/host/analytics/drill/rooms',
        builder: (ctx, _) => const Scaffold(body: Text('DrillRoomScreen')),
      ),
      GoRoute(
        path: '/host/analytics/drill/room/:roomId/contracts',
        builder: (ctx, _) => const Scaffold(body: Text('DrillContractScreen')),
      ),
    ],
  );
}

Widget _buildApp(DrillProvider drillProvider) {
  return ChangeNotifierProvider<DrillProvider>.value(
    value: drillProvider,
    child: MaterialApp.router(
      routerConfig: _makeRouter(drillProvider),
    ),
  );
}

void main() {
  group('Breadcrumb', () {
    testWidgets('renders root segment "Tổng quan"', (tester) async {
      final provider = DrillProvider();
      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();
      expect(find.text('Tổng quan'), findsOneWidget);
    });

    testWidgets('renders multiple segments when breadcrumb has items',
        (tester) async {
      final provider = DrillProvider();
      provider.pushLevel(level: 1, title: 'Phòng 101');

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.text('Tổng quan'), findsOneWidget);
      expect(find.text('Phòng 101'), findsOneWidget);
      // Separator is rendered.
      expect(find.text('/'), findsWidgets);
    });

    testWidgets('truncates label longer than 20 chars', (tester) async {
      final provider = DrillProvider();
      provider.pushLevel(
        level: 1,
        title: 'Phòng rất dài tên quá hai mươi ký tự',
      );

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      // Truncated to 20 chars + ellipsis.
      expect(find.text('Phòng rất dài tên qu…'), findsOneWidget);
    });

    testWidgets('does NOT truncate label of exactly 20 chars', (tester) async {
      const title = '12345678901234567890'; // exactly 20 chars
      final provider = DrillProvider();
      provider.pushLevel(level: 1, title: title);

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget);
    });

    testWidgets('tapping non-last segment calls popToLevel', (tester) async {
      final provider = DrillProvider();
      provider.pushLevel(level: 1, title: 'Phòng 101');
      provider.pushLevel(level: 2, title: 'HĐ #42');

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      // Tap "Tổng quan" (level 0) — should pop to level 0.
      await tester.tap(find.text('Tổng quan'));
      await tester.pumpAndSettle();

      expect(provider.currentLevel, equals(0));
      expect(provider.breadcrumb.length, equals(1));
    });

    testWidgets('last segment is disabled (non-tappable)', (tester) async {
      final provider = DrillProvider();
      provider.pushLevel(level: 1, title: 'Phòng 101');

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      // The last item (Phòng 101) is disabled — tapping should NOT change level.
      await tester.tap(find.text('Phòng 101'));
      await tester.pumpAndSettle();

      // Level unchanged — still at 1.
      expect(provider.currentLevel, equals(1));
    });

    testWidgets('4-segment breadcrumb renders all items', (tester) async {
      final provider = DrillProvider();
      provider.pushLevel(level: 1, title: 'P101');
      provider.pushLevel(level: 2, title: 'HĐ #1');
      provider.pushLevel(level: 3, title: 'Nguyễn A');
      provider.pushLevel(level: 4, title: 'INV-001');

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      // Should find 5 text items (root + 4 levels).
      expect(find.text('Tổng quan'), findsOneWidget);
      expect(find.text('P101'), findsOneWidget);
      expect(find.text('HĐ #1'), findsOneWidget);
      expect(find.text('Nguyễn A'), findsOneWidget);
      expect(find.text('INV-001'), findsOneWidget);
    });
  });
}
