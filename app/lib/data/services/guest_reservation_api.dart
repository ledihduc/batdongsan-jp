import 'package:house_booking/data/models/reservation_model.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Guest-facing reservation calls used by the public sale/project flow.
class GuestReservationApi {
  const GuestReservationApi({ApiClient client = const ApiClient()})
    : _client = client;

  final ApiClient _client;

  Future<ReservationModel> create({
    required int roomId,
    required String guestName,
    required String guestPhone,
    String? guestEmail,
    required String checkInDate,
    required String checkOutDate,
    String? note,
  }) async {
    final response = await _client.post(
      '/api/guest/reservations',
      body: {
        'room_id': roomId,
        'guest_name': guestName,
        'guest_phone': guestPhone,
        if (guestEmail != null && guestEmail.isNotEmpty)
          'guest_email': guestEmail,
        'check_in_date': checkInDate,
        'check_out_date': checkOutDate,
        'source': 'marketplace',
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return ReservationModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// Đơn đặt phòng CỦA TÔI. Server tự lọc theo token — không nhận `userId` từ
  /// app, nếu không ai cũng đọc được đơn của người khác bằng cách đổi tham số.
  Future<List<ReservationModel>> cuaToi() async {
    final list = await _client.getList('/api/guest/reservations');
    return list
        .whereType<Map>()
        .map((e) => ReservationModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Khách tự huỷ đơn của mình. Tiền hoàn do server tính theo chính sách đã
  /// chụp lại lúc đặt — app KHÔNG tự tính rồi hiển thị, vì hai bên tính lệch
  /// nhau là chỗ cãi nhau về tiền.
  Future<ReservationModel> huy(int id, {String? lyDo}) async {
    final r = await _client.post(
      '/api/guest/reservations/$id/cancel',
      body: {if (lyDo != null && lyDo.isNotEmpty) 'reason': lyDo},
    );
    return ReservationModel.fromJson(Map<String, dynamic>.from(r));
  }
}
