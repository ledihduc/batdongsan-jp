/// Unit tests for [MockJpListingRepository].
///
/// Verifies the mock returns fixture data correctly and filters work.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/repositories/jp/mock_jp_listing_repository.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_listing_repository.dart';

void main() {
  late MockJpListingRepository repo;

  setUp(() {
    repo = const MockJpListingRepository();
  });

  group('MockJpListingRepository', () {
    test('search() returns non-empty fixture list', () async {
      final results = await repo.search(const JpListingSearchParams());
      expect(results, isNotEmpty);
    });

    test('search() filters by layout', () async {
      final results = await repo.search(
        const JpListingSearchParams(layouts: ['1LDK']),
      );
      expect(results.every((l) => l.layout == '1LDK'), isTrue);
    });

    test('search() filters by max rent', () async {
      const maxRent = 100000;
      final results = await repo.search(
        const JpListingSearchParams(maxRent: maxRent),
      );
      expect(results.every((l) => l.monthlyRent <= maxRent), isTrue);
    });

    test('search() filters by max walk minutes', () async {
      const maxWalk = 6;
      final results = await repo.search(
        const JpListingSearchParams(maxWalkMinutes: maxWalk),
      );
      for (final r in results) {
        expect(
          r.nearestStationWalkMin == null ||
              r.nearestStationWalkMin! <= maxWalk,
          isTrue,
        );
      }
    });

    test('getById() returns correct fixture', () async {
      final listing = await repo.getById(9001);
      expect(listing.listingId, equals(9001));
      expect(listing.propertyInfo.layout, equals('1LDK'));
    });

    test('getById() throws when listing not found', () async {
      expect(
        () => repo.getById(99999),
        throwsA(isA<Exception>()),
      );
    });

    test('create() returns a fixture without error', () async {
      final result = await repo.create({'title': 'テスト物件'});
      expect(result.listingId, isPositive);
    });
  });
}
