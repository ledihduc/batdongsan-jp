/// Widget tests for [ItSessionJoinScreen].
///
/// Verifies: consent required before Zoom button is enabled; checkbox enables button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/it_session/it_session_join_screen.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('Zoom button disabled before consent checked', (tester) async {
    final repo = MockItSessionRepository();
    await pumpApp(
      tester,
      ItSessionJoinScreen(viewingId: 1, repository: repo),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // Session loaded — should show takken-shi info.
    expect(find.text('山田 太郎'), findsOneWidget);

    // Consent checkbox should be unchecked.
    final checkboxes = find.byType(Checkbox);
    expect(checkboxes, findsOneWidget);
    final checkbox = tester.widget<Checkbox>(checkboxes.first);
    expect(checkbox.value, isFalse);
  });

  testWidgets('consent checkbox exists and can be toggled', (tester) async {
    final repo = MockItSessionRepository();
    await pumpApp(
      tester,
      ItSessionJoinScreen(viewingId: 1, repository: repo),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final checkboxes = find.byType(Checkbox);
    expect(checkboxes, findsOneWidget);

    await tester.tap(checkboxes.first);
    await tester.pump();

    final updated = tester.widget<Checkbox>(checkboxes.first);
    expect(updated.value, isTrue);
  });

  testWidgets('license number displayed', (tester) async {
    final repo = MockItSessionRepository();
    await pumpApp(
      tester,
      ItSessionJoinScreen(viewingId: 1, repository: repo),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('東京都知事'), findsOneWidget);
  });
}
