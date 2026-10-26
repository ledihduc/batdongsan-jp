/// Shared fake builders for planning tests.
/// Use these instead of constructing models inline — keeps tests DRY.
library;

import 'package:house_booking/data/models/planning_district_model.dart';
import 'package:house_booking/data/models/planning_parcel_model.dart';
import 'package:house_booking/data/models/planning_search_hit_model.dart';
import 'package:house_booking/data/models/risky_house_model.dart';

/// Returns a valid [ParcelDetail] with sensible defaults.
/// Override any field via named params.
ParcelDetail fakeParcel({
  String parcelId = 'p-001',
  String? zoneCode = 'ODT',
  String? zoneName = 'Đất ở đô thị',
  String? zoneColor = '#4CAF50',
  double? areaM2 = 120.5,
  String? district = 'Quận 1',
  String? sheetNo = 'BM-01',
  String? parcelNo = '123',
  DateTime? fetchedAt,
}) {
  return ParcelDetail(
    parcelId: parcelId,
    zoneCode: zoneCode,
    zoneName: zoneName,
    zoneColor: zoneColor,
    areaM2: areaM2,
    sheetNo: sheetNo,
    parcelNo: parcelNo,
    district: district,
    fetchedAt: fetchedAt ?? DateTime.now().subtract(const Duration(days: 5)),
    geometry: const {
      'type': 'Polygon',
      'coordinates': [
        [
          [106.69, 10.77],
          [106.70, 10.77],
          [106.70, 10.78],
          [106.69, 10.77],
        ]
      ],
    },
  );
}

/// Returns a [ParcelDetail] whose [zoneCode] is risky (triggers amber banner).
ParcelDetail fakeRiskyParcel({
  String zoneCode = 'DGT',
  String zoneName = 'Đất giao thông (giải tỏa)',
}) =>
    fakeParcel(zoneCode: zoneCode, zoneName: zoneName, zoneColor: '#FF9800');

/// Returns a [ParcelDetail] with [fetchedAt] older than 30 days (stale).
ParcelDetail fakeStaleParcel() =>
    fakeParcel(fetchedAt: DateTime.now().subtract(const Duration(days: 40)));

/// Returns a valid [RiskyHouse].
RiskyHouse fakeRiskyHouse({
  int id = 1,
  String title = 'Phòng trọ Quận 1',
  double latitude = 10.77,
  double longitude = 106.69,
  String? zoneCode = 'DGT',
  String? zoneName = 'Đất giao thông',
}) {
  return RiskyHouse(
    id: id,
    title: title,
    latitude: latitude,
    longitude: longitude,
    zoneCode: zoneCode,
    zoneName: zoneName,
  );
}

/// Returns a valid [SearchHit] inside HCMC bbox.
SearchHit fakeSearchHit({
  String displayName = 'Bến Thành Market, Quận 1, HCM',
  double lat = 10.772,
  double lon = 106.698,
}) {
  return SearchHit(
    displayName: displayName,
    lat: lat,
    lon: lon,
    importance: 0.7,
    type: 'marketplace',
    osmId: '12345',
  );
}

/// Returns a [DistrictItem].
DistrictItem fakeDistrict({
  String district = 'Quận 1',
  int parcelCount = 500,
}) {
  return DistrictItem(district: district, parcelCount: parcelCount);
}
