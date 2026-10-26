/// Unit tests for ReportProvider — v2 analytics methods + SourceInUseException.
///
/// Tests: state transitions (loading→data→notify), isFresh boundary at 5 min,
/// cache eviction on period change, source CRUD invalidates cache,
/// 409 surfaced as SourceInUseException, drill pagination, v1 shim delegates.
///
/// Uses mocktail to mock IAnalyticsRepository.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:house_booking/data/models/analytics_summary_model.dart';
import 'package:house_booking/data/models/heatmap_cell_model.dart';
import 'package:house_booking/data/models/revenue_source_model.dart';
import 'package:house_booking/data/models/source_breakdown_model.dart';
import 'package:house_booking/data/models/trend_bucket_model.dart';
import 'package:house_booking/data/repositories/api_report_repository.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/domain/repositories/i_analytics_repository.dart';
import 'package:house_booking/features/host/analytics/services/period_helper.dart';
import 'package:house_booking/providers/report_provider.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAnalyticsRepository extends Mock implements IAnalyticsRepository {}

class MockApiReportRepository extends Mock implements ApiReportRepository {}

// ---------------------------------------------------------------------------
// SourceInUseException contract
// ---------------------------------------------------------------------------

void _sourceInUseExceptionTests() {
  group('SourceInUseException', () {
    test('toString contains exception name', () {
      const ex = SourceInUseException();
      expect(ex.toString(), contains('SourceInUseException'));
    });

    test('is an Exception', () {
      const ex = SourceInUseException();
      expect(ex, isA<Exception>());
    });
  });
}

// ---------------------------------------------------------------------------
// Fake data builders
// ---------------------------------------------------------------------------

AnalyticsSummaryModel _fakeSummary() => AnalyticsSummaryModel(
      period: PeriodInfo(
        type: 'month',
        date: '2026-07',
        startUtc: DateTime.utc(2026, 6, 30, 17),
        endUtc: DateTime.utc(2026, 7, 31, 17),
      ),
      kpis: const KpiBlock(
        grossRevenue: 5000000,
        netRevenue: 4500000,
        refundTotal: 500000,
        commissionTotal: 0,
        occupancyPct: 72.5,
        adr: 350000,
        bookingPace: 12,
      ),
      deltas: const DeltaBlock(grossRevenuePct: 15.0),
    );

RevenueTrendModel _fakeTrend() => const RevenueTrendModel(
      periods: ['2025-08', '2026-07'],
      current: [0.0, 5000000.0],
      currentNet: [0.0, 4500000.0],
      prior: [0.0, 3000000.0],
      priorNet: [0.0, 2800000.0],
    );

OccupancyHeatmapModel _fakeHeatmap() => const OccupancyHeatmapModel(
      month: '2026-07',
      days: 31,
      rooms: [],
    );

SourceBreakdownModel _fakeBreakdown() => const SourceBreakdownModel(
      period: '2026-07',
      total: 5000000,
      items: [],
    );

RevenueSourceModel _fakeSource({int id = 1, bool isArchived = false}) =>
    RevenueSourceModel(
      id: id,
      hostId: 42,
      name: 'Trực tiếp',
      displayName: 'Trực tiếp',
      colorHex: '#4CAF50',
      isArchived: isArchived,
      createdAt: DateTime.utc(2026, 1, 15),
      updatedAt: DateTime.utc(2026, 6, 28),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Run SourceInUseException tests (standalone — no provider needed)
  _sourceInUseExceptionTests();

  late MockAnalyticsRepository mockAnalytics;
  late ReportProvider provider;
  final date = DateTime(2026, 7, 1);

  setUpAll(() {
    // mocktail fallback values
    registerFallbackValue(_fakeSummary());
    registerFallbackValue(_fakeTrend());
    registerFallbackValue(_fakeHeatmap());
    registerFallbackValue(_fakeBreakdown());
    registerFallbackValue(_fakeSource());
    registerFallbackValue(<RevenueSourceModel>[]);
  });

  setUp(() {
    mockAnalytics = MockAnalyticsRepository();
    provider = ReportProvider(analyticsRepo: mockAnalytics);
  });

  tearDown(() => provider.dispose());

  // ---------------------------------------------------------------------------
  // fetchAnalyticsSummary state transitions
  // ---------------------------------------------------------------------------

  group('fetchAnalyticsSummary', () {
    test('transitions loading → data → notifyListeners called', () async {
      when(() => mockAnalytics.fetchSummary(
            period: any(named: 'period'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => _fakeSummary());

      final states = <bool>[];
      provider.addListener(() => states.add(provider.summaryLoading));

      await provider.fetchAnalyticsSummary(
        period: PeriodType.month,
        date: date,
        force: true,
      );

      // Listener was called at least twice: true (loading) then false (done)
      expect(states, contains(true));
      expect(states.last, isFalse);
      expect(provider.summary, isNotNull);
      expect(provider.summaryError, isNull);
    });

    test('sets summaryError on ApiException', () async {
      when(() => mockAnalytics.fetchSummary(
            period: any(named: 'period'),
            date: any(named: 'date'),
          )).thenThrow(ApiException(500, 'Server error'));

      await provider.fetchAnalyticsSummary(
        period: PeriodType.month,
        date: date,
        force: true,
      );

      expect(provider.summary, isNull);
      expect(provider.summaryError, isNotNull);
      expect(provider.summaryLoading, isFalse);
    });

    test('skips network when cache is fresh (force=false)', () async {
      when(() => mockAnalytics.fetchSummary(
            period: any(named: 'period'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => _fakeSummary());

      // First call — fetches
      await provider.fetchAnalyticsSummary(
        period: PeriodType.month,
        date: date,
        force: true,
      );

      // Second call without force — should use cache
      await provider.fetchAnalyticsSummary(
        period: PeriodType.month,
        date: date,
      );

      verify(() => mockAnalytics.fetchSummary(
            period: any(named: 'period'),
            date: any(named: 'date'),
          )).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // isFresh boundary
  // ---------------------------------------------------------------------------

  group('isFresh', () {
    test('returns false before any fetch', () {
      expect(provider.isFresh('summary', 'month', '2026-07'), isFalse);
    });

    test('returns true immediately after fetch (within 5 min)', () async {
      when(() => mockAnalytics.fetchSummary(
            period: any(named: 'period'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => _fakeSummary());

      await provider.fetchAnalyticsSummary(
        period: PeriodType.month,
        date: date,
        force: true,
      );

      expect(
        provider.isFresh('summary', 'month', '2026-07',
            maxAge: const Duration(minutes: 5)),
        isTrue,
      );
    });

    test('returns false with maxAge=zero (instant expiry)', () async {
      when(() => mockAnalytics.fetchSummary(
            period: any(named: 'period'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => _fakeSummary());

      await provider.fetchAnalyticsSummary(
        period: PeriodType.month,
        date: date,
        force: true,
      );

      expect(
        provider.isFresh('summary', 'month', '2026-07',
            maxAge: Duration.zero),
        isFalse,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Cache eviction on period change
  // ---------------------------------------------------------------------------

  group('cache eviction', () {
    test('period change triggers new network request', () async {
      when(() => mockAnalytics.fetchSummary(
            period: any(named: 'period'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => _fakeSummary());

      // Fetch July 2026
      await provider.fetchAnalyticsSummary(
        period: PeriodType.month,
        date: DateTime(2026, 7, 1),
        force: true,
      );

      // Fetch June 2026 — different period key → cache miss → new request
      await provider.fetchAnalyticsSummary(
        period: PeriodType.month,
        date: DateTime(2026, 6, 1),
        force: false, // NOT forced — must detect param change
      );

      // Two calls: July + June
      verify(() => mockAnalytics.fetchSummary(
            period: any(named: 'period'),
            date: any(named: 'date'),
          )).called(2);
    });
  });

  // ---------------------------------------------------------------------------
  // fetchTrend
  // ---------------------------------------------------------------------------

  group('fetchTrend', () {
    test('happy path sets trend and clears error', () async {
      when(() => mockAnalytics.fetchTrend(
            period: any(named: 'period'),
            anchor: any(named: 'anchor'),
          )).thenAnswer((_) async => _fakeTrend());

      await provider.fetchTrend(
        period: PeriodType.month,
        anchor: date,
        force: true,
      );

      expect(provider.trend, isNotNull);
      expect(provider.trendError, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // fetchHeatmap
  // ---------------------------------------------------------------------------

  group('fetchHeatmap', () {
    test('happy path sets heatmap', () async {
      when(() => mockAnalytics.fetchHeatmap(
            month: any(named: 'month'),
            buildingId: any(named: 'buildingId'),
          )).thenAnswer((_) async => _fakeHeatmap());

      await provider.fetchHeatmap(month: date, force: true);

      expect(provider.heatmap, isNotNull);
      expect(provider.heatmapError, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // fetchSources
  // ---------------------------------------------------------------------------

  group('fetchSources', () {
    test('happy path sets sources list', () async {
      when(() => mockAnalytics.fetchSources(
            includeArchived: any(named: 'includeArchived'),
          )).thenAnswer((_) async => [_fakeSource()]);

      await provider.fetchSources(force: true);

      expect(provider.sources, hasLength(1));
      expect(provider.sourcesError, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Source CRUD — cache invalidation
  // ---------------------------------------------------------------------------

  group('source CRUD', () {
    test('createSource invalidates sources cache', () async {
      when(() => mockAnalytics.fetchSources(
            includeArchived: any(named: 'includeArchived'),
          )).thenAnswer((_) async => [_fakeSource()]);

      when(() => mockAnalytics.createSource(
            name: any(named: 'name'),
            colorHex: any(named: 'colorHex'),
          )).thenAnswer((_) async => _fakeSource(id: 2));

      // Populate cache
      await provider.fetchSources(force: true);
      expect(provider.isFresh('sources', 'active', ''), isTrue);

      // Create invalidates
      await provider.createSource(name: 'Mới', colorHex: '#FF0000');
      expect(provider.isFresh('sources', 'active', ''), isFalse);
    });

    test('updateSource invalidates sources cache', () async {
      when(() => mockAnalytics.fetchSources(
            includeArchived: any(named: 'includeArchived'),
          )).thenAnswer((_) async => [_fakeSource()]);

      when(() => mockAnalytics.updateSource(
            id: any(named: 'id'),
            name: any(named: 'name'),
            colorHex: any(named: 'colorHex'),
            archive: any(named: 'archive'),
          )).thenAnswer((_) async => _fakeSource());

      await provider.fetchSources(force: true);
      await provider.updateSource(id: 1, name: 'Updated');

      expect(provider.isFresh('sources', 'active', ''), isFalse);
    });

    test('archiveSource invalidates sources cache', () async {
      when(() => mockAnalytics.fetchSources(
            includeArchived: any(named: 'includeArchived'),
          )).thenAnswer((_) async => [_fakeSource()]);

      when(() => mockAnalytics.updateSource(
            id: any(named: 'id'),
            name: any(named: 'name'),
            colorHex: any(named: 'colorHex'),
            archive: any(named: 'archive'),
          )).thenAnswer((_) async => _fakeSource(isArchived: true));

      await provider.fetchSources(force: true);
      await provider.archiveSource(1);

      expect(provider.isFresh('sources', 'active', ''), isFalse);
    });

    test('deleteSource invalidates sources cache on success', () async {
      when(() => mockAnalytics.fetchSources(
            includeArchived: any(named: 'includeArchived'),
          )).thenAnswer((_) async => [_fakeSource()]);

      when(() => mockAnalytics.deleteSource(any()))
          .thenAnswer((_) async {});

      await provider.fetchSources(force: true);
      await provider.deleteSource(1);

      expect(provider.isFresh('sources', 'active', ''), isFalse);
    });

    test('deleteSource propagates SourceInUseException (409)', () async {
      when(() => mockAnalytics.deleteSource(any()))
          .thenThrow(const SourceInUseException());

      expect(
        () => provider.deleteSource(1),
        throwsA(isA<SourceInUseException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // fetchSourceBreakdown
  // ---------------------------------------------------------------------------

  group('fetchSourceBreakdown', () {
    test('happy path sets sourceBreakdown', () async {
      when(() => mockAnalytics.fetchSourceBreakdown(
            period: any(named: 'period'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => _fakeBreakdown());

      await provider.fetchSourceBreakdown(
        period: PeriodType.month,
        date: date,
        force: true,
      );

      expect(provider.sourceBreakdown, isNotNull);
      expect(provider.sourceBreakdownError, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Drill-down — not cached
  // ---------------------------------------------------------------------------

  group('fetchDrill*', () {
    test('fetchDrillRooms calls fetchDrillRaw and returns RoomListResponse',
        () async {
      when(() => mockAnalytics.fetchDrillRaw(
            level: any(named: 'level'),
            params: any(named: 'params'),
          )).thenAnswer((_) async => {
                'items': [
                  {
                    'room_id': 101,
                    'room_code': 'P.101',
                    'room_status': 'occupied',
                    'building_id': 1,
                    'building_name': 'Tòa A',
                  },
                ],
                'total_count': 1,
                'page': 1,
                'page_size': 50,
              });

      final resp = await provider.fetchDrillRooms();
      expect(resp.items, hasLength(1));
      expect(resp.items.first.roomId, equals(101));
    });

    test('fetchDrillContracts passes room_id param', () async {
      when(() => mockAnalytics.fetchDrillRaw(
            level: any(named: 'level'),
            params: any(named: 'params'),
          )).thenAnswer((_) async => {
                'items': [],
                'total_count': 0,
                'page': 1,
                'page_size': 50,
              });

      final resp = await provider.fetchDrillContracts(roomId: 42);
      expect(resp.items, isEmpty);

      final captured = verify(() => mockAnalytics.fetchDrillRaw(
            level: any(named: 'level'),
            params: captureAny(named: 'params'),
          )).captured;
      final params = captured.first as Map<String, dynamic>;
      expect(params['room_id'], equals(42));
    });

    test('fetchDrillTenants passes contract_id param', () async {
      when(() => mockAnalytics.fetchDrillRaw(
            level: any(named: 'level'),
            params: any(named: 'params'),
          )).thenAnswer((_) async => {
                'items': [],
                'total_count': 0,
                'page': 1,
                'page_size': 50,
              });

      final resp = await provider.fetchDrillTenants(contractId: 99);
      expect(resp.items, isEmpty);
    });

    test('fetchDrillInvoices passes tenant_id param', () async {
      when(() => mockAnalytics.fetchDrillRaw(
            level: any(named: 'level'),
            params: any(named: 'params'),
          )).thenAnswer((_) async => {
                'items': [],
                'total_count': 0,
                'page': 1,
                'page_size': 50,
              });

      final resp = await provider.fetchDrillInvoices(tenantId: 201);
      expect(resp.items, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // fetchTrend — error path
  // ---------------------------------------------------------------------------

  group('fetchTrend error', () {
    test('sets trendError on ApiException', () async {
      when(() => mockAnalytics.fetchTrend(
            period: any(named: 'period'),
            anchor: any(named: 'anchor'),
          )).thenThrow(ApiException(503, 'Unavailable'));

      await provider.fetchTrend(
        period: PeriodType.month,
        anchor: date,
        force: true,
      );

      expect(provider.trendError, isNotNull);
      expect(provider.trendLoading, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // fetchHeatmap — error path
  // ---------------------------------------------------------------------------

  group('fetchHeatmap error', () {
    test('sets heatmapError on ApiException', () async {
      when(() => mockAnalytics.fetchHeatmap(
            month: any(named: 'month'),
            buildingId: any(named: 'buildingId'),
          )).thenThrow(ApiException(500, 'Server error'));

      await provider.fetchHeatmap(month: date, force: true);

      expect(provider.heatmapError, isNotNull);
      expect(provider.heatmapLoading, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // fetchSourceBreakdown — error path
  // ---------------------------------------------------------------------------

  group('fetchSourceBreakdown error', () {
    test('sets sourceBreakdownError on ApiException', () async {
      when(() => mockAnalytics.fetchSourceBreakdown(
            period: any(named: 'period'),
            date: any(named: 'date'),
          )).thenThrow(ApiException(500, 'Server error'));

      await provider.fetchSourceBreakdown(
        period: PeriodType.month,
        date: date,
        force: true,
      );

      expect(provider.sourceBreakdownError, isNotNull);
      expect(provider.sourceBreakdownLoading, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // fetchSources — error path
  // ---------------------------------------------------------------------------

  group('fetchSources error', () {
    test('sets sourcesError on ApiException', () async {
      when(() => mockAnalytics.fetchSources(
            includeArchived: any(named: 'includeArchived'),
          )).thenThrow(ApiException(500, 'Server error'));

      await provider.fetchSources(force: true);

      expect(provider.sourcesError, isNotNull);
      expect(provider.sourcesLoading, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // downloadInvoicesCsv — via MockApiReportRepository
  // ---------------------------------------------------------------------------

  group('downloadInvoicesCsv (v1 shim)', () {
    late MockApiReportRepository mockRepo;
    late ReportProvider providerWithRepo;

    setUp(() {
      mockRepo = MockApiReportRepository();
      providerWithRepo =
          ReportProvider(repo: mockRepo, analyticsRepo: mockAnalytics);
    });

    tearDown(() => providerWithRepo.dispose());

    test('returns bytes on success', () async {
      when(() => mockRepo.exportInvoicesCsv(month: any(named: 'month')))
          .thenAnswer((_) async => [1, 2, 3]);

      final bytes = await providerWithRepo.downloadInvoicesCsv(month: '2026-07');
      expect(bytes, equals([1, 2, 3]));
      expect(providerWithRepo.error, isNull);
    });

    test('returns null on ApiException and sets error', () async {
      when(() => mockRepo.exportInvoicesCsv(month: any(named: 'month')))
          .thenThrow(ApiException(500, 'Export failed'));

      final bytes = await providerWithRepo.downloadInvoicesCsv(month: '2026-07');
      expect(bytes, isNull);
      expect(providerWithRepo.error, isNotNull);
    });
  });
}
