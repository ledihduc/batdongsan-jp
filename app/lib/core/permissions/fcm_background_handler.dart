// Top-level FCM background message handler.
// MUST be a top-level function (not a method) per firebase_messaging requirement.
// Runs in a separate Dart isolate — MUST NOT access UI, Provider, or Navigator.
// MUST NOT access flutter_secure_storage (SecureStorage opens UI channel on some platforms).
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Handles FCM messages when the app is in background or terminated.
///
/// Firebase requires this to be a top-level function annotated with
/// `@pragma('vm:entry-point')` so the Dart VM does not tree-shake it
/// in release builds.
///
/// Constraints (per spec + firebase_messaging docs):
/// - MUST call [Firebase.initializeApp] — runs in a fresh isolate.
/// - MUST NOT touch SharedPreferences / flutter_secure_storage — they require
///   platform channel which may not be available in the background isolate.
/// - MUST NOT display UI.
/// - SHOULD remain lightweight to avoid ANR on Android.
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  try {
    // Background isolate needs its own Firebase init.
    // Catch [core/duplicate-app] silently — safe to ignore.
    await Firebase.initializeApp();
  } catch (e) {
    // [core/duplicate-app] or no google-services.json yet — continue without crash.
    // ignore: avoid_print
    assert(() {
      // ignore: avoid_print
      print('[fcmBackgroundHandler] Firebase init: $e');
      return true;
    }());
  }

  // Lightweight logging only — no DB writes, no secure storage, no UI.
  assert(() {
    // ignore: avoid_print
    print('[fcmBackgroundHandler] Received: ${message.messageId} type=${message.data['type']}');
    return true;
  }());

  // Phase 6 will add: badge update via flutter_local_notifications (separate isolate-safe plugin).
  // TODO(phase6): increment badge count via local notifications plugin.
}
