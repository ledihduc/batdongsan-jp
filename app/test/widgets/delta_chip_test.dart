/// Widget tests for DeltaChip — covers all 4 AC-02 display rules.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/host/analytics/widgets/delta_chip.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

void main() {
  group('DeltaChip', () {
    testWidgets('null deltaPct → shows "—" in muted color', (tester) async {
      await _pump(tester, const DeltaChip(deltaPct: null));
      expect(find.text('—'), findsOneWidget);
      // No up/down arrow icons
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
      // Text should be muted color
      final textWidget = tester.widget<Text>(find.text('—'));
      expect(textWidget.style?.color, HD.inkMuted);
    });

    testWidgets('positive delta → green up arrow + "+X.X%"', (tester) async {
      await _pump(tester, const DeltaChip(deltaPct: 5.0));
      expect(find.text('+5.0%'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      // Icon should be positive (green) color
      final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_upward));
      expect(icon.color, HD.positive);
      // Text should also be positive color
      final textWidget = tester.widget<Text>(find.text('+5.0%'));
      expect(textWidget.style?.color, HD.positive);
    });

    testWidgets('negative delta → red down arrow + "X.X%"', (tester) async {
      await _pump(tester, const DeltaChip(deltaPct: -3.2));
      expect(find.text('-3.2%'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_downward));
      expect(icon.color, HD.negative);
      final textWidget = tester.widget<Text>(find.text('-3.2%'));
      expect(textWidget.style?.color, HD.negative);
    });

    testWidgets('zero delta → muted "0.0%" with no arrows', (tester) async {
      await _pump(tester, const DeltaChip(deltaPct: 0.0));
      expect(find.text('0.0%'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
      final textWidget = tester.widget<Text>(find.text('0.0%'));
      expect(textWidget.style?.color, HD.inkMuted);
    });

    testWidgets('isPercentagePoint=true → appends "pp" suffix', (tester) async {
      await _pump(
        tester,
        const DeltaChip(deltaPct: 4.5, isPercentagePoint: true),
      );
      expect(find.text('+4.5pp'), findsOneWidget);
    });

    testWidgets(
        'isPercentagePoint=true negative → "X.Xpp" with down arrow',
        (tester) async {
      await _pump(
        tester,
        const DeltaChip(deltaPct: -2.1, isPercentagePoint: true),
      );
      expect(find.text('-2.1pp'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('large positive delta formats to 1 decimal', (tester) async {
      // Use a value that rounds unambiguously with floating point
      await _pump(tester, const DeltaChip(deltaPct: 120.8));
      expect(find.text('+120.8%'), findsOneWidget);
    });
  });
}
