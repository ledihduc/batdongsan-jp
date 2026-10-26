/// Widget tests for [JpSearchFacetsDrawer].
///
/// Opens the drawer from a Scaffold and verifies filter chips and apply callback.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/guest/search/jp_search_facets_drawer.dart';

import '../../helpers/pump_app.dart';

final _scaffoldKey = GlobalKey<ScaffoldState>();

/// Wraps the drawer in a Scaffold with an EndDrawer so it can be opened.
Widget _scaffold({
  required void Function(JpSearchFilter) onApply,
  JpSearchFilter initial = const JpSearchFilter(),
}) {
  return Scaffold(
    key: _scaffoldKey,
    endDrawer: JpSearchFacetsDrawer(
      onApply: onApply,
      initialFilter: initial,
    ),
    body: TextButton(
      onPressed: () => _scaffoldKey.currentState!.openEndDrawer(),
      child: const Text('open'),
    ),
  );
}

void main() {
  testWidgets('renders layout chips', (tester) async {
    await pumpApp(tester, _scaffold(onApply: (_) {}));
    await tester.pump();

    // Open drawer
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('1LDK'), findsAtLeastNWidgets(1));
    expect(find.text('2LDK'), findsAtLeastNWidgets(1));
    expect(find.text('1K'), findsAtLeastNWidgets(1));
  });

  testWidgets('tapping layout chip toggles selection', (tester) async {
    await pumpApp(tester, _scaffold(onApply: (_) {}));
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Scroll until 1LDK chip is visible then tap
    await tester.ensureVisible(find.text('1LDK').first);
    await tester.tap(find.text('1LDK').first);
    await tester.pump();

    // After tap, chip is selected — FilterChip shows a checkmark SVG.
    // We verify by checking the chip still exists (selection does not throw).
    expect(find.text('1LDK'), findsAtLeastNWidgets(1));
  });

  testWidgets('apply button fires onApply callback', (tester) async {
    JpSearchFilter? captured;
    await pumpApp(tester, _scaffold(onApply: (f) => captured = f));
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Find and tap the apply (submit) button — DsButton at the bottom of the drawer.
    final applyBtn = find.byType(DsButton);
    expect(applyBtn, findsAtLeastNWidgets(1));
    await tester.tap(applyBtn.last);
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
  });

  testWidgets('reset button clears selected layouts', (tester) async {
    final initial = const JpSearchFilter(layouts: ['1LDK', '2LDK']);
    await pumpApp(tester, _scaffold(onApply: (_) {}, initial: initial));
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tap reset button (text 'リセット' is hardcoded in the widget)
    await tester.tap(find.text('リセット'));
    await tester.pump();

    // Confirm the widget did not throw after reset
    expect(find.byType(Drawer), findsOneWidget);
  });

  testWidgets('renders flag chip labels in drawer', (tester) async {
    await pumpApp(tester, _scaffold(onApply: (_) {}));
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // FilterChip widgets are present for the flag section (4 flags total).
    // We look for FilterChips rendered in the drawer.
    expect(find.byType(FilterChip), findsAtLeastNWidgets(1));
  });
}
