/// Model cho BDS rủi ro quy hoạch — dùng ở admin risky listings screen.
/// Chỉ chứa thông tin hiển thị danh sách; KHÔNG chứa PII (host phone/email).
class RiskyHouse {
  final int id;
  final String title;
  final double latitude;
  final double longitude;

  /// Mã vùng quy hoạch (VD: "ODT", "CX") — có thể null nếu backend chưa gán.
  final String? zoneCode;

  /// Tên vùng quy hoạch (VD: "Đất ở đô thị") — có thể null.
  final String? zoneName;

  const RiskyHouse({
    required this.id,
    required this.title,
    required this.latitude,
    required this.longitude,
    this.zoneCode,
    this.zoneName,
  });

  factory RiskyHouse.fromJson(Map<String, dynamic> j) => RiskyHouse(
    id: j['id'] as int,
    title: j['title'] as String,
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    zoneCode: j['zone_code'] as String?,
    zoneName: j['zone_name'] as String?,
  );
}
