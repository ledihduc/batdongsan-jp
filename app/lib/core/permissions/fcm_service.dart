// FCM wrapper: init, token lifecycle, foreground/tap message streams.
// Phase 4 wires these streams into the router and notification provider.
// Phase 5 adds iOS provisional 24h fallback timer storage.
// Phase 6 adds registerToken/unregisterToken (BE push-token endpoints) and
// attachUserContext to re-register on FCM token refresh.
// ignore_for_file: prefer_initializing_formals
// Reason: Constructor uses public param names ('events', 'jwtProvider') while
// fields are private ('_eventSink', '_jwtProvider'). Initializing formals would
// force the public names onto the private fields — not acceptable here.
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:house_booking/core/config/api_config.dart';

import 'permission_events.dart';
import 'permission_types.dart';

/// Wraps [FirebaseMessaging] with a clean, testable API.
///
/// Caller MUST verify [GmsDetector.isFcmAvailable()] returns true on Android
/// before constructing / calling [init]. FCM will crash otherwise (R6).
///
/// Responsibilities:
/// - Request OS permission (iOS provisional or full, Android via permission_handler).
/// - Register/refresh/delete FCM token tied to a (userId, installId).
/// - Expose foreground message stream and notification-tap stream for routing.
/// - iOS provisional → full upgrade detection (polling on foreground).
/// - iOS provisional 24h APNs fallback: stores grantedAt + delivered flag.
class FcmService {
  FcmService({
    required FirebaseMessaging? messaging,
    required PermissionEventSink events,
    required String? webVapidKey,
    Future<String?> Function()? jwtProvider,
    FlutterSecureStorage? storage,
  })  : _eventSink = events,
        _jwtProvider = jwtProvider,
        _storage = storage ?? const FlutterSecureStorage() {
    _messaging = messaging;
    _webVapidKey = webVapidKey;
  }

  /// Null when Firebase is unavailable (Huawei / no-GMS / web without config).
  /// Real instances of [FcmService] are only constructed when GMS is detected,
  /// so the non-null assertion below is contractually safe. Subclasses that
  /// override every public method (see _NullFcmService) can pass null.
  late final FirebaseMessaging? _messaging;

  // Retained for future use: FcmService may enqueue token-related events here.
  // ignore: unused_field
  final PermissionEventSink _eventSink;

  late final String? _webVapidKey;

  /// Optional JWT provider — injected so registerToken can call BE without
  /// a hard dependency on SessionService (keeps this class testable).
  final Future<String?> Function()? _jwtProvider;

  /// Secure storage for iOS provisional 24h fallback timer state.
  /// Key: `fcm_provisional_state:{userId}`
  /// Value: JSON `{"grantedAt": "<ISO8601 UTC>", "delivered": false}`
  final FlutterSecureStorage _storage;

  // ── iOS provisional state storage key ────────────────────────────────────

  static String _provisionalKey(String userId) =>
      'fcm_provisional_state:$userId';

  // ── User context for token refresh re-registration ────────────────────────

  // ignore: unused_field — used via closure capture in attachUserContext listener.
  String? _attachedUserId;
  // ignore: unused_field — stored for future detach/re-attach needs.
  String? _attachedInstallId;
  StreamSubscription<String>? _tokenRefreshSub;

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Configure FCM: foreground presentation options on iOS.
  /// Call once after [Firebase.initializeApp()].
  Future<void> init() async {
    try {
      await _messaging!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      // Non-fatal: foreground presentation may not work on all platforms.
      assert(() {
        // ignore: avoid_print
        print('[FcmService] setForegroundNotificationPresentationOptions failed: $e');
        return true;
      }());
    }
  }

  // ── User context wiring ───────────────────────────────────────────────────

  /// Attaches the current user context so that FCM token refreshes automatically
  /// re-register with the BE push-token endpoint.
  ///
  /// Call this after a successful login / session restore. Cancels any previous
  /// subscription before subscribing so that repeated calls (e.g. role upgrade)
  /// do not stack listeners.
  ///
  /// Reason for a setter instead of constructor param: userId is not known at
  /// FcmService construction time (constructed before auth bootstraps in main.dart).
  void attachUserContext({
    required String userId,
    required String installId,
  }) {
    _attachedUserId = userId;
    _attachedInstallId = installId;

    // Cancel previous refresh listener before re-subscribing.
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging!.onTokenRefresh.listen((newToken) {
      // Re-register silently; failure is non-fatal.
      registerToken(userId: userId, installId: installId);
    });
  }

  /// Detaches user context and cancels the token-refresh subscription.
  /// Call on logout before [deleteToken].
  void detachUserContext() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _attachedUserId = null;
    _attachedInstallId = null;
  }

  // ── BE token registration ─────────────────────────────────────────────────

  /// Registers the current FCM token with the BE push-token endpoint.
  ///
  /// `POST /api/users/me/push-token { token, deviceId, platform }`
  ///
  /// Returns true on 2xx. Logs failures via [debugPrint] — never throws.
  Future<bool> registerToken({
    required String userId,
    required String installId,
  }) async {
    try {
      final fcmToken = await getToken();
      if (fcmToken == null) return false;

      final jwtToken = await _jwtProvider?.call();
      if (jwtToken == null || jwtToken.isEmpty) return false;

      final uri = Uri.parse('${ApiConfig.baseUrl}/api/users/me/push-token');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'token': fcmToken,
          'deviceId': installId,
          'platform': _platformString(),
        }),
      );

      final ok = response.statusCode >= 200 && response.statusCode < 300;
      if (!ok) {
        debugPrint(
          '[FcmService] registerToken failed: HTTP ${response.statusCode}',
        );
      }
      return ok;
    } catch (e) {
      debugPrint('[FcmService] registerToken error: $e');
      return false;
    }
  }

  /// Unregisters the device's push token from the BE.
  ///
  /// `DELETE /api/users/me/push-token { deviceId: installId }`
  ///
  /// Returns true on 2xx AND on 404 (idempotent — BE contract specifies 404
  /// is treated as success). Never throws.
  Future<bool> unregisterToken({required String installId}) async {
    try {
      final jwtToken = await _jwtProvider?.call();
      if (jwtToken == null || jwtToken.isEmpty) return false;

      final uri = Uri.parse('${ApiConfig.baseUrl}/api/users/me/push-token');
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'deviceId': installId}),
      );

      final status = response.statusCode;
      // 404 treated as success — idempotent per BE contract.
      final ok =
          (status >= 200 && status < 300) || status == 404;
      if (!ok) {
        debugPrint(
          '[FcmService] unregisterToken failed: HTTP $status',
        );
      }
      return ok;
    } catch (e) {
      debugPrint('[FcmService] unregisterToken error: $e');
      return false;
    }
  }

  /// Returns the lowercase platform string for BE registration payloads.
  /// Shared by registerToken and (indirectly) PermissionService._platform.
  String _platformString() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
    } catch (_) {
      // Platform not available in this build context.
    }
    return 'unknown';
  }

  // ── Permission request ────────────────────────────────────────────────────

  /// Requests OS notification permission via FCM.
  ///
  /// On iOS with [useProvisionalOnIos] = true:
  ///   Requests provisional grant — notifications delivered quietly to NC.
  ///   Per AC-N5: requests [.alert, .badge, .sound, .provisional].
  ///   On provisional result: persists 24h fallback timer state in secure storage
  ///   under key `fcm_provisional_state:{userId}`.
  ///
  /// iOS 18 bug workaround (researcher Task 2 issue #1):
  ///   If [authorizationStatus] is [notDetermined] after request, treat as
  ///   [PrimingOutcome.defer] rather than [PrimingOutcome.osDeny].
  ///
  /// [userId] is required to scope the 24h fallback timer per-user.
  ///   Pass empty string ('') when userId is not yet available (pre-login flows).
  ///   The provisional timer will not fire for anonymous users since
  ///   [shouldShowApnsFallback] also requires a non-empty userId.
  ///
  /// Returns the [PrimingOutcome] representing the OS response.
  Future<PrimingOutcome> requestPermission({
    required UserRole role,
    required bool useProvisionalOnIos,
    String userId = '',
  }) async {
    try {
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: useProvisionalOnIos,
      );

      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
          // Clear any provisional fallback timer — user has full permission.
          if (userId.isNotEmpty) {
            await _clearProvisionalState(userId);
          }
          return PrimingOutcome.osGrant;

        case AuthorizationStatus.provisional:
          // Persist 24h fallback timer (AC-N5 APNs fallback).
          if (userId.isNotEmpty) {
            await _writeProvisionalState(userId);
          }
          return PrimingOutcome.osProvisional;

        case AuthorizationStatus.denied:
          return PrimingOutcome.osDeny;

        case AuthorizationStatus.notDetermined:
          // iOS 18 bug: user dismissed dialog without choosing → treat as defer,
          // not deny, so the 30-day deny cooldown does NOT trigger (researcher Task 2).
          return PrimingOutcome.defer;
      }
    } catch (e) {
      return PrimingOutcome.osDeny;
    }
  }

  // ── iOS provisional 24h fallback timer ───────────────────────────────────

  /// Stores provisional grant timestamp + delivered=false for [userId].
  ///
  /// Key: `fcm_provisional_state:{userId}`
  /// Value: `{"grantedAt": "<ISO8601 UTC>", "delivered": false}`
  Future<void> _writeProvisionalState(String userId) async {
    try {
      final payload = jsonEncode({
        'grantedAt': DateTime.now().toUtc().toIso8601String(),
        'delivered': false,
      });
      await _storage.write(key: _provisionalKey(userId), value: payload);
    } catch (_) {
      // Non-fatal — if storage fails, fallback timer simply won't trigger.
    }
  }

  /// Clears the provisional fallback timer for [userId].
  /// Called when the user upgrades from provisional → full (authorized).
  Future<void> _clearProvisionalState(String userId) async {
    try {
      await _storage.delete(key: _provisionalKey(userId));
    } catch (_) {}
  }

  /// Returns true if the iOS APNs 24h fallback should trigger for [userId].
  ///
  /// Conditions:
  ///   1. Stored `grantedAt` is non-null.
  ///   2. More than 24h have elapsed since `grantedAt` (UTC).
  ///   3. `delivered` is still false (no foreground/background message received).
  ///
  /// Called by [PermissionService.shouldShowApnsFallback] and forwarded to UI.
  Future<bool> shouldShowApnsFallback(String userId) async {
    if (userId.isEmpty) return false;
    try {
      final raw = await _storage.read(key: _provisionalKey(userId));
      if (raw == null || raw.isEmpty) return false;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final grantedAtStr = data['grantedAt'] as String?;
      if (grantedAtStr == null) return false;

      final grantedAt = DateTime.tryParse(grantedAtStr);
      if (grantedAt == null) return false;

      final delivered = (data['delivered'] as bool?) ?? false;
      if (delivered) return false;

      final elapsed = DateTime.now().toUtc().difference(grantedAt.toUtc());
      return elapsed >= const Duration(hours: 24);
    } catch (_) {
      return false;
    }
  }

  /// Marks the provisional APNs delivery as confirmed for [userId].
  ///
  /// Called when any [RemoteMessage] is received (foreground or by the caller
  /// that processes background messages). Clears the 24h fallback timer.
  /// Safe to call multiple times (idempotent).
  Future<void> markDelivered(String userId) async {
    if (userId.isEmpty) return;
    try {
      final raw = await _storage.read(key: _provisionalKey(userId));
      if (raw == null || raw.isEmpty) return;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      // Only write if not already marked — avoids unnecessary storage writes.
      if (data['delivered'] == true) return;

      data['delivered'] = true;
      await _storage.write(
        key: _provisionalKey(userId),
        value: jsonEncode(data),
      );
    } catch (_) {
      // Non-fatal — delivery tracking is best-effort.
    }
  }

  // ── Token management ──────────────────────────────────────────────────────

  /// Fetches the current FCM registration token.
  ///
  /// On web, [_webVapidKey] is required for VAPID authentication (AC-N6).
  /// Returns null if the token could not be obtained (GMS unavailable, network error).
  Future<String?> getToken() async {
    try {
      final token = await _messaging!.getToken(
        vapidKey: kIsWeb ? _webVapidKey : null,
      );
      // Never log token in production — it's a semi-sensitive credential (AC-T1).
      assert(() {
        // Debug only: omit actual token value from logs.
        // ignore: avoid_print
        print('[FcmService] Token obtained: ${token != null ? '***' : 'null'}');
        return true;
      }());
      return token;
    } catch (_) {
      return null;
    }
  }

  /// Deletes the FCM token from this device.
  /// Called on logout (AC-T1) so the device stops receiving notifications.
  Future<void> deleteToken() async {
    try {
      await _messaging!.deleteToken();
    } catch (_) {
      // Best-effort; token will expire server-side eventually.
    }
  }

  /// Stream of token refreshes — caller (Phase 4) should re-register with BE.
  Stream<String> get onTokenRefresh => _messaging!.onTokenRefresh;

  // ── Message streams ───────────────────────────────────────────────────────

  /// Messages received while the app is in foreground.
  /// Phase 4 subscribes to show in-app banners.
  Stream<RemoteMessage> get foregroundMessages =>
      FirebaseMessaging.onMessage;

  /// Taps on notifications that opened the app from background/terminated.
  /// Phase 4 routes these via go_router.
  Stream<RemoteMessage> get notificationTaps =>
      FirebaseMessaging.onMessageOpenedApp;

  // ── iOS provisional upgrade detection ────────────────────────────────────

  /// Polls whether the user has upgraded from provisional → full.
  ///
  /// No automatic event exists on iOS (researcher Task 2 known limitation).
  /// Phase 4 calls this on each app foreground event.
  ///
  /// Returns true if an upgrade is detected (caller should update [PrimingState]
  /// and enqueue [PrimingOutcome.osProvisionalUpgrade] event).
  Future<bool> checkProvisionalUpgrade() async {
    try {
      final settings = await _messaging!.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (_) {
      return false;
    }
  }

  // ── Web pre-check ─────────────────────────────────────────────────────────

  /// On web: reads `Notification.permission` to check if already granted.
  ///
  /// Used by AC-N6 revised: if `granted` → skip priming, just register token.
  /// On non-web platforms always returns false (handled natively).
  Future<bool> isWebAlreadyGranted() async {
    if (!kIsWeb) return false;
    try {
      // Dart Web: access Notification.permission via dart:html or package:web.
      // We use dynamic interop to avoid a hard dependency on dart:html
      // in the core module (dart:html is deprecated in favour of package:web).
      final permission = _getWebNotificationPermission();
      return permission == 'granted';
    } catch (_) {
      return false;
    }
  }

  /// Reads `window.Notification.permission` via JS interop.
  /// Only called when [kIsWeb] is true so the dart:html import is never
  /// exercised on mobile/desktop native.
  String _getWebNotificationPermission() {
    // Wrapped in try/catch at call site; if JS interop fails → 'unknown'
    // which is treated as not-granted.
    try {
      // ignore: undefined_prefixed_name
      return _WebNotification.permission;
    } catch (_) {
      return 'unknown';
    }
  }
}

// ─── Minimal JS interop helper (web only) ────────────────────────────────────
// We use @JS annotation-free dynamic access to avoid pulling in dart:js_interop
// as a required import on all platforms. The try/catch in _getWebNotificationPermission
// handles the case where the class does not exist.
class _WebNotification {
  static String get permission {
    // Accessed via dart:html on web builds; will throw on non-web builds
    // (caught by caller).
    // ignore: avoid_dynamic_calls
    final dynamic notification =
        // ignore: undefined_identifier
        (const Object() as dynamic).window?.Notification;
    return (notification?.permission as String?) ?? 'unknown';
  }
}
