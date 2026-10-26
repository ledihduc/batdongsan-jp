/// Phase 04 — MeterReading mirrors backend schema.
class MeterReadingModel {
  final int id;
  final int hostId;
  final int roomId;
  final String readingDate; // YYYY-MM-DD
  final double electricityKwh;
  final double waterM3;
  final String? note;
  final DateTime createdAt;

  const MeterReadingModel({
    required this.id,
    required this.hostId,
    required this.roomId,
    required this.readingDate,
    required this.electricityKwh,
    required this.waterM3,
    this.note,
    required this.createdAt,
  });

  factory MeterReadingModel.fromJson(Map<String, dynamic> json) {
    return MeterReadingModel(
      id: json['id'] as int,
      hostId: json['host_id'] as int,
      roomId: json['room_id'] as int,
      readingDate: json['reading_date'] as String,
      electricityKwh: (json['electricity_kwh'] as num?)?.toDouble() ?? 0,
      waterM3: (json['water_m3'] as num?)?.toDouble() ?? 0,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
