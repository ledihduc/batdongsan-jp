// Local event queue for permission analytics (offline-first, no HTTP here).
// Phase 6 builds the batch-upload uploader that calls drainPending().
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'permission_types.dart';

// ─── Abstract interface ───────────────────────────────────────────────────────

/// Abstraction so Phase 6 uploader and tests can swap implementations.
abstract class PermissionEventSink {
  /// Capture a single [PermissionEvent] into the local queue.
  Future<void> capture(PermissionEvent event);

  /// Returns all queued events and removes them from the queue atomically.
  /// Phase 6 calls this on app foreground to batch-upload to BE.
  Future<List<PermissionEvent>> drainPending();

  /// Marks [uploaded] events as acknowledged — removes them if they are still
  /// head-of-queue (safe to call after drainPending + successful upload).
  Future<void> clear(List<PermissionEvent> uploaded);
}

// ─── Local implementation ─────────────────────────────────────────────────────

/// In-memory + secure-storage backed event queue.
///
/// - Append-only; capped at 200 events (drop oldest on overflow).
/// - Hydrated from storage on first [capture] call.
/// - No HTTP — drain is called by Phase 6 uploader.
///
/// Storage key: [_key] → JSON array of [PermissionEvent.toJson()] objects.
class LocalPermissionEventSink implements PermissionEventSink {
  LocalPermissionEventSink(this._storage);

  final FlutterSecureStorage _storage;

  static const _key = 'priming_event_queue_v1';
  static const _maxEvents = 200;

  final List<PermissionEvent> _queue = [];
  bool _hydrated = false;

  // ── Public API ──────────────────────────────────────────────────────────────

  @override
  Future<void> capture(PermissionEvent event) async {
    await _ensureHydrated();
    _queue.add(event);

    // Cap at _maxEvents by dropping oldest entries.
    if (_queue.length > _maxEvents) {
      _queue.removeRange(0, _queue.length - _maxEvents);
    }

    await _persist();
  }

  @override
  Future<List<PermissionEvent>> drainPending() async {
    await _ensureHydrated();
    // Returns a snapshot WITHOUT clearing — caller (uploader) clears per-chunk
    // after each confirmed 200 response via [clear]. This ensures events are not
    // lost if the app is killed between drain and a successful upload.
    return List<PermissionEvent>.from(_queue);
  }

  @override
  Future<void> clear(List<PermissionEvent> uploaded) async {
    if (uploaded.isEmpty) return;
    await _ensureHydrated();
    // Match events by ts microsecondsSinceEpoch — high-enough resolution that
    // collision probability is negligible for the expected event volume (~10/lifetime).
    final uploadedKeys =
        uploaded.map((e) => e.ts.microsecondsSinceEpoch).toSet();
    _queue.removeWhere((e) => uploadedKeys.contains(e.ts.microsecondsSinceEpoch));
    await _persist();
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> _ensureHydrated() async {
    if (_hydrated) return;
    _hydrated = true; // Set before IO to prevent double-hydration on concurrent calls.
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        try {
          _queue.add(PermissionEvent.fromJson(item as Map<String, dynamic>));
        } catch (_) {
          // Skip malformed entries (format change across app versions).
        }
      }
    } catch (_) {
      // Storage read failed — start with empty queue.
    }
  }

  Future<void> _persist() async {
    try {
      final encoded = jsonEncode(_queue.map((e) => e.toJson()).toList());
      await _storage.write(key: _key, value: encoded);
    } catch (_) {
      // Non-fatal — events lost on crash but cooldown state is independent.
    }
  }
}
