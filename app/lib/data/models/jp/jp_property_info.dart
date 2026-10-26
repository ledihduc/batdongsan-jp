/// Physical/structural property data for JP listings.
///
/// Maps 1:1 to backend `JpPropertyInfo` table.
library;

/// Building structure type (構造).
enum JpStructure {
  rc, // 鉄筋コンクリート
  wood, // 木造
  steel, // 鉄骨
  src, // 鉄骨鉄筋コンクリート
  unknown,
}

JpStructure jpStructureFromString(String? s) {
  switch (s) {
    case 'RC':
      return JpStructure.rc;
    case 'WOOD':
      return JpStructure.wood;
    case 'STEEL':
      return JpStructure.steel;
    case 'SRC':
      return JpStructure.src;
    default:
      return JpStructure.unknown;
  }
}

String jpStructureToString(JpStructure s) {
  switch (s) {
    case JpStructure.rc:
      return 'RC';
    case JpStructure.wood:
      return 'WOOD';
    case JpStructure.steel:
      return 'STEEL';
    case JpStructure.src:
      return 'SRC';
    case JpStructure.unknown:
      return '';
  }
}

/// Compass orientation (向き).
enum JpOrientation {
  n,
  ne,
  e,
  se,
  s,
  sw,
  w,
  nw,
  unknown,
}

JpOrientation jpOrientationFromString(String? s) {
  switch (s?.toUpperCase()) {
    case 'N':
      return JpOrientation.n;
    case 'NE':
      return JpOrientation.ne;
    case 'E':
      return JpOrientation.e;
    case 'SE':
      return JpOrientation.se;
    case 'S':
      return JpOrientation.s;
    case 'SW':
      return JpOrientation.sw;
    case 'W':
      return JpOrientation.w;
    case 'NW':
      return JpOrientation.nw;
    default:
      return JpOrientation.unknown;
  }
}

String jpOrientationToString(JpOrientation o) {
  switch (o) {
    case JpOrientation.n:
      return 'N';
    case JpOrientation.ne:
      return 'NE';
    case JpOrientation.e:
      return 'E';
    case JpOrientation.se:
      return 'SE';
    case JpOrientation.s:
      return 'S';
    case JpOrientation.sw:
      return 'SW';
    case JpOrientation.w:
      return 'W';
    case JpOrientation.nw:
      return 'NW';
    case JpOrientation.unknown:
      return '';
  }
}

/// Immutable physical/structural info for a JP rental property.
class JpPropertyInfo {
  const JpPropertyInfo({
    required this.id,
    required this.layout,
    required this.floorAreaM2,
    required this.structure,
    required this.buildingYear,
    this.floorNumber,
    this.totalFloors,
    this.orientation = JpOrientation.unknown,
    this.availableFrom,
  });

  final int id;

  /// 間取り — layout code, e.g. '1K', '2LDK', '3SLDK'.
  final String layout;

  /// 専有面積 — exclusive floor area in m².
  final double floorAreaM2;

  /// 構造 — building structure type.
  final JpStructure structure;

  /// 築年数 — calendar year the building was completed (e.g. 2005).
  final int buildingYear;

  /// 階数 — unit floor number; null if not applicable (e.g. whole building).
  final int? floorNumber;

  /// Total floors in the building.
  final int? totalFloors;

  /// 向き — direction the main balcony/window faces.
  final JpOrientation orientation;

  /// 入居可能日 — ISO-8601 date string (YYYY-MM-DD) when unit becomes available.
  final String? availableFrom;

  /// Years since construction (derived at query time, read-only).
  int? get buildingAgeYears {
    final now = DateTime.now();
    final age = now.year - buildingYear;
    return age >= 0 ? age : null;
  }

  factory JpPropertyInfo.fromJson(Map<String, dynamic> json) {
    return JpPropertyInfo(
      id: json['id'] as int,
      layout: json['layout'] as String? ?? '',
      floorAreaM2: (json['floor_area_m2'] as num?)?.toDouble() ?? 0,
      structure: jpStructureFromString(json['structure'] as String?),
      buildingYear: json['building_year'] as int? ?? 0,
      floorNumber: json['floor_number'] as int?,
      totalFloors: json['total_floors'] as int?,
      orientation:
          jpOrientationFromString(json['orientation'] as String?),
      availableFrom: json['available_from'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'layout': layout,
        'floor_area_m2': floorAreaM2,
        'structure': jpStructureToString(structure),
        'building_year': buildingYear,
        if (floorNumber != null) 'floor_number': floorNumber,
        if (totalFloors != null) 'total_floors': totalFloors,
        'orientation': jpOrientationToString(orientation),
        if (availableFrom != null) 'available_from': availableFrom,
      };

  JpPropertyInfo copyWith({
    String? layout,
    double? floorAreaM2,
    JpStructure? structure,
    int? buildingYear,
    int? floorNumber,
    int? totalFloors,
    JpOrientation? orientation,
    String? availableFrom,
  }) {
    return JpPropertyInfo(
      id: id,
      layout: layout ?? this.layout,
      floorAreaM2: floorAreaM2 ?? this.floorAreaM2,
      structure: structure ?? this.structure,
      buildingYear: buildingYear ?? this.buildingYear,
      floorNumber: floorNumber ?? this.floorNumber,
      totalFloors: totalFloors ?? this.totalFloors,
      orientation: orientation ?? this.orientation,
      availableFrom: availableFrom ?? this.availableFrom,
    );
  }
}
