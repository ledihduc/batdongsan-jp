import 'package:house_booking/data/models/reservation_model.dart';
import 'package:house_booking/data/services/api_client.dart';

const shortStayModes = {
  'theo_gio': 'Theo giờ',
  'qua_dem': 'Qua đêm',
  'theo_ngay': 'Theo ngày',
};

/// Pickers always show Vietnam wall time, including on devices in other zones.
String stayIso(DateTime wallTime) =>
    '${wallTime.toIso8601String().split('.').first}+07:00';
// UTC containers hold Vietnam wall-clock fields so arithmetic is unaffected by
// the device's daylight-saving transitions. stayIso supplies the real +07 offset.
DateTime stayNow() => DateTime.now().toUtc().add(const Duration(hours: 7));
String stayTime(String? value) {
  if (value == null) return '';
  final d = DateTime.parse(value).toUtc().add(const Duration(hours: 7));
  return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String stayMoney(dynamic value) => '${(value as num).toStringAsFixed(0)}đ';

class ShortStayApi {
  const ShortStayApi({this.client = const ApiClient()});
  final ApiClient client;

  Future<List<Map<String, dynamic>>> search({
    String query = '',
    String? mode,
    DateTime? start,
    DateTime? end,
  }) async => (await client.getList(
    '/api/short-stays/rooms',
    queryParameters: {
      'query': query,
      'booking_mode': mode,
      if (start != null) 'check_in_at': stayIso(start),
      if (end != null) 'check_out_at': stayIso(end),
    },
  )).map((e) => Map<String, dynamic>.from(e)).toList();
  Future<Map<String, dynamic>> detail(int id) =>
      client.get('/api/short-stays/rooms/$id');
  Future<Map<String, dynamic>> quote(
    int id,
    String mode,
    DateTime start,
    DateTime end,
  ) => client.post(
    '/api/short-stays/quote',
    body: {
      'room_id': id,
      'booking_mode': mode,
      'check_in_at': stayIso(start),
      'check_out_at': stayIso(end),
    },
  );

  /// Đặt phòng. [houseId] = tin đăng khách bấm vào (bỏ trống nếu đặt từ trang
  /// toà của sale). KHÔNG gửi sale: server tự xác định sale phụ trách phòng,
  /// app không được tự ghi công cho ai.
  Future<ReservationModel> book(
    Map<String, dynamic> quote,
    String name,
    String phone,
    String note, {
    int? houseId,
  }) async => ReservationModel.fromJson(
    await client.post(
      '/api/guest/reservations',
      body: {
        if (houseId != null) 'house_id': houseId,
        'room_id': quote['room_id'],
        'booking_mode': quote['booking_mode'],
        'check_in_at': quote['check_in_at'],
        'check_out_at': quote['check_out_at'],
        'quote_token': quote['quote_token'],
        'guest_name': name,
        'guest_phone': phone,
        'note': note,
        'source': 'marketplace',
      },
    ),
  );
  Future<List<ReservationModel>> bookings({
    bool operations = false,
    bool today = true,
  }) async =>
      (await client.getList(
            operations
                ? '/api/host/short-stays/reservations'
                : '/api/guest/reservations',
            queryParameters: operations ? {'today': today} : null,
          ))
          .map((e) => ReservationModel.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.bookingMode != null)
          .toList();

  /// Lấy lại một booking sau sự kiện realtime. Backend hiện dùng endpoint
  /// danh sách theo vai trò; lọc tại client giúp ba màn dùng cùng một nguồn
  /// dữ liệu mà không tạo API chi tiết giả.
  Future<ReservationModel?> reservation(
    int id, {
    bool operations = false,
  }) async {
    final rows = await bookings(operations: operations, today: false);
    for (final row in rows) {
      if (row.id == id) return row;
    }
    return null;
  }

  Future<ReservationModel> cancel(int id) async => ReservationModel.fromJson(
    await client.post('/api/guest/reservations/$id/cancel', body: {}),
  );
  Future<ReservationModel> action(
    int id,
    String action,
    String? reason,
  ) async => ReservationModel.fromJson(
    await client.post(
      '/api/host/short-stays/reservations/$id/actions',
      body: {'action': action, 'reason': reason},
    ),
  );
  Future<List<Map<String, dynamic>>> rooms() async => (await client.getList(
    '/api/host/short-stays/rooms',
  )).map((e) => Map<String, dynamic>.from(e)).toList();
  Future<void> rates(int id, Map<String, dynamic> rates) async {
    await client.put('/api/host/short-stays/rooms/$id/rates', body: rates);
  }

  Future<List<Map<String, dynamic>>> blocks(int id) async =>
      (await client.getList(
        '/api/host/short-stays/rooms/$id/blocks',
      )).map((e) => Map<String, dynamic>.from(e)).toList();
  Future<void> block(int id, DateTime start, DateTime end, String note) async {
    await client.post(
      '/api/host/short-stays/rooms/$id/blocks',
      body: {
        'check_in_at': stayIso(start),
        'check_out_at': stayIso(end),
        'note': note,
      },
    );
  }

  Future<void> unblock(int roomId, int blockId) async {
    await client.delete('/api/host/short-stays/rooms/$roomId/blocks/$blockId');
  }
}
