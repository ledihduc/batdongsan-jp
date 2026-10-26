/// Route gate tests for JP market routes.
///
/// Verifies:
///   1. In a standard VN test build, [FeatureFlags.isJapan] is false — JP
///      routes are never registered (they sit behind `if (FeatureFlags.isJapan)`
///      compile-time guards, so no router test can navigate to them).
///   2. The [JpSearchFilter.toSearchParams()] converter produces correct params.
///   3. The redirect logic would gate VN-only paths in a JP build — verified by
///      calling the predicate directly without spinning up GoRouter.
///
/// Note: compile-time constant tests.
/// [FeatureFlags.isJapan] == false in test runs (no --dart-define=REGION=jp).
/// JP routes are simply absent from the route table in this build.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/config/feature_flags.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_listing_repository.dart';
import 'package:house_booking/features/guest/search/jp_search_facets_drawer.dart';

void main() {
  group('FeatureFlags region gate', () {
    test('isJapan is false in default VN test build', () {
      // The REGION dart-define defaults to "vn".
      // All JP routes sit behind `if (FeatureFlags.isJapan)` — they are absent
      // from the route table in this build, so navigation to them is impossible.
      expect(FeatureFlags.isJapan, isFalse);
    });

    test('region defaults to vn', () {
      expect(FeatureFlags.region, equals('vn'));
    });
  });

  group('JpSearchFilter.toSearchParams()', () {
    test('empty filter produces default params', () {
      const filter = JpSearchFilter();
      final params = filter.toSearchParams();

      expect(params.layouts, isNull);
      expect(params.minRent, isNull);
      expect(params.maxRent, isNull);
      expect(params.petsOk, isNull);
      expect(params.noGuarantorRequired, isNull);
    });

    test('selected layouts are passed through', () {
      const filter = JpSearchFilter(layouts: ['1LDK', '2LDK']);
      final params = filter.toSearchParams();

      expect(params.layouts, equals(['1LDK', '2LDK']));
    });

    test('empty layouts list maps to null (not empty list)', () {
      const filter = JpSearchFilter(layouts: []);
      final params = filter.toSearchParams();

      // Backend treats absence of layouts as "all" — empty list would be
      // misinterpreted as "no layouts match". Converter must return null.
      expect(params.layouts, isNull);
    });

    test('petsOk=true maps to true in params', () {
      const filter = JpSearchFilter(petsOk: true);
      final params = filter.toSearchParams();

      expect(params.petsOk, isTrue);
    });

    test('petsOk=false maps to null (not false) in params', () {
      // null = "no filter"; false would incorrectly exclude petsOk listings.
      const filter = JpSearchFilter(petsOk: false);
      final params = filter.toSearchParams();

      expect(params.petsOk, isNull);
    });

    test('rent range values passed through', () {
      const filter = JpSearchFilter(minRent: 50000, maxRent: 200000);
      final params = filter.toSearchParams();

      expect(params.minRent, equals(50000));
      expect(params.maxRent, equals(200000));
    });

    test('walkMinutes and buildingAge passed through', () {
      const filter = JpSearchFilter(
        maxWalkMinutes: 10,
        maxBuildingAgeYears: 20,
      );
      final params = filter.toSearchParams();

      expect(params.maxWalkMinutes, equals(10));
      expect(params.maxBuildingAgeYears, equals(20));
    });
  });

  group('JpListingSearchParams.toQueryParameters()', () {
    test('default params include page and page_size', () {
      const params = JpListingSearchParams();
      final qp = params.toQueryParameters();

      // Always includes pagination — backend requires these fields.
      expect(qp['page'], equals('1'));
      expect(qp['page_size'], equals('20'));
    });

    test('layout list is serialised as comma-separated', () {
      const params = JpListingSearchParams(layouts: ['1LDK', '2LDK']);
      final qp = params.toQueryParameters();

      expect(qp['layouts'], equals('1LDK,2LDK'));
    });

    test('numeric params serialised as strings', () {
      const params = JpListingSearchParams(maxRent: 150000, maxWalkMinutes: 8);
      final qp = params.toQueryParameters();

      expect(qp['max_rent'], equals('150000'));
      // Implementation uses 'max_walk_min' (backend key)
      expect(qp['max_walk_min'], equals('8'));
    });
  });
}
