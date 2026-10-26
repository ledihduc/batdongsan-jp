# Phase 04 — Integration

**Status:** pending | **Effort:** 8h | **Depends on:** Phase 2 + Phase 3 | **Blocks:** Phase 5

## Context Links

- BA Section 8 (impact table — 6 image_picker sites)
- BA Section 10.1 AC-N2/N7/N8, AC-T1, AC-C1
- Existing: `lib/main.dart`, `lib/core/router/app_router.dart` (`_RootGate`), `lib/providers/auth_provider.dart`, `lib/providers/notification_provider.dart`

## Overview

Wire the module from Phase 2 + widgets from Phase 3 into the live app:
1. Bootstrap Firebase + GMS detection in `main.dart`.
2. Hook priming-on-login at `AuthProvider` success.
3. Wrap all 6 `image_picker` call sites with `withCameraPermission(...)`.
4. Extend `NotificationProvider` for push token + foreground handler + tap routing.
5. Add `/permission-debug` route (debug builds only).
6. Role-upgrade hooks (guest→host→admin).

## Key Insights

- **`_RootGate` already gates auth state** — easiest place to trigger first-login priming (post-build callback after `_RootGate` resolves to home).
- **`NotificationProvider` already exists** for in-app polling — extend it, do NOT replace; keep polling as Huawei fallback (AC-N9).
- **Image picker wrap pattern:** create one helper `Future<XFile?> withCameraPermission(BuildContext, ImageSource, CameraContext)` to keep DRY across all 6 sites.
- **Background message handler** must be top-level function (`@pragma('vm:entry-point')`) — required by `firebase_messaging`.
- **Role upgrade detection:** `AuthProvider.user.role` change triggers `PermissionService.shouldRetriggerOnRoleUpgrade`.

## Requirements

### Functional

- After first successful login per `(userId, installId)`: present notification priming sheet for current role.
- After role upgrade (e.g. guest→host): if previously granted, re-present sheet with new copy (AC-N8).
- All 6 `image_picker.pickImage(camera)` call sites: show camera priming sheet on first use per `CameraContext`.
- FCM token registered to BE on grant; unregistered on logout (AC-T1).
- Foreground push messages show in-app banner via existing notification UI.
- Notification tap deep-links to relevant screen (booking detail, chat, etc.) via `go_router`.
- Debug route `/permission-debug` exposes: reset all priming state, time-skip cooldown, view event queue, force-show each sheet variant.

### Non-functional

- Zero regression on existing image_picker flows (cancel = same behavior as today).
- Login flow does not block on FCM init (fire-and-forget; degrade gracefully).
- Background handler must not load entire app module (cold-start cost).

## Architecture

```
main.dart
  ↓
  Firebase.initializeApp() — guarded by GmsDetector.isFcmAvailable()
  ↓
  registerBackgroundMessageHandler(_fcmBackgroundHandler)
  ↓
  runApp(MyApp)

MyApp
  ├── Provider<PermissionService>  (DI root)
  ├── ChangeNotifierProvider<NotificationProvider> (extended)
  └── MaterialApp.router → app_router

app_router._RootGate
  ↓ on auth state -> Home
  ↓ post-frame callback
  ↓ if (await service.shouldShowNotificationPriming(userId, role))
  ↓   PrimingPresenter.presentNotification(context, role)

image_picker call site (×6)
  ↓ user taps "Tải ảnh"
  ↓ final file = await withCameraPermission(context, ImageSource.camera, CameraContext.cccdUpload)
  ↓ if file != null → existing upload logic
```

## Related Code Files

### Modify

- `lib/main.dart` — Firebase init guarded by GMS, register background handler, inject `PermissionService` via Provider.
- `lib/core/router/app_router.dart` — `_RootGate` post-login priming trigger; add `/permission-debug` route under `kDebugMode`.
- `lib/providers/auth_provider.dart` — on logout: `permissionService.onLogout(userId)`. On role change: trigger re-priming hook.
- `lib/providers/notification_provider.dart` — add: FCM token register/refresh listener, foreground message stream subscription, notification-tap router (uses `GoRouter.of(context).go(deepLink)`).
- `lib/features/host/onboarding/widgets/cccd_uploader.dart` — wrap `_pickImage` with `withCameraPermission(..., CameraContext.cccdUpload)`.
- `lib/features/host/property/screens/contract_form_screen.dart` — wrap both pickers (line 118, 143) → `CameraContext.contractPhoto`.
- `lib/features/host/property/screens/contract_terminate_screen.dart` — wrap picker (line 71) → `CameraContext.contractTerminatePhoto`.
- `lib/features/guest/post/post_house_screen.dart` — wrap `_picker` calls → `CameraContext.postHousePhoto`.
- `lib/features/guest/profile/edit_profile_screen.dart` — wrap `_picker` → `CameraContext.profileAvatar`.
- `lib/features/planning/report/report_error_screen.dart` — wrap `_picker` → `CameraContext.reportErrorPhoto`.

### Create

- `lib/core/permissions/with_camera_permission.dart` — single helper used at all 6 sites.
- `lib/core/permissions/fcm_background_handler.dart` — top-level `_fcmBackgroundHandler` function with `@pragma('vm:entry-point')`.
- `lib/features/permissions/debug/permission_debug_screen.dart` — debug menu (kDebugMode).
- `lib/features/permissions/helpers/notification_tap_router.dart` — parses RemoteMessage data → GoRoute path.

### Delete

- None.

## Helper Signature

### `with_camera_permission.dart`

```dart
/// One-liner used at all 6 image_picker call sites.
///
/// Flow:
/// 1. If PermissionService.shouldShowCameraPriming(...) -> present sheet.
///    If user taps Huỷ -> return null (caller does nothing).
///    If user taps Tiếp tục -> proceed to step 2.
/// 2. Call image_picker.pickImage(source: source). image_picker triggers OS dialog
///    on first call per process. (We do NOT call permission_handler.Permission.camera
///    explicitly — image_picker handles iOS PHPicker / Android intent path).
/// 3. If OS denies -> record osDeny; show settings dialog if permanent deny.
/// 4. Return XFile? to caller (existing upload code unchanged).
Future<XFile?> withCameraPermission(
  BuildContext context, {
  required ImageSource source,
  required CameraContext primingContext,
  required String userId,
});
```

**Critical:** This helper is the ONLY new API consumers learn — 6-site change is mechanical, low-risk.

### `fcm_background_handler.dart`

```dart
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  // MUST: initialize Firebase (it's a separate isolate)
  // SHOULD NOT: touch SharedPreferences/secure storage; spawn UI; long compute
  // Just log + (optionally) update badge via flutter_local_notifications
  await Firebase.initializeApp();
  // ... lightweight handling
}
```

## Implementation Steps

### Step 1 — `main.dart` bootstrap

1. In `main()`, wrap with `WidgetsFlutterBinding.ensureInitialized()`.
2. `if (await GmsDetector.isFcmAvailable()) { await Firebase.initializeApp(); FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler); }`
3. If false on Android: log analytics `fcmUnavailableGmsMissing` via `PermissionEventSink`; skip Firebase entirely.
4. Construct `PermissionService` (with FCM stub on Huawei) and inject via `Provider`.

### Step 2 — `_RootGate` priming trigger

1. After `_RootGate` resolves authenticated state, wrap home screen in `_NotificationPrimingGate(child: HomeScreen())`.
2. `_NotificationPrimingGate` uses `WidgetsBinding.instance.addPostFrameCallback` to call `service.shouldShowNotificationPriming(userId, role)`.
3. If true: `await PrimingPresenter.presentNotification(context, role)`; outcome auto-recorded via callbacks.
4. Implement once-per-session guard so post-app-resume doesn't re-trigger.

### Step 3 — Wrap 6 image_picker sites (mechanical)

For each file:
1. Add import `package:ancu365/core/permissions/with_camera_permission.dart`.
2. Replace `await _picker.pickImage(source: ImageSource.camera)` with `await withCameraPermission(context, source: ImageSource.camera, primingContext: CameraContext.X, userId: authProvider.userId)`.
3. Gallery source (`ImageSource.gallery`) also wrapped — gallery doesn't need camera perm but iOS still asks photo lib permission; same helper.
4. Keep existing null-check + upload code unchanged.

| File | Line(s) | CameraContext |
|------|---------|---------------|
| `cccd_uploader.dart` | 36 (picker init), call sites | `cccdUpload` |
| `contract_form_screen.dart` | 118, 143 | `contractPhoto` |
| `contract_terminate_screen.dart` | 71 | `contractTerminatePhoto` |
| `post_house_screen.dart` | 53 + call sites | `postHousePhoto` |
| `edit_profile_screen.dart` | 23 + call sites | `profileAvatar` |
| `report_error_screen.dart` | 39 + call sites | `reportErrorPhoto` |

### Step 4 — Extend `NotificationProvider`

1. Add field `StreamSubscription<RemoteMessage>? _fgSub;`.
2. In `init()`: if `fcmService != null`, subscribe to `fcmService.foregroundMessages` → push event to existing in-app notification list (so user sees instantly).
3. Subscribe to `fcmService.notificationTaps` → call `NotificationTapRouter.route(message, context)`.
4. On `_authProvider.user` change: register/unregister token via `fcmService.registerToken/unregisterToken`.
5. Listen to `FirebaseMessaging.instance.onTokenRefresh` → re-register.

### Step 5 — `NotificationTapRouter`

```dart
class NotificationTapRouter {
  static void route(RemoteMessage message, GoRouter router) {
    final type = message.data['type'] as String?;
    final id = message.data['id'] as String?;
    switch (type) {
      case 'booking': router.go('/host/bookings/$id'); break;
      case 'chat':    router.go('/chat/$id'); break;
      case 'house':   router.go('/houses/$id'); break;
      case 'admin_alert': router.go('/admin/dashboard'); break;
      default: router.go('/notifications');
    }
  }
}
```

### Step 6 — Role-upgrade hook (AC-N8)

1. In `AuthProvider`, detect `user.role` change (before/after).
2. If changed: call `await permissionService.shouldRetriggerOnRoleUpgrade(userId, newRole)`.
3. If true: `PrimingPresenter.presentNotification(context, newRole)`.
4. If false but state.osPermanentlyDenied: show `SoftReaskBanner` in `_RootGate` for current session.

### Step 7 — Debug route

1. In `app_router.dart`, under `if (kDebugMode)` add `GoRoute(path: '/permission-debug', builder: (_, __) => PermissionDebugScreen())`.
2. Debug screen exposes: list all priming state JSON, "Reset all", "Skip 7 days", "Skip 30 days", buttons to force-show each sheet variant.
3. AC-V4 satisfied.

### Step 8 — Build verification

1. `flutter analyze` clean.
2. `flutter run` on iOS sim + Android emu: login → priming sheet shows.
3. Tap "Tải ảnh CCCD" → camera sheet shows (first time only — second time goes direct).
4. Logout → check FCM token deleted from BE (curl admin endpoint or BE log).

## Todo List

- [ ] `main.dart` Firebase init + GMS guard + background handler register
- [ ] `_RootGate` post-login priming trigger
- [ ] `AuthProvider` logout hook + role-upgrade detector
- [ ] `NotificationProvider` FCM extension (foreground + tap + token refresh)
- [ ] `with_camera_permission.dart` helper
- [ ] Wrap cccd_uploader.dart
- [ ] Wrap contract_form_screen.dart (2 sites)
- [ ] Wrap contract_terminate_screen.dart
- [ ] Wrap post_house_screen.dart
- [ ] Wrap edit_profile_screen.dart
- [ ] Wrap report_error_screen.dart
- [ ] `NotificationTapRouter` + deep-link map
- [ ] `fcm_background_handler.dart`
- [ ] `permission_debug_screen.dart` (AC-V4)
- [ ] `/permission-debug` route registered (kDebugMode only)
- [ ] Smoke test all 3 platforms

## Success Criteria

- Login on fresh install → notification sheet appears once; deferred = no re-show for 7d (verify via debug skip).
- All 6 image_picker sites: first tap shows camera sheet; second tap skips it.
- Push notification tap on backgrounded app → correct deep-link.
- Logout → BE confirms device-token deleted (check via BE log or `GET /api/users/me/push-tokens` admin).
- Role upgrade guest→host: sees host notification sheet (verify in dev via auth mock).
- Huawei device (no GMS): app launches, no sheet shown, no crash.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Priming sheet shows during deep-link navigation | M | M | `_NotificationPrimingGate` only triggers on `home/` route, not deep paths |
| `withCameraPermission` regressions on web (image_picker uses file input) | M | M | Branch on `kIsWeb` inside helper — web skips priming sheet (browser owns flow); just call picker |
| Background handler init Firebase twice → exception | L | M | Use `Firebase.initializeApp` with try/catch ignoring `[core/duplicate-app]` |
| Role-upgrade detector fires on every `notifyListeners` (false positive) | M | M | Track previous-role in private field, compare on change only |
| Notification tap on cold start lost (RemoteMessage not delivered) | M | M | Use `FirebaseMessaging.instance.getInitialMessage()` in `main.dart`, queue route |
| Logout race: token deleted before background message in-flight | L | L | Acceptable — user is logged out, message discarded server-side after 24h |

## Security Considerations

- **JWT** required on `POST /api/users/me/push-token` — `AuthProvider.token` injected via interceptor (existing `dio` setup).
- **Deep-link IDs** validated server-side (notification payload `id` cannot be trusted client-side).
- **Background handler** does NOT decode JWT, does NOT touch secure storage — safe isolate boundary.
- **Debug screen** route guarded by `kDebugMode` AND `kReleaseMode == false`; impossible to reach in release build.
- `image_picker` already handles photo library permission — no double-prompt.

## Next Steps

- Phase 5 verifies platform-specific edge cases (iOS provisional, Android 13, Web SW, Huawei).
- Phase 6 wires `PermissionEventSink.drainPending` to BE batch upload on app foreground.
- Phase 7 e2e tests golden + deny paths.
