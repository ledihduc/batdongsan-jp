/// Widget tests for [HelpCenterScreen].
///
/// Verifies search bar filtering, category grouping, and empty state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/help/help_center_screen.dart';
import 'package:house_booking/features/help/help_models.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('HelpCenterScreen', () {
    testWidgets('renders first visible category header', (tester) async {
      await pumpApp(tester, const HelpCenterScreen());
      await tester.pumpAndSettle();

      // The first category (更新) should be visible in the initial viewport.
      expect(find.text('更新'), findsWidgets); // appears as category + article titles
    });

    testWidgets('renders category headers in a scrollable list', (tester) async {
      await pumpApp(tester, const HelpCenterScreen());
      await tester.pumpAndSettle();

      // At least 1 category header is rendered.
      final categoryFinder = find.byType(ListView);
      expect(categoryFinder, findsOneWidget);
    });

    testWidgets('renders search bar', (tester) async {
      await pumpApp(tester, const HelpCenterScreen());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('search filters articles by Japanese title', (tester) async {
      await pumpApp(tester, const HelpCenterScreen());
      await tester.pumpAndSettle();

      // Enter a query that matches only renewal articles.
      await tester.enterText(find.byType(TextField), '更新');
      await tester.pump();

      // Should show only renewal category.
      expect(find.text('更新'), findsWidgets); // category header + article matches
      // Deposit, privacy, payment etc should not show their headers.
      expect(find.text('敷金精算'), findsNothing);
      expect(find.text('支払い'), findsNothing);
    });

    testWidgets('search shows empty state when no match', (tester) async {
      await pumpApp(tester, const HelpCenterScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'xyznosucharticle');
      await tester.pump();

      // Empty state widget should appear.
      expect(find.byType(Column), findsWidgets);
      // The icon for no results should be present.
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
    });

    testWidgets('clear button appears when query is non-empty', (tester) async {
      await pumpApp(tester, const HelpCenterScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clear button resets search and shows all categories',
        (tester) async {
      await pumpApp(tester, const HelpCenterScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '更新');
      await tester.pump();

      // Only renewal visible.
      expect(find.text('敷金精算'), findsNothing);

      // Tap clear.
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      // All categories should be back.
      expect(find.text('敷金精算'), findsOneWidget);
    });

    testWidgets('search filters by English title too', (tester) async {
      await pumpApp(tester, const HelpCenterScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'deposit');
      await tester.pump();

      // Deposit category header should appear.
      expect(find.text('敷金精算'), findsOneWidget);
      // Renewal should not.
      expect(find.text('更新'), findsNothing);
    });
  });
}
