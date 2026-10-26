/// Model cho thửa đất quy hoạch — ánh xạ response của
/// `GET /api/planning/parcels` và `GET /api/planning/parcels/{id}`.
class ParcelDetail {
  final String parcelId;
  final String? zoneCode;
  final String? zoneName;

  /// Màu hex của vùng quy hoạch, ví dụ '#FF5733'.
  final String? zoneColor;
  final double? areaM2;
  final String? sheetNo;
  final String? parcelNo;
  final String? district;
  final DateTime fetchedAt;

  /// GeoJSON geometry object (type + coordinates).
  final Map<String, dynamic> geometry;

  const ParcelDetail({
    required this.parcelId,
    this.zoneCode,
    this.zoneName,
    this.zoneColor,
    this.areaM2,
    this.sheetNo,
    this.parcelNo,
    this.district,
    required this.fetchedAt,
    required this.geometry,
  });

  factory ParcelDetail.fromJson(Map<String, dynamic> j) => ParcelDetail(
    parcelId: j['parcel_id'] as String,
    zoneCode: j['zone_code'] as String?,
    zoneName: j['zone_name'] as String?,
    zoneColor: j['zone_color'] as String?,
    areaM2: (j['area_m2'] as num?)?.toDouble(),
    sheetNo: j['sheet_no'] as String?,
    parcelNo: j['parcel_no'] as String?,
    district: j['district'] as String?,
    fetchedAt: DateTime.parse(j['fetched_at'] as String),
    geometry: j['geometry'] as Map<String, dynamic>,
  );

  Map<String, dynamic> toJson() => {
    'parcel_id': parcelId,
    if (zoneCode != null) 'zone_code': zoneCode,
    if (zoneName != null) 'zone_name': zoneName,
    if (zoneColor != null) 'zone_color': zoneColor,
    if (areaM2 != null) 'area_m2': areaM2,
    if (sheetNo != null) 'sheet_no': sheetNo,
    if (parcelNo != null) 'parcel_no': parcelNo,
    if (district != null) 'district': district,
    'fetched_at': fetchedAt.toIso8601String(),
    'geometry': geometry,
  };
}
