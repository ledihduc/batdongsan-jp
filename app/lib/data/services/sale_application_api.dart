import 'package:house_booking/data/services/api_client.dart';

/// Bắt đầu handoff an toàn từ app sang trang web đăng ký Sale.
///
/// Backend trả URL với ticket ở fragment (`#ticket=...`), không phải JWT. App
/// chỉ mở URL nguyên vẹn bằng browser ngoài; web BFF sẽ đổi ticket một lần.
class SaleApplicationApi {
  const SaleApplicationApi({ApiClient? client})
    : _client = client ?? const ApiClient();

  final ApiClient _client;

  Future<Uri> moTrangDangKy() async {
    final result = await _client.post('/api/v2/sale-application-web-sessions');
    final raw = result['handoff_url'] as String?;
    final uri = raw == null ? null : Uri.tryParse(raw);
    if (uri == null || uri.fragment.isEmpty) {
      throw ApiException(502, 'Không tạo được liên kết đăng ký Sale an toàn');
    }
    return uri;
  }
}
