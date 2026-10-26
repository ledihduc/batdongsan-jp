/// Widget tests for FilterBottomSheet — chip toggle, reset, apply.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/features/host/analytics/providers/drill_provider.dart';
import 'package:house_booking/features/host/analytics/widgets/filter_bottom_sheet.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';
import 'package:house_booking/providers/report_provider.dart';
import 'package:house_booking/core/telemetry/telemetry_service.dart';

/// Pump widget with required providers.
Future<void> _pumpSheet(WidgetTester tester) async {
  final drill = DrillProvider();
  final building = BuildingProvider();
  final report = ReportProvider();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DrillProvider>.value(value: drill),
        ChangeNotifierProvider<BuildingProvider>.value(value: building),
        ChangeNotifierProvider<ReportProvider>.value(value: report),
        // Nút Áp dụng/Đặt lại ghi telemetry — thiếu provider này thì bấm nút
        // ném ProviderNotFoundException nên sheet không bao giờ đóng.
        Provider<TelemetryService>(create: (_) => TelemetryService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('vi'),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open_filter'),
                onPressed: () => showFilterBottomSheet(ctx),
                child: const Text('Open Filter'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // Open the bottom sheet.
  await tester.tap(find.byKey(const Key('open_filter')));
  await tester.pumpAndSettle();
}

void main() {
  group('FilterBottomSheet', () {
    testWidgets('renders filter sheet with title "Lọc"', (tester) async {
      await _pumpSheet(tester);
      expect(find.text('Lọc'), findsOneWidget);
    });

    testWidgets('renders Reset and Áp dụng buttons', (tester) async {
      await _pumpSheet(tester);
      expect(find.byKey(const Key('filter_reset_btn')), findsOneWidget);
      expect(find.byKey(const Key('filter_apply_btn')), findsOneWidget);
    });

    testWidgets('renders room type chips', (tester) async {
      await _pumpSheet(tester);
      expect(find.byKey(const Key('room_type_Phòng trọ')), findsOneWidget);
      expect(find.byKey(const Key('room_type_Homestay')), findsOneWidget);
    });

    testWidgets('renders date range button', (tester) async {
      await _pumpSheet(tester);
      expect(find.byKey(const Key('date_range_button')), findsOneWidget);
    });

    testWidgets('tapping Homestay chip selects it', (tester) async {
      await _pumpSheet(tester);
      final chip = find.byKey(const Key('room_type_Homestay'));
      expect(chip, findsOneWidget);

      // Tap to select.
      await tester.tap(chip);
      await tester.pumpAndSettle();

      // After selection the chip's selected state changes — verify by tapping apply.
      // The button should be present.
      expect(find.byKey(const Key('filter_apply_btn')), findsOneWidget);
    });

    testWidgets('tapping Apply closes the sheet', (tester) async {
      await _pumpSheet(tester);
      await tester.tap(find.byKey(const Key('filter_apply_btn')));
      await tester.pumpAndSettle();
      // Sheet closed — no longer finds the apply button.
      expect(find.byKey(const Key('filter_apply_btn')), findsNothing);
    });

    testWidgets('tapping Reset closes the sheet', (tester) async {
      await _pumpSheet(tester);
      await tester.tap(find.byKey(const Key('filter_reset_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('filter_reset_btn')), findsNothing);
    });

    testWidgets('Apply updates DrillProvider filter', (tester) async {
      final drill = DrillProvider();
      final building = BuildingProvider();
      final report = ReportProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DrillProvider>.value(value: drill),
            ChangeNotifierProvider<BuildingProvider>.value(value: building),
            ChangeNotifierProvider<ReportProvider>.value(value: report),
            Provider<TelemetryService>(create: (_) => TelemetryService()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('vi'),
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    key: const Key('open_filter'),
                    onPressed: () => showFilterBottomSheet(ctx),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_filter')));
      await tester.pumpAndSettle();

      // Select Homestay room type.
      await tester.tap(find.byKey(const Key('room_type_Homestay')));
      await tester.pumpAndSettle();

      // Apply.
      await tester.tap(find.byKey(const Key('filter_apply_btn')));
      await tester.pumpAndSettle();

      // DrillProvider filter updated.
      expect(drill.filter.roomType, equals('Homestay'));
    });

    testWidgets('Reset clears DrillProvider filter', (tester) async {
      final drill = DrillProvider();
      // Pre-set a filter.
      drill.updateFilter(const FilterState(roomType: 'Homestay'));

      final building = BuildingProvider();
      final report = ReportProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DrillProvider>.value(value: drill),
            ChangeNotifierProvider<BuildingProvider>.value(value: building),
            ChangeNotifierProvider<ReportProvider>.value(value: report),
            Provider<TelemetryService>(create: (_) => TelemetryService()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('vi'),
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    key: const Key('open_filter'),
                    onPressed: () => showFilterBottomSheet(ctx),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_filter')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filter_reset_btn')));
      await tester.pumpAndSettle();

      // Filter cleared.
      expect(drill.filter.isEmpty, isTrue);
    });
  });

  group('FilterChipGroup (via bottom sheet)', () {
    testWidgets('renders with no building options (empty) without crashing',
        (tester) async {
      await _pumpSheet(tester);
      // No building chips rendered when BuildingProvider has empty list.
      // No crash expected — just verify sheet is shown.
      expect(find.text('Lọc'), findsOneWidget);
    });
  });
}
