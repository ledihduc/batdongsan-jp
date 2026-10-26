# Permission Priming Research — Executive Summary

**Status:** DONE  
**Confidence:** HIGH (8+ sources, official docs prioritized)  
**Date:** 2026-06-28

---

## Key Findings

### 1. Package Compatibility (CRITICAL)
- **permission_handler v12.x:** ❌ Requires Flutter 3.24+ (incompatible with your 3.12.2)
- **Recommendation:** Use v10.4.5 (Dart 2.15+ compatible)
- **Other packages:** firebase_messaging 15.x, flutter_local_notifications 17.0.0, firebase_core 3.1.x all compatible with FL 3.12

### 2. iOS Notification Priming
- ✅ Provisional permissions work (silent, no dialog)
- ⚠️ iOS 18 has AuthorizationStatus bug (dismissal → `notDetermined`)
- ❌ Cannot programmatically upgrade provisional→full; users must toggle in Settings

### 3. Android 13+ Permissions
- ✅ POST_NOTIFICATIONS runtime permission required (Android 13+)
- ⚠️ Android 15 adds Notification Cooldown (space requests ≥4 hours)
- ✅ Auto-granted on Android 12 and below

### 4. Web Push (Flutter Web)
- ✅ Supported via Firebase Messaging + Service Worker
- ⚠️ Requires firebase-messaging-sw.js + VAPID key setup
- ❌ Safari < 16.4 and Firefox don't fully support

### 5. Huawei Devices (Vietnam)
- ⚠️ Huawei devices have NO Google Play Services
- ❌ FCM will NOT work on these devices
- ✅ Fallback option: HMS Push (requires separate integration)
- 💡 For MVP: Detect device, skip push gracefully

### 6. Permission State Storage
- ✅ Use `flutter_secure_storage` (already in pubspec)
- ❌ NOT `shared_preferences` (plain text)
- ❌ NOT SQLite (overkill)

### 7. Priming UX Pattern
- Two-phase recommended: In-app education sheet → OS permission dialog
- Bottom sheet widget pattern provided in full report
- Track "last shown" timestamp to avoid prompt spam (24h+ cooldown)

---

## Recommended Versions Table

| Package | Version | Min Flutter | Status |
|---------|---------|-------------|--------|
| permission_handler | **10.4.5** | 3.12+ | ⚠️ Do NOT upgrade to 12.x |
| firebase_messaging | 15.x | 3.3+ | ✅ Compatible |
| firebase_core | 3.1.x | 3.3+ | ✅ Compatible |
| flutter_local_notifications | 17.0.0 | 3.38.1+ | ✅ Compatible |
| flutter_secure_storage | 9.2.4 | 3.0+ | ✅ Already in pubspec |
| app_settings | 5.2.x | 3.0+ | ✅ Compatible |

---

## Implementation Roadmap

### Phase 1: Setup (1 day)
- [ ] Update pubspec.yaml with pinned versions
- [ ] Add POST_NOTIFICATIONS to AndroidManifest.xml
- [ ] Add firebase-messaging-sw.js to web/
- [ ] Generate VAPID key in Firebase Console

### Phase 2: Permission Services (2 days)
- [ ] Create PermissionCooldownManager (secure storage layer)
- [ ] Create NotificationService (FCM init + Huawei detection)
- [ ] Create NotificationPrimingSheet widget

### Phase 3: Platform-Specific Testing (2 days)
- [ ] iOS: Test provisional → full upgrade + iOS 18 edge case
- [ ] Android: Test on Android 13, 14, 15 (4-hour spacing for Android 15)
- [ ] Web: Test on Chrome/Edge/Firefox + Service Worker

### Phase 4: Integration (1 day)
- [ ] Add priming sheet to onboarding flow
- [ ] Wire up FCM token handling
- [ ] Analytics tracking (optional Phase 2)

---

## Code Snippets Provided

✅ Full PermissionCooldownManager (secure storage key-value manager)  
✅ NotificationService with Huawei detection logic  
✅ Complete NotificationPrimingSheet widget (UI + permission flow)  
✅ firebase-messaging-sw.js template  
✅ Web/index.html service worker registration pattern  
✅ iOS 18 AuthorizationStatus workaround  

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Flutter 3.12 incompatible with permission_handler 12.x | HIGH | Pinned to v10.4.5 in recommendations |
| iOS 18 AuthorizationStatus bug | MEDIUM | Treat `notDetermined` as deferred |
| Android 15 notification cooldown | LOW | Space requests ≥4 hours |
| Huawei devices (Vietnam) | MEDIUM | Detect early, skip FCM gracefully |
| Service Worker misconfiguration (Web) | MEDIUM | Template + clear error handling in docs |

---

## Next Steps

1. **Review** this summary + full report with team
2. **Confirm** recommended versions (may need MAJOR upgrade of Flutter to use latest packages)
3. **Schedule** platform-specific testing (iOS 18 emulator essential)
4. **Create** tech lead implementation plan from Phase roadmap
5. **Assign** developer to build PermissionService + NotificationPrimingSheet

---

## Full Report Location

**File:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-app/plans/260628-1700-permission-priming-onboarding/reports/researcher-flutter-permissions.md`

**Contains:**
- Task 1: Detailed version compatibility matrix + cross-package verification
- Task 2: iOS provisional API + iOS 18 bug workaround + "cannot re-request" limitation
- Task 3: Android 13+ POST_NOTIFICATIONS + auto-grant behavior by version
- Task 4: Web FCM service worker setup + VAPID key generation steps
- Task 5: Storage strategy (flutter_secure_storage) with code example
- Task 6: Huawei detection + HMS fallback (MVP approach)
- Task 7: iOS 18/Android 14-15 API changes + deprecations
- Task 8: Permission priming pattern example + bottom sheet widget code
- Implementation checklist (42 checkpoints across 6 phases)
- Risk assessment matrix

---

**Status:** ✅ RESEARCH COMPLETE — Ready for Tech Lead planning  
**Unresolved Questions:** 3 (see full report section on Huawei market size, cooldown timing, provisional vs. full strategy)
