/// Heatmap models — mirrors GET /api/host/analytics/heatmap response.
///
/// JSON contract frozen in _analytics_shapes.md §3.

/// Status of a single day-cell in the occupancy heatmap.
///
/// Values: vacant | booked | paid | overdue
enum HeatmapCellStatus { vacant, booked, paid, overdue }

/// A single day-cell in a room's occupancy row.
class HeatmapCell {
  /// 1-indexed day of the month.
  final int day;
  final HeatmapCellStatus status;

  const HeatmapCell({required this.day, required this.status});

  factory HeatmapCell.fromJson(Map<String, dynamic> json) {
    return HeatmapCell(
      day: json['day'] as int,
      status: _parseStatus(json['status'] as String? ?? 'vacant'),
    );
  }

  static HeatmapCellStatus _parseStatus(String s) {
    switch (s) {
      case 'booked':
        return HeatmapCellStatus.booked;
      case 'paid':
        return HeatmapCellStatus.paid;
      case 'overdue':
        return HeatmapCellStatus.overdue;
      default:
        return HeatmapCellStatus.vacant;
    }
  }
}

/// One room's row in the heatmap: [days] cells sorted by day 1..N.
class HeatmapRoomRow {
  final int roomId;
  final String roomName;
  final String buildingName;
  final List<HeatmapCell> cells;

  const HeatmapRoomRow({
    required this.roomId,
    required this.roomName,
    required this.buildingName,
    required this.cells,
  });

  factory HeatmapRoomRow.fromJson(Map<String, dynamic> json) {
    final cellList = (json['cells'] as List? ?? const [])
        .map((e) => HeatmapCell.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return HeatmapRoomRow(
      roomId: json['room_id'] as int,
      roomName: json['room_name'] as String? ?? '',
      buildingName: json['building_name'] as String? ?? '',
      cells: cellList,
    );
  }
}

/// Full heatmap response for a given month.
///
/// [days] = total days in [month] (28/29/30/31).
/// [rooms] = sorted by building_name then room_name.
class OccupancyHeatmapModel {
  /// HCM-scoped month key, e.g. "2026-07". Use directly for display.
  final String month;
  final int days;
  final List<HeatmapRoomRow> rooms;

  const OccupancyHeatmapModel({
    required this.month,
    required this.days,
    required this.rooms,
  });

  factory OccupancyHeatmapModel.fromJson(Map<String, dynamic> json) {
    final roomList = (json['rooms'] as List? ?? const [])
        .map(
          (e) => HeatmapRoomRow.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    return OccupancyHeatmapModel(
      month: json['month'] as String? ?? '',
      days: json['days'] as int? ?? 0,
      rooms: roomList,
    );
  }
}
