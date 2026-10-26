/// Lightweight local preferences. Reuses the same conditional storage backend
/// as [SessionService] so we don't add new package deps.
import '_session_storage_io.dart'
    if (dart.library.html) '_session_storage_web.dart'
    as backend;

class UserPrefsService {
  UserPrefsService._();
  static final UserPrefsService instance = UserPrefsService._();

  static const _modeKey = 'last_active_mode';
  static const _fabPosKey = 'post_fab_pos'; // "dx,dy" (góc trái-trên, px)
  static const _langKey = 'app_lang'; // 'vi' | 'en' | 'zh'

  /// Mã ngôn ngữ đã chọn ('vi'|'en'|'zh') hoặc null (dùng mặc định 'vi').
  Future<String?> getLang() async {
    try {
      return await backend.readToken(_langKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> setLang(String code) async {
    try {
      await backend.writeToken(_langKey, code);
    } catch (_) {}
  }

  /// Clear the workspace on logout so the next account cannot inherit it.
  Future<void> clearLastMode() async {
    try {
      await backend.deleteToken(_modeKey);
    } catch (_) {}
  }

  /// Chế độ giao diện cuối cùng của tài khoản trên thiết bị này.
  /// Đây chỉ là ngữ cảnh UI; quyền thật vẫn phải được backend kiểm tra.
  Future<String?> getLastMode() async {
    try {
      return await backend.readToken(_modeKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> setLastMode(String mode) async {
    try {
      await backend.writeToken(_modeKey, mode);
    } catch (_) {}
  }

  /// Vị trí nút "Đăng tin" người dùng đã kéo (góc trái-trên, px). null → dùng
  /// vị trí mặc định (giữa-dưới). Trả về Offset dưới dạng [dx, dy].
  Future<List<double>?> getFabOffset() async {
    try {
      final raw = await backend.readToken(_fabPosKey);
      if (raw == null) return null;
      final parts = raw.split(',');
      if (parts.length != 2) return null;
      final dx = double.tryParse(parts[0]);
      final dy = double.tryParse(parts[1]);
      if (dx == null || dy == null) return null;
      return [dx, dy];
    } catch (_) {
      return null;
    }
  }

  Future<void> setFabOffset(double dx, double dy) async {
    try {
      await backend.writeToken(_fabPosKey, '$dx,$dy');
    } catch (_) {}
  }
}
