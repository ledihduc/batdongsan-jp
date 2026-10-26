// Platform capability detection for the permission-priming module.
//
// Centralises all "can this platform do X?" queries so callers never scatter
// [Platform] / [kIsWeb] checks across files.
//
// Cross-platform import safety:
//   - [dart:io] is only ever accessed after a [kIsWeb] == false guard.
//   - Web JS interop uses the same [dynamic]-cast pattern as [FcmService]
//     ([_WebNotification]) and is only reached when [kIsWeb] is true.
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'gms_detector.dart';

/// Static capability queries for the permission-priming feature.
class PlatformCapability {
  // ── iOS provisional support ───────────────────────────────────────────────

  /// True if the platform supports iOS provisional push permission.
  ///
  /// Provisional delivers notifications silently to Notification Centre without
  /// showing an OS dialog. Only available on iOS / iPadOS (AC-N5).
  static bool get supportsProvisionalIos {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  // ── Web push support ──────────────────────────────────────────────────────

  /// Returns true if the current browser supports Web Push via FCM.
  ///
  /// Requirements:
  ///   1. Running in a web context ([kIsWeb]).
  ///   2. `Notification` API present in the browser.
  ///   3. `ServiceWorker` API present.
  ///   4. Safari: Version must be ≥ 16.4 (PWA-only Web Push gate).
  ///      Safari < 16.4 → false; priming must be hidden (AC-N6).
  static Future<bool> get supportsWebPush async {
    if (!kIsWeb) return false;
    try {
      return _WebPushCapability.isSupported();
    } catch (_) {
      return false;
    }
  }

  // ── Huawei / non-GMS ─────────────────────────────────────────────────────

  /// Returns true if the device is Android AND GMS is unavailable.
  ///
  /// Huawei devices and de-Googled ROMs fail [GmsDetector.isFcmAvailable()].
  /// Callers must hide notification priming entirely (AC-N9 / D9).
  /// Always false on iOS and web.
  static Future<bool> get isHuaweiWithoutGms async {
    if (kIsWeb) return false;
    try {
      if (!Platform.isAndroid) return false;
      return !(await GmsDetector.isFcmAvailable());
    } catch (_) {
      // Conservative: treat as GMS available to avoid incorrectly hiding priming.
      return false;
    }
  }
}

// ─── Web capability check (only reached when kIsWeb is true) ─────────────────

/// Browser-level push-capability checks using the same JS interop pattern
/// as [FcmService._WebNotification] — dynamic cast via const Object().
///
/// Methods are only called when [kIsWeb] is true (guarded in PlatformCapability).
// ignore: avoid_classes_with_only_static_members
class _WebPushCapability {
  /// Returns true when: Notification API + ServiceWorker exist AND Safari ≥ 16.4.
  static bool isSupported() {
    // Access browser globals via dart:html-free dynamic interop.
    // This compiles correctly on web; on native the kIsWeb guard prevents calls.
    // ignore: avoid_dynamic_calls
    final dynamic nav = _navigator();
    if (nav == null) return false;

    // ServiceWorker is required for background message handling.
    try {
      // ignore: avoid_dynamic_calls
      if (nav.serviceWorker == null) return false;
    } catch (_) {
      return false;
    }

    // Notification API must exist.
    if (!_notificationApiExists()) return false;

    // Safari version gate.
    final ua = _userAgent();
    if (ua != null && _isSafariOnly(ua)) {
      final ver = _parseSafariVersion(ua);
      if (ver == null) return false; // Unknown Safari → treat as unsupported.
      // Require Safari ≥ 16.4 (PWA Web Push introduced in 16.4).
      if (ver.$1 < 16 || (ver.$1 == 16 && ver.$2 < 4)) return false;
    }

    return true;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static dynamic _navigator() {
    try {
      // ignore: avoid_dynamic_calls
      return (const Object() as dynamic).window?.navigator;
    } catch (_) {
      return null;
    }
  }

  static bool _notificationApiExists() {
    try {
      // ignore: avoid_dynamic_calls
      final dynamic cls = (const Object() as dynamic).window?.Notification;
      return cls != null;
    } catch (_) {
      return false;
    }
  }

  static String? _userAgent() {
    try {
      // ignore: avoid_dynamic_calls
      final dynamic ua = (const Object() as dynamic).window?.navigator?.userAgent;
      return ua?.toString();
    } catch (_) {
      return null;
    }
  }

  /// True when the UA belongs to Safari and NOT Chrome/Chromium/Edge.
  /// Chrome/Edge include "Safari" in their UAs — they are not affected
  /// by the Safari 16.4 restriction.
  static bool _isSafariOnly(String ua) {
    if (!ua.contains('Safari')) return false;
    if (ua.contains('Chrome')) return false;
    if (ua.contains('Chromium')) return false;
    if (ua.contains('CriOS')) return false; // Chrome iOS
    if (ua.contains('FxiOS')) return false; // Firefox iOS
    if (ua.contains('EdgA')) return false;  // Edge Android
    return true;
  }

  /// Extracts (major, minor) from `Version/X.Y` in WebKit user-agent strings.
  /// Returns null if not parseable — caller treats null as unsupported.
  static (int, int)? _parseSafariVersion(String ua) {
    final match = RegExp(r'Version/(\d+)\.(\d+)').firstMatch(ua);
    if (match == null) return null;
    try {
      return (int.parse(match.group(1)!), int.parse(match.group(2)!));
    } catch (_) {
      return null;
    }
  }
}
