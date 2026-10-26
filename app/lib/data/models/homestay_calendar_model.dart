/// Phase 07 — Homestay calendar models.
///
/// Mirror backend `app/schemas/calendar.py` (CalendarResponse,
/// CalendarDay, UnifiedCalendarRow, UnifiedCalendarResponse).
library;

class CalendarDay {
  final String date; // ISO YYYY-MM-DD
  final String status; // available | reserved | blocked
  final double pricePerNight;
  final int? reservationId;
  final String? note;

  const CalendarDay({
    required this.date,
    required this.status,
    required this.pricePerNight,
    required this.reservationId,
    required this.note,
  });

  bool get isAvailable => status == 'available';
  bool get isReserved => status == 'reserved';
  bool get isBlocked => status == 'blocked';

  factory CalendarDay.fromJson(Map<String, dynamic> json) => CalendarDay(
    date: json['date'] as String,
    status: json['status'] as String,
    pricePerNight: (json['price_per_night'] as num).toDouble(),
    reservationId: json['reservation_id'] as int?,
    note: json['note'] as String?,
  );
}

class CalendarResponse {
  final int roomId;
  final String roomCode;
  final String month; // ISO YYYY-MM
  final double basePrice;
  final List<CalendarDay> days;

  const CalendarResponse({
    required this.roomId,
    required this.roomCode,
    required this.month,
    required this.basePrice,
    required this.days,
  });

  factory CalendarResponse.fromJson(Map<String, dynamic> json) =>
      CalendarResponse(
        roomId: json['room_id'] as int,
        roomCode: json['room_code'] as String,
        month: json['month'] as String,
        basePrice: (json['base_price'] as num?)?.toDouble() ?? 0,
        days: (json['days'] as List<dynamic>)
            .map(
              (e) => CalendarDay.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
      );
}

class UnifiedCalendarRow {
  final int roomId;
  final String roomCode;
  final String buildingName;
  final List<CalendarDay> days;

  const UnifiedCalendarRow({
    required this.roomId,
    required this.roomCode,
    required this.buildingName,
    required this.days,
  });

  factory UnifiedCalendarRow.fromJson(Map<String, dynamic> json) =>
      UnifiedCalendarRow(
        roomId: json['room_id'] as int,
        roomCode: json['room_code'] as String,
        buildingName: json['building_name'] as String? ?? '',
        days: (json['days'] as List<dynamic>)
            .map(
              (e) => CalendarDay.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
      );
}

class UnifiedCalendarResponse {
  final String month;
  final List<UnifiedCalendarRow> rows;

  const UnifiedCalendarResponse({required this.month, required this.rows});

  factory UnifiedCalendarResponse.fromJson(Map<String, dynamic> json) =>
      UnifiedCalendarResponse(
        month: json['month'] as String,
        rows: (json['rows'] as List<dynamic>)
            .map(
              (e) => UnifiedCalendarRow.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
      );
}
