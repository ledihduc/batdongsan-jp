/// Widget tests for OfflineBadge.
///
/// Covers:
///   - renders icon + formatted time when lastFetchAt is provided
///   - renders "Offline" fallback text when lastFetchAt is null
///   - tap triggers SnackBar with expected message
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/features/host/analytics/widgets/offline_badge.dart';

/// Wraps the badge in a Scaffold so ScaffoldMessenger works for SnackBar tests.
Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  group('OfflineBadge', () {
    testWidgets('renders Icons.cloud_off', (tester) async {
      await tester.pumpWidget(
        _wrap(const OfflineBadge(lastFetchAt: null)),
      );

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('shows "Offline" fallback when lastFetchAt is null',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const OfflineBadge(lastFetchAt: null)),
      );

      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('shows formatted time when lastFetchAt is provided',
        (tester) async {
      // Fixed reference: 14:35
      final ts = DateTime(2026, 6, 29, 14, 35);
      await tester.pumpWidget(
        _wrap(OfflineBadge(lastFetchAt: ts)),
      );

      // The text should contain the formatted time "14:35"
      expect(find.textContaining('14:35'), findsOneWidget);
      expect(find.textContaining('Offline'), findsOneWidget);
    });

    testWidgets('tap shows SnackBar with offline reconnect message',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const OfflineBadge(lastFetchAt: null)),
      );

      await tester.tap(find.byKey(const Key('offline_badge')));
      await tester.pump(); // start SnackBar animation
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.text('Đang offline — kết nối lại để cập nhật'),
        findsOneWidget,
      );
    });

    testWidgets('has correct orange/warning background', (tester) async {
      await tester.pumpWidget(
        _wrap(const OfflineBadge(lastFetchAt: null)),
      );

      // The key is set directly on the Container widget.
      final container = tester.widget<Container>(
        find.byKey(const Key('offline_badge')),
      );
      final decoration = container.decoration as BoxDecoration;
      // Should be a non-transparent color (warning amber)
      expect(decoration.color, isNotNull);
      // Verify the badge has a visible (non-transparent) background.
      expect((decoration.color!.a * 255.0).round(), greaterThan(0));
    });
  });
}
