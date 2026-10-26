/// ĐỊNH DANH đăng nhập ở phía app — email hay số điện thoại?
///
/// Bản sao NHẸ của `app/services/dinh_danh.py`. Cố ý chỉ kiểm **hình dạng** để
/// báo lỗi sớm cho người dùng, và **không chuẩn hoá trước khi gửi**: app gửi
/// đúng chuỗi người ta gõ, backend mới là nơi quyết định dạng lưu.
///
/// Vì sao tách bạch như vậy: nếu cả hai bên cùng chuẩn hoá thì đến lúc luật đổi
/// (thêm đầu số mới chẳng hạn) mà chỉ một bên được cập nhật, app sẽ lặng lẽ gửi
/// một dạng còn DB lưu một dạng — và người dùng không đăng nhập được bằng chính
/// số họ vừa đăng ký. Một nguồn sự thật, đặt ở phía không thể cũ: máy chủ.
class DinhDanh {
  const DinhDanh._();

  /// Không số điện thoại nào chứa `@`, nên phép phân loại này không nhập nhằng.
  static bool laEmail(String s) => s.contains('@');

  static final RegExp _email = RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$');

  /// Di động VN sau đợt chuyển đổi 2018: 03x 05x 07x 08x 09x, đúng 10 chữ số.
  /// Chấp nhận cả `+84…`/`84…` và các dấu cách/chấm/gạch người dùng hay gõ.
  static final RegExp _sdt = RegExp(r'^(0|\+?84)[35789]\d{8}$');

  static bool hopLe(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return false;
    return laEmail(s) ? _email.hasMatch(s) : sdtHopLe(s);
  }

  static bool sdtHopLe(String raw) {
    final s = raw.trim().replaceAll(RegExp(r'[\s.\-()]'), '');
    if (s.isEmpty) return false;
    // `+84912345678` bỏ dấu + còn 11 số; `0912345678` còn 10 — cả hai đều khớp.
    return _sdt.hasMatch(s.startsWith('+') ? s : s);
  }
}
