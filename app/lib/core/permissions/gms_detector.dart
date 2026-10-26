// GMS (Google Mobile Services) availability detector.
// Gates all FCM calls on Android — AC-N9 / R6 (non-GMS crash prevention).
import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional import: google_api_availability is Android-only.
// On non-Android platforms the stub returns true immediately.
import 'gms_detector_stub.dart'
    if (dart.library.io) 'gms_detector_android.dart' as impl;

/// Detects whether Firebase Cloud Messaging is supported on the current device.
///
/// Rules (AC-N9 / D9):
/// - iOS, Web, macOS, Windows, Linux → always returns `true` (FCM works natively).
/// - Android with GMS available → `true`.
/// - Android without GMS (Huawei, de-Googled ROM) → `false`.
///   Caller must skip FCM init and hide notification priming entirely (no error shown).
/// - Any exception → `false` (degrade gracefully; crash-safety per R6).
class GmsDetector {
  /// Returns `true` if FCM is available and safe to initialise.
  ///
  /// Applies a 2-second timeout on Android to avoid hanging the splash screen
  /// on misconfigured emulators without GMS.
  static Future<bool> isFcmAvailable() async {
    // Web has no concept of GMS; Firebase JS SDK works directly.
    if (kIsWeb) return true;

    try {
      return await impl
          .checkGmsAvailability()
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }
}
