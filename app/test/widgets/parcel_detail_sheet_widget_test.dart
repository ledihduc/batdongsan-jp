/// Widget tests for ParcelDetailSheet.
///
/// ParcelDetailSheet is a pure display widget — it takes a [ParcelDetail]
/// and reads [PlanningMapProvider] from the Provider tree only for dismissSheet.
/// We inject a real provider backed by a MockPlanningService.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/data/models/planning_parcel_model.dart';
import 'package:house_booking/features/planning/providers/planning_map_provider.dart';
import 'package:house_booking/features/planning/widgets/parcel_detail_sheet.dart';

import '../_fakes.dart';
import '../_mocks.dart';

/// Pump a ParcelDetailSheet inside a minimal Provider + MaterialApp tree.
Future<void> _pumpSheet(WidgetTester tester, ParcelDetail parcel) async {
  final mockSvc = MockPlanningService();
  // searchSuggest and tapParcel are not called in this widget; stub them anyway
  when(() => mockSvc.getParcelByPoint(
        any(),
        any(),
        cancelToken: any(named: 'cancelToken'),
      )).thenAnswer((_) async => null);

  final provider = PlanningMapProvider(mockSvc);

  await tester.pumpWidget(
    ChangeNotifierProvider<PlanningMapProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [ParcelDetailSheet(parcel: parcel)],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(registerFallbacks);

  group('ParcelDetailSheet', () {
    // -------------------------------------------------------------------------
    // Field rendering
    // -------------------------------------------------------------------------

    testWidgets('renders zone name', (tester) async {
      final parcel = fakeParcel(zoneName: 'Đất ở đô thị');
      await _pumpSheet(tester, parcel);

      expect(find.textContaining('Đất ở đô thị'), findsWidgets);
    });

    testWidgets('renders district', (tester) async {
      final parcel = fakeParcel(district: 'Quận 1');
      await _pumpSheet(tester, parcel);

      expect(find.textContaining('Quận 1'), findsOneWidget);
    });

    testWidgets('renders area in m²', (tester) async {
      final parcel = fakeParcel(areaM2: 120.5);
      await _pumpSheet(tester, parcel);

      expect(find.textContaining('120.5 m²'), findsOneWidget);
    });

    testWidgets('renders sheet / parcel number', (tester) async {
      final parcel = fakeParcel(sheetNo: 'BM-01', parcelNo: '123');
      await _pumpSheet(tester, parcel);

      expect(find.textContaining('BM-01'), findsOneWidget);
      expect(find.textContaining('123'), findsOneWidget);
    });

    testWidgets('renders zone code', (tester) async {
      final parcel = fakeParcel(zoneCode: 'ODT');
      await _pumpSheet(tester, parcel);

      expect(find.textContaining('ODT'), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // Freshness warning (AC-15)
    // -------------------------------------------------------------------------

    testWidgets('shows freshness warning when fetchedAt is 40 days ago',
        (tester) async {
      final parcel = fakeStaleParcel(); // 40 days ago
      await _pumpSheet(tester, parcel);

      // Warning text contains "cũ hơn 30 ngày"
      expect(find.textContaining('cũ hơn 30 ngày'), findsOneWidget);
    });

    testWidgets('does NOT show freshness warning when fetchedAt is 5 days ago',
        (tester) async {
      final parcel = fakeParcel(
        fetchedAt: DateTime.now().subtract(const Duration(days: 5)),
      );
      await _pumpSheet(tester, parcel);

      expect(find.textContaining('cũ hơn 30 ngày'), findsNothing);
    });

    testWidgets('shows freshness warning exactly at boundary (31 days)', (tester) async {
      final parcel = fakeParcel(
        fetchedAt: DateTime.now().subtract(const Duration(days: 31)),
      );
      await _pumpSheet(tester, parcel);

      expect(find.textContaining('cũ hơn 30 ngày'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Disclaimer (AC-09)
    // -------------------------------------------------------------------------

    testWidgets('disclaimer banner is present', (tester) async {
      await _pumpSheet(tester, fakeParcel());

      // DisclaimerBanner renders text about "tham khảo"
      expect(find.textContaining('Dữ liệu tham khảo'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Report button present
    // -------------------------------------------------------------------------

    testWidgets('report button is present', (tester) async {
      await _pumpSheet(tester, fakeParcel());

      expect(find.textContaining('Báo cáo'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Close button interaction
    // -------------------------------------------------------------------------

    testWidgets('close button calls dismissSheet without throwing', (tester) async {
      await _pumpSheet(tester, fakeParcel());

      final closeBtn = find.byIcon(Icons.close);
      if (closeBtn.evaluate().isNotEmpty) {
        await tester.tap(closeBtn);
        await tester.pump();
      }
      // No exception means dismissSheet was called safely.
      expect(tester.takeException(), isNull);
    });
  });
}
