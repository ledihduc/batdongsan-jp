/// Model cho item quận/huyện — ánh xạ response của
/// `GET /api/planning/districts`.
class DistrictItem {
  final String district;
  final int parcelCount;

  const DistrictItem({required this.district, required this.parcelCount});

  factory DistrictItem.fromJson(Map<String, dynamic> j) => DistrictItem(
    district: j['district'] as String,
    parcelCount: (j['parcel_count'] as num).toInt(),
  );

  Map<String, dynamic> toJson() => {
    'district': district,
    'parcel_count': parcelCount,
  };
}
