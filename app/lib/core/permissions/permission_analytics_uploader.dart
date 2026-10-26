// Batch-uploads queued [PermissionEvent]s to the analytics endpoint.
// Storage: events are read from [PermissionEventSink] (secure-storage backed).
// HTTP: uses package:http directly (same client used by [ApiClient]) with JWT
//       injected via [jwtProvider] callback (delegates to SessionService).
//
// Design decisions:
// - Backoff is in-memory only (resets on app restart by design — per plan spec).
// - Chunks of ≤50 events per request to stay within BE rate-limit headroom.
// - 404 treated as 5xx (BE endpoint may not exist yet) → backoff gracefully.
// - 401 discards entire queue (token expired → events are stale, no retry value).
// - drainPending() is a snapshot; clear() removes confirmed events after 200.
//   This prevents event loss if the app is killed between drain and upload.
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/permissions/permission_events.dart';
import 'package:house_booking/core/permissions/permission_types.dart';

/// Batches [PermissionEvent]s from a [PermissionEventSink] and uploads them
/// to `POST /api/analytics/permission-events` in groups of 50.
///
/// Call [flush] on every `AppLifecycleState.resumed` event (wired in main.dart).
/// Safe to call concurrently — the [_flushing] lock prevents overlapping runs.
// ignore_for_file: prefer_initializing_formals
// Reason: Constructor params are named 'sink'/'jwtProvider' (public API) while
// fields are '_sink'/'_jwtProvider' (private). Dart's initializing formals require
// the same name, which would force public names for private fields — not acceptable here.

class PermissionAnalyticsUploader {
  PermissionAnalyticsUploader({
    required PermissionEventSink sink,
    required Future<String?> Function() jwtProvider,
  })  : _sink = sink,
        _jwtProvider = jwtProvider;

  final PermissionEventSink _sink;

  /// Returns the current Bearer token. Delegates to SessionService at the call site.
  final Future<String?> Function() _jwtProvider;

  // ── Backoff state (in-memory only — resets on app restart) ─────────────────

  static const _backoffSteps = [
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  int _backoffIndex = 0;
  DateTime? _nextRetryAt;
  bool _flushing = false;

  static const int _chunkSize = 50;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// True if the uploader is in a backoff window and [nextRetryAt] is in the future.
  bool get isBackoff =>
      _nextRetryAt != null && DateTime.now().isBefore(_nextRetryAt!);

  /// Earliest time the next flush attempt will run (null = no backoff active).
  DateTime? get nextRetryAt => _nextRetryAt;

  /// Idempotent flush — safe to call on every app foreground.
  ///
  /// Returns the count of events successfully uploaded this run.
  /// Returns 0 immediately if: no events queued, backoff active, or already flushing.
  Future<int> flush() async {
    if (_flushing) return 0;
    if (isBackoff) return 0;

    final token = await _jwtProvider();
    if (token == null || token.isEmpty) {
      // Not authenticated — skip upload, keep queue.
      return 0;
    }

    _flushing = true;
    int uploaded = 0;

    try {
      // Snapshot (does NOT clear — events remain until clear() is called per chunk).
      final pending = await _sink.drainPending();
      if (pending.isEmpty) return 0;

      // Split into chunks of _chunkSize.
      for (var i = 0; i < pending.length; i += _chunkSize) {
        final end =
            (i + _chunkSize < pending.length) ? i + _chunkSize : pending.length;
        final chunk = pending.sublist(i, end);

        final result = await _postChunk(chunk, token);

        if (result == _UploadResult.success) {
          await _sink.clear(chunk);
          uploaded += chunk.length;
          _resetBackoff();
        } else if (result == _UploadResult.authFailed) {
          // 401: discard entire queue — events belong to an expired session.
          await _sink.clear(pending);
          _resetBackoff();
          debugPrint(
            '[PermissionAnalyticsUploader] 401 — discarding ${pending.length} queued events.',
          );
          break;
        } else {
          // 429 / 5xx / 404 / network error — back off, retry next foreground.
          _advanceBackoff();
          debugPrint(
            '[PermissionAnalyticsUploader] Upload failed — '
            'next retry at $_nextRetryAt (backoff step $_backoffIndex).',
          );
          break;
        }
      }
    } catch (e) {
      _advanceBackoff();
      debugPrint('[PermissionAnalyticsUploader] Unexpected flush error: $e');
    } finally {
      _flushing = false;
    }

    return uploaded;
  }

  // ── HTTP ────────────────────────────────────────────────────────────────────

  Future<_UploadResult> _postChunk(
    List<PermissionEvent> chunk,
    String token,
  ) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/api/analytics/permission-events',
      );
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'events': chunk.map((e) => e.toJson()).toList(),
        }),
      );

      final status = response.statusCode;
      if (status >= 200 && status < 300) return _UploadResult.success;
      if (status == 401) return _UploadResult.authFailed;
      // 404 and all other error codes (400, 429, 5xx) → server error → backoff.
      return _UploadResult.serverError;
    } catch (_) {
      // Network error — treat as transient.
      return _UploadResult.serverError;
    }
  }

  // ── Backoff helpers ─────────────────────────────────────────────────────────

  void _advanceBackoff() {
    final step = _backoffSteps[_backoffIndex];
    _nextRetryAt = DateTime.now().add(step);
    if (_backoffIndex < _backoffSteps.length - 1) _backoffIndex++;
  }

  void _resetBackoff() {
    _backoffIndex = 0;
    _nextRetryAt = null;
  }
}

enum _UploadResult { success, authFailed, serverError }
