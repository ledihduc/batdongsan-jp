/// Model cho layer quy hoạch — ánh xạ response của
/// `GET /api/planning/layers`.
class PlanningLayer {
  final String layerId;
  final String name;

  /// URL template MVT, ví dụ `http://host/planning.parcels/{z}/{x}/{y}.pbf`.
  final String tileUrlTemplate;
  final double defaultOpacity;
  final bool isDefault;
  final String? description;

  const PlanningLayer({
    required this.layerId,
    required this.name,
    required this.tileUrlTemplate,
    this.defaultOpacity = 0.7,
    this.isDefault = false,
    this.description,
  });

  factory PlanningLayer.fromJson(Map<String, dynamic> j) => PlanningLayer(
    layerId: j['layer_id'] as String,
    name: j['name'] as String,
    tileUrlTemplate: j['tile_url_template'] as String,
    defaultOpacity: (j['default_opacity'] as num?)?.toDouble() ?? 0.7,
    isDefault: (j['is_default'] as bool?) ?? false,
    description: j['description'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'layer_id': layerId,
    'name': name,
    'tile_url_template': tileUrlTemplate,
    'default_opacity': defaultOpacity,
    'is_default': isDefault,
    if (description != null) 'description': description,
  };
}
