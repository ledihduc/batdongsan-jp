import 'package:house_booking/data/services/api_client.dart';

/// Liên hệ CÔNG KHAI mà người bán tự bật trên trang cá nhân của mình.
///
/// API: GET/PATCH /api/sales/me/lien-he
///
/// Mặc định TẮT — cả repo giữ bất biến "SĐT masked", mở số là quyết định của
/// người bán chứ không phải mặc định của hệ thống.
class SaleLienHeApi {
  const SaleLienHeApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<LienHeCongKhai> xem() async =>
      LienHeCongKhai.tuMap(await _c.get('/api/sales/me/lien-he'));

  /// Trường nào truyền `null` thì backend KHÔNG đụng tới. Muốn gỡ Zalo thì
  /// truyền chuỗi rỗng, không phải null.
  Future<LienHeCongKhai> sua({
    bool? choGoi,
    String? zalo,
    String? facebook,
  }) async {
    return LienHeCongKhai.tuMap(
      await _c.patch(
        '/api/sales/me/lien-he',
        body: {'show_phone': ?choGoi, 'zalo': ?zalo, 'facebook': ?facebook},
      ),
    );
  }
}

class LienHeCongKhai {
  const LienHeCongKhai({
    required this.choGoi,
    required this.zalo,
    required this.facebook,
    required this.coSoDienThoai,
  });

  /// Khách xem trang có thấy nút "Gọi" không.
  final bool choGoi;
  final String? zalo;
  final String? facebook;

  /// Tài khoản có số để mà bật hay không — công tắc khoá lại nếu không có.
  final bool coSoDienThoai;

  factory LienHeCongKhai.tuMap(Map<String, dynamic> m) => LienHeCongKhai(
    choGoi: m['show_phone'] == true,
    zalo: (m['zalo'] as String?)?.trim(),
    facebook: (m['facebook'] as String?)?.trim(),
    coSoDienThoai: m['co_so_dien_thoai'] == true,
  );
}
