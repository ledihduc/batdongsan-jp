/// Widget tests for AnalyticsHomeScreen — loading, data, empty, error states.
///
/// Uses mocktail to mock ReportProvider and HostProfileProvider.
/// Provider states are driven by stub implementations that expose
/// specific loading/error/summary values for each test case.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:house_booking/data/models/analytics_summary_model.dart';
import 'package:house_booking/features/host/analytics/screens/analytics_home_screen.dart';
import 'package:house_booking/features/host/analytics/services/period_helper.dart';
import 'package:house_booking/features/host/analytics/widgets/analytics_empty_state.dart';
import 'package:house_booking/features/host/analytics/widgets/analytics_error_state.dart';
import 'package:house_booking/features/host/analytics/widgets/analytics_skeleton.dart';
import 'package:house_booking/providers/host_profile_provider.dart';
import 'package:house_booking/providers/report_provider.dart';
import '../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockReportProvider extends Mock implements ReportProvider {}

class MockHostProfileProvider extends Mock implements HostProfileProvider {}

// ---------------------------------------------------------------------------
// Fake data helpers
// ---------------------------------------------------------------------------

AnalyticsSummaryModel _fakeSummary({
  double grossRevenue = 5000000,
  double netRevenue = 4500000,
  double occupancyPct = 82.4,
  double adr = 800000,
  int bookingPace = 12,
  double? grossRevenuePct = 10.0,
  double? netRevenuePct = 8.0,
  double? occupancyPctDiff = 2.5,
}) {
  return AnalyticsSummaryModel(
    period: PeriodInfo(
      type: 'month',
      date: '2026-06',
      startUtc: DateTime.utc(2026, 5, 31, 17),
      endUtc: DateTime.utc(2026, 6, 30, 16, 59, 59),
    ),
    kpis: KpiBlock(
      grossRevenue: grossRevenue,
      netRevenue: netRevenue,
      refundTotal: 0,
      commissionTotal: 0,
      occupancyPct: occupancyPct,
      adr: adr,
      bookingPace: bookingPace,
    ),
    deltas: DeltaBlock(
      grossRevenuePct: grossRevenuePct,
      netRevenuePct: netRevenuePct,
      occupancyPctDiff: occupancyPctDiff,
    ),
  );
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Pumps AnalyticsHomeScreen with the given provider states.
/// Uses a GoRouter wrapper to satisfy any GoRouter.of(context) calls.
Future<void> _pumpScreen(
  WidgetTester tester, {
  required ReportProvider reportProvider,
  required HostProfileProvider hostProfileProvider,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => MultiProvider(
          providers: [
            ChangeNotifierProvider<ReportProvider>.value(value: reportProvider),
            ChangeNotifierProvider<HostProfileProvider>.value(
                value: hostProfileProvider),
          ],
          child: const AnalyticsHomeScreen(),
        ),
      ),
    ],
  );

  // Màn hình ghi telemetry → phải có Provider<TelemetryService> ở gốc.
  await pumpAppRaw(tester, MaterialApp.router(routerConfig: router));
  await tester.pump(); // let initState post-frame callback fire
  await tester.pump(); // settle animations
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockReportProvider reportProvider;
  late MockHostProfileProvider hostProfileProvider;

  setUpAll(() {
    registerFallbackValue(PeriodType.month);
    registerFallbackValue(DateTime.now());
  });

  setUp(() {
    reportProvider = MockReportProvider();
    hostProfileProvider = MockHostProfileProvider();

    // Default stubs — tests override as needed
    when(() => reportProvider.summaryLoading).thenReturn(false);
    when(() => reportProvider.summaryError).thenReturn(null);
    when(() => reportProvider.summary).thenReturn(null);
    when(() => reportProvider.offline).thenReturn(false);
    when(() => reportProvider.lastSuccessfulFetchAt).thenReturn(null);
    when(
      () => reportProvider.fetchAnalyticsSummary(
        period: any(named: 'period'),
        date: any(named: 'date'),
        force: any(named: 'force'),
      ),
    ).thenAnswer((_) async {});

    when(() => hostProfileProvider.profile).thenReturn(null);
    when(() => hostProfileProvider.isLoading).thenReturn(false);
    when(() => hostProfileProvider.error).thenReturn(null);
    when(() => hostProfileProvider.isOnboardingComplete).thenReturn(false);
    when(() => hostProfileProvider.fetchProfile()).thenAnswer((_) async {});
  });

  group('AnalyticsHomeScreen — loading state', () {
    testWidgets('loading=true + no summary → skeleton visible', (tester) async {
      when(() => reportProvider.summaryLoading).thenReturn(true);
      when(() => reportProvider.summary).thenReturn(null);

      await _pumpScreen(
        tester,
        reportProvider: reportProvider,
        hostProfileProvider: hostProfileProvider,
      );

      expect(find.byType(AnalyticsSkeleton), findsOneWidget);
      expect(find.byKey(const Key('kpi_gross')), findsNothing);
    });
  });

  group('AnalyticsHomeScreen — data state', () {
    testWidgets('summary available → 5 KPI cards visible', (tester) async {
      when(() => reportProvider.summaryLoading).thenReturn(false);
      when(() => reportProvider.summary).thenReturn(_fakeSummary());

      await _pumpScreen(
        tester,
        reportProvider: reportProvider,
        hostProfileProvider: hostProfileProvider,
      );

      expect(find.byKey(const Key('kpi_gross')), findsOneWidget);
      expect(find.byKey(const Key('kpi_net')), findsOneWidget);
      expect(find.byKey(const Key('kpi_occupancy')), findsOneWidget);
      expect(find.byKey(const Key('kpi_adr')), findsOneWidget);
      expect(find.byKey(const Key('kpi_booking_pace')), findsOneWidget);
    });

    testWidgets('title "Thống kê doanh thu" visible', (tester) async {
      when(() => reportProvider.summary).thenReturn(_fakeSummary());

      await _pumpScreen(
        tester,
        reportProvider: reportProvider,
        hostProfileProvider: hostProfileProvider,
      );

      expect(find.text('Thống kê doanh thu'), findsOneWidget);
    });
  });

  group('AnalyticsHomeScreen — empty state', () {
    testWidgets(
        'gross=0 and bookingPace=0 → empty widget visible + CTA button',
        (tester) async {
      when(() => reportProvider.summary).thenReturn(
        _fakeSummary(
          grossRevenue: 0,
          netRevenue: 0,
          occupancyPct: 0,
          adr: 0,
          bookingPace: 0,
          grossRevenuePct: null,
          netRevenuePct: null,
          occupancyPctDiff: null,
        ),
      );

      await _pumpScreen(
        tester,
        reportProvider: reportProvider,
        hostProfileProvider: hostProfileProvider,
      );

      expect(find.byType(AnalyticsEmptyState), findsOneWidget);
      expect(find.byKey(const Key('empty_cta_btn')), findsOneWidget);
      // KPI cards should NOT appear
      expect(find.byKey(const Key('kpi_gross')), findsNothing);
    });
  });

  group('AnalyticsHomeScreen — error state', () {
    testWidgets('error + no summary → error widget + retry button',
        (tester) async {
      when(() => reportProvider.summaryError)
          .thenReturn('Không thể kết nối máy chủ');
      when(() => reportProvider.summary).thenReturn(null);

      await _pumpScreen(
        tester,
        reportProvider: reportProvider,
        hostProfileProvider: hostProfileProvider,
      );

      expect(find.byType(AnalyticsErrorState), findsOneWidget);
      expect(find.byKey(const Key('error_retry_btn')), findsOneWidget);
      expect(find.text('Không thể kết nối máy chủ'), findsOneWidget);
    });

    testWidgets('tap retry → provider.fetchAnalyticsSummary called',
        (tester) async {
      when(() => reportProvider.summaryError).thenReturn('Lỗi mạng');
      when(() => reportProvider.summary).thenReturn(null);

      await _pumpScreen(
        tester,
        reportProvider: reportProvider,
        hostProfileProvider: hostProfileProvider,
      );

      await tester.tap(find.byKey(const Key('error_retry_btn')));
      await tester.pump();

      verify(
        () => reportProvider.fetchAnalyticsSummary(
          period: any(named: 'period'),
          date: any(named: 'date'),
          force: any(named: 'force'),
        ),
      ).called(greaterThan(0));
    });
  });

  group('AnalyticsHomeScreen — initState fetch', () {
    testWidgets('on init → fetchAnalyticsSummary is called', (tester) async {
      when(() => reportProvider.summary).thenReturn(_fakeSummary());

      await _pumpScreen(
        tester,
        reportProvider: reportProvider,
        hostProfileProvider: hostProfileProvider,
      );

      verify(
        () => reportProvider.fetchAnalyticsSummary(
          period: any(named: 'period'),
          date: any(named: 'date'),
          force: any(named: 'force'),
        ),
      ).called(greaterThan(0));
    });
  });
}
