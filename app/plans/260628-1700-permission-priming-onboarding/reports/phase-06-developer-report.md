# Phase 06 Developer Report — Analytics + BE Contract

**Date:** 2026-06-28  
**Status:** DONE

---

## Files Created

| File | Lines | Notes |
|------|-------|-------|
| `lib/core/permissions/permission_analytics_uploader.dart` | 174 | New batch-upload class |
| `docs/features/permission-priming-api.md` | 257 | BE contract deliverable (3 endpoints) |

## Files Modified

| File | Lines (after) | What was added |
|------|----------------|----------------|
| `lib/core/permissions/permission_events.dart` | 109 | `drainPending()` changed to snapshot-only (no clear); `clear()` implemented with ts-key matching |
| `lib/core/permissions/fcm_service.dart` | 374 | Added `registerToken`, `unregisterToken`, `attachUserContext`, `detachUserContext`, `_platformString`; added `jwtProvider` constructor param |
| `lib/core/permissions/permission_service.dart` | 438 | `grantNotification`: fire-and-forget `registerToken` after OS grant; `onLogout`: `unregisterToken` + `detachUserContext` before `deleteToken`; added `eventSink` getter |
| `lib/main.dart` | 334 | `_MyAppState` gains `with WidgetsBindingObserver`; `_uploader` field; `initState` wires observer + constructs uploader; `dispose` removes observer; `didChangeAppLifecycleState` flushes on resumed+authenticated; `Provider<PermissionAnalyticsUploader>` added to MultiProvider; `_NullFcmService` overrides new methods |
| `lib/providers/notification_provider.dart` | 191 | `attachFcm` signature extended with optional `uploader` param; calls `uploader?.flush()` after wiring subscriptions |
| `lib/core/router/app_router.dart` | 442 | `_RootGateState` post-login block: reads context-dependent providers before first `await` (lint compliance); calls `attachFcm(... uploader:)`; calls `permService.fcm.attachUserContext` with installId |

---

## flutter analyze Result

- **Before Phase 6:** 141 issues (140 info, 1 error in test/widget_test.dart — pre-existing)
- **After Phase 6:** 140 issues (139 info, 1 error in test/widget_test.dart — pre-existing)
- **Delta:** -1 issue (removed a pre-existing TODO comment in notification_provider.dart)
- **New issues introduced by Phase 6 files:** 0 errors, 0 warnings

The 2 `info` warnings in `app_router.dart` (`use_build_context_synchronously`) were pre-existing before Phase 6 (confirmed via `git stash` baseline).

---

## Verification Grep Results

1. **`PermissionAnalyticsUploader` registered as Provider in `main.dart`:**  
   `lib/main.dart:228: Provider<PermissionAnalyticsUploader>.value(value: _uploader)`  ✓

2. **`WidgetsBindingObserver` mixed into `_MyAppState`:**  
   `lib/main.dart:174: class _MyAppState extends State<MyApp> with WidgetsBindingObserver`  ✓

3. **`didChangeAppLifecycleState` calls `flush()`:**  
   `lib/main.dart:214-216: didChangeAppLifecycleState → _uploader.flush()`  ✓

4. **`LocalPermissionEventSink` has no stub/TODO bodies:**  
   `drainPending()` returns snapshot (no clear). `clear()` removes by ts-microsecond key. No TODO markers remain.  ✓

5. **`docs/features/permission-priming-api.md` exists with all 3 endpoints:**  
   File exists (257 lines). Contains `POST /api/users/me/push-token`, `DELETE /api/users/me/push-token`, `POST /api/analytics/permission-events` — confirmed by grep count = 3.  ✓

6. **`registerToken` and `unregisterToken` exist in `FcmService` and called from `PermissionService`:**  
   - `fcm_service.dart:126`: `Future<bool> registerToken({...})`  
   - `fcm_service.dart:170`: `Future<bool> unregisterToken({...})`  
   - `permission_service.dart:160`: `unawaited(_fcm.registerToken(...))` in `grantNotification`  
   - `permission_service.dart:304`: `await _fcm.unregisterToken(...)` in `onLogout`  ✓

---

## HTTP Client Choice

**Used `package:http` directly** (same package already used by `ApiClient`) — NOT via `ApiClient` wrapper.

Rationale:
- `ApiClient` wraps `http.post/delete` but does not expose the raw status code cleanly — it throws `ApiException` on any non-2xx. The uploader needs to distinguish 401 (discard queue) vs 429/5xx (backoff) vs 200 (success).
- Adding another method to `ApiClient` that returns raw status would widen that class's interface with analytics-specific logic (violates SRP).
- Using `http` directly matches the same transport layer (no new dependency). `ApiClient` already imports `http`.
- JWT injection is done inline using `SessionService.instance.getToken` — same pattern as `ApiClient._headers()`.

---

## BE Endpoint Stub Behavior (404 Graceful Degradation)

When BE endpoints don't exist yet, the server may return 404. The client handles this gracefully:

- **Analytics endpoint** (`POST /api/analytics/permission-events`): 404 treated as server error → backoff schedule (1m → 5m → 15m, in-memory only). Events stay in the local queue and are retried on each subsequent app foreground after the backoff window expires. No data loss.
- **Token register** (`POST /api/users/me/push-token`): Returns `false` silently. No retry mechanism — the token-refresh listener will re-attempt on next FCM token rotation. FCM push will silently not work until BE implements the endpoint.
- **Token unregister** (`DELETE /api/users/me/push-token`): Returns `false` silently. 404 is treated as success (idempotent). No impact on user experience.

This means the feature can ship and be tested client-side before BE implements any of these endpoints.

---

## `drainPending()` Semantic Change

The original `drainPending()` in Phase 2 atomically cleared the queue (drain = remove). This was changed in Phase 6 to be **snapshot-only** (drain = read without clearing). Rationale:

- The uploader uploads in chunks of 50 events; only confirmed chunks (200 response) should be cleared.
- If the app is killed after draining but before confirming, events would be lost with the old semantics.
- With snapshot semantics, events remain until `clear(chunk)` is explicitly called after each successful HTTP 200.

The `clear()` method was also upgraded from a no-op to a real implementation that removes events by `ts.microsecondsSinceEpoch` key.

---

## Known TODOs / Deferred Items

1. **VAPID key for web push** — `main.dart:55: TODO(ops): set VAPID key from env when deploying web push.` Pre-existing, not Phase 6 scope.
2. **`_NullFcmService.registerToken`** — returns `false` unconditionally. Correct for Huawei/no-GMS devices.
3. **Retry on `registerToken` failure** — plan mentions "retry once after 30s" but implementation does fire-and-forget. The token-refresh listener + next foreground flush acts as the retry mechanism. Per plan risk table: acceptable.
4. **Widget test in `test/widget_test.dart`** — pre-existing `missing_required_argument` error (added `fcmAvailable` param to `MyApp` in Phase 1). Not Phase 6 scope.
5. **Phase 7 e2e tests** — uploader has no unit tests in this phase. Phase 7 covers full suite with BE staging.
