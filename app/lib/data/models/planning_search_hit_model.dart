/// Model cho kết quả search địa điểm — ánh xạ response của
/// `GET /api/planning/search`.
class SearchHit {
  final String displayName;
  final double lat;
  final double lon;
  final double importance;
  final String? type;
  final String? osmId;

  const SearchHit({
    required this.displayName,
    required this.lat,
    required this.lon,
    required this.importance,
    this.type,
    this.osmId,
  });

  factory SearchHit.fromJson(Map<String, dynamic> j) => SearchHit(
    displayName: j['display_name'] as String,
    lat: double.parse(j['lat'].toString()),
    lon: double.parse(j['lon'].toString()),
    importance: (j['importance'] as num?)?.toDouble() ?? 0.0,
    type: j['type'] as String?,
    osmId: j['osm_id']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'display_name': displayName,
    'lat': lat,
    'lon': lon,
    'importance': importance,
    if (type != null) 'type': type,
    if (osmId != null) 'osm_id': osmId,
  };
}
