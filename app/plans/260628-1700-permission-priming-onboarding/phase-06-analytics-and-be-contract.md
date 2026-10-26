# Phase 06 — Analytics & Backend Contract

**Status:** pending | **Effort:** 4h | **Depends on:** Phase 2 | **Blocks:** Phase 7 (e2e needs real BE)

## Context Links

- BA Section 10.1 AC-T1, Section 10.2 AC-M3 revised, AC-M1
- BA Leader review H3 (analytics security)
- Researcher: Task 5 (storage choice)

## Overview

Define the **client ↔ backend contract** for 3 endpoints and implement client-side batch upload + retry. Storage decision: **secure-storage queue** (NOT SQLite) — rationale below. Backend implementation is OUT OF SCOPE for this BA (separate ticket), but this phase ships **request/response JSON spec** so BE team can implement in parallel.

## Key Insights

- **Storage choice = secure-storage JSON queue** (not SQLite). Rationale:
  - Event volume = ~5-10 events per user lifetime (priming is rare).
  - Payload size ~200 bytes × 200 cap = 40KB max — well under secure-storage practical limit.
  - SQLite adds: schema migration cost, query overhead, dependency. Violates YAGNI.
  - Already using `flutter_secure_storage` (M3 constraint).
- **Discard on logout** (H3 revised): events buffered while logged out are dropped, not retroactively sent. Avoids unauthenticated-payload risk.
- **Server-side whitelist** is the security boundary — client schema may evolve, BE must reject unknown fields.
- **Rate limit 60 req/min/user** prevents abuse; client batches in groups of 50 per upload to stay well under.
- **Token endpoint is per-device** (AC-T1): allows multi-device push per D8.

## Requirements

### Functional

- Local queue captures all 10 outcome events (per AC-M1 list).
- Batch upload to BE on app foreground (after login). Group of ≤50 events per request.
- On 200: clear uploaded events from queue.
- On 401: clear queue (token expired — discard rather than retry).
- On 429/5xx: keep events, retry on next foreground (exponential backoff: 1m, 5m, 15m).
- Token register on grant (`POST`), unregister on logout (`DELETE`), re-register on token refresh.

### Non-functional

- Upload happens off main thread (existing `dio` is async).
- Queue is append-only; deletes only by uploaded-event reference list.
- No PII in event payloads.

## Architecture

```
PermissionService.grantNotification(...)
  └── PermissionEventSink.capture(PermissionEvent(...))
        └── append to secure_storage 'priming_event_queue_v1' (JSON array)

App onForeground (existing lifecycle observer)
  └── PermissionAnalyticsUploader.flush()
        ├── pending = await sink.drainPending()  (snapshot, doesn't clear yet)
        ├── chunks of 50 events
        ├── for each chunk:
        │     POST /api/analytics/permission-events { events: [...] }
        │     on 200: await sink.clear(chunk)
        │     on 401: await sink.clear(pending)  (discard)
        │     on 429/5xx: stop, retry next foreground
```

## Related Code Files

### Modify

- `lib/core/permissions/permission_events.dart` — finalize `LocalPermissionEventSink` (Phase 2 stubbed signatures).
- `lib/main.dart` — register `WidgetsBindingObserver` for `AppLifecycleState.resumed` → trigger uploader.
- `lib/providers/notification_provider.dart` — call uploader inside existing `init`/`refresh`.

### Create

- `lib/core/permissions/permission_analytics_uploader.dart` — orchestrates batch upload via existing `dio` client.
- `docs/features/permission-priming-api.md` — BE contract doc (this file's content extracted, for BE team).

### Delete

- None.

## Backend Contract (DELIVERABLE — for BE ticket)

### 1. `POST /api/users/me/push-token` (AC-T1)

**Auth:** JWT required (existing scheme).

**Request:**
```json
{
  "token": "fGxK8s...long_fcm_token...",
  "deviceId": "uuid-v4-from-permission-install-id",
  "platform": "ios" | "android" | "web"
}
```

**Response 200:**
```json
{ "registered": true, "deviceCount": 2 }
```

**Response 400:** invalid platform enum or missing fields.

**Storage:** BE table `user_push_tokens (user_id, device_id PK, token, platform, last_seen_at)`. **Upsert** on `(user_id, device_id)`. Multiple devices per user allowed (D8).

**Notes for BE:**
- On insert, if `token` already exists for different `user_id`: delete old row first (token rotation after logout/login).
- `last_seen_at = NOW()` updated on every call (used for stale-token cleanup, 90d).

### 2. `DELETE /api/users/me/push-token` (AC-T1)

**Auth:** JWT required.

**Request:** (body OR query param, BE choice)
```json
{ "deviceId": "uuid-v4-from-permission-install-id" }
```

**Response 200:**
```json
{ "unregistered": true, "deviceCount": 1 }
```

**Response 404:** device not found (idempotent — return 200 anyway, log warning).

**Behavior:** Deletes row matching `(user_id, device_id)`. Other devices unaffected.

### 3. `POST /api/analytics/permission-events` (AC-M1, AC-M3)

**Auth:** JWT required. Reject 401 if missing.

**Rate limit:** 60 req/min/user (AC-M3 revised).

**Request:**
```json
{
  "events": [
    {
      "outcome": "prime_shown" | "prime_accept" | "prime_defer"
               | "os_grant" | "os_deny" | "os_perm_deny"
               | "os_provisional" | "os_provisional_upgrade"
               | "settings_opened" | "fcm_unavailable_gms_missing",
      "kind": "notification" | "camera",
      "role": "guest" | "host" | "admin" | null,
      "context": "cccdUpload" | "postHousePhoto" | "contractPhoto"
               | "contractTerminatePhoto" | "profileAvatar"
               | "reportErrorPhoto" | null,
      "platform": "ios" | "android" | "web",
      "ts": "2026-06-28T10:15:30.000Z"
    }
  ]
}
```

**Field rules:**
- `events.length` ≤ 50 (BE may reject >50 with 400).
- `role` required if `kind == notification`; null allowed for camera.
- `context` required if `kind == camera`; null allowed for notification.
- `ts` must parse as ISO8601 UTC; reject otherwise.

**Whitelist (server-side, AC-M3 revised):** reject any unknown field with HTTP 400. Reject any unknown enum value. No `userAgent`, no `ip`, no `deviceModel`.

**Response 200:**
```json
{ "accepted": 12 }
```

**Response 400:** schema violation.

**Response 401:** JWT invalid/expired — client discards queue.

**Response 429:** rate limit — client backs off.

**Storage:** BE table `permission_events (id, user_id, outcome, kind, role, context, platform, ts, received_at)`. Index on `(user_id, ts)` for dashboard queries.

## Client Implementation Signatures

### `permission_analytics_uploader.dart`

```dart
class PermissionAnalyticsUploader {
  PermissionAnalyticsUploader({
    required Dio dio,
    required PermissionEventSink sink,
    required String Function() jwtProvider, // delegates to AuthProvider.token
  });

  /// Idempotent flush. Safe to call on every app foreground.
  /// Returns count of events successfully uploaded.
  Future<int> flush();

  /// Backoff state (in-memory only).
  bool get isBackoff;
  DateTime? get nextRetryAt;
}
```

Backoff state:
- After 429 or 5xx: `nextRetryAt = now + backoffDuration`.
- `backoffDuration` doubles each consecutive failure: 1m → 5m → 15m → 15m (cap).
- Resets on first 200.

### `LocalPermissionEventSink` (finalize from Phase 2)

```dart
class LocalPermissionEventSink implements PermissionEventSink {
  // Key: priming_event_queue_v1
  // Value: JSON array of PermissionEvent objects

  @override
  Future<void> capture(PermissionEvent event) async {
    final current = await _readQueue();
    current.add(event);
    if (current.length > 200) current.removeRange(0, current.length - 200); // FIFO cap
    await _writeQueue(current);
  }

  @override
  Future<List<PermissionEvent>> drainPending() async {
    return _readQueue(); // snapshot only — clear happens after upload confirms
  }

  @override
  Future<void> clear(List<PermissionEvent> uploaded) async {
    final current = await _readQueue();
    // Match by ts (PermissionEvent has ts as natural key; high enough resolution)
    final uploadedKeys = uploaded.map((e) => e.ts.microsecondsSinceEpoch).toSet();
    current.removeWhere((e) => uploadedKeys.contains(e.ts.microsecondsSinceEpoch));
    await _writeQueue(current);
  }
}
```

## Implementation Steps

1. Finalize `LocalPermissionEventSink` impl (Phase 2 had signatures).
2. Implement `PermissionAnalyticsUploader.flush`:
   - Read queue snapshot.
   - Chunk into groups of 50.
   - For each: POST via `dio` with Bearer token from `jwtProvider`.
   - Update backoff on failure; clear on success.
3. Wire `flush()` call:
   - In `lib/main.dart`: add `WidgetsBindingObserver` mixin to root state; on `didChangeAppLifecycleState(AppLifecycleState.resumed)` → call `uploader.flush()`.
   - Inside `flush()`: short-circuit if `isBackoff && nextRetryAt > now`.
4. Implement token register/unregister in `FcmService` (Phase 2 had signatures):
   - `registerToken(userId, installId)` → `POST /api/users/me/push-token` with `{token, deviceId: installId, platform}`.
   - `unregisterToken(userId, installId)` → `DELETE` with `{deviceId: installId}`.
   - On `messaging.onTokenRefresh`: re-call `registerToken`.
5. Write `docs/features/permission-priming-api.md` — copy the contract spec above for BE team consumption.
6. Add `flutter_test` mocks for `Dio` to unit-test uploader (Phase 7 covers full suite; stub here).

## Todo List

- [ ] Finalize `LocalPermissionEventSink` (capture/drain/clear)
- [ ] Implement `PermissionAnalyticsUploader.flush` + backoff
- [ ] Implement `FcmService.registerToken` / `unregisterToken` / token-refresh listener
- [ ] Wire `WidgetsBindingObserver` in `main.dart` → `uploader.flush()`
- [ ] Ship `docs/features/permission-priming-api.md` for BE team
- [ ] Sanity test: send 100 events locally, verify <=50 per request, 200 path clears

## Success Criteria

- AC-M1 verified: all 10 outcomes captured locally + uploaded.
- AC-M3 (revised) verified: 401 discards queue; 429 backs off; unknown fields rejected by BE (BE responsibility — confirm spec).
- AC-T1 verified: multi-device — log in on 2 devices, both tokens stored; logout 1 device, only that token deleted.
- No PII visible in any captured event payload (manual review).

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| BE endpoint not ready by feature launch | H | H | Client gracefully no-ops if endpoint returns 404 (treat as 5xx → backoff forever); ship feature, BE follows |
| Queue grows unbounded if uploader stuck | L | M | FIFO cap at 200 enforced in `capture()` |
| Event timestamp collision (ts as natural key) | L | L | Use microsecondsSinceEpoch — collision probability negligible; worst case = small over-delete |
| Backoff window prevents urgent event upload | L | L | Acceptable — analytics is not realtime |
| Token register fails on flaky network | M | M | Retry once after 30s; persist intent so next foreground retries |
| Multi-device token list grows stale (uninstall = no DELETE) | M | M | BE responsibility: stale-token cleanup at 90d via `last_seen_at` |

## Security Considerations

- All 3 endpoints **MUST require JWT** (AC-M3). No anonymous events.
- **Payload whitelist on BE** (AC-M3 revised). Client schema is the source of truth; BE rejects extras.
- **No PII** — verified at code review. Specifically: no `userAgent`, no `ip`, no `deviceModel`, no email/phone/name.
- **Rate limit** prevents log-flooding attack on BE storage.
- **Token endpoints** use existing JWT auth — no new auth surface.
- **Discard-on-logout** prevents leaking previous user's behavior to new user.
- **FCM token** treated as semi-sensitive — sent only over HTTPS; never logged.

## Next Steps

- Phase 7 e2e tests verify upload path with real BE staging.
- BE team builds endpoints per `docs/features/permission-priming-api.md`.
- Post-launch: build admin dashboard reading `permission_events` table for opt-in rate monitoring (AC-M2 measurement).
