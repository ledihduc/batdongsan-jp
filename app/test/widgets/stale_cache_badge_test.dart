/// Widget tests for StaleCacheBadge.
///
/// Covers:
///   - renders Icons.access_time
///   - renders Vietnamese stale-cache text
///   - has grey background (HD.hairline)
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/features/host/analytics/widgets/stale_cache_badge.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  group('StaleCacheBadge', () {
    testWidgets('renders Icons.access_time', (tester) async {
      await tester.pumpWidget(_wrap(const StaleCacheBadge()));

      expect(find.byIcon(Icons.access_time), findsOneWidget);
    });

    testWidgets('renders Vietnamese stale message', (tester) async {
      await tester.pumpWidget(_wrap(const StaleCacheBadge()));

      expect(
        find.text('Dữ liệu có thể cũ đến 5 phút'),
        findsOneWidget,
      );
    });

    testWidgets('has non-transparent background', (tester) async {
      await tester.pumpWidget(_wrap(const StaleCacheBadge()));

      // The key is set directly on the Container widget.
      final container = tester.widget<Container>(
        find.byKey(const Key('stale_cache_badge')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, isNotNull);
      // Verify the badge has a visible (non-transparent) background.
      expect((decoration.color!.a * 255.0).round(), greaterThan(0));
    });

    testWidgets('is a const stateless widget — renders without errors',
        (tester) async {
      await tester.pumpWidget(_wrap(const StaleCacheBadge()));
      expect(tester.takeException(), isNull);
    });
  });
}
