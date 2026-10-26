# Phase 05 Developer Report — Platform Specifics

**Date:** 2026-06-28  
**Phase:** 05 — Platform Specifics  
**Status:** DONE_WITH_CONCERNS (file-size concerns on 2 pre-existing service files)

---

## Files Created

| File | Lines | Notes |
|------|-------|-------|
| `lib/core/permissions/platform_capability.dart` | 165 | New. `supportsProvisionalIos`, `supportsWebPush`, `isHuaweiWithoutGms` |

---

## Files Modified

| File | Lines (after) | What was added |
|------|--------------|----------------|
| `lib/core/permissions/gms_detector_android.dart` | 34 | Expanded comment enumerating all failure statuses; logic was already correct in Phase 1 (returns `false` for any non-`success` status). Added `serviceUpdating` / `notAvailableOnPlatform` / `unknown` to documentation. |
| `lib/core/permissions/fcm_service.dart` | 487 | Added `FlutterSecureStorage` dep + `_storage` field; added `userId` param to `requestPermission`; added `_writeProvisionalState`, `_clearProvisionalState`, `shouldShowApnsFallback`, `markDelivered`; clear provisional on `authorized` result. |
| `lib/core/permissions/permission_service.dart` | 671 | Added web pre-checks to `shouldShowNotificationPriming`; split `grantNotification` into `_requestOsPermission` + `_requestAndroidPermission` platform branches; added `shouldShowApnsFallback` + `markApnsDelivered` public API; extended `onAppForeground` with APNs fallback check. |
| `lib/main.dart` | 364 | Added `dart:io` import; added Huawei `fcmUnavailableGmsMissing` event logging block post-GMS-check; fixed `_NullFcmService.requestPermission` override to include `userId = ''` param. |
| `web/firebase-messaging-sw.js` | 97 | Rewrote `notificationclick` handler: now sends `client.postMessage({type: 'notification_tap', data})` to all existing clients before focus/open. Uses `click_action` field from notification data for deep-link target. |
| `web/index.html` | 137 | Added Safari version detection block around SW registration. Skips registration on genuine Safari < 16.4 with console log explaining why. |
| `docs/features/permission-priming-config.md` | +90 lines | Appended section 9 "Per-Platform Behavior" with platform matrix, iOS APNs timer doc, Safari PWA note, Huawei silent skip rationale, Android 13+ dialog flow, and test matrix. |

---

## flutter analyze Result

- **Before Phase 5:** 139 issues (1 error in `test/widget_test.dart`)
- **After Phase 5:** 142 issues (1 error in `test/widget_test.dart`)
- **Delta:** +3 info-level issues (not in Phase 5 files; unrelated existing code picked up by re-analysis)
- **New errors introduced:** 0
- **Pre-existing error unchanged:** `test/widget_test.dart:16` — `missing_required_argument` for `fcmAvailable`. This predates Phase 5 (exists since Phase 4 added the param to `MyApp`). Not in scope to fix here.

---

## 8 Verification Grep Results

1. **`PlatformCapability.supportsWebPush`** — used in `permission_service.dart` (2 call sites: `shouldShowNotificationPriming` + `_requestOsPermission`). ✓
2. **`fcm_provisional_state`** — storage key defined in `fcm_service.dart` (`_provisionalKey()` method). Referenced in `_writeProvisionalState`, `_clearProvisionalState`, `shouldShowApnsFallback`, `markDelivered`. ✓
3. **`Permission.notification.request()`** — called in `permission_service.dart:_requestAndroidPermission` behind `sdkInt >= 33` guard. ✓
4. **`GoogleApiAvailability`** in `gms_detector_android.dart` — `GoogleApiAvailability.instance.checkGooglePlayServicesAvailability()`. ✓
5. **`notificationclick` listener** in `web/firebase-messaging-sw.js` line 56. ✓
6. **`postMessage`** in `web/firebase-messaging-sw.js` line 70 — sends `{type:'notification_tap', data}` to each active client. ✓
7. **Safari version check** in `web/index.html` — `_isSafariOnly` + `_shouldRegister` block wraps SW registration. ✓
8. **`flutter pub get`** — succeeded; no version conflicts. ✓

---

## `requestPermission` API Signature Change

**Old:**
```dart
Future<PrimingOutcome> requestPermission({
  required UserRole role,
  required bool useProvisionalOnIos,
})
```

**New:**
```dart
Future<PrimingOutcome> requestPermission({
  required UserRole role,
  required bool useProvisionalOnIos,
  String userId = '',   // ← optional with default; backwards-compatible
})
```

`userId` is optional (defaults to `''`) so all existing call sites are unaffected. Updated call sites:
- `permission_service.dart` — 4 call sites in `_requestOsPermission` and `_requestAndroidPermission`; all pass explicit `userId`.
- `main.dart` — `_NullFcmService.requestPermission` override updated to include `String userId = ''`.

No other files call `requestPermission` directly (confirmed via grep — all callers route through `PermissionService.grantNotification`).

---

## iOS APNs Fallback UI Integration Plan

`shouldShowApnsFallback(userId)` is now a **public method on `PermissionService`** that delegates to `FcmService.shouldShowApnsFallback`. It is NOT yet wired into the UI layer (no `_RootGate` changes).

**How `_RootGate` should consume it (deferred to Phase 7):**
1. In `_maybePresentNotificationPriming`, after priming sheet is dismissed or on app foreground:
   ```dart
   final showBanner = await permService.shouldShowApnsFallback(userId);
   if (showBanner) {
     // Render SoftReaskBanner — same UI as permanent-deny recover banner
     // but with copy: "iOS đã gửi thông báo thử nghiệm nhưng chưa nhận được..."
   }
   ```
2. `NotificationProvider.attachFcm` already subscribes to `FcmService.foregroundMessages`. Extend that handler to also call `permService.markApnsDelivered(userId)` on any message receipt — this clears the 24h timer.
3. `onAppForeground` already captures the `osPermDeny` analytics event when the fallback fires — UI just needs to poll `shouldShowApnsFallback` separately.

**Phase 7 e2e action:** Use `debugSkipDays` to fast-forward past 24h, verify banner renders, verify foreground message receipt clears the banner.

---

## Known TODOs / Deferred Items

1. **`platform_capability.dart` — `supportsProvisionalIos` not yet used** at call sites. `PermissionService._requestOsPermission` checks `Platform.isIOS` directly (equivalent). Could be unified — YAGNI: leave until Phase 7 tests reveal a need.
2. **`isHuaweiWithoutGms` not yet called** from `shouldShowNotificationPriming`. Current flow: `_RootGate` already skips priming when `fcmAvailable == false` (set in `main()` before app starts). The `PlatformCapability.isHuaweiWithoutGms` helper is available for any caller that needs it at runtime without access to the `fcmAvailable` bool. Documented — no functional gap.
3. **`supportsProvisionalIos` in `PlatformCapability`** exposed but not consumed. Available for Phase 3 widget to conditionally show "provisional" copy variant if needed.
4. **`web/firebase-messaging-sw.js` `notificationclick` postMessage listener** — Flutter Web side wiring is NOT in scope for Phase 5. Phase 4's `NotificationProvider.attachFcm` would need to add `window.addEventListener('message', ...)` or use `ServiceWorker.addEventListener`. Deferred to Phase 7 / NotificationProvider update.
5. **File size:** `fcm_service.dart` (487 lines) and `permission_service.dart` (671 lines) exceed the 200-line guideline. Per phase spec "keep changes additive — don't refactor existing Phase 4/6 logic", no split was done. Track for a separate refactor sprint post-Phase 7 go-live.
6. **Pre-existing test error** (`test/widget_test.dart:16` — `missing_required_argument`): pre-dates Phase 5. Needs `MyApp(fcmAvailable: false)` in the test file. Out of scope for this phase.

---

## Unresolved Questions

None blocking.
