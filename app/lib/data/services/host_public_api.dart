import 'package:house_booking/data/services/api_client.dart';

/// Hồ sơ CÔNG KHAI của môi giới / chủ nhà.
///
/// Khác `admin_api_service.getUsers()` (admin-only, PII đầy đủ): backend ở đây
/// chỉ trả tên/ảnh/điểm/số tin — không email, không SĐT.
class HostPublicApi {
  /// [client] chỉ để test bơm MockClient — code sản phẩm dùng mặc định.
  const HostPublicApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  /// Môi giới tiêu biểu. Backend xếp hạng CỨNG (tin cậy → điểm → đánh giá →
  /// số tin) và chỉ trả người ĐÃ có tin đăng, nên client không sắp lại.
  Future<List<Map<String, dynamic>>> featured({int limit = 12}) async {
    final r = await _c.get(
      '/api/hosts/featured',
      queryParameters: {'limit': limit},
    );
    return List<Map<String, dynamic>>.from(r['hosts'] as List? ?? const []);
  }

  /// Danh bạ Sale đã được Admin duyệt. Khác [featured], Sale chưa có tin đăng
  /// vẫn xuất hiện. [query] tìm gần đúng theo tên; nếu là email thì backend
  /// chỉ khớp chính xác và không bao giờ trả email trong response.
  Future<PublicSalePage> sales({
    String query = '',
    int limit = 50,
    int offset = 0,
  }) async {
    final r = await _c.get(
      '/api/hosts/sales',
      queryParameters: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        'limit': limit,
        'offset': offset,
      },
    );
    return PublicSalePage(
      items: List<Map<String, dynamic>>.from(r['sales'] as List? ?? const []),
      total: (r['total'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Map<String, dynamic>> profile(int userId) async {
    return await _c.get('/api/hosts/$userId');
  }

  /// Nhận xét khách hàng — GỘP review của mọi tin người này đăng (review vốn
  /// gắn theo từng tin, trang hồ sơ cần nhìn cả người).
  Future<List<Map<String, dynamic>>> reviews(
    int userId, {
    int limit = 10,
  }) async {
    final r = await _c.get(
      '/api/hosts/$userId/reviews',
      queryParameters: {'limit': limit},
    );
    return List<Map<String, dynamic>>.from(r['reviews'] as List? ?? const []);
  }
}

class PublicSalePage {
  const PublicSalePage({required this.items, required this.total});

  final List<Map<String, dynamic>> items;
  final int total;
}
