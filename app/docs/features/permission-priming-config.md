# Permission Priming — Ops Configuration Guide

> **Audience:** DevOps / Backend team  
> **Last updated:** 2026-06-28  
> **Feature plan:** `plans/260628-1700-permission-priming-onboarding/`

This document lists exactly what must be provided by Ops before the Permission Priming + Push Notification feature can be fully activated. Phase 1 setup is done; the code is wired but Firebase init is intentionally deferred until real credentials are present.

---

## 1. Firebase Project Setup

### 1.1 Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Add project**
3. Suggested project name: `ancu365-prod` (prod) / `ancu365-dev` (dev)
4. Enable Google Analytics → accept defaults

### 1.2 Register Apps

Register these 3 apps in the same project:

| Platform | Bundle ID / Package Name | App nickname |
|----------|--------------------------|--------------|
| **iOS** | `com.ancu365.app` (confirm with Xcode: Runner target → General → Bundle Identifier) | `ancu365 iOS` |
| **Android** | `com.housebooking.house_booking` (from `android/app/build.gradle.kts` → `applicationId`) | `ancu365 Android` |
| **Web** | — (enter any app name) | `ancu365 Web` |

---

## 2. Config Files Required

### 2.1 iOS — `GoogleService-Info.plist`

- Download from: Firebase Console → Project Settings → iOS app → Download `GoogleService-Info.plist`
- Place at: `ios/Runner/GoogleService-Info.plist`
- Then in Xcode: Runner target → right-click `Runner` group → "Add Files to Runner" → check "Copy items if needed"
- **Safe to commit** (keys are restricted to your bundle ID in Firebase)

### 2.2 Android — `google-services.json`

- Download from: Firebase Console → Project Settings → Android app → Download `google-services.json`
- Place at: `android/app/google-services.json`
- **Safe to commit** (keys are restricted to your package name in Firebase)

### 2.3 Web — VAPID Public Key

- Generate from: Firebase Console → Project Settings → **Cloud Messaging** tab → Web Push certificates → **Generate Key Pair**
- Copy the **Public Key** (long base64 string starting with `B...`)
- **DO NOT commit this key directly** — inject it at build time:

```bash
# Example build command with VAPID key
flutter build web --dart-define=FIREBASE_VAPID_KEY=<your-vapid-public-key>

# Example for local dev
flutter run -d chrome --dart-define=FIREBASE_VAPID_KEY=<your-vapid-public-key>
```

- The Dart code in Phase 4 (`lib/core/permissions/notification_service.dart`) reads it via:
  ```dart
  const vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');
  ```

---

## 3. Web Firebase Config Placeholders

After creating the Web app in Firebase Console, replace the placeholder values in **two files**:

### `web/index.html`

Find the `firebaseConfig` object and replace all `"__FIREBASE_*__"` values:

```javascript
const firebaseConfig = {
  apiKey: "AIza...",              // ← Firebase Console → Project Settings → Web app
  authDomain: "ancu365-prod.firebaseapp.com",
  projectId: "ancu365-prod",
  storageBucket: "ancu365-prod.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abc123",
};
```

### `web/firebase-messaging-sw.js`

Replace the same `firebaseConfig` object with identical values.

> Note: The guard `if (!firebaseConfig.apiKey.startsWith('__'))` prevents crashes with placeholder values. Once real values are inserted, the guard is automatically bypassed.

---

## 4. Enable Cloud Messaging API

1. Firebase Console → Project Settings → **Cloud Messaging** tab
2. Verify **Firebase Cloud Messaging API (V1)** is **Enabled**
3. The legacy API (v1 Server Key) is deprecated — use V1 HTTP API only

---

## 5. iOS APNs Setup (Required for iOS Push)

1. Apple Developer Console → Certificates, Identifiers & Profiles → Keys → Create new key
2. Enable **Apple Push Notifications service (APNs)**
3. Download the `.p8` key file (one-time download)
4. Firebase Console → Project Settings → Cloud Messaging → **Apple app configuration**
5. Upload the `.p8` key + note the Key ID + Team ID

Without this step, iOS push notifications will silently fail (no error in app).

---

## 6. Verification Checklist

After completing steps above:

- [ ] `ios/Runner/GoogleService-Info.plist` present (check `BUNDLE_ID` matches Xcode)
- [ ] `android/app/google-services.json` present (check `package_name` matches `build.gradle.kts`)
- [ ] `web/index.html` firebaseConfig has no `__PLACEHOLDER__` values
- [ ] `web/firebase-messaging-sw.js` firebaseConfig has no `__PLACEHOLDER__` values
- [ ] VAPID key generated and noted for CI/CD env var `FIREBASE_VAPID_KEY`
- [ ] APNs key uploaded to Firebase (iOS only)
- [ ] `flutter pub get && flutter build apk --debug` passes (Android)
- [ ] `flutter build ios --debug --no-codesign` passes (iOS)
- [ ] `flutter build web --dart-define=FIREBASE_VAPID_KEY=<key>` passes (Web)

---

## 7. Environment Variables for CI/CD

Add these to your CI/CD pipeline (GitHub Actions secrets / GitLab CI variables):

| Variable | Description | Required for |
|----------|-------------|--------------|
| `FIREBASE_VAPID_KEY` | Web Push VAPID public key | Web build only |

The `GoogleService-Info.plist` and `google-services.json` files should be committed to the repo (they are safe to commit per Firebase security model — access is restricted by bundle ID / package name). If your security policy requires otherwise, inject them as CI/CD secrets and write them to the expected paths before build.

---

## 8. Phase 4 Activation

Once all files above are in place, Phase 4 developer will:

1. Add `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` to `lib/main.dart`
2. Run `flutterfire configure` to auto-generate `lib/firebase_options.dart`
3. Wire up `NotificationService.initialize()` post-login

**DO NOT** add `Firebase.initializeApp()` before the config files are present — it crashes the app on launch.

---

## 9. Per-Platform Behavior (Phase 5 — Engineering Reference)

> Updated: Phase 5 implementation. Source of truth: `lib/core/permissions/platform_capability.dart`, `permission_service.dart`, `gms_detector_android.dart`.

### 9.1 Platform × Feature Matrix

| Platform | Permission Dialog | FCM Token | Background Push | Priming Sheet | Fallback if Denied |
|----------|------------------|-----------|-----------------|---------------|--------------------|
| **iOS 16–17** | `messaging.requestPermission(provisional: true)` | APNs via FCM | UNNotificationServiceExtension | Shown | Soft re-ask banner + Settings deep-link |
| **iOS 18** | Same as 16–17; `notDetermined` after dismiss → treated as `defer` (not deny) to avoid 30-day cooldown | Same | Same | Shown | Same |
| **Android < 13 (SDK < 33)** | Auto-granted (manifest only) | `messaging.getToken()` | FCM service in manifest | Shown | Settings deep-link (edge case) |
| **Android 13+ (SDK ≥ 33)** | `permission_handler.Permission.notification.request()` → OS POST_NOTIFICATIONS dialog | Same | Same | Shown | Settings deep-link |
| **Android 15** | Same as 13+; respect cooldown ≥ 4h (covered by existing 7-day defer cooldown) | Same | Same | Shown | Same |
| **Chrome / Edge / Firefox** | `Notification.requestPermission()` via `firebase_messaging_web` | `messaging.getToken(vapidKey)` | Service worker `onBackgroundMessage` | Shown | Banner: "Bật trong cài đặt trình duyệt" |
| **Safari ≥ 16.4 (PWA)** | Same as Chrome but requires PWA install (`window.navigator.standalone`) | Same | Same | Shown | Same |
| **Safari < 16.4** | NOT supported | NOT available | NOT available | **Hidden** (priming not shown) | Nothing shown |
| **Huawei / no-GMS Android** | NOT requested | NOT available | NOT available | **Hidden** (priming not shown) | Silent skip; in-app polling continues |

### 9.2 iOS APNs 24h Fallback Timer

- **When:** iOS provisional grant (`osProvisional`) — notifications delivered quietly to Notification Centre without user action.
- **Storage key:** `fcm_provisional_state:{userId}` in `flutter_secure_storage`.
- **Schema:** `{"grantedAt": "<ISO8601 UTC>", "delivered": false}`
- **Timer fires when:** `now - grantedAt > 24h` AND `delivered == false`.
- **Cleared when:** Any `RemoteMessage` received (foreground/background) calls `FcmService.markDelivered(userId)`.
- **UI integration:** `PermissionService.shouldShowApnsFallback(userId)` → Phase 7 e2e wires this to `SoftReaskBanner`.

### 9.3 Safari ≥ 16.4 PWA Requirement

Safari Web Push (macOS 13+, iOS/iPadOS 16.4+) requires the site to be installed as a **PWA** (added to Home Screen) before `Notification.requestPermission()` works. The UA detection in `PlatformCapability.supportsWebPush` and `web/index.html` gates on Version ≥ 16.4 but does **not** check `window.navigator.standalone` — showing priming on Safari PWA is the intended UX. Non-PWA Safari users see no priming (same as Safari < 16.4 result).

### 9.4 Huawei Silent Skip (D9)

When `GmsDetector.isFcmAvailable()` returns false on Android:
1. Firebase is NOT initialized (crash safety per R6).
2. `_NullFcmService` stub is used → all FCM calls are no-ops.
3. `fcmUnavailableGmsMissing` event is logged to the local event queue at app launch (pre-login, best-effort).
4. No user-visible error is shown — the notification priming UI is simply hidden.
5. In-app polling (chat, appointment status) still works via REST.

### 9.5 Android 13+ (SDK ≥ 33) Runtime Dialog

`permission_handler.Permission.notification.request()` drives the OS `POST_NOTIFICATIONS` dialog. If the user denies:
- `isPermanentlyDenied` → `osPermDeny` → 30-day cooldown, Settings deep-link on next encounter.
- `!isGranted && !isPermanentlyDenied` → `osDeny` → 7-day cooldown.

On grant, `FcmService.requestPermission()` is called without `provisional` flag to obtain the FCM token (no second dialog shown on Android).

### 9.6 Test Matrix (Manual — Phase 7 Automated)

| Test scenario | iOS 16 | iOS 17 | iOS 18 | And 12 | And 13+ | Chrome | Safari 16.4 | Safari <16.4 | Huawei |
|--------------|--------|--------|--------|--------|---------|--------|-------------|-------------|--------|
| App launches without crash | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Priming sheet shown post-login | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ |
| Provisional grant stored | ✓ | ✓ | ✓ | n/a | n/a | n/a | n/a | n/a | n/a |
| 24h APNs fallback fires | manual | manual | manual | n/a | n/a | n/a | n/a | n/a | n/a |
| SDK ≥ 33 dialog shown | n/a | n/a | n/a | ✗ | ✓ | n/a | n/a | n/a | n/a |
| Notification.permission pre-check | n/a | n/a | n/a | n/a | n/a | ✓ | ✓ | n/a | n/a |
| SW registered + bg message | n/a | n/a | n/a | n/a | n/a | ✓ | ✓ | ✗ (skipped) | n/a |
| GMS detector returns false | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | ✓ |
| `fcmUnavailableGmsMissing` event logged | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | ✓ |
| iOS 18 dismiss = defer (not deny) | n/a | n/a | ✓ | n/a | n/a | n/a | n/a | n/a | n/a |
