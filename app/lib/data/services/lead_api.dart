import 'package:house_booking/data/services/api_client.dart';

/// Client lead 'gọi lại' nhẹ — thu Tên+SĐT không cần login (POST /api/leads),
/// và admin xem danh sách (GET /api/admin/leads). TÁCH khỏi RFQ báo giá thi công.
class LeadApi {
  /// [client] chỉ để test bơm MockClient — code sản phẩm dùng mặc định.
  const LeadApi({ApiClient client = const ApiClient()}) : _c = client;
  final ApiClient _c;

  Future<void> submit({
    required String name,
    required String phone,
    required String source,
    String? note,
    String? world,
    String? provinceCode,
  }) async {
    await _c.post(
      '/api/leads',
      body: {
        'name': name,
        'phone': phone,
        'source': source,
        if (note != null && note.trim().isNotEmpty) 'context': note.trim(),
        if (world != null && world.isNotEmpty) 'world': world,
        if (provinceCode != null && provinceCode.isNotEmpty)
          'province_code': provinceCode,
      },
    );
  }

  Future<List<Map<String, dynamic>>> adminList({String status = ''}) async {
    final r = await _c.get(
      '/api/admin/leads',
      queryParameters: {'status': status},
    );
    return List<Map<String, dynamic>>.from(r['leads'] as List? ?? const []);
  }
}
