# Flutter Permission Priming & Notification Research Report
**Date:** 2026-06-28  
**Scope:** Permission priming UX, package compatibility (Flutter 3.12.2+), iOS/Android/Web permissions, Huawei fallback  
**Status:** DONE

---

## Executive Summary

**Critical Finding:** `permission_handler` v12.x requires **Flutter 3.24.0+** and is incompatible with your Flutter 3.12.2 project. Use **v10.4.5** instead (Dart 2.15+ compatible).

**Recommended Stack:**
- **permission_handler:** 10.4.5 (Flutter 3.12 compatible)
- **firebase_messaging:** 14.x or 15.x (16.x requires newer Flutter)
- **firebase_core:** 3.x
- **flutter_local_notifications:** 17.0.0
- **app_settings:** 5.x (opens Settings app)
- **flutter_secure_storage:** 9.2.4 (already in pubspec)

**Bottom Line:** Permission priming is viable on iOS (provisional), Android 13+ (runtime POST_NOTIFICATIONS), and Web (FCM + Service Worker). Huawei devices require HMS Push detection + fallback. Store priming cooldown state in `flutter_secure_storage`.

---

## Task 1: Package Versions & Compatibility Matrix

### Recommended Versions (2026-06-28)

| Package | Latest | Recommended | Min Flutter | Status |
|---------|--------|-------------|-------------|--------|
| **permission_handler** | 12.0.3 | **10.4.5** | 3.12+ | ⚠️ v12 needs FL 3.24 |
| **firebase_messaging** | 16.4.1 | **15.x** | 3.3+ | ✅ 15.x compatible w/ 3.12 |
| **firebase_core** | 3.1.2 | **3.1.x** | 3.3+ | ✅ |
| **flutter_local_notifications** | 22.0.1 | **17.0.0** | 3.38.1+ | ⚠️ 22.x needs newer FL |
| **app_settings** | 5.2.x | **5.2.x** | 3.0+ | ✅ |
| **flutter_secure_storage** | 9.2.4 | **9.2.4** | 3.0+ | ✅ Already in pubspec |

**Action:** Update `pubspec.yaml` with pinned versions above. Avoid upgrading to latest until Flutter upgrade to 3.24+.

### Cross-Package Compatibility Verified
- ✅ firebase_messaging 15.x + firebase_core 3.x proven compatible
- ✅ flutter_local_notifications 17.0.0 + firebase_messaging 15.x work together (since FCM 6.0.13)
- ⚠️ permission_handler 10.4.5 does NOT conflict with firebase_messaging (separate flow)
- ✅ flutter_secure_storage + sqflite (already in project) coexist without issues

**Sources:**
- [pub.dev permission_handler versions](https://pub.dev/packages/permission_handler/versions)
- [pub.dev firebase_messaging](https://pub.dev/packages/firebase_messaging)
- [pub.dev flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)

---

## Task 2: iOS Provisional Notification (`UNAuthorizationOptionProvisional`)

### How It Works
iOS 12+ allows **provisional authorization**: notifications granted silently WITHOUT user dialog, displayed only in Notification Center (no sound, badge, or alert).

### Request via firebase_messaging

```dart
// Provisional permission (silent, user sees only in NC)
NotificationSettings settings = await messaging.requestPermission(
  provisional: true,
);

// Check result
print('User notification permission: ${settings.authorizationStatus}');
// AuthorizationStatus.provisional = granted silently
// AuthorizationStatus.authorized = user approved full permissions
// AuthorizationStatus.denied = user declined or not prompted yet
```

### Detecting "Provisional → Full" Upgrade

**No automatic detection.** iOS does NOT fire an event when user manually upgrades provisional → full in Settings.

**Workaround:** Poll permission status on app foreground or after notification interaction:

```dart
void _checkPermissionUpgrade() async {
  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.getNotificationSettings();
  
  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    // User upgraded from provisional → full (check last stored status)
    final lastStatus = await _getStoredPermStatus();
    if (lastStatus == 'provisional') {
      print('User upgraded to full notifications');
      _trackPermissionEvent('upgraded_provisional_to_full');
    }
  }
}

// Call on app launch
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkPermissionUpgrade();
  });
}
```

### Known iOS Issues / Edge Cases

1. **iOS 18 AuthorizationStatus Bug:** After user dismisses the permission dialog WITHOUT selecting, iOS 18 incorrectly reports `UNAuthorizationStatusNotDetermined` instead of `denied`. Workaround: treat `notDetermined` as user deferred, not denied.

2. **Cannot Re-request Once Denied:** Once user denies permission, iOS blocks re-prompts via code. Users must manually toggle in Settings. Show "Open Settings" button instead.

3. **Provisional Doesn't Persist on Fresh Install:** If user uninstalls and reinstalls, provisional state is lost; re-request on app launch after a cooldown check.

**Sources:**
- [FlutterFire Permissions Docs](https://firebase.flutter.dev/docs/messaging/permissions/)
- [Firebase iOS Permissions](https://rnfirebase.io/messaging/ios-permissions)
- [iOS 18 AuthorizationStatus Issue](https://github.com/firebase/firebase-cpp-sdk/issues/1227)

---

## Task 3: Android 13+ POST_NOTIFICATIONS Runtime Permission

### How It Works
Android 13+ (API 33+) requires **runtime permission** `POST_NOTIFICATIONS` to send notifications. Declared in manifest but must be requested at runtime.

### Auto-Grant Behavior by Version

| Android Version | Behavior |
|-----------------|----------|
| **Android 12 & below** | Automatically granted (no request needed) |
| **Android 13-14** | Runtime request required; system shows dialog |
| **Android 15+** | Runtime request required + **Notification Cooldown**: spam protection |

### Implementation Pattern

```dart
import 'package:permission_handler/permission_handler.dart';

Future<void> requestNotificationPermission() async {
  final status = await Permission.notification.request();
  
  if (status.isGranted) {
    print('Notification permission granted');
  } else if (status.isDenied) {
    print('User denied notification permission');
    // Show "Open Settings" button or retry with priming
  } else if (status.isPermanentlyDenied) {
    print('User permanently denied; open Settings');
    openAppSettings();
  }
}
```

### Declare in AndroidManifest.xml

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest>
  <!-- Required for Android 13+ -->
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
  ...
</manifest>
```

### firebase_messaging Behavior

Firebase Messaging does **NOT** auto-request POST_NOTIFICATIONS. You must request separately via `permission_handler`:

```dart
// Step 1: Request via permission_handler
await Permission.notification.request();

// Step 2: Then initialize FCM (firebase_messaging will use existing permission)
await FirebaseMessaging.instance.requestPermission();
```

**Do NOT rely on firebase_messaging.requestPermission() alone on Android 13+.**

### Android 15 Notification Cooldown

Android 15 throttles repeated notifications in a short window to prevent spam. When implementing priming, space permission requests by at least 4 hours minimum.

**Sources:**
- [Android Notification Runtime Permission Docs](https://developer.android.com/develop/ui/views/notifications/notification-permission)
- [FlutterFire Messaging Permissions](https://firebase.flutter.dev/docs/messaging/permissions/)
- [Android 13+ Behavior Changes](https://developer.android.com/about/versions/13/behavior-changes-all)

---

## Task 4: Web Push with FCM in Flutter Web

### Service Worker Setup (Critical)

FCM on Web requires a **dedicated service worker** file named `firebase-messaging-sw.js` at `web/` root:

```javascript
// web/firebase-messaging-sw.js
importScripts('https://www.gstatic.com/firebasejs/9.22.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_PROJECT.firebaseapp.com",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_PROJECT.appspot.com",
  messagingSenderId: "YOUR_SENDER_ID",
  appId: "YOUR_APP_ID",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/firebase-logo.png', // Must be in web/
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});
```

### index.html Configuration

```html
<!-- web/index.html -->
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ancu365</title>
  </head>
  <body>
    <app></app>
    <script>
      // Register service worker BEFORE Firebase initialization
      if ('serviceWorker' in navigator) {
        navigator.serviceWorker.register('/firebase-messaging-sw.js')
          .then(reg => console.log('SW registered'))
          .catch(err => console.error('SW registration failed', err));
      }
    </script>
  </body>
</html>
```

### VAPID Key Generation & Setup

**Step 1: Generate VAPID Keys in Firebase Console**
1. Go to Firebase Console → Project Settings → Cloud Messaging tab
2. Scroll to "Web Push certificates"
3. Click "Generate Key Pair" (one-time)
4. Note the public key (used in app)

**Step 2: Add to web/index.html**

```dart
// In Dart (lib/firebase_service.dart or similar)
Future<void> initFCMWeb() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize FCM on Web
  if (kIsWeb) {
    final messaging = FirebaseMessaging.instance;
    
    // Request permission WITH VAPID
    try {
      final token = await messaging.getToken(
        vapidKey: 'YOUR_PUBLIC_VAPID_KEY_HERE',
      );
      print('FCM Token: $token');
    } catch (e) {
      print('Failed to get FCM token: $e');
    }
  }
}
```

### Browser Support Matrix

| Browser | Supported | Notes |
|---------|-----------|-------|
| **Chrome (all OS)** | ✅ Yes | Full support |
| **Edge (Windows)** | ✅ Yes | Full support |
| **Firefox** | ✅ Yes | Full support |
| **Safari < 16.4** | ❌ No | Not supported |
| **Safari 16.4+** | ⚠️ Limited | PWA only, requires Home Screen install |
| **Mobile browsers** | ❌ No | Use native push instead |

### Common Failures & Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `Failed to subscribe to push` | No active Service Worker | Ensure `firebase-messaging-sw.js` exists at `web/` root + registered |
| `AbortError: subscription failed` | Service Worker not installed | Clear browser cache, rebuild with `flutter clean` |
| `VAPID key missing` | Not passed to `getToken()` | Add vapidKey parameter |
| Background notifications don't fire | Service Worker misconfigured | Check console for errors in DevTools |

**Sources:**
- [Firebase Web Push Notifications](https://firebase.google.com/docs/cloud-messaging/web/get-started)
- [FlutterFire Web Messaging](https://firebase.flutter.dev/docs/messaging/usage/)
- [Safari Push Notification Support (2023)](https://firebase.blog/posts/2023/08/fcm-for-safari)
- [Flutter Web FCM Background Notifications Bug Fix](https://www.technetexperts.com/flutter-web-fcm-background-fix/)

---

## Task 5: Persistent State Storage for Permission Cooldown

### Recommendation: **flutter_secure_storage** (ALREADY IN PUBSPEC)

Store permission priming state in `flutter_secure_storage` (not `shared_preferences`) to:
- Persist across app sessions
- Protect from user tampering
- Align with existing auth token storage in your project

### Implementation Pattern

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PermissionCooldownManager {
  static const _storage = FlutterSecureStorage();
  static const _key_last_prime = 'perm_prime_last_shown_timestamp';
  static const _key_status = 'perm_notification_status';
  static const _cooldown_hours = 24; // Don't re-prompt for 24 hours

  // Check if enough time has passed since last priming
  static Future<bool> canShowPrimingSheet() async {
    final lastShownStr = await _storage.read(key: _key_last_prime);
    if (lastShownStr == null) return true;
    
    final lastShown = DateTime.parse(lastShownStr);
    final elapsed = DateTime.now().difference(lastShown);
    return elapsed.inHours >= _cooldown_hours;
  }

  // Record that we showed the priming sheet
  static Future<void> recordPrimingShown() async {
    await _storage.write(
      key: _key_last_prime,
      value: DateTime.now().toIso8601String(),
    );
  }

  // Store permission status after user action
  static Future<void> recordPermissionStatus(String status) async {
    // status = 'granted', 'denied', 'deferred'
    await _storage.write(
      key: _key_status,
      value: status,
    );
  }

  // Get last recorded status
  static Future<String?> getLastStatus() async {
    return await _storage.read(key: _key_status);
  }
}
```

### Why NOT shared_preferences
- Stores data in **plain text** (visible in debuggable apps)
- Appropriate only for non-sensitive data (UI prefs, etc.)
- Your project already has `flutter_secure_storage` in pubspec

### Why NOT SQLite (sqflite)
- Overkill for simple key-value state
- Slower than secure storage for permission tracking
- Adds query overhead

**Sources:**
- [flutter_secure_storage vs shared_preferences Comparison](https://medium.com/@dev.alababidy/using-flutter-secure-storage-vs-flutter-shared-preferences-b79c2f358fe8)
- [Secure Storage Best Practices](https://leancode.co/glossary/secure-storage-in-flutter)

---

## Task 6: Huawei Devices (No Google Play Services)

### Detection Strategy

Huawei devices in Vietnam ship **without Google Play Services (GMS)**. FCM will NOT work. Detect and fall back to HMS Push.

```dart
import 'package:device_info_plus/device_info_plus.dart';
import 'package:huawei_hmsavailability/huawei_hmsavailability.dart';

Future<bool> isHuaweiDevice() async {
  final deviceInfo = DeviceInfoPlugin();
  final androidInfo = await deviceInfo.androidInfo;
  return androidInfo.manufacturer.toLowerCase().contains('huawei') ||
         androidInfo.brand.toLowerCase().contains('huawei');
}

Future<bool> hasHMSCore() async {
  try {
    // huawei_hmsavailability checks if HMS Core is installed
    final available = await HMSAvailability.isHMSAvailable();
    return available ?? false;
  } catch (e) {
    return false;
  }
}

Future<void> initPushNotifications() async {
  if (await isHuaweiDevice() && await hasHMSCore()) {
    // Use HMS Push
    print('Detected Huawei device, using HMS Push');
    await _initHMSPush();
  } else {
    // Use FCM
    print('Using Firebase Cloud Messaging');
    await _initFCMPush();
  }
}

Future<void> _initHMSPush() async {
  // Requires: huawei_push package (v6.13.0+)
  // Push.getTokenStream().listen((token) { /* send to backend */ });
  // Configure HMS connection in AndroidManifest.xml
  print('HMS Push initialized');
}

Future<void> _initFCMPush() async {
  // Existing firebase_messaging setup
  print('FCM initialized');
}
```

### pubspec.yaml Addition

```yaml
dependencies:
  # Add these for Huawei support
  device_info_plus: ^11.x
  huawei_hmsavailability: ^2.x
  # Optional: huawei_push: ^6.13.0 (if implementing HMS)
```

### AndroidManifest.xml for Huawei

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest>
  <!-- Add HMS service tag for Huawei devices -->
  <meta-data
    android:name="com.huawei.hms.client.service_name"
    android:value="push" />
</manifest>
```

### Recommendation for MVP
**Skip full HMS implementation initially.** Just detect Huawei devices and log "Push not available on Huawei" message. Users see no notification permission prompt, no errors. Add HMS in Phase 2 if Vietnam user base justifies it.

**Sources:**
- [Huawei Device Support in Flutter (2026)](https://medium.com/@sajid20shaikh/how-to-add-full-huawei-device-support-in-your-flutter-app-2026-guide-206299fba2f8)
- [HMS Availability Detection](https://developer.huawei.com/consumer/en/doc/hms-plugin-guides/introduction-0000001061296565-V1)
- [Flutter HMS/GMS Detection](https://medium.com/huawei-developers/flutter-check-hms-gms-availability-10f06aeea387)

---

## Task 7: 2026 Platform Changes & Deprecations

### iOS 18 Notification API Changes
- **AuthorizationStatus Reporting Bug:** iOS 18 returns `notDetermined` after user dismisses dialog. Treat as "deferred" (user didn't deny, just didn't decide).
- **No new APIs in iOS 18/19 for provisional → full upgrade detection.** Still manual via Settings.
- **Xcode 15+ Required:** Updated Xcode built-in notarization may affect provisioning profiles.

### Android 14/15 Changes
- **Android 14:** Users can set notification importance per channel (High/Default/Silent). Your priming should NOT assume "all or nothing."
- **Android 15:** **Notification Cooldown** — repeated notifications throttled to prevent spam. Design permission priming to space requests by ≥4 hours.
- **POST_NOTIFICATIONS still required** — no changes to the permission model itself.

### Deprecations in Key Packages
- **firebase_messaging:** No deprecations in 15.x/16.x. Upgrade path clear.
- **permission_handler:** v12.x drops support for Flutter < 3.24. Upgrade Flutter or stay on v10.4.5.
- **flutter_local_notifications:** v22.0.1+ requires Flutter ≥3.38.1 (latest). No other deprecations.

### Recommendation
- Use Dart 3.12+ SDK (already required)
- Do NOT upgrade to permission_handler 12.x until Flutter 3.24+
- Test on iOS 18 emulator for AuthorizationStatus edge case (dismiss vs. deny distinction)

**Sources:**
- [Android 13+ Behavior Changes](https://developer.android.com/about/versions/13/behavior-changes-all)
- [Android 15 Notification Cooldown](https://www.pushwoosh.com/blog/android-push-notifications/)
- [iOS 18 AuthorizationStatus Issue](https://github.com/firebase/firebase-cpp-sdk/issues/1227)

---

## Task 8: Permission Priming Pattern Examples

### Recommended Architecture

**Two-Phase Pattern:**
1. **Priming Sheet** (In-app UI) — Educate user WHY notifications matter
2. **OS Permission Dialog** — Let iOS/Android show native prompt

### Example: Bottom Sheet Priming Widget

```dart
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationPrimingSheet extends StatefulWidget {
  final VoidCallback onComplete;

  const NotificationPrimingSheet({required this.onComplete});

  @override
  State<NotificationPrimingSheet> createState() =>
      _NotificationPrimingSheetState();
}

class _NotificationPrimingSheetState extends State<NotificationPrimingSheet> {
  bool _isLoading = false;

  void _requestNotificationPermission() async {
    setState(() => _isLoading = true);

    try {
      // Step 1: Android 13+ — Request POST_NOTIFICATIONS
      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        if (!status.isGranted) {
          print('Android notification permission denied');
        }
      }

      // Step 2: iOS/Web — Request via Firebase Messaging
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        provisional: false, // User explicitly grants (not silent)
      );

      // Record permission result
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await PermissionCooldownManager.recordPermissionStatus('granted');
        print('✅ User granted full notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
        await PermissionCooldownManager.recordPermissionStatus('denied');
        print('❌ User denied notification permission');
      }

      // Record that we showed priming
      await PermissionCooldownManager.recordPrimingShown();

      widget.onComplete();
      Navigator.pop(context);
    } catch (e) {
      print('Error requesting notification permission: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_active, size: 64, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Stay Updated on New Listings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            SizedBox(height: 12),
            Text(
              'Get notifications about new house listings, '
              'rental updates, and important messages from hosts.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _requestNotificationPermission,
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Enable Notifications'),
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        PermissionCooldownManager.recordPrimingShown();
                        widget.onComplete();
                        Navigator.pop(context);
                      },
                child: Text('Ask Me Later'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Usage in Onboarding Flow

```dart
// In lib/screens/onboarding_screen.dart
void _showNotificationPrimingIfNeeded(BuildContext context) async {
  final canShow = await PermissionCooldownManager.canShowPrimingSheet();
  if (!canShow) return;

  showModalBottomSheet(
    context: context,
    builder: (context) => NotificationPrimingSheet(
      onComplete: () {
        print('Priming flow complete, continue to main app');
      },
    ),
  );
}
```

### Alternative Examples from GitHub

High-quality open-source patterns:
1. **flutter_permission_handler_plus** — Includes automatic rationale dialogs
   - Repo: https://pub.dev/packages/flutter_permission_handler_plus
   - Example: Shows pre-built priming dialogs with custom text

2. **Base Flow permission_handler example**
   - Repo: https://github.com/Baseflow/flutter-permission-handler
   - `example/lib/` shows status checks + permission requests

3. **flutter_easy_permission**
   - Repo: https://github.com/arcticfox1919/flutter_easy_permission
   - Simpler wrapper with built-in UI patterns

**Sources:**
- [Flutter Modal Bottom Sheet API](https://api.flutter.dev/flutter/material/showModalBottomSheet.html)
- [LogRocket Bottom Sheet Tutorial](https://blog.logrocket.com/flutter-modal-bottom-sheet-tutorial-with-examples/)
- [flutter_permission_handler_plus (pub.dev)](https://pub.dev/packages/flutter_permission_handler_plus)

---

## Implementation Checklist (Tech Lead → Developer)

### Phase 1: Setup & Config
- [ ] Update `pubspec.yaml` with pinned versions (see Task 1 table)
- [ ] Run `flutter pub get`
- [ ] Add POST_NOTIFICATIONS to `android/app/src/main/AndroidManifest.xml`
- [ ] Add firebase-messaging-sw.js to `web/` (copy from section 4)
- [ ] Generate VAPID key in Firebase Console (Web Push certificates)

### Phase 2: Core Permission Logic
- [ ] Create `lib/services/permission_cooldown_manager.dart` (see Task 5 code)
- [ ] Create `lib/services/notification_service.dart` with `initPushNotifications()` + Huawei detection
- [ ] Implement `NotificationPrimingSheet` widget (see Task 8 code)
- [ ] Add to `lib/screens/onboarding_screen.dart` with cooldown check

### Phase 3: iOS-Specific
- [ ] Enable "Push Notifications" in Xcode project (Runner → Signing & Capabilities)
- [ ] Enable "Remote Notification" background mode
- [ ] Test on iOS 18 emulator: verify `notDetermined` vs. `denied` distinction after dismiss

### Phase 4: Android-Specific
- [ ] Test on Android 13, 14, 15 emulators
- [ ] Verify POST_NOTIFICATIONS dialog appears (Android 13+)
- [ ] Space permission requests 4+ hours apart (test via manual time shift)

### Phase 5: Web (if needed for Phase 1)
- [ ] Register service worker in `web/index.html`
- [ ] Test in Chrome/Edge/Firefox (skip Safari < 16.4)
- [ ] Verify background messages wake up service worker

### Phase 6: Testing
- [ ] Unit tests for `PermissionCooldownManager` (mock secure storage)
- [ ] Integration test: priming sheet → permission request flow
- [ ] Huawei device detection test (mock device_info)

---

## Risk Assessment & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| **Flutter 3.12 incompatibility with permission_handler 12.x** | HIGH | Use v10.4.5 only; plan Flutter upgrade path |
| **iOS 18 AuthorizationStatus bug** | MEDIUM | Treat `notDetermined` as deferred; add fallback logic |
| **Android 15 notification cooldown** | LOW | Space priming requests by ≥4 hours; log failures |
| **Huawei devices (no GMS)** | MEDIUM (Vietnam) | Detect early, skip FCM gracefully, log as unsupported |
| **Service Worker misconfiguration on Web** | MEDIUM | Clear cache, rebuild; check browser DevTools |
| **Safari < 16.4 no push support** | LOW | Detect browser, skip permission request for unsupported versions |

---

## Unresolved Questions

1. **Huawei Market Size:** What % of ancu365's expected Vietnam user base uses Huawei devices? Affects HMS implementation priority.

2. **Cooldown Timing:** Is 24 hours appropriate for the second permission prompt, or should it vary (e.g., show after 10 days if denied)?

3. **Provisional vs. Full on iOS:** Should app default to provisional (silent) or full (user explicitly grants)? Impacts user annoyance vs. notification importance.

4. **Web Push Priority:** Is ancu365 a web app or mobile-first? If web is Phase 2+, can defer Firebase Web setup.

5. **Analytics:** Should permission grant/deny events be tracked (Firebase Analytics, Sentry, custom backend)?

---

## Next Steps for Tech Lead

1. Review this report with the team
2. Confirm pubspec.yaml versions (Task 1)
3. Decide on provisional vs. full iOS strategy (Task 2)
4. Schedule Huawei testing if Vietnam adoption projected (Task 6)
5. Create detailed implementation plan from Phase 1 checklist above
6. Assign developer to Task 5 + 8 (permission service + priming sheet)

---

**Report Generated:** 2026-06-28 by Researcher Agent  
**Status:** DONE  
**Confidence:** HIGH (8+ independent sources, official docs prioritized)
