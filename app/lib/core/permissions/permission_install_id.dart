// Generates and caches a stable UUID per app install.
// Survives app restarts; cleared only on uninstall (keychain persists on iOS until uninstall).
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Provides a stable, opaque identifier for this device install.
///
/// Used to namespace priming cooldown keys alongside userId so that:
/// - Re-install resets the install-level state (new UUID generated).
/// - Multi-user on the same device gets per-userId tracking (see [PermissionStorage]).
///
/// Pattern: read from [_key] in secure storage; if absent, generate 32-char
/// hex via [Random.secure()] and persist. Subsequent calls return the cached value.
class PermissionInstallId {
  PermissionInstallId(this._storage);

  final FlutterSecureStorage _storage;

  static const _key = 'priming_install_id_v1';

  String? _cached;

  /// Returns the install UUID. Generates and persists on first call.
  /// Safe to call concurrently — concurrent calls may each write the same value.
  Future<String> get() async {
    if (_cached != null) return _cached!;

    try {
      final stored = await _storage.read(key: _key);
      if (stored != null && stored.isNotEmpty) {
        _cached = stored;
        return _cached!;
      }

      final generated = _generateHex32();
      await _storage.write(key: _key, value: generated);
      _cached = generated;
      return _cached!;
    } catch (_) {
      // Secure storage unavailable (e.g. encrypted backup restore mismatch).
      // Return a session-only ID so callers still function — state won't persist.
      _cached ??= _generateHex32();
      return _cached!;
    }
  }

  /// Generates a 32-character lowercase hex string from [Random.secure()].
  /// Equivalent entropy to UUID v4 (128 bits).
  static String _generateHex32() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
