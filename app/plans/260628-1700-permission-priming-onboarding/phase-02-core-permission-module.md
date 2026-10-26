# Phase 02 — Core Permission Module

**Status:** pending | **Effort:** 6h | **Depends on:** Phase 1 | **Blocks:** Phase 4, 6

## Context Links

- BA Section 10.1 (AC-N7/N8/N9/T1), 10.2 (AC-N2 revised), 10.8 (M3 storage)
- BA Leader review C1, C2
- Researcher: `reports/researcher-flutter-permissions.md` Task 5, 6
- Existing pattern: `lib/features/onboarding/onboarding_screen.dart` (`_storage.read('onboarding_done')`)

## Overview

Build `lib/core/permissions/` — pure-logic module with **no UI imports**. Manages cooldown state, OS permission calls, FCM lifecycle, GMS detection, and analytics event capture. Phase 3 (widgets) and Phase 4 (integration) consume this module.

## Key Insights

- **Storage key per user** (AC-N7): `priming_v1:{userId}` namespacing prevents cross-account leakage on shared device.
- **Logout does NOT clear other users' keys** — only deletes current user's key + device token.
- **GMS check must run BEFORE `Firebase.initializeApp()`** — calling Firebase init on non-GMS Android crashes (R6).
- **iOS 18 `notDetermined` bug** (researcher Task 2 issue #1): treat as `deferred`, not `denied`.
- **`flutter_secure_storage` only** (M3) — no SharedPreferences mixing.

## Requirements

### Functional

- Provide `PermissionService` with single entry per operation: `requestNotification(role)`, `requestCamera(context)`, `unregisterDevice()`.
- Persist cooldown state per `(userId, installId)` pair.
- Capture event log to local queue (Phase 6 flushes to BE).
- Re-trigger logic on role upgrade (AC-N8).
- GMS detection gates all FCM calls (AC-N9).

### Non-functional

- Pure Dart logic — no `BuildContext` parameter at this layer.
- Async-safe (no race on concurrent priming requests — use a mutex per userId).
- Testable: storage and FCM are injected, not direct singletons.

## Architecture

```
lib/core/permissions/
├── permission_types.dart       (enums + data classes)
├── permission_storage.dart     (cooldown read/write — secure storage wrapper)
├── permission_events.dart      (local event queue + analytics dispatch interface)
├── permission_service.dart     (orchestrator — main public API)
├── fcm_service.dart            (FCM init + token register/refresh)
├── gms_detector.dart           (Android GMS availability check)
└── permission_install_id.dart  (one-time install UUID generation)

External dep injection points:
  • FlutterSecureStorage  (testable)
  • FirebaseMessaging     (testable via wrapper)
  • permission_handler   (testable via wrapper)
  • GoogleApiAvailability (Android-only, no-op elsewhere)
```

## Related Code Files

### Create (all NEW)

- `lib/core/permissions/permission_types.dart`
- `lib/core/permissions/permission_storage.dart`
- `lib/core/permissions/permission_events.dart`
- `lib/core/permissions/permission_service.dart`
- `lib/core/permissions/fcm_service.dart`
- `lib/core/permissions/gms_detector.dart`
- `lib/core/permissions/permission_install_id.dart`

### Modify

- None in this phase (consumers wired in Phase 4).

### Delete

- None.

## Class Signatures (signatures only — Phase 4 developer writes bodies)

### `permission_types.dart`

```dart
enum UserRole { guest, host, admin }

enum CameraContext {
  cccdUpload,
  postHousePhoto,
  contractPhoto,
  contractTerminatePhoto,
  profileAvatar,
  reportErrorPhoto,
}

enum PrimingOutcome {
  shown,      // sheet displayed
  accept,     // user tapped primary -> OS dialog triggered
  defer,      // user tapped "Để sau"
  osGrant,    // OS returned granted
  osDeny,     // OS returned denied (recoverable)
  osPermDeny, // OS returned permanently denied (iOS / Android "Don't ask again")
  osProvisional, // iOS provisional granted
  osProvisionalUpgrade, // iOS user upgraded provisional -> full
  settingsOpened,
  fcmUnavailableGmsMissing, // AC-N9
}

enum PermissionKind { notification, camera }

class PrimingState {
  final DateTime? lastShownAt;
  final DateTime? lastDeferAt;
  final DateTime? lastDenyAt;
  final UserRole? lastShownForRole;  // for AC-N8 role-upgrade detection
  final bool osGranted;
  final bool osPermanentlyDenied;
  // serialization to/from JSON for secure storage
}

class PermissionEvent {
  final PrimingOutcome outcome;
  final PermissionKind kind;
  final UserRole? role;
  final String? context; // CameraContext.name for camera events
  final String platform; // 'ios' | 'android' | 'web'
  final DateTime ts;
  // Map<String,dynamic> toJson() — see Phase 6 schema
}
```

### `permission_install_id.dart`

```dart
class PermissionInstallId {
  PermissionInstallId(this._storage);
  final FlutterSecureStorage _storage;
  static const _key = 'priming_install_id_v1';

  // Lazy generate UUID v4 on first read, persist forever (until reinstall).
  Future<String> get(); // returns the install UUID
}
```

### `permission_storage.dart`

```dart
class PermissionStorage {
  PermissionStorage(this._storage);
  final FlutterSecureStorage _storage;

  // Key schema: priming_v1:{userId}:{kind} -> JSON of PrimingState
  // Example: priming_v1:42:notification, priming_v1:42:camera:cccdUpload
  String _key(String userId, PermissionKind kind, [String? subContext]);

  Future<PrimingState> read(String userId, PermissionKind kind, {String? subContext});
  Future<void> write(String userId, PermissionKind kind, PrimingState state, {String? subContext});
  Future<void> clearUser(String userId); // logout helper — only clears this user
  Future<void> resetAll(); // debug menu only (kDebugMode)
  Future<void> skipDays(int days); // AC-V4: dev time-travel for cooldown testing
}
```

### `permission_events.dart`

```dart
abstract class PermissionEventSink {
  Future<void> capture(PermissionEvent event);
  Future<List<PermissionEvent>> drainPending(); // for Phase 6 batch upload
  Future<void> clear(List<PermissionEvent> uploaded);
}

class LocalPermissionEventSink implements PermissionEventSink {
  LocalPermissionEventSink(this._storage);
  final FlutterSecureStorage _storage;
  static const _key = 'priming_event_queue_v1';
  // Append-only JSON array in secure storage. Cap at 200 events; drop oldest if exceeded.
  // Rationale: SQLite overkill per BA M3; secure-storage queue is offline-safe and < 50KB typical.
}
```

### `gms_detector.dart`

```dart
class GmsDetector {
  // Returns false on iOS/Web (no-op true equivalent — Firebase works).
  // Returns true on Android with GMS available (GoogleApiAvailability.SUCCESS == 0).
  // Returns false on Android without GMS (Huawei). AC-N9.
  static Future<bool> isFcmAvailable();
}
```

### `fcm_service.dart`

```dart
class FcmService {
  FcmService({
    required FirebaseMessaging messaging,
    required PermissionEventSink events,
    required String? webVapidKey,
  });

  /// Initialize FCM, register handlers, get token. Caller must ensure
  /// [GmsDetector.isFcmAvailable] returned true before calling.
  Future<void> init();

  /// Register current token with backend. Idempotent.
  /// Returns the token string for caller to use.
  Future<String?> registerToken(String userId, String installId);

  /// Unregister on logout. Calls DELETE on BE.
  Future<void> unregisterToken(String userId, String installId);

  /// Stream of incoming foreground messages (Phase 4 consumes for in-app banner).
  Stream<RemoteMessage> get foregroundMessages;

  /// Stream of notification taps (Phase 4 routes via go_router).
  Stream<RemoteMessage> get notificationTaps;

  /// iOS-only: poll provisional -> full upgrade. Call on app foreground.
  Future<bool> checkProvisionalUpgrade();
}
```

### `permission_service.dart` (main API)

```dart
class PermissionService {
  PermissionService({
    required PermissionStorage storage,
    required PermissionEventSink events,
    required FcmService fcm,
    required PermissionInstallId installId,
  });

  // ─── Notification (called from main.dart post-login, AC-N2) ───

  /// Returns true if priming should be shown for [userId] + [role].
  /// Applies cooldown logic (AC-N3) and role-upgrade rules (AC-N8).
  Future<bool> shouldShowNotificationPriming(String userId, UserRole role);

  /// Called when user taps "Bật thông báo" on priming sheet.
  /// Handles iOS provisional vs Android runtime vs Web Notification API.
  Future<PrimingOutcome> grantNotification({
    required String userId,
    required UserRole role,
    required bool useProvisionalIos, // false = full, true = provisional+full upgrade flow
  });

  /// Called when user taps "Để sau" — records defer, starts 7-day cooldown.
  Future<void> deferNotification(String userId, UserRole role);

  /// Called from soft re-ask banner (AC-N4) — opens app settings.
  Future<void> openSettingsForNotification(String userId);

  // ─── Camera (called from withCameraPermission helper, AC-C1) ───

  Future<bool> shouldShowCameraPriming(String userId, CameraContext context);

  Future<PrimingOutcome> grantCamera({
    required String userId,
    required CameraContext context,
  });

  Future<void> deferCamera(String userId, CameraContext context);

  // ─── Lifecycle hooks (Phase 4 wires these) ───

  /// On logout: unregister FCM device token from BE. Do NOT clear other-user storage.
  Future<void> onLogout(String userId);

  /// On role upgrade (guest -> host -> admin): per AC-N8, re-trigger priming once
  /// with new role copy if user previously accepted.
  Future<bool> shouldRetriggerOnRoleUpgrade(String userId, UserRole newRole);

  /// On app foreground: check iOS provisional upgrade, flush event queue (Phase 6).
  Future<void> onAppForeground(String userId);
}
```

## Implementation Steps

1. Create all 7 files with class skeletons matching signatures above (NO bodies yet — leave `throw UnimplementedError()`).
2. Implement `permission_install_id.dart` first (smallest unit, others depend on it).
3. Implement `permission_storage.dart` with PrimingState JSON serializer.
4. Implement `permission_events.dart` `LocalPermissionEventSink` (FIFO queue cap 200).
5. Implement `gms_detector.dart` using `google_api_availability` package; conditional import for non-Android.
6. Implement `fcm_service.dart` — wrap `firebase_messaging` API; expose streams.
7. Implement `permission_service.dart` — wire all dependencies; encode cooldown logic:
   - `shouldShowNotificationPriming`: skip if `osGranted && lastShownForRole == role`; skip if `lastDeferAt < 7d ago`; skip if `lastDenyAt < 30d ago && !roleChanged`.
   - `shouldRetriggerOnRoleUpgrade`: return true if state.lastShownForRole != newRole && state.osGranted.
8. Write unit tests (Phase 7 covers, but stub here): `permission_service_test.dart` with mock storage + FCM.
9. Run `flutter analyze` — zero warnings. Run `dart compile` smoke test on each file.

## Todo List

- [ ] Create 7 files with signatures
- [ ] Implement `PermissionInstallId` + test
- [ ] Implement `PermissionStorage` with PrimingState serialization
- [ ] Implement `LocalPermissionEventSink` (queue cap 200)
- [ ] Implement `GmsDetector` with conditional imports
- [ ] Implement `FcmService` (init, token register/unregister, streams)
- [ ] Implement `PermissionService` orchestrator + cooldown logic
- [ ] `flutter analyze` clean
- [ ] Module unit tests stubbed (full tests in Phase 7)

## Success Criteria

- Module compiles standalone (no UI deps).
- All 11 notif ACs + 3 camera ACs + AC-T1 + AC-N9 are expressible via this API surface.
- `PermissionService` API is the SINGLE entry point — widgets never call `firebase_messaging` directly.
- Public methods have explicit return types; no `dynamic` leaks.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Concurrent priming requests race storage | M | M | Use `synchronized` package per-userId mutex on write |
| `flutter_secure_storage` size limit (4KB iOS keychain item) | L | M | Cap event queue at 200; PrimingState JSON ~200 bytes per key — well under |
| FCM token refresh fires before login | M | M | Cache token in service; defer BE register until userId known |
| iOS 18 notDetermined misreported | M | M | Treat as deferred in service, not denied (researcher Task 2) |
| GmsDetector hangs on Android emulator without GMS | L | L | 2-sec timeout on isFcmAvailable, default false |

## Security Considerations

- Storage key includes userId — verify userId is a sanitized opaque ID (not email/PII).
- Event queue payloads contain ONLY: outcome, kind, role, context, platform, ts. **No PII** (per AC-M3 revised).
- On `clearUser`: deletes ONLY current-user's keys, never iterates all keys (avoid log leak).
- FCM token treated as semi-sensitive — never logged via `print` or `debugPrint` in production; use `assert(() { ... return true; }())` guards.
- `resetAll` and `skipDays` MUST be guarded by `assert(kDebugMode)` at call site (Phase 4).

## Next Steps

- Phase 3 (widgets) can start in parallel — uses signatures only.
- Phase 4 wires `PermissionService` into login, image_picker sites, router.
- Phase 6 wires `PermissionEventSink.drainPending` to BE batch upload.
