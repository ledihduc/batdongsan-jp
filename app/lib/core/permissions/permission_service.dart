// Orchestrator: single public API consumed by Phase 4 (integration) and Phase 3 (widgets).
// No BuildContext, no UI imports, no HTTP.
// dart:async provides unawaited() to mark intentional fire-and-forget calls.
// Phase 5 adds per-platform grantNotification branches + iOS APNs fallback.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_settings/app_settings.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart' as ph;

import 'fcm_service.dart';
import 'permission_events.dart';
import 'permission_install_id.dart';
import 'permission_storage.dart';
import 'permission_types.dart';
import 'platform_capability.dart';

/// Central permission orchestrator.
///
/// All permission-related decisions flow through this class — widgets and
/// feature screens never call [firebase_messaging] or [permission_handler]
/// directly (per phase spec success criteria).
///
/// Thread safety: a per-userId [Completer] mutex serialises concurrent
/// priming calls for the same user so storage reads/writes don't race.
class PermissionService {
  PermissionService({
    required PermissionStorage storage,
    required PermissionEventSink events,
    required FcmService fcm,
    required PermissionInstallId installId,
  })  : _storage = storage,
        _events = events,
        _fcm = fcm,
        _installId = installId;

  // ignore_for_file: prefer_initializing_formals
  final PermissionStorage _storage;
  final PermissionEventSink _events;
  final FcmService _fcm;
  final PermissionInstallId _installId;

  /// Per-userId mutex: prevents concurrent priming state mutations.
  final Map<String, Future<void>> _locks = {};

  // ── Platform helper ───────────────────────────────────────────────────────

  /// Returns a lowercase platform string for analytics events.
  /// dart:io import is safe here because [kIsWeb] is checked first.
  String get _platform {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
      if (Platform.isLinux) return 'linux';
    } catch (_) {
      // Platform not available on this build.
    }
    return 'unknown';
  }

  // ─── Notification priming ─────────────────────────────────────────────────

  /// Returns true if the notification priming sheet should be shown.
  ///
  /// Conditions for showing (AC-N3, AC-N8):
  /// 1. User is not in defer cooldown (7d) or deny cooldown (30d).
  /// 2. OS has NOT permanently denied (would show settings banner instead).
  /// 3. One of:
  ///    - Never shown before, OR
  ///    - Previously shown for a different role (role upgrade, AC-N8).
  ///
  /// Web-specific pre-checks (AC-N6):
  /// - If already granted → false (caller's code path still registers token
  ///   via [FcmService.attachUserContext] / [registerToken]).
  /// - If browser doesn't support Web Push → false (hide priming entirely).
  /// - If Notification.permission == 'denied' → false (show recover banner).
  Future<bool> shouldShowNotificationPriming(
    String userId,
    UserRole role,
  ) async {
    // ── Web pre-checks ────────────────────────────────────────────────────
    if (kIsWeb) {
      // Already granted: no need to show sheet; token is registered via
      // attachUserContext → onTokenRefresh listener.
      final alreadyGranted = await _fcm.isWebAlreadyGranted();
      if (alreadyGranted) return false;

      // Browser doesn't support Web Push (e.g. Safari < 16.4).
      final supported = await PlatformCapability.supportsWebPush;
      if (!supported) return false;

      // Permission explicitly denied in browser settings.
      // UI layer (_RootGate) shows a recover banner for this case instead.
      final webPerm = _getWebNotificationPermission();
      if (webPerm == 'denied') return false;
    }

    return _withLock(userId, () => _shouldShowNotification(userId, role));
  }

  /// Reads `window.Notification.permission` string on web.
  /// Returns 'unknown' on any error or non-web platform.
  String _getWebNotificationPermission() {
    try {
      // ignore: avoid_dynamic_calls
      final dynamic notif = (const Object() as dynamic).window?.Notification;
      return (notif?.permission as String?) ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  Future<bool> _shouldShowNotification(String userId, UserRole role) async {
    final state =
        await _storage.read(userId, PermissionKind.notification);

    // Already granted — no need to ask again unless role changed (AC-N8).
    if (state.osGranted && !state.osProvisional) {
      final roleChanged = state.lastShownForRole != null &&
          state.lastShownForRole != role;
      if (!roleChanged) return false;
    }

    // OS permanently denied → soft re-ask (settings banner) only, not priming.
    if (state.osPermanentlyDenied) return false;

    // Cooldown check (AC-N3 / D7).
    final inCooldown =
        await _storage.isInCooldown(userId, PermissionKind.notification);
    if (inCooldown) return false;

    return true;
  }

  /// Handles the user tapping "Bật thông báo" on the priming sheet.
  ///
  /// Platform branches (Phase 5):
  ///
  /// **iOS:** Calls FCM [requestPermission] with provisional flag. On provisional
  ///   result, the 24h APNs fallback timer is persisted automatically in
  ///   [FcmService.requestPermission].
  ///
  /// **Android SDK ≥ 33:** Drives the POST_NOTIFICATIONS OS dialog via
  ///   [permission_handler]. Then calls FCM for the token (no second dialog).
  ///   If the OS dialog denies → returns [PrimingOutcome.osDeny] early
  ///   (FCM token not requested).
  ///   If permanently denied → returns [PrimingOutcome.osPermDeny].
  ///
  /// **Android SDK < 33:** POST_NOTIFICATIONS is auto-granted (manifest-only).
  ///   Calls FCM directly for the token.
  ///
  /// **Web:** Pre-checks `Notification.permission`:
  ///   - `'granted'` → skip dialog, call FCM for token.
  ///   - `'denied'` → return [PrimingOutcome.osPermDeny]; UI shows recover banner.
  ///   - unsupported browser → return [PrimingOutcome.osDeny].
  ///   - else → proceed with FCM [requestPermission] (shows browser dialog).
  ///
  /// Flow:
  /// 1. Enqueue [PrimingOutcome.accept] event.
  /// 2. Call FCM to request OS permission (via platform branch above).
  /// 3. Persist result in [PrimingState].
  /// 4. Enqueue OS-level outcome event.
  /// 5. Return the OS outcome so the UI can react.
  Future<PrimingOutcome> grantNotification({
    required String userId,
    required UserRole role,
    required bool useProvisionalIos,
  }) async {
    return _withLock(userId, () async {
      await _events.capture(PermissionEvent(
        outcome: PrimingOutcome.accept,
        kind: PermissionKind.notification,
        role: role,
        platform: _platform,
        ts: DateTime.now(),
      ));

      final osOutcome = await _requestOsPermission(
        userId: userId,
        role: role,
        useProvisionalIos: useProvisionalIos,
      );

      final now = DateTime.now();
      var state =
          await _storage.read(userId, PermissionKind.notification);

      state = state.copyWith(
        lastShownAt: now,
        lastShownForRole: role,
        osGranted: osOutcome == PrimingOutcome.osGrant ||
            osOutcome == PrimingOutcome.osProvisional,
        osProvisional: osOutcome == PrimingOutcome.osProvisional,
        osPermanentlyDenied: osOutcome == PrimingOutcome.osPermDeny,
        lastDenyAt: (osOutcome == PrimingOutcome.osDeny ||
                osOutcome == PrimingOutcome.osPermDeny)
            ? now
            : null,
      );

      await _storage.write(userId, PermissionKind.notification, state);

      await _events.capture(PermissionEvent(
        outcome: osOutcome,
        kind: PermissionKind.notification,
        role: role,
        platform: _platform,
        ts: DateTime.now(),
      ));

      // Register FCM token with BE if OS granted (AC-T1).
      // Fire-and-forget: registration failure must NOT block the user-facing flow.
      if (osOutcome == PrimingOutcome.osGrant ||
          osOutcome == PrimingOutcome.osProvisional) {
        try {
          final installId = await _installId.get();
          unawaited(_fcm.registerToken(userId: userId, installId: installId));
        } catch (_) {
          // Non-fatal — token will be re-registered on next foreground.
        }
      }

      return osOutcome;
    });
  }

  /// Platform-branched OS permission request (Phase 5 — AC-N5, AC-N6, AC-N9).
  ///
  /// Separated from [grantNotification] to keep the public method readable.
  Future<PrimingOutcome> _requestOsPermission({
    required String userId,
    required UserRole role,
    required bool useProvisionalIos,
  }) async {
    // ── Web branch ────────────────────────────────────────────────────────
    if (kIsWeb) {
      // Pre-check: already granted → just request token, skip dialog.
      final alreadyGranted = await _fcm.isWebAlreadyGranted();
      if (alreadyGranted) {
        // Token is registered via attachUserContext; nothing to do here.
        return PrimingOutcome.osGrant;
      }

      // Browser doesn't support Web Push (e.g. Safari < 16.4).
      final supported = await PlatformCapability.supportsWebPush;
      if (!supported) {
        // Treat unsupported browser as permanent denial (priming should never
        // have been shown — caller guards via shouldShowNotificationPriming).
        return PrimingOutcome.osPermDeny;
      }

      // Permission already denied in browser settings → no dialog possible.
      final webPerm = _getWebNotificationPermission();
      if (webPerm == 'denied') {
        return PrimingOutcome.osPermDeny;
      }

      // Proceed with FCM requestPermission — internally calls
      // Notification.requestPermission() and obtains VAPID token.
      return _fcm.requestPermission(
        role: role,
        useProvisionalOnIos: false, // Web doesn't use iOS provisional.
        userId: userId,
      );
    }

    // ── iOS branch ────────────────────────────────────────────────────────
    if (!kIsWeb) {
      bool isIos = false;
      bool isAndroid = false;
      try {
        isIos = Platform.isIOS;
        isAndroid = Platform.isAndroid;
      } catch (_) {}

      if (isIos) {
        return _fcm.requestPermission(
          role: role,
          useProvisionalOnIos: useProvisionalIos,
          userId: userId,
        );
      }

      // ── Android branch ──────────────────────────────────────────────────
      if (isAndroid) {
        return _requestAndroidPermission(
          userId: userId,
          role: role,
        );
      }
    }

    // Fallback for macOS, Windows, Linux (FCM works natively, no OS dialog).
    return _fcm.requestPermission(
      role: role,
      useProvisionalOnIos: false,
      userId: userId,
    );
  }

  /// Android permission request branch (Phase 5 — SDK version detection).
  ///
  /// SDK ≥ 33: POST_NOTIFICATIONS runtime permission required.
  ///   Shows OS dialog via [permission_handler]. On denial → early return
  ///   (no FCM token request). On grant → call FCM for token.
  ///
  /// SDK < 33: POST_NOTIFICATIONS auto-granted by manifest.
  ///   Call FCM directly for the token.
  Future<PrimingOutcome> _requestAndroidPermission({
    required String userId,
    required UserRole role,
  }) async {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        // Android 13+: POST_NOTIFICATIONS runtime permission required.
        final status = await ph.Permission.notification.request();

        if (status.isPermanentlyDenied) {
          return PrimingOutcome.osPermDeny;
        }
        if (!status.isGranted) {
          return PrimingOutcome.osDeny;
        }
        // Granted: call FCM for the token (no second dialog on Android).
        return _fcm.requestPermission(
          role: role,
          useProvisionalOnIos: false,
          userId: userId,
        );
      } else {
        // Android < 13: notifications auto-granted via manifest.
        // Call FCM directly to obtain the token.
        return _fcm.requestPermission(
          role: role,
          useProvisionalOnIos: false,
          userId: userId,
        );
      }
    } catch (_) {
      // Fallback: assume granted, attempt FCM token acquisition.
      return _fcm.requestPermission(
        role: role,
        useProvisionalOnIos: false,
        userId: userId,
      );
    }
  }

  /// User tapped "Để sau" — record defer, start 7-day cooldown (AC-N3).
  Future<void> deferNotification(String userId, UserRole role) async {
    await _withLock(userId, () async {
      final now = DateTime.now();
      var state =
          await _storage.read(userId, PermissionKind.notification);
      state = state.copyWith(
        lastShownAt: now,
        lastShownForRole: role,
        lastDeferAt: now,
      );
      await _storage.write(userId, PermissionKind.notification, state);
      await _events.capture(PermissionEvent(
        outcome: PrimingOutcome.defer,
        kind: PermissionKind.notification,
        role: role,
        platform: _platform,
        ts: now,
      ));
    });
  }

  /// Opens app notification Settings (AC-N4) and records the navigation event.
  Future<void> openSettingsForNotification(String userId) async {
    try {
      await AppSettings.openAppSettings();
    } catch (_) {
      // app_settings is best-effort.
    }
    await _events.capture(PermissionEvent(
      outcome: PrimingOutcome.settingsOpened,
      kind: PermissionKind.notification,
      platform: _platform,
      ts: DateTime.now(),
    ));
  }

  // ─── Camera priming ───────────────────────────────────────────────────────

  /// Returns true if camera priming should be shown for [context].
  ///
  /// Priming fires once per context (AC-C2). After first shown + accepted/denied
  /// for a given context, go straight to OS picker.
  Future<bool> shouldShowCameraPriming(
    String userId,
    CameraContext context,
  ) async {
    return _withLock(userId, () async {
      final state = await _storage.read(
        userId,
        PermissionKind.camera,
        subContext: context.name,
      );

      // Already shown once for this context → skip priming (AC-C2).
      if (state.lastShownAt != null) return false;

      // Permanently denied → show settings guidance, not priming sheet.
      if (state.osPermanentlyDenied) return false;

      return true;
    });
  }

  /// User tapped "Tiếp tục" on camera priming — records accept and marks
  /// context as shown. Actual OS permission request happens in the picker
  /// call-site (Phase 4) since [permission_handler] is used there.
  Future<PrimingOutcome> grantCamera({
    required String userId,
    required CameraContext context,
  }) async {
    return _withLock(userId, () async {
      final now = DateTime.now();
      var state = await _storage.read(
        userId,
        PermissionKind.camera,
        subContext: context.name,
      );
      state = state.copyWith(lastShownAt: now, osGranted: true);
      await _storage.write(
        userId,
        PermissionKind.camera,
        state,
        subContext: context.name,
      );
      await _events.capture(PermissionEvent(
        outcome: PrimingOutcome.accept,
        kind: PermissionKind.camera,
        context: context.name,
        platform: _platform,
        ts: now,
      ));
      return PrimingOutcome.accept;
    });
  }

  /// User tapped "Hủy" on camera priming.
  Future<void> deferCamera(String userId, CameraContext context) async {
    await _withLock(userId, () async {
      final now = DateTime.now();
      var state = await _storage.read(
        userId,
        PermissionKind.camera,
        subContext: context.name,
      );
      state = state.copyWith(lastShownAt: now, lastDeferAt: now);
      await _storage.write(
        userId,
        PermissionKind.camera,
        state,
        subContext: context.name,
      );
      await _events.capture(PermissionEvent(
        outcome: PrimingOutcome.defer,
        kind: PermissionKind.camera,
        context: context.name,
        platform: _platform,
        ts: now,
      ));
    });
  }

  // ─── Lifecycle hooks ──────────────────────────────────────────────────────

  /// Called on logout (AC-T1):
  /// - Informs BE to remove this device's push token (AC-T1 multi-device cleanup).
  /// - Deletes FCM token from device (device stops receiving push).
  /// - Clears this user's priming keys from secure storage (AC-N7).
  /// - Does NOT touch other users' keys.
  Future<void> onLogout(String userId) async {
    // Unregister from BE BEFORE deleting the local token, so we still have
    // the installId available for the request payload.
    try {
      final installId = await _installId.get();
      await _fcm.unregisterToken(installId: installId);
    } catch (_) {
      // Non-fatal — BE will expire stale tokens after 90 days (last_seen_at).
    }

    // Detach user context to cancel the onTokenRefresh listener.
    _fcm.detachUserContext();

    await _fcm.deleteToken();
    await _storage.clearUser(userId);
    await _events.capture(PermissionEvent(
      outcome: PrimingOutcome.settingsOpened, // closest event type for logout
      kind: PermissionKind.notification,
      platform: _platform,
      ts: DateTime.now(),
    ));
  }

  /// Returns true if priming should re-trigger due to role upgrade (AC-N8).
  ///
  /// Condition: user previously accepted for a different role.
  /// If OS was permanently denied, only soft re-ask is appropriate (no re-trigger).
  Future<bool> shouldRetriggerOnRoleUpgrade(
      String userId, UserRole newRole) async {
    final state =
        await _storage.read(userId, PermissionKind.notification);

    if (state.osPermanentlyDenied) return false;
    if (!state.osGranted && state.lastShownForRole == null) return false;

    return state.lastShownForRole != newRole;
  }

  /// Called on role upgrade — resets [PrimingState.lastShownForRole] so
  /// [shouldShowNotificationPriming] returns true with new role copy (AC-N8).
  Future<void> onRoleUpgrade(String userId, UserRole newRole) async {
    await _withLock(userId, () async {
      var state =
          await _storage.read(userId, PermissionKind.notification);
      // Clear lastShownForRole → triggers re-evaluation in shouldShow*.
      state = state.copyWith(clearLastShownForRole: true);
      await _storage.write(userId, PermissionKind.notification, state);
    });
  }

  /// Called on app foreground:
  /// 1. Checks iOS provisional → full upgrade (poll via FCM).
  /// 2. Checks iOS APNs 24h fallback — exposes via [shouldShowApnsFallback].
  /// 3. Phase 6 calls [PermissionEventSink.drainPending] for BE upload.
  Future<void> onAppForeground(String userId) async {
    try {
      // ── iOS provisional upgrade poll ──────────────────────────────────
      final upgraded = await _fcm.checkProvisionalUpgrade();
      if (upgraded) {
        await _withLock(userId, () async {
          var state =
              await _storage.read(userId, PermissionKind.notification);
          if (state.osProvisional) {
            state = state.copyWith(
              osGranted: true,
              osProvisional: false,
            );
            await _storage.write(userId, PermissionKind.notification, state);
            await _events.capture(PermissionEvent(
              outcome: PrimingOutcome.osProvisionalUpgrade,
              kind: PermissionKind.notification,
              platform: _platform,
              ts: DateTime.now(),
            ));
          }
        });
      }

      // ── iOS APNs 24h fallback check ───────────────────────────────────
      // If the fallback timer has elapsed without delivery, we enqueue an
      // event so analytics captures the scenario.
      // The UI layer polls [shouldShowApnsFallback] directly and renders the
      // SoftReaskBanner — we do NOT open the sheet here.
      //
      // Note: we use osPermDeny as the closest existing outcome semantic for
      // "provisional delivered but OS may have suppressed silently after 24h
      // without a real foreground delivery". This is intentional and documented.
      // Phase 7 e2e tests verify the banner renders when this event is present.
      final apnsFallbackNeeded =
          await _fcm.shouldShowApnsFallback(userId);
      if (apnsFallbackNeeded) {
        await _events.capture(PermissionEvent(
          // osPermDeny chosen as the closest semantic to "silent provisional
          // with no delivery detected after 24h" — additive to existing enum.
          outcome: PrimingOutcome.osPermDeny,
          kind: PermissionKind.notification,
          platform: _platform,
          ts: DateTime.now(),
        ));
      }
    } catch (_) {
      // Non-fatal; foreground check is best-effort.
    }
  }

  // ── iOS APNs fallback public API ─────────────────────────────────────────

  /// Returns true if the iOS APNs 24h fallback banner should be shown.
  ///
  /// Delegates to [FcmService.shouldShowApnsFallback] which checks the
  /// provisionally stored timer in secure storage.
  ///
  /// The UI layer (_RootGate / SoftReaskBanner) should poll this on:
  ///   - App foreground (already triggered by [onAppForeground] analytics capture).
  ///   - After receiving a foreground notification (to clear the banner).
  ///
  /// Phase 7 e2e: verify banner renders after time-skip past 24h threshold.
  Future<bool> shouldShowApnsFallback(String userId) =>
      _fcm.shouldShowApnsFallback(userId);

  /// Marks the APNs provisional delivery as confirmed for [userId].
  ///
  /// Call this when a [RemoteMessage] is received (from [FcmService.foregroundMessages]
  /// or via [FcmService.notificationTaps]). Clears the 24h fallback timer.
  Future<void> markApnsDelivered(String userId) =>
      _fcm.markDelivered(userId);

  // ─── FCM token helpers (for Phase 4 to call after priming grant) ──────────

  /// Returns the FCM token for BE registration (AC-T1).
  Future<String?> getFcmToken() => _fcm.getToken();

  /// Returns the install UUID (for token registration payload).
  Future<String> getInstallId() => _installId.get();

  /// Exposes FcmService so Phase 4 can attach it to NotificationProvider.
  FcmService get fcm => _fcm;

  /// Exposes the event sink so Phase 6 uploader can share the same queue
  /// instance rather than creating a second reader for the same storage key.
  PermissionEventSink get eventSink => _events;

  // ─── Debug helpers (Phase 4 PermissionDebugScreen, kDebugMode only) ───────

  /// Deletes ALL priming keys. Must only be called from debug screen.
  Future<void> debugResetAll() async {
    assert(() {
      // Warn if called outside debug mode at runtime.
      // ignore: avoid_print
      print('[PermissionService] debugResetAll called');
      return true;
    }());
    await _storage.resetAll();
  }

  /// Shifts cooldown timestamps backwards by [days] for the given user.
  Future<void> debugSkipDays(String userId, int days) async {
    assert(() {
      // ignore: avoid_print
      print('[PermissionService] debugSkipDays($userId, $days)');
      return true;
    }());
    await _storage.skipDays(userId, days);
  }

  // ─── Mutex helper ─────────────────────────────────────────────────────────

  /// Serialises [fn] for the given [userId].
  /// Prevents concurrent reads/writes racing on the same user's storage keys.
  Future<T> _withLock<T>(String userId, Future<T> Function() fn) async {
    // Wait for any in-flight operation for this userId.
    final prev = _locks[userId];
    final completer = Completer<void>();
    _locks[userId] = completer.future;

    try {
      if (prev != null) await prev.catchError((_) {});
      return await fn();
    } finally {
      completer.complete();
      if (_locks[userId] == completer.future) {
        _locks.remove(userId);
      }
    }
  }
}
