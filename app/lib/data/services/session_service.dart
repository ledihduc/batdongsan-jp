// Conditional import: web dùng dart:html localStorage, native dùng
// flutter_secure_storage (Keychain / EncryptedSharedPreferences / DPAPI).
import '_session_storage_io.dart'
    if (dart.library.html) '_session_storage_web.dart'
    as backend;

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const _tokenKey = 'auth_token';

  String? _cached;
  bool _loaded = false;

  Future<String?> getToken() async {
    if (_loaded) return _cached;
    try {
      _cached = await backend.readToken(_tokenKey);
    } catch (_) {
      _cached = null;
    }
    _loaded = true;
    return _cached;
  }

  Future<void> setToken(String token) async {
    _cached = token;
    _loaded = true;
    try {
      await backend.writeToken(_tokenKey, token);
    } catch (_) {
      // Swallow — token vẫn còn trong cache cho phiên hiện tại.
    }
  }

  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    try {
      await backend.deleteToken(_tokenKey);
    } catch (_) {}
  }
}
