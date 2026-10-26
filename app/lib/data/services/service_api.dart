import 'package:house_booking/data/services/api_client.dart';

/// Cụm DỊCH VỤ (`/api/services`) — danh mục nghề + yêu cầu của khách.
///
/// Thay cho `ConstructionApi` cũ: mảng thi công (sàn nhà thầu, báo giá, thư
/// viện thiết kế) đã bị gỡ khỏi sản phẩm, dịch vụ nay đứng một mình.
class ServiceApi {
  /// [client] chỉ để test bơm MockClient — code sản phẩm dùng mặc định.
  const ServiceApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  /// Danh mục nghề (công khai). Backend chỉ trả nghề đang bật.
  Future<List<Map<String, dynamic>>> danhMuc() async {
    final rows = await _c.getList('/api/services');
    return rows.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Khách gửi yêu cầu — KHÔNG cần đăng nhập.
  Future<void> guiYeuCau(Map<String, dynamic> body) async {
    await _c.post('/api/services/requests', body: body);
  }

  /// Yêu cầu của CHÍNH người đang đăng nhập.
  ///
  /// Lỗi mạng / endpoint chưa có trên máy chủ → trả danh sách RỖNG thay vì
  /// ném: đây là một mục trong trang cá nhân, hỏng nó không được làm vỡ cả
  /// trang.
  Future<List<Map<String, dynamic>>> yeuCauCuaToi() async {
    try {
      final r = await _c.get('/api/services/requests/mine');
      return List<Map<String, dynamic>>.from(
        r['requests'] as List? ?? const [],
      );
    } catch (_) {
      return const [];
    }
  }

  // ── ADMIN ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> adminDanhSach({
    String? status,
    String? q,
    int limit = 50,
  }) async {
    final r = await _c.get(
      '/api/services/requests',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (q != null && q.isNotEmpty) 'q': q,
        'limit': limit,
      },
    );
    return List<Map<String, dynamic>>.from(r['requests'] as List? ?? const []);
  }

  Future<void> adminCapNhat(
    int id, {
    String? status,
    DateTime? scheduledAt,
    String? adminNote,
  }) async {
    await _c.patch(
      '/api/services/requests/$id',
      body: {
        if (status != null) 'status': status,
        if (scheduledAt != null) 'scheduled_at': scheduledAt.toIso8601String(),
        if (adminNote != null) 'admin_note': adminNote,
      },
    );
  }
}
