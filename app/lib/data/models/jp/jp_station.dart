/// JP rail station reference model.
///
/// Populated from 駅データ.jp CSV import (quarterly). Read-only at runtime.
library;

/// A single rail station entry.
class JpStation {
  const JpStation({
    required this.id,
    required this.name,
    required this.nameKana,
    required this.lineName,
    required this.lineId,
    this.prefectureName,
    this.latitude,
    this.longitude,
  });

  final int id;

  /// Station name in kanji, e.g. '渋谷'.
  final String name;

  /// Station name in hiragana/kana, e.g. 'しぶや'.
  final String nameKana;

  /// Line name, e.g. '山手線'.
  final String lineName;

  final int lineId;

  /// Prefecture name, e.g. '東京都'.
  final String? prefectureName;

  final double? latitude;
  final double? longitude;

  factory JpStation.fromJson(Map<String, dynamic> json) {
    return JpStation(
      id: json['id'] as int,
      name: json['name'] as String,
      nameKana: json['name_kana'] as String? ?? '',
      lineName: json['line_name'] as String? ?? '',
      lineId: json['line_id'] as int? ?? 0,
      prefectureName: json['prefecture_name'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'name_kana': nameKana,
        'line_name': lineName,
        'line_id': lineId,
        if (prefectureName != null) 'prefecture_name': prefectureName,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
}

/// Transit access record linking a listing to a station.
class JpTransitAccess {
  const JpTransitAccess({
    required this.id,
    required this.listingId,
    required this.station,
    required this.walkMinutes,
  });

  final int id;
  final int listingId;

  /// The station this transit record refers to.
  final JpStation station;

  /// 駅徒歩分 — walk time in minutes from station to property.
  final int walkMinutes;

  factory JpTransitAccess.fromJson(Map<String, dynamic> json) {
    return JpTransitAccess(
      id: json['id'] as int,
      listingId: json['listing_id'] as int,
      station: JpStation.fromJson(json['station'] as Map<String, dynamic>),
      walkMinutes: json['walk_minutes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'listing_id': listingId,
        'station': station.toJson(),
        'walk_minutes': walkMinutes,
      };
}
