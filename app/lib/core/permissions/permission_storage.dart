// Secure-storage wrapper for per-user, per-kind PrimingState.
// Key schema: priming_v1:{userId}:{kind}[:{subContext}]
// All IO is async; all failures return safe defaults (offline-first AC).
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'permission_types.dart';

/// Manages cooldown state persistence for the priming module.
///
/// Storage key per entry: `priming_v1:{userId}:{kind.name}[:{subContext}]`
///
/// Examples:
///   priming_v1:42:notification
///   priming_v1:42:camera:cccdUpload
///
/// Security notes:
/// - userId must be an opaque numeric/UUID ID, never email or PII.
/// - [clearUser] only deletes current user's keys (no full-key enumeration).
/// - [resetAll] and [skipDays] are debug-only, guarded by [kDebugMode].
class PermissionStorage {
  PermissionStorage(this._storage);

  final FlutterSecureStorage _storage;

  // ── Key helpers ─────────────────────────────────────────────────────────────

  String _key(String userId, PermissionKind kind, [String? subContext]) {
    final base = 'priming_v1:$userId:${kind.name}';
    return subContext != null ? '$base:$subContext' : base;
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Reads the persisted [PrimingState] for the given user + kind.
  /// Returns [PrimingState.empty()] if no state exists or on read error.
  Future<PrimingState> read(
    String userId,
    PermissionKind kind, {
    String? subContext,
  }) async {
    try {
      final raw = await _storage.read(key: _key(userId, kind, subContext));
      if (raw == null || raw.isEmpty) return PrimingState.empty();
      return PrimingState.fromJsonString(raw);
    } catch (_) {
      return PrimingState.empty();
    }
  }

  /// Persists [state] for the given user + kind.
  /// Silently swallows write errors (offline-first: next read returns stale state).
  Future<void> write(
    String userId,
    PermissionKind kind,
    PrimingState state, {
    String? subContext,
  }) async {
    try {
      await _storage.write(
        key: _key(userId, kind, subContext),
        value: state.toJsonString(),
      );
    } catch (_) {
      // Non-fatal: priming will re-trigger on next session.
    }
  }

  /// Deletes only the current user's priming keys. Does NOT touch other users.
  /// Called on logout (AC-T1 / AC-N7 — never clear sibling accounts).
  Future<void> clearUser(String userId) async {
    try {
      for (final kind in PermissionKind.values) {
        await _storage.delete(key: _key(userId, kind));
        // Also clear camera sub-context keys.
        for (final ctx in CameraContext.values) {
          await _storage.delete(key: _key(userId, kind, ctx.name));
        }
      }
    } catch (_) {
      // Best-effort; not fatal.
    }
  }

  /// Returns true if the user is still within the cooldown window.
  ///
  /// Cooldown rules (AC-N3 / D7):
  /// - After defer  → 7 days cooldown.
  /// - After OS deny → 30 days cooldown.
  Future<bool> isInCooldown(
    String userId,
    PermissionKind kind, {
    String? subContext,
    Duration deferCooldown = const Duration(days: 7),
    Duration denyCooldown = const Duration(days: 30),
  }) async {
    final state = await read(userId, kind, subContext: subContext);
    final now = DateTime.now();

    final deferAt = state.lastDeferAt;
    if (deferAt != null && now.difference(deferAt) < deferCooldown) {
      return true;
    }

    final denyAt = state.lastDenyAt;
    if (denyAt != null && now.difference(denyAt) < denyCooldown) {
      return true;
    }

    return false;
  }

  // ── Debug helpers (kDebugMode only) ─────────────────────────────────────────

  /// Deletes ALL priming keys (debug menu / QA reset — AC-V2).
  /// Caller MUST guard with [kDebugMode] at call site.
  Future<void> resetAll() async {
    assert(kDebugMode, 'resetAll() must only be called in debug builds');
    try {
      final all = await _storage.readAll();
      for (final key in all.keys) {
        if (key.startsWith('priming_v1:')) {
          await _storage.delete(key: key);
        }
      }
    } catch (_) {}
  }

  /// Shifts stored cooldown timestamps backwards by [days] so the
  /// cooldown appears to have already elapsed (AC-V4 time-travel for QA).
  /// Caller MUST guard with [kDebugMode] at call site.
  Future<void> skipDays(String userId, int days) async {
    assert(kDebugMode, 'skipDays() must only be called in debug builds');
    final offset = Duration(days: days);
    try {
      for (final kind in PermissionKind.values) {
        final contexts = <String?>[null, ...CameraContext.values.map((c) => c.name)];
        for (final ctx in contexts) {
          final state = await read(userId, kind, subContext: ctx);
          final shifted = PrimingState(
            lastShownAt: state.lastShownAt?.subtract(offset),
            lastDeferAt: state.lastDeferAt?.subtract(offset),
            lastDenyAt: state.lastDenyAt?.subtract(offset),
            lastShownForRole: state.lastShownForRole,
            osGranted: state.osGranted,
            osPermanentlyDenied: state.osPermanentlyDenied,
            osProvisional: state.osProvisional,
          );
          await write(userId, kind, shifted, subContext: ctx);
        }
      }
    } catch (_) {}
  }
}
