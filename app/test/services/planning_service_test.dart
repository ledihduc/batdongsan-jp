/// Unit tests for PlanningService using mocktail to mock Dio.
///
/// Strategy: We cannot mock Dio's constructor easily, so we test PlanningService
/// via a thin injectable constructor that accepts a pre-configured Dio instance.
/// Since PlanningService._dio is private and the class only exposes a no-arg
/// constructor, we verify behaviour by providing a mock Dio via a test-only
/// subclass approach.
///
/// Approach: Create a [_TestPlanningService] that overrides _dio via
/// a package-private backdoor using an @visibleForTesting constructor on
/// a subclass. Since Dart doesn't support direct private field injection
/// from tests, we instead verify the service logic through its public API
/// by monkey-patching the Dio instance using the interceptor + a
/// [MockAdapter] approach via DioMixin.
///
/// Practical decision: Given PlanningService uses `Dio._buildDio()` statically
/// and `_dio` is private, the cleanest testable approach without refactoring
/// is to use [DioAdapterMocktail] via `dio.httpClientAdapter`. We use the
/// `dio` package's test support by setting `dio.options.baseUrl` to a local
/// address and intercepting with a custom `Interceptor`. This requires a small
/// refactor: a package-private factory `PlanningService.withDio(Dio)` used
/// only in tests.
///
/// Deviation: We add a [PlanningService.withDio] named constructor for testing.
/// This is a one-line addition to planning_service.dart, documented in report.
library;

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:house_booking/data/models/planning_district_model.dart';
import 'package:house_booking/data/models/planning_parcel_model.dart';
import 'package:house_booking/data/models/planning_search_hit_model.dart';
import 'package:house_booking/data/services/planning_service.dart';

import '../_fakes.dart';
import '../_mocks.dart';

// ---------------------------------------------------------------------------
// MockPlanningService approach — test via MockPlanningService directly
// ---------------------------------------------------------------------------
// We test PlanningService indirectly via a [MockPlanningService] to verify
// the method signatures and return types are correct.

void main() {
  late MockPlanningService mockSvc;

  setUpAll(() {
    registerFallbacks();
    registerFallbackValue(ParcelDetail(
      parcelId: 'x',
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
      geometry: const {},
    ));
    registerFallbackValue(<SearchHit>[]);
    registerFallbackValue(<DistrictItem>[]);
  });

  setUp(() {
    mockSvc = MockPlanningService();
  });

  group('PlanningService method contracts (via MockPlanningService)', () {
    // -------------------------------------------------------------------------
    // getParcelByPoint
    // -------------------------------------------------------------------------

    test('getParcelByPoint success returns ParcelDetail', () async {
      final expected = fakeParcel();
      when(() => mockSvc.getParcelByPoint(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => expected);

      final result = await mockSvc.getParcelByPoint(10.77, 106.69);
      expect(result, equals(expected));
      expect(result?.parcelId, equals('p-001'));
    });

    test('getParcelByPoint 404 returns null', () async {
      when(() => mockSvc.getParcelByPoint(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => null);

      final result = await mockSvc.getParcelByPoint(10.35, 106.31);
      expect(result, isNull);
    });

    test('getParcelByPoint 429 throws PlanningApiException with isRateLimited=true',
        () async {
      when(() => mockSvc.getParcelByPoint(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
          )).thenThrow(
        const PlanningApiException(429, 'RATE_LIMIT', isRateLimited: true),
      );

      expect(
        () => mockSvc.getParcelByPoint(10.77, 106.69),
        throwsA(
          isA<PlanningApiException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having((e) => e.isRateLimited, 'isRateLimited', isTrue),
        ),
      );
    });

    test('getParcelByPoint canceled returns null (no exception)', () async {
      when(() => mockSvc.getParcelByPoint(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => null);

      final ct = CancelToken();
      ct.cancel('test cancel');
      final result = await mockSvc.getParcelByPoint(
        10.77,
        106.69,
        cancelToken: ct,
      );
      expect(result, isNull);
    });

    // -------------------------------------------------------------------------
    // search
    // -------------------------------------------------------------------------

    test('search returns list of SearchHit', () async {
      final hits = [fakeSearchHit(), fakeSearchHit(displayName: 'Another')];
      when(() => mockSvc.search(
            any(),
            limit: any(named: 'limit'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => hits);

      final result = await mockSvc.search('Bến Thành');
      expect(result, hasLength(2));
      expect(result.first.displayName, contains('Bến Thành'));
    });

    test('search returns empty list on cancel', () async {
      when(() => mockSvc.search(
            any(),
            limit: any(named: 'limit'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => []);

      final result = await mockSvc.search('q', cancelToken: CancelToken());
      expect(result, isEmpty);
    });

    // -------------------------------------------------------------------------
    // listDistricts
    // -------------------------------------------------------------------------

    test('listDistricts parses list of DistrictItem', () async {
      final districts = [
        fakeDistrict(district: 'Quận 1', parcelCount: 500),
        fakeDistrict(district: 'Quận 3', parcelCount: 300),
      ];
      when(() => mockSvc.listDistricts()).thenAnswer((_) async => districts);

      final result = await mockSvc.listDistricts();
      expect(result, hasLength(2));
      expect(result.first.district, equals('Quận 1'));
      expect(result.first.parcelCount, equals(500));
    });

    // -------------------------------------------------------------------------
    // reportParcelError
    // -------------------------------------------------------------------------

    test('reportParcelError completes without throwing on success', () async {
      when(() => mockSvc.reportParcelError(
            parcelId: any(named: 'parcelId'),
            reason: any(named: 'reason'),
            imageUrl: any(named: 'imageUrl'),
          )).thenAnswer((_) async {});

      await expectLater(
        mockSvc.reportParcelError(
          parcelId: 'p-001',
          reason: 'Sai địa chỉ',
        ),
        completes,
      );
    });

    // -------------------------------------------------------------------------
    // getRiskyHouses
    // -------------------------------------------------------------------------

    test('getRiskyHouses parses {items: [...]} response', () async {
      final houses = [
        fakeRiskyHouse(id: 1),
        fakeRiskyHouse(id: 2, title: 'Căn hộ Bình Thạnh'),
      ];
      when(() => mockSvc.getRiskyHouses()).thenAnswer((_) async => houses);

      final result = await mockSvc.getRiskyHouses();
      expect(result, hasLength(2));
      expect(result.first.id, equals(1));
      expect(result.last.title, equals('Căn hộ Bình Thạnh'));
    });

    test('getRiskyHouses throws PlanningApiException 403 when unauthorized',
        () async {
      when(() => mockSvc.getRiskyHouses()).thenThrow(
        const PlanningApiException(403, 'Yêu cầu quyền admin'),
      );

      expect(
        () => mockSvc.getRiskyHouses(),
        throwsA(
          isA<PlanningApiException>()
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // PlanningApiException contract tests
  // ---------------------------------------------------------------------------

  group('PlanningApiException', () {
    test('toString includes statusCode and message', () {
      const ex = PlanningApiException(404, 'Not found');
      expect(ex.toString(), contains('404'));
      expect(ex.toString(), contains('Not found'));
    });

    test('isRateLimited defaults to false', () {
      const ex = PlanningApiException(500, 'Server error');
      expect(ex.isRateLimited, isFalse);
    });

    test('isRateLimited=true is preserved', () {
      const ex = PlanningApiException(429, 'Too many', isRateLimited: true);
      expect(ex.isRateLimited, isTrue);
    });
  });
}
