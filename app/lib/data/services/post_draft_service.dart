import 'dart:convert';

// Dùng LẠI lớp lưu trữ của phiên đăng nhập (web: localStorage · native: secure
// storage) thay vì thêm phụ thuộc mới — hai hàm này chỉ là key/value thuần.
import '_session_storage_io.dart'
    if (dart.library.html) '_session_storage_web.dart'
    as backend;

/// Nháp form đăng tin — chống mất công khi thoát giữa chừng.
///
/// Form đăng tin có 8 trường; thoát nửa chừng (bấm nhầm back, hết pin, đóng
/// tab) trước đây là mất sạch, phải gõ lại từ đầu.
///
/// CỐ Ý không lưu ảnh: ảnh chưa tải lên chỉ là đường dẫn tạm của thiết bị,
/// khôi phục sẽ trỏ vào tệp không còn truy cập được. Người dùng chọn lại ảnh.
class PostDraftService {
  const PostDraftService();

  static const _key = 'post_house_draft';

  Future<void> save(Map<String, dynamic> data) async {
    try {
      await backend.writeToken(_key, jsonEncode(data));
    } catch (_) {
      // Nháp là tiện ích, không phải chức năng cốt lõi — hỏng thì bỏ qua,
      // tuyệt đối không chặn người dùng đăng tin.
    }
  }

  Future<Map<String, dynamic>?> load() async {
    try {
      final raw = await backend.readToken(_key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await backend.deleteToken(_key);
    } catch (_) {
      /* im lặng */
    }
  }
}
