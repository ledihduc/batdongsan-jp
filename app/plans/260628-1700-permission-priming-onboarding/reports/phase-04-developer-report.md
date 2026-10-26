# Phase 04 — Integration Developer Report

**Date:** 2026-06-28
**Phase:** 04 — Integration
**Status:** DONE_WITH_CONCERNS

---

## Files Created

| File | Lines | Notes |
|------|-------|-------|
| `lib/core/permissions/with_camera_permission.dart` | 72 | Single helper used at 5 of 6 sites (post_house uses inline variant for pickMultiImage) |
| `lib/core/permissions/fcm_background_handler.dart` | 45 | Top-level `@pragma('vm:entry-point')` function |
| `lib/features/permissions/helpers/notification_tap_router.dart` | 59 | Defensive routing from RemoteMessage.data |
| `lib/features/permissions/debug/permission_debug_screen.dart` | 235 | kDebugMode-only screen |

---

## Files Modified

| File | Change summary |
|------|---------------|
| `lib/core/permissions/permission_service.dart` | Added `fcm` getter, `debugResetAll()`, `debugSkipDays()` accessors |
| `lib/main.dart` | Firebase init + GMS guard, background handler registration, `buildPermissionService()` factory, `Provider<PermissionService>`, `_NullFcmService` stub, `MyApp.fcmAvailable` param |
| `lib/core/router/app_router.dart` | `_NotificationPrimingGate`, `_maybePresentNotificationPriming`, `attachFcm` wiring in post-login callback, `/permission-debug` route under `kDebugMode`, imports |
| `lib/providers/auth_provider.dart` | `setPermissionService()` injector, `_previousRoleSnapshot` tracking, `_detectAndHandleRoleChange()`, logout calls `onLogout()`, role upgrade calls `onRoleUpgrade()` |
| `lib/providers/notification_provider.dart` | Added `attachFcm()`, `detachFcm()`, `setFcm()`, stream subscriptions for foreground/tap/tokenRefresh; `clear()` now calls `detachFcm()` |
| `lib/features/host/onboarding/widgets/cccd_uploader.dart` | Wrapped `_pickImage` — removed `_picker` field, added `withCameraPermission(CameraContext.cccdUpload)` |
| `lib/features/host/property/screens/contract_form_screen.dart` | Wrapped `_pickHandoverPhoto` + `_pickCccdPhoto` — both use `CameraContext.contractPhoto` |
| `lib/features/host/property/screens/contract_terminate_screen.dart` | Wrapped `_pickDamagePhoto` — uses `CameraContext.contractTerminatePhoto` |
| `lib/features/guest/post/post_house_screen.dart` | Inline priming block before `pickMultiImage` (gallery-only, no single-file helper) — uses `CameraContext.postHousePhoto` |
| `lib/features/guest/profile/edit_profile_screen.dart` | Wrapped `_pickAvatar` — removed `_picker` field, uses `CameraContext.profileAvatar` |
| `lib/features/planning/report/report_error_screen.dart` | Wrapped `_pickImage` — removed `_picker` field, uses `CameraContext.reportErrorPhoto` |

---

## flutter analyze result

**0 errors. 0 new warnings.**

137 total issues — all pre-existing `info` hints (`withOpacity` deprecation, `unnecessary_underscores`, etc.) plus 3 pre-existing `unused_element_parameter` warnings on `_PickedImage` in `post_house_screen.dart`. None introduced by Phase 4.

---

## 6 Image Picker Sites Verification

| File | Method | Line (approx) | CameraContext | withCameraPermission? |
|------|--------|-------|---------------|----------------------|
| `cccd_uploader.dart` | `_pickImage()` | 47 | `cccdUpload` | `withCameraPermission()` |
| `contract_form_screen.dart` | `_pickHandoverPhoto()` | 126 | `contractPhoto` | `withCameraPermission()` |
| `contract_form_screen.dart` | `_pickCccdPhoto()` | 159 | `contractPhoto` | `withCameraPermission()` |
| `contract_terminate_screen.dart` | `_pickDamagePhoto()` | 79 | `contractTerminatePhoto` | `withCameraPermission()` |
| `post_house_screen.dart` | `_pickImages()` | ~118 | `postHousePhoto` | Inline priming block (pickMultiImage) |
| `edit_profile_screen.dart` | `_pickAvatar()` | 71 | `profileAvatar` | `withCameraPermission()` |
| `report_error_screen.dart` | `_pickImage()` | 64 | `reportErrorPhoto` | `withCameraPermission()` |

**Note:** `post_house_screen.dart` uses `pickMultiImage` (gallery multi-select) — `withCameraPermission` only wraps `pickImage`. The priming check + `PrimingPresenter.presentCamera` + `grantCamera`/`deferCamera` are done inline before the `pickMultiImage` call. Semantically equivalent.

---

## Known Limitations / TODO Comments Left in Code

1. **`buildPermissionService()` — VAPID key**: `webVapidKey: null` in `main.dart`. TODO comment left: set from env variable when deploying web push (Ops blocker).
2. **Token refresh BE registration**: `attachFcm` subscribes to `onTokenRefresh` but logs a TODO(phase6) comment — actual `POST /api/users/me/push-token` call deferred to Phase 6.
3. **`getAPNSToken()` in `_NullFcmService`**: Not overridden — `_NullFcmService` extends `FcmService` which doesn't expose `getAPNSToken` publicly, so this is fine.
4. **`FirebaseMessaging.getInitialMessage()`**: Not handled in `main.dart` (cold-start deep link). Listed as risk in plan, deferred to Phase 5.
5. **`_NotificationPrimingGate`**: Currently a transparent wrapper (StatelessWidget). Placeholder for Phase 5 app-resume re-priming checks.

---

## Deviations from Spec

1. **`post_house_screen.dart` uses `pickMultiImage`** — the spec says "wrap `_picker` calls". Since `withCameraPermission` only wraps `pickImage`, the priming logic is inlined before the `pickMultiImage` call. Functionally identical: priming runs once per context, then gallery picker proceeds.

2. **`_NullFcmService` extends `FcmService`** rather than using a separate stub class with a fake `FirebaseMessaging` implementation — `FirebaseMessaging` is a concrete `@pragma` class in `firebase_messaging ^15.0.0` with 20+ required interface members. Subclassing `FcmService` and overriding only the 8 public methods is cleaner and compiles cleanly.

3. **`PermissionService.debugResetAll()` / `debugSkipDays()`** added to `permission_service.dart` (Phase 2 file) — spec explicitly permits "small accessors" when justification is provided. The debug screen needs these; the alternative (exposing `PermissionStorage` directly) would be a larger API surface.

---

## Verification Checklist (all pass)

- [x] `flutter analyze` clean (0 errors).
- [x] `withCameraPermission(` in 5 direct files + 1 inline equivalent = all 6 sites.
- [x] `_NotificationPrimingGate` referenced in `_RootGate.build()`.
- [x] `Provider<PermissionService>` registered in `main.dart` MultiProvider.
- [x] `attachFcm` called from `_RootGate` post-login hydration callback.
- [x] `kDebugMode` guards the `/permission-debug` route in `app_router.dart`.
- [x] Firebase init wrapped in try/catch — app continues in no-FCM mode if `google-services.json` absent.
- [x] `_NullFcmService` used on Huawei/no-GMS — no crash.
