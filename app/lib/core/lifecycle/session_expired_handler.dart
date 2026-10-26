typedef SessionExpiredCallback = void Function();

/// Xử lý TẬP TRUNG khi phiên đăng nhập hết hiệu lực (HTTP 401).
///
/// Vì sao cần: trước đây [ApiClient] chỉ xử lý riêng một mã 401 duy nhất
/// (`DELEGATION_REVOKED`); mọi 401 khác — điển hình là JWT hết hạn giữa chừng
/// (TTL 7 ngày) — chỉ ném `ApiException` cho từng nơi gọi tự lo. Hậu quả:
/// `AuthProvider` vẫn tưởng đang đăng nhập, giao diện vẫn hiện tên người dùng,
/// còn từng màn thì lần lượt báo "Yêu cầu thất bại" rời rạc, không ai nói cho
/// người dùng biết là phải đăng nhập lại.
///
/// Chỉ đăng ký MỘT nơi (ở gốc cây widget) để có sẵn `context` mà điều hướng.
class SessionExpiredHandler {
  SessionExpiredHandler._();

  static SessionExpiredCallback? _handler;

  /// Chống gọi dồn: một màn hỏng thường bắn nhiều request song song, tất cả
  /// cùng trả 401 → nếu không chặn sẽ đăng xuất và điều hướng nhiều lần.
  static bool _dangXuLy = false;

  /// Truyền null để gỡ (lúc dispose).
  static void register(SessionExpiredCallback? handler) {
    _handler = handler;
    _dangXuLy = false;
  }

  static void trigger() {
    final h = _handler;
    if (h == null || _dangXuLy) return;
    _dangXuLy = true;
    try {
      h();
    } catch (_) {
      // Không nghiêm trọng — nơi gọi vẫn nhận ApiException và tự xử lý được.
    }
  }

  /// Gọi sau khi đã xử lý xong (đăng xuất + điều hướng) để lần hết phiên sau
  /// vẫn được xử lý.
  static void reset() => _dangXuLy = false;
}
