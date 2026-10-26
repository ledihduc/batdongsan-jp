/// Widget tests for [DsTrustedBadge] — the "Uy tín" badge overlaid on
/// house-card / detail image when a listing has been trusted-flagged by admin.
///
/// Verifies:
/// - Default constructor renders icon + label.
/// - `iconOnly` constructor omits the label.
/// - Semantics label present for screen readers.
/// - Uses `Icons.workspace_premium` per D7 spec.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/widgets/ds_trusted_badge.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('DsTrustedBadge', () {
    testWidgets('default constructor renders icon + "Uy tín" label',
        (tester) async {
      await _pump(tester, const DsTrustedBadge());

      expect(find.text('Uy tín'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium), findsOneWidget);
    });

    testWidgets('iconOnly constructor omits the text label', (tester) async {
      await _pump(tester, const DsTrustedBadge.iconOnly());

      expect(find.text('Uy tín'), findsNothing);
      expect(find.byIcon(Icons.workspace_premium), findsOneWidget);
    });

    testWidgets('exposes semantics label for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const DsTrustedBadge());

      // Semantics finder — matches the wrapper Semantics widget label.
      // With a11y tree enabled, the wrapper label merges with the child text.
      expect(find.bySemanticsLabel(RegExp(r'Tin uy tín')), findsAtLeastNWidgets(1));
      handle.dispose();
    });

    testWidgets('semantics label present in iconOnly variant too',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const DsTrustedBadge.iconOnly());
      expect(find.bySemanticsLabel(RegExp(r'Tin uy tín')), findsAtLeastNWidgets(1));
      handle.dispose();
    });

    testWidgets('renders inside a Container decorated with rounded border',
        (tester) async {
      await _pump(tester, const DsTrustedBadge());

      // The badge should render exactly one decorated Container as its box.
      final container = tester
          .widgetList<Container>(find.descendant(
            of: find.byType(DsTrustedBadge),
            matching: find.byType(Container),
          ))
          .firstWhere((c) => c.decoration is BoxDecoration);
      final deco = container.decoration as BoxDecoration;
      expect(deco.borderRadius, isNotNull);
      expect(deco.border, isNotNull);
      expect(deco.boxShadow, isNotNull);
      expect(deco.boxShadow!.length, greaterThan(0));
    });
  });
}
