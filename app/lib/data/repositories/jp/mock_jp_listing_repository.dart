/// Mock implementation of [IJpListingRepository].
///
/// Returns fixture data matching the BE schema so UI can be built and tested
/// before `/api/jp/listings` is live. Swap out for [ApiJpListingRepository]
/// when backend is ready — no change to UI code required.
library;

import 'package:house_booking/data/models/jp/jp_listing.dart';
import 'package:house_booking/data/models/jp/jp_property_info.dart';
import 'package:house_booking/data/models/jp/jp_rental_terms.dart';
import 'package:house_booking/data/models/jp/jp_station.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_listing_repository.dart';

/// Shared fixture listings reused across mock repos.
final _fixtures = <JpListing>[
  JpListing(
    listingId: 9001,
    title: '渋谷区道玄坂 1LDK マンション',
    rentalTerms: const JpRentalTerms(
      id: 1,
      monthlyRent: 150000,
      managementFee: 10000,
      shikikin: 300000,
      reikin: 150000,
      koushinryo: 150000,
      brokerageFeeRate: 1.0,
      taxIncluded: false,
    ),
    propertyInfo: const JpPropertyInfo(
      id: 1,
      layout: '1LDK',
      floorAreaM2: 45.5,
      structure: JpStructure.rc,
      buildingYear: 2015,
      floorNumber: 8,
      totalFloors: 15,
      orientation: JpOrientation.s,
      availableFrom: '2026-12-01',
    ),
    transitAccesses: [
      JpTransitAccess(
        id: 1,
        listingId: 9001,
        station: const JpStation(
          id: 101,
          name: '渋谷',
          nameKana: 'しぶや',
          lineName: '山手線',
          lineId: 11,
          prefectureName: '東京都',
        ),
        walkMinutes: 8,
      ),
    ],
    imageUrls: const [
      'https://picsum.photos/seed/jp9001a/800/600',
      'https://picsum.photos/seed/jp9001b/800/600',
    ],
    prefecture: '東京都',
    city: '渋谷区',
    address: '道玄坂1丁目',
    isPublished: true,
    assignedAgentId: 501,
  ),
  JpListing(
    listingId: 9002,
    title: '新宿区西新宿 2DK アパート',
    rentalTerms: const JpRentalTerms(
      id: 2,
      monthlyRent: 98000,
      managementFee: 5000,
      shikikin: 196000,
      reikin: 98000,
      koushinryo: 98000,
      brokerageFeeRate: 0.5,
      taxIncluded: false,
    ),
    propertyInfo: const JpPropertyInfo(
      id: 2,
      layout: '2DK',
      floorAreaM2: 38.0,
      structure: JpStructure.wood,
      buildingYear: 2003,
      floorNumber: 2,
      totalFloors: 4,
      orientation: JpOrientation.e,
      availableFrom: '2026-11-15',
    ),
    transitAccesses: [
      JpTransitAccess(
        id: 2,
        listingId: 9002,
        station: const JpStation(
          id: 201,
          name: '西新宿',
          nameKana: 'にしじゅんく',
          lineName: '丸ノ内線',
          lineId: 12,
          prefectureName: '東京都',
        ),
        walkMinutes: 5,
      ),
    ],
    imageUrls: const [
      'https://picsum.photos/seed/jp9002a/800/600',
    ],
    prefecture: '東京都',
    city: '新宿区',
    address: '西新宿3丁目',
    isPublished: true,
    assignedAgentId: 501,
  ),
];

class MockJpListingRepository implements IJpListingRepository {
  const MockJpListingRepository();

  @override
  Future<List<JpListingSummary>> search(JpListingSearchParams params) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _fixtures
        .where((l) {
          if (params.layouts != null && params.layouts!.isNotEmpty) {
            if (!params.layouts!
                .contains(l.propertyInfo.layout)) return false;
          }
          if (params.maxWalkMinutes != null) {
            final nearest = l.nearestStation;
            if (nearest != null &&
                nearest.walkMinutes > params.maxWalkMinutes!) {
              return false;
            }
          }
          if (params.minRent != null &&
              l.rentalTerms.monthlyRent < params.minRent!) return false;
          if (params.maxRent != null &&
              l.rentalTerms.monthlyRent > params.maxRent!) return false;
          return true;
        })
        .map((l) => JpListingSummary(
              listingId: l.listingId,
              title: l.title,
              monthlyRent: l.rentalTerms.monthlyRent,
              layout: l.propertyInfo.layout,
              floorAreaM2: l.propertyInfo.floorAreaM2,
              nearestStationName:
                  l.nearestStation?.station.name,
              nearestStationWalkMin:
                  l.nearestStation?.walkMinutes,
              thumbnailUrl: l.imageUrls.isNotEmpty ? l.imageUrls.first : null,
              city: l.city,
              isPublished: l.isPublished,
            ))
        .toList();
  }

  @override
  Future<JpListing> getById(int listingId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final match = _fixtures.where((l) => l.listingId == listingId);
    if (match.isEmpty) {
      throw Exception('JP listing $listingId not found in mock data');
    }
    return match.first;
  }

  @override
  Future<JpListing> create(Map<String, dynamic> payload) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    // Return the first fixture as a stub for tests.
    return _fixtures.first;
  }

  @override
  Future<JpListing> update(int listingId, Map<String, dynamic> payload) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return await getById(listingId);
  }
}
