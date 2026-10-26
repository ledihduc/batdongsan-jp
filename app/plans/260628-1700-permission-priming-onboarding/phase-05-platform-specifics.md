# Phase 05 — Platform Specifics

**Status:** pending | **Effort:** 4h | **Depends on:** Phase 4 | **Blocks:** Phase 7

## Context Links

- BA Section 10.1 AC-N5 (iOS provisional + APNs 24h), AC-N6 (Web pre-check), AC-N9 (Huawei/GMS)
- Researcher: Task 2 (iOS provisional), Task 3 (Android 13+), Task 4 (Web SW), Task 6 (Huawei), Task 7 (iOS 18 + Android 15)

## Overview

Per-platform polish: iOS provisional flow with 24h APNs fallback, Android 13+ runtime perm + Android 15 cooldown, Web `Notification.permission` pre-check + service worker, Huawei graceful skip. This is the **edge-case hardening** phase — no new architecture, just platform branches.

## Key Insights

- **iOS 18 bug:** `notDetermined` after dismiss must be treated as `deferred`, not `denied` (researcher Task 7).
- **Android 15 cooldown:** keep priming ≥4h apart (handled by 7-day defer cooldown already, but document).
- **Web pre-check:** call `Notification.permission` BEFORE rendering sheet (AC-N6) — if `granted`, just register token; if `denied`, show recover banner instead.
- **Huawei silent skip (D9):** log event for sizing, no user-visible error.
- **APNs feedback** must be BE responsibility — client only triggers fallback after 24h timer expires without delivery confirmation.

## Requirements

### Functional

- **iOS:** Provisional+full flow per AC-N5. Detect provisional→full upgrade on app foreground (poll). If no APNs delivery within 24h: show soft re-ask banner (BE pings client via separate "no_apns_delivered" push or client timer).
- **Android:** Detect SDK version. SDK ≥33 → request POST_NOTIFICATIONS via `permission_handler`. SDK <33 → auto-granted, skip OS dialog, just register FCM.
- **Web:** Pre-check `Notification.permission`. Service worker registered + receives background messages. Disable priming on Safari <16.4.
- **Huawei:** `GmsDetector.isFcmAvailable() == false` → skip Firebase init, hide priming, log event, fallback to in-app polling.

### Non-functional

- No crash on any of: iOS 16/17/18, Android 12/13/14/15, Chrome desktop/mobile, Firefox, Safari ≥16.4, Huawei Mate.
- Provisional fallback timer is per-install (stored in `flutter_secure_storage`), not server-managed (avoids BE dep).
- Service worker version matches Firebase JS SDK in `index.html` (avoid SW staleness).

## Architecture

```
PermissionService.grantNotification(useProvisionalIos)
  ├── if (Platform.isIOS)
  │     await messaging.requestPermission(provisional: useProvisionalIos)
  │     if result == provisional: schedule 24h fallback timer
  │     if result == authorized: clear fallback timer
  │
  ├── if (Platform.isAndroid)
  │     if (SDK >= 33) await Permission.notification.request()
  │     else status = granted (auto)
  │     await messaging.requestPermission()  // for token, no dialog
  │
  └── if (kIsWeb)
        if (browser unsupported) return osDeny
        webPerm = await html.Notification.requestPermission()
        if (webPerm == granted) register FCM token with VAPID

GmsDetector.isFcmAvailable()
  ├── if (kIsWeb) return supportsNotification()
  ├── if (Platform.isIOS) return true
  └── if (Platform.isAndroid)
        return GoogleApiAvailability.checkPlayServices() == SUCCESS

APNs 24h Fallback Timer (iOS)
  ├── Store grantedAt timestamp + delivered=false in secure storage
  ├── On app foreground: check if grantedAt > 24h ago AND not delivered
  │     -> trigger SoftReaskBanner kind=notification
  ├── On any RemoteMessage received (foreground or background):
  │     mark delivered=true, clear timer
```

## Related Code Files

### Modify

- `lib/core/permissions/permission_service.dart` — branch `grantNotification` on platform.
- `lib/core/permissions/fcm_service.dart` — implement iOS provisional upgrade poll; implement 24h fallback timer storage.
- `lib/core/permissions/gms_detector.dart` — implement actual platform branches.
- `lib/main.dart` — Huawei branch: skip FirebaseMessaging entirely.
- `web/firebase-messaging-sw.js` — finalize background handler with deep-link payload extraction.
- `web/index.html` — add Safari version detect, disable SW register on Safari <16.4.

### Create

- `lib/core/permissions/platform_capability.dart` — capability detection (`supportsWebPush`, `supportsProvisionalIos`, `isHuawei`).

### Delete

- None.

## Per-Platform Behavior Matrix

| Platform | Permission API | Token API | Background | Fallback if denied |
|----------|---------------|-----------|------------|--------------------|
| **iOS 16-17** | `messaging.requestPermission(provisional: true)` then upgrade | `messaging.getAPNSToken()` + `getToken()` | UNNotificationServiceExtension via Firebase | Soft re-ask banner + Settings deep-link |
| **iOS 18** | Same as 16-17 + treat `notDetermined` after dismiss as deferred | Same | Same | Same |
| **Android 12** | Auto-granted (manifest only) | `messaging.getToken()` | Auto via FCM service in manifest | Settings deep-link (rare path) |
| **Android 13+** | `permission_handler.Permission.notification.request()` | Same | Same | Settings deep-link |
| **Android 15** | Same as 13+; respect cooldown ≥4h (covered by 7d defer) | Same | Same | Same |
| **Chrome/Edge/Firefox** | `Notification.requestPermission()` via firebase_messaging_web | `messaging.getToken({vapidKey})` | Service worker `onBackgroundMessage` | Banner: "Bật trong cài đặt trình duyệt" |
| **Safari 16.4+ (PWA)** | Same as Chrome but PWA-install required | Same | Same | Same |
| **Safari <16.4** | NO support | NO token | NO background | Hide priming entirely |
| **Huawei (no GMS)** | NO request | NO token | NO background | Hide priming entirely; in-app polling continues |

## Implementation Steps

1. **`platform_capability.dart`:**
   ```dart
   class PlatformCapability {
     static bool get supportsProvisionalIos => Platform.isIOS;
     static Future<bool> get supportsWebPush async {
       if (!kIsWeb) return false;
       // Check window.Notification + ServiceWorker
       // Safari <16.4 returns false here
     }
     static Future<bool> get isHuaweiWithoutGms async { ... }
   }
   ```
2. **`gms_detector.dart` full implementation:** use `google_api_availability: ^5.x`; return `false` on `SERVICE_MISSING`, `SERVICE_VERSION_UPDATE_REQUIRED`, `SERVICE_DISABLED`, `SERVICE_INVALID`.
3. **iOS provisional flow in `fcm_service.dart`:**
   - On `init()`: read stored auth status. If `provisional`, start polling on every `onAppForeground` for upgrade.
   - 24h fallback: store `grantedAt: ISO8601` + `delivered: false` in secure storage key `fcm_provisional_state:{userId}`.
   - In `foregroundMessages` stream listener: if first message received, set `delivered: true`, clear timer.
   - `permission_service.onAppForeground`: if `provisional && grantedAt + 24h < now && !delivered` → trigger soft re-ask banner via callback to UI layer.
4. **Android branch in `grantNotification`:**
   ```dart
   if (Platform.isAndroid) {
     final sdkInt = await DeviceInfoPlugin().androidInfo.then((i) => i.version.sdkInt);
     if (sdkInt >= 33) {
       final status = await Permission.notification.request();
       if (!status.isGranted) return PrimingOutcome.osDeny;
     }
     await messaging.requestPermission(); // for token, no dialog on <33
     final token = await messaging.getToken();
     await registerToken(userId, installId);
     return PrimingOutcome.osGrant;
   }
   ```
5. **Web branch in `grantNotification`:**
   - Pre-check: `final preCheck = html.Notification.permission;` — if `'granted'` skip dialog, jump to token register; if `'denied'` return `osPermDeny` so UI shows recover banner.
   - Request: `final settings = await messaging.requestPermission()` (which internally calls `Notification.requestPermission()`).
   - On grant: `final token = await messaging.getToken(vapidKey: const String.fromEnvironment('FIREBASE_VAPID_KEY'))`.
6. **Web pre-check before sheet render** (`PermissionService.shouldShowNotificationPriming`):
   - If `kIsWeb && html.Notification.permission == 'granted'`: return false (skip sheet, but call token register).
   - If `kIsWeb && html.Notification.permission == 'denied'`: return false (show recover banner instead — handled in `_RootGate`).
   - If `kIsWeb && !PlatformCapability.supportsWebPush`: return false.
7. **Huawei branch in `main.dart`:**
   ```dart
   final fcmAvailable = await GmsDetector.isFcmAvailable();
   if (!fcmAvailable && Platform.isAndroid) {
     await eventSink.capture(PermissionEvent(
       outcome: PrimingOutcome.fcmUnavailableGmsMissing,
       kind: PermissionKind.notification, platform: 'android', ts: DateTime.now(),
     ));
     // Skip Firebase init entirely. PermissionService gets FcmService stub.
   } else {
     await Firebase.initializeApp(...);
   }
   ```
8. **`web/firebase-messaging-sw.js` finalize:** add `notificationclick` event handler that posts `client.postMessage({type: 'notification_tap', data: ...})` so Flutter Web app can route.
9. **Web Safari detect in `index.html`:** before SW registration, `if (navigator.userAgent.includes('Safari') && !navigator.userAgent.includes('Chrome')) { /* check version, skip if < 16.4 */ }`.

## Per-Platform Test Matrix

| Test | iOS 16 | iOS 17 | iOS 18 | And 12 | And 13 | And 14 | And 15 | Chrome | FF | Safari 16.4 | Safari <16.4 | Huawei |
|------|--------|--------|--------|--------|--------|--------|--------|--------|-----|------------|-------------|---------|
| App launches | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Priming sheet shown post-login | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ (hide) | ✗ (hide) |
| Provisional flow | ✓ | ✓ | ✓ | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| 24h APNs fallback fires | manual | manual | manual | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| Runtime POST_NOTIFICATIONS dialog | n/a | n/a | n/a | ✗ (auto) | ✓ | ✓ | ✓ | n/a | n/a | n/a | n/a | n/a |
| `Notification.permission` pre-check | n/a | n/a | n/a | n/a | n/a | n/a | n/a | ✓ | ✓ | ✓ | n/a | n/a |
| Service worker bg msg | n/a | n/a | n/a | n/a | n/a | n/a | n/a | ✓ | ✓ | ✓ | n/a | n/a |
| GMS detector returns false | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | ✓ |
| In-app polling still works | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | ✓ |
| iOS 18 dismiss = deferred | n/a | n/a | ✓ | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a |

## Todo List

- [ ] `platform_capability.dart` capability detection
- [ ] `gms_detector.dart` full impl with `google_api_availability`
- [ ] iOS provisional flow + 24h fallback timer
- [ ] Android SDK branch (auto-grant <33 vs request ≥33)
- [ ] Web pre-check + recover banner branch
- [ ] Web SW finalize (notificationclick + postMessage)
- [ ] Web Safari version detect in `index.html`
- [ ] Huawei branch in `main.dart`
- [ ] Manual test matrix run (all rows above)
- [ ] Update `docs/features/permission-priming.md` with per-platform notes

## Success Criteria

- All 12 columns × 11 rows in test matrix pass (or marked correctly as n/a).
- AC-N5: iOS provisional → upgrade detected on next foreground.
- AC-N5: 24h with no APNs delivery → soft re-ask shown (verified via debug time-skip).
- AC-N6: Web with already-granted permission → no sheet, just token register.
- AC-N6: Web with denied permission → recover banner shown.
- AC-N9: Huawei device launches, polling works, event logged.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `google_api_availability` package returns wrong status on Huawei | M | H | Test on real Huawei device pre-release; fallback: hardcode brand check |
| iOS 18 dismiss handling not actually fixed | M | M | Wrap status check in safe wrapper that maps notDetermined→deferred always |
| 24h fallback timer drift across timezones | L | L | Use UTC ISO8601 timestamps; compute delta in seconds |
| Web SW caches old VAPID key on Firebase rotation | L | M | Version SW file (`firebase-messaging-sw.js?v=2`) on VAPID rotation |
| Safari 16.4 PWA-only requirement confuses users | M | L | Don't promise web push on Safari unless PWA detected (`window.navigator.standalone`) |
| Android 15 cooldown blocks our test notifications | L | L | Document; QA waits 4h between manual tests |

## Security Considerations

- VAPID key passed via `--dart-define=FIREBASE_VAPID_KEY=...`; never logged.
- iOS APNs token: sent to BE only (`registerToken`); never logged in production.
- Web SW does NOT access cookies / localStorage / IndexedDB — pure message relay.
- GMS detection result is not user-visible (no "your phone unsupported" message — D9).

## Next Steps

- Phase 7 builds e2e tests per platform.
- Post-launch: review `fcm_unavailable_gms_missing` event counts in analytics to size Huawei impact (informs HMS Push decision).
