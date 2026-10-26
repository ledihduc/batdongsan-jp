/// Tỉnh / thành VN — mirror schema từ `vietnam-provinces.json` ở backend.
/// `tileLayerSlug` non-null khi có raster overlay (17/63 tỉnh).
class Province {
  const Province({
    required this.id,
    required this.name,
    required this.slug,
    required this.lat,
    required this.lng,
    required this.latNe,
    required this.lngNe,
    required this.latSw,
    required this.lngSw,
    required this.hasTiles,
    required this.tileLayerSlug,
  });

  final int id;
  final String name;
  final String slug;
  final double lat;
  final double lng;
  final double latNe;
  final double lngNe;
  final double latSw;
  final double lngSw;
  final bool hasTiles;
  final String? tileLayerSlug;

  factory Province.fromJson(Map<String, dynamic> j) => Province(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String,
    slug: j['slug'] as String,
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    latNe: (j['lat_ne'] as num).toDouble(),
    lngNe: (j['lng_ne'] as num).toDouble(),
    latSw: (j['lat_sw'] as num).toDouble(),
    lngSw: (j['lng_sw'] as num).toDouble(),
    hasTiles: j['has_tiles'] as bool? ?? false,
    tileLayerSlug: j['tile_layer_slug'] as String?,
  );
}
