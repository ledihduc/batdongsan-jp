/// Occupancy report (Phase 06 G2).
class OccupancyReportModel {
  final String month;
  final List<OccupancyRow> byRoom;
  final double buildingAvgPct;
  final int roomCount;

  const OccupancyReportModel({
    required this.month,
    required this.byRoom,
    required this.buildingAvgPct,
    required this.roomCount,
  });

  factory OccupancyReportModel.fromJson(Map<String, dynamic> json) {
    final rows = (json['by_room'] as List? ?? const [])
        .map((e) => OccupancyRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return OccupancyReportModel(
      month: json['month'] as String? ?? '',
      byRoom: rows,
      buildingAvgPct: (json['building_avg_pct'] as num? ?? 0).toDouble(),
      roomCount: (json['room_count'] as num? ?? 0).toInt(),
    );
  }
}

class OccupancyRow {
  final int roomId;
  final String roomCode;
  final int buildingId;
  final String buildingName;
  final String status; // vacant | occupied | maintenance
  final int occupiedDays;
  final int totalDays;
  final double occupiedPct;

  const OccupancyRow({
    required this.roomId,
    required this.roomCode,
    required this.buildingId,
    required this.buildingName,
    required this.status,
    required this.occupiedDays,
    required this.totalDays,
    required this.occupiedPct,
  });

  factory OccupancyRow.fromJson(Map<String, dynamic> json) => OccupancyRow(
    roomId: json['room_id'] as int,
    roomCode: json['room_code'] as String? ?? '',
    buildingId: json['building_id'] as int,
    buildingName: json['building_name'] as String? ?? '',
    status: json['status'] as String? ?? 'vacant',
    occupiedDays: (json['occupied_days'] as num? ?? 0).toInt(),
    totalDays: (json['total_days'] as num? ?? 0).toInt(),
    occupiedPct: (json['occupied_pct'] as num? ?? 0).toDouble(),
  );
}
