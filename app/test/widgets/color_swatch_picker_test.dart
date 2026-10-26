/// Widget tests for ColorSwatchPicker.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/features/host/analytics/widgets/color_swatch_picker.dart';

Widget buildSwatchPicker({
  required String selectedHex,
  required void Function(String) onChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ColorSwatchPicker(
        selectedHex: selectedHex,
        onChanged: onChanged,
      ),
    ),
  );
}

void main() {
  group('ColorSwatchPicker', () {
    testWidgets('renders 10 swatches', (tester) async {
      await tester.pumpWidget(buildSwatchPicker(
        selectedHex: kSourceColorPresets.first,
        onChanged: (_) {},
      ));

      // Each swatch has a GestureDetector with Key('swatch_#RRGGBB')
      for (final hex in kSourceColorPresets) {
        expect(find.byKey(Key('swatch_$hex')), findsOneWidget);
      }
    });

    testWidgets('selected swatch shows checkmark icon', (tester) async {
      const selected = '#1E88E5';
      await tester.pumpWidget(buildSwatchPicker(
        selectedHex: selected,
        onChanged: (_) {},
      ));

      // There should be exactly one check icon (on the selected swatch).
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('tapping unselected swatch calls onChanged with correct hex',
        (tester) async {
      const initial = '#1E88E5';
      const target = '#43A047';
      String? received;

      await tester.pumpWidget(buildSwatchPicker(
        selectedHex: initial,
        onChanged: (h) => received = h,
      ));

      await tester.tap(find.byKey(Key('swatch_$target')));
      await tester.pump();

      expect(received, equals(target));
    });

    testWidgets('does not show multiple checkmarks', (tester) async {
      await tester.pumpWidget(buildSwatchPicker(
        selectedHex: kSourceColorPresets.first,
        onChanged: (_) {},
      ));

      // Only 1 check icon (the selected one)
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('case-insensitive: uppercase hex still shows checkmark',
        (tester) async {
      // Pass the hex in uppercase to verify the equality check is case-insensitive.
      final hex = kSourceColorPresets.first.toUpperCase();
      await tester.pumpWidget(buildSwatchPicker(
        selectedHex: hex,
        onChanged: (_) {},
      ));

      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });
}
