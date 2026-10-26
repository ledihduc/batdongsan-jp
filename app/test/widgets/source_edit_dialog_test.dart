/// Widget tests for SourceEditDialog — validation, colour picker, server error.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/revenue_source_model.dart';
import 'package:house_booking/features/host/analytics/widgets/color_swatch_picker.dart';
import 'package:house_booking/features/host/analytics/widgets/source_edit_dialog.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

RevenueSourceModel _fakeSource({
  int id = 1,
  String displayName = 'Booking.com',
  String colorHex = '#1E88E5',
  bool isArchived = false,
}) {
  final now = DateTime.now();
  return RevenueSourceModel(
    id: id,
    hostId: 1,
    name: displayName,
    displayName: displayName,
    colorHex: colorHex,
    isArchived: isArchived,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  RevenueSourceModel? initial,
  required Future<void> Function(String, String) onSubmit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            key: const Key('open_dialog'),
            onPressed: () => showDialog<bool>(
              context: ctx,
              builder: (_) => SourceEditDialog(
                initial: initial,
                onSubmit: onSubmit,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.byKey(const Key('open_dialog')));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SourceEditDialog — create mode', () {
    testWidgets('Save button disabled when name is empty', (tester) async {
      await _pumpDialog(
        tester,
        onSubmit: (name, hex) async {},
      );

      // Name field is empty by default
      final saveBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('source_edit_save')),
      );
      expect(saveBtn.onPressed, isNull);
    });

    testWidgets('Save button enabled after entering valid name', (tester) async {
      await _pumpDialog(
        tester,
        onSubmit: (name, hex) async {},
      );

      await tester.enterText(
          find.byKey(const Key('source_name_field')), 'Zalo');
      await tester.pump();

      final saveBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('source_edit_save')),
      );
      expect(saveBtn.onPressed, isNotNull);
    });

    // Note: TextField has maxLength=50 so the widget itself caps input at 50.
    // The _validateName guard still runs when Save is pressed with exactly 50 chars;
    // validation error only fires for empty / trimmed-empty inputs at the UI level.
    // This test verifies the 50-char boundary is the exact limit (no error at 50).
    testWidgets('Save button enabled at maxLength 50 chars (boundary)',
        (tester) async {
      await _pumpDialog(
        tester,
        onSubmit: (name, hex) async {},
      );

      // maxLength=50 limits input to 50 chars → Save should be enabled
      final maxName = 'C' * 50;
      await tester.enterText(
          find.byKey(const Key('source_name_field')), maxName);
      await tester.pump();

      final saveBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('source_edit_save')),
      );
      expect(saveBtn.onPressed, isNotNull);
    });

    testWidgets('Save calls onSubmit with trimmed name and selected hex',
        (tester) async {
      String? receivedName;
      String? receivedHex;

      await _pumpDialog(
        tester,
        onSubmit: (name, hex) async {
          receivedName = name;
          receivedHex = hex;
        },
      );

      await tester.enterText(
          find.byKey(const Key('source_name_field')), '  Zalo  ');
      await tester.pump();

      // Tap the second swatch to change colour
      final secondHex = kSourceColorPresets[1];
      await tester.tap(find.byKey(Key('swatch_$secondHex')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('source_edit_save')));
      await tester.pumpAndSettle();

      expect(receivedName, equals('Zalo'));
      expect(receivedHex, equals(secondHex));
    });

    testWidgets('onSubmit throws → inline error displayed', (tester) async {
      await _pumpDialog(
        tester,
        onSubmit: (name, hex) async {
          throw Exception('revenue_source_name_conflict: Tên đã tồn tại');
        },
      );

      await tester.enterText(
          find.byKey(const Key('source_name_field')), 'Duplicate');
      await tester.pump();

      await tester.tap(find.byKey(const Key('source_edit_save')));
      await tester.pumpAndSettle();

      // Dialog should still be visible with error text
      expect(find.text('Lưu'), findsOneWidget); // dialog still open
      expect(find.textContaining('Tên đã tồn tại'), findsOneWidget);
    });

    testWidgets('Cancel button closes dialog', (tester) async {
      await _pumpDialog(
        tester,
        onSubmit: (name, hex) async {},
      );

      await tester.tap(find.byKey(const Key('source_edit_cancel')));
      await tester.pumpAndSettle();

      // Dialog dismissed — title no longer visible
      expect(find.text('Thêm nguồn mới'), findsNothing);
    });
  });

  group('SourceEditDialog — edit mode', () {
    testWidgets('Pre-fills displayName and colorHex', (tester) async {
      final source = _fakeSource(displayName: 'Booking.com', colorHex: '#43A047');

      await _pumpDialog(
        tester,
        initial: source,
        onSubmit: (name, hex) async {},
      );

      // Name field shows displayName
      final field = tester.widget<TextField>(
        find.byKey(const Key('source_name_field')),
      );
      expect(field.controller!.text, equals('Booking.com'));

      // Selected swatch shows checkmark on the correct colour
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('Title shows "Sửa nguồn" in edit mode', (tester) async {
      await _pumpDialog(
        tester,
        initial: _fakeSource(),
        onSubmit: (name, hex) async {},
      );

      expect(find.text('Sửa nguồn'), findsOneWidget);
    });

    testWidgets('Colour picker selection updates state', (tester) async {
      String? changedHex;
      final source = _fakeSource(colorHex: '#1E88E5');

      await _pumpDialog(
        tester,
        initial: source,
        onSubmit: (_, hex) async => changedHex = hex,
      );

      // Tap a different swatch
      final targetHex = kSourceColorPresets[2]; // '#FB8C00'
      await tester.tap(find.byKey(Key('swatch_$targetHex')));
      await tester.pump();

      // Save
      await tester.tap(find.byKey(const Key('source_edit_save')));
      await tester.pumpAndSettle();

      expect(changedHex, equals(targetHex));
    });
  });
}
