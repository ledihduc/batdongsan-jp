import 'package:house_booking/data/models/homestay_calendar_model.dart';
import 'package:house_booking/data/models/pricing_rule_model.dart';
import 'package:house_booking/data/models/reservation_model.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Phase 07 — calendar / pricing / reservation endpoints under
/// `/api/host/homestay/*`. Mirrors `app/routers/host_homestay.py`.
class ApiHomestayRepository {
  final ApiClient _client = const ApiClient();

  // ── calendar ─────────────────────────────────────────────────────────
  Future<UnifiedCalendarResponse> fetchUnifiedCalendar(String month) async {
    final resp = await _client.get(
      '/api/host/homestay/unified-calendar',
      queryParameters: {'month': month},
    );
    return UnifiedCalendarResponse.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<CalendarResponse> fetchRoomCalendar({
    required int roomId,
    required String month,
  }) async {
    final resp = await _client.get(
      '/api/host/homestay/rooms/$roomId/calendar',
      queryParameters: {'month': month},
    );
    return CalendarResponse.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<int> blockAvailability({
    required int roomId,
    required String startDate,
    required String endDate,
    required String action, // 'block' | 'unblock'
    String? note,
  }) async {
    final resp = await _client.post(
      '/api/host/homestay/availability/block',
      body: {
        'room_id': roomId,
        'start_date': startDate,
        'end_date': endDate,
        'action': action,
        if (note != null) 'note': note,
      },
    );
    return resp['rows_affected'] as int? ?? 0;
  }

  // ── pricing rules ────────────────────────────────────────────────────
  Future<List<PricingRuleModel>> fetchPricingRules({
    int? roomId,
    int? houseId,
    String? ruleType,
  }) async {
    final list = await _client.getList(
      '/api/host/homestay/pricing-rules',
      queryParameters: {
        if (roomId != null) 'room_id': roomId,
        if (houseId != null) 'house_id': houseId,
        if (ruleType != null) 'rule_type': ruleType,
      },
    );
    return list
        .map(
          (e) => PricingRuleModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<PricingRuleModel> createPricingRule({
    int? roomId,
    int? houseId,
    required String ruleType,
    required String startDate,
    required String endDate,
    required double pricePerNight,
    int? priority,
    int? weekdayMask,
    String? holidayName,
  }) async {
    final resp = await _client.post(
      '/api/host/homestay/pricing-rules',
      body: {
        if (roomId != null) 'room_id': roomId,
        if (houseId != null) 'house_id': houseId,
        'rule_type': ruleType,
        'start_date': startDate,
        'end_date': endDate,
        'price_per_night': pricePerNight,
        if (priority != null) 'priority': priority,
        if (weekdayMask != null) 'weekday_mask': weekdayMask,
        if (holidayName != null) 'holiday_name': holidayName,
      },
    );
    return PricingRuleModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<PricingRuleModel> updatePricingRule({
    required int ruleId,
    String? startDate,
    String? endDate,
    double? pricePerNight,
    int? priority,
    int? weekdayMask,
    String? holidayName,
  }) async {
    final resp = await _client.patch(
      '/api/host/homestay/pricing-rules/$ruleId',
      body: {
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (pricePerNight != null) 'price_per_night': pricePerNight,
        if (priority != null) 'priority': priority,
        if (weekdayMask != null) 'weekday_mask': weekdayMask,
        if (holidayName != null) 'holiday_name': holidayName,
      },
    );
    return PricingRuleModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<void> deletePricingRule(int ruleId) async {
    await _client.delete('/api/host/homestay/pricing-rules/$ruleId');
  }

  // ── reservations ─────────────────────────────────────────────────────
  Future<List<ReservationModel>> fetchReservations({
    String? status,
    int? roomId,
  }) async {
    final list = await _client.getList(
      '/api/host/homestay/reservations',
      queryParameters: {
        if (status != null) 'status': status,
        if (roomId != null) 'room_id': roomId,
      },
    );
    return list
        .map(
          (e) => ReservationModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<ReservationModel> getReservation(int id) async {
    final resp = await _client.get('/api/host/homestay/reservations/$id');
    return ReservationModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<ReservationModel> createReservation({
    required int roomId,
    required String guestName,
    String? guestPhone,
    String? guestEmail,
    required String checkInDate,
    required String checkOutDate,
    String? note,
    String source = 'manual',
  }) async {
    final resp = await _client.post(
      '/api/host/homestay/reservations',
      body: {
        'room_id': roomId,
        'guest_name': guestName,
        if (guestPhone != null) 'guest_phone': guestPhone,
        if (guestEmail != null) 'guest_email': guestEmail,
        'check_in_date': checkInDate,
        'check_out_date': checkOutDate,
        if (note != null) 'note': note,
        'source': source,
      },
    );
    return ReservationModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<ReservationModel> approveReservation(int id) async {
    final resp = await _client.patch(
      '/api/host/homestay/reservations/$id/status',
      body: {'action': 'approve'},
    );
    return ReservationModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<ReservationModel> rejectReservation(int id, String reason) async {
    final resp = await _client.patch(
      '/api/host/homestay/reservations/$id/status',
      body: {'action': 'reject', 'rejection_reason': reason},
    );
    return ReservationModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<ReservationModel> checkInReservation(int id) async {
    final resp = await _client.patch(
      '/api/host/homestay/reservations/$id/check-in',
    );
    return ReservationModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<ReservationModel> checkOutReservation(int id) async {
    final resp = await _client.patch(
      '/api/host/homestay/reservations/$id/check-out',
    );
    return ReservationModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<ReservationModel> cancelReservation(int id, {String? reason}) async {
    final resp = await _client.post(
      '/api/host/homestay/reservations/$id/cancel',
      body: {if (reason != null) 'reason': reason},
    );
    return ReservationModel.fromJson(Map<String, dynamic>.from(resp));
  }
}
