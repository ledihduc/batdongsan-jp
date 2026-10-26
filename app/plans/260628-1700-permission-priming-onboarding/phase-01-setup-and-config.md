# Phase 01 — Setup & Config

**Status:** pending | **Effort:** 4h | **Depends on:** — | **Blocks:** all other phases

## Context Links

- BA Section 8 (Impact), Section 10.9 (tech stack pins)
- Researcher: `reports/researcher-flutter-permissions.md` Task 1 + Task 4
- Existing onboarding pattern: `lib/features/onboarding/onboarding_screen.dart`

## Overview

Foundation phase. Pin package versions for Flutter 3.12.2, register Firebase apps on all 3 platforms, declare permissions in platform manifests, scaffold web service worker. **No Dart logic** yet — just plumbing.

## Key Insights

- **Pin permission_handler at 10.4.5** (v12.x breaks at FL <3.24, see researcher Task 1).
- **Firebase init MUST be guarded by GMS check** on Android — done in Phase 5, but ANDROID GRADLE PLUGIN must be installed now.
- **Web service worker** path is `web/firebase-messaging-sw.js` (root, not nested) — Firebase enforces this.
- Existing `flutter_secure_storage` 9.2.4 already pinned; do not bump.

## Requirements

### Functional

- App must compile and launch on iOS 16+, Android 12+, Web Chrome/Firefox/Safari 16.4+ after this phase.
- No runtime behavior change yet (priming/push logic in later phases).
- No regression in current 6 `image_picker` call sites.

### Non-functional

- Bundle size delta < 6 MB (FCM + permission_handler combined).
- No breaking changes to existing `pubspec.yaml` constraints.
- iOS `aps-environment` entitlement uses `development` for dev / `production` for release (build config).

## Architecture

```
pubspec.yaml (modify)
    │ + permission_handler 10.4.5
    │ + firebase_core 3.1.x
    │ + firebase_messaging 15.x
    │ + flutter_local_notifications 17.0.0
    │ + app_settings 5.2.x
    │ + device_info_plus 11.x       (Huawei detect, AC-N9)
    │ + google_api_availability 5.x (GMS check, AC-N9)
    │
    ├── ios/Runner/Info.plist            (add usage strings + background mode)
    ├── ios/Runner/Runner.entitlements   (add aps-environment)
    ├── ios/Runner/GoogleService-Info.plist (NEW from Firebase console)
    │
    ├── android/app/build.gradle         (add gms plugin)
    ├── android/build.gradle             (add gms classpath)
    ├── android/app/src/main/AndroidManifest.xml (POST_NOTIFICATIONS + FCM service)
    ├── android/app/google-services.json (NEW from Firebase console)
    │
    └── web/index.html                   (add Firebase JS SDK + SW register)
        web/firebase-messaging-sw.js (NEW)
```

## Related Code Files

### Modify

- `pubspec.yaml` — add 6 packages with pinned versions.
- `ios/Runner/Info.plist` — add `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `UIBackgroundModes: remote-notification`.
- `ios/Runner/Runner.entitlements` — add `aps-environment` key.
- `ios/Podfile` — ensure platform :ios, '13.0' (FCM 15.x min).
- `android/build.gradle` — add `classpath 'com.google.gms:google-services:4.4.2'` in buildscript.
- `android/app/build.gradle` — apply `com.google.gms.google-services` plugin at bottom; bump `compileSdkVersion 34`, `minSdkVersion 21`.
- `android/app/src/main/AndroidManifest.xml` — add `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` (camera already present? verify), `<meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="ancu365_default"/>`, `<meta-data android:name="com.google.firebase.messaging.default_notification_icon" android:resource="@mipmap/ic_launcher"/>`.
- `web/index.html` — add `<script src="https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js">`, messaging-compat, init block with VAPID config, SW registration block.

### Create

- `ios/Runner/GoogleService-Info.plist` — from Firebase console (placeholder commit; ops to swap real values).
- `android/app/google-services.json` — same.
- `web/firebase-messaging-sw.js` — background message handler skeleton (see researcher Task 4 snippet, line 193).
- `docs/features/permission-priming-config.md` — short doc listing env keys + Firebase setup steps for ops.

### Delete

None.

## Implementation Steps

1. **Verify Firebase project exists.** Block until ops provides project ID + 3 config files. If blocked: create scratch Firebase project for dev so phase can proceed, swap later.
2. **Update `pubspec.yaml`** with pinned versions. Run `flutter pub get`. Confirm no resolver conflicts (in particular check `intl`, `meta` constraints from `firebase_core 3.x`).
3. **iOS:**
   - Drop `GoogleService-Info.plist` into `ios/Runner/`. Open `Runner.xcworkspace` → Runner target → "Add Files" → check "Copy if needed".
   - Edit `Info.plist` (use PlistBuddy or Xcode): add usage descriptions in Vietnamese:
     - `NSCameraUsageDescription` = `"ancu365 cần truy cập camera để bạn chụp ảnh CCCD, ảnh phòng và avatar."`
     - `NSPhotoLibraryUsageDescription` = `"ancu365 cần truy cập thư viện ảnh để bạn chọn ảnh phòng và CCCD đã chụp sẵn."`
     - `UIBackgroundModes` array → add `remote-notification`.
   - Edit `Runner.entitlements`: add `<key>aps-environment</key><string>development</string>`.
   - Add Push Notifications + Background Modes capabilities via Xcode Signing & Capabilities.
4. **Android:**
   - Drop `google-services.json` into `android/app/`.
   - Edit `android/build.gradle` add gms classpath under `buildscript.dependencies`.
   - Edit `android/app/build.gradle`: apply plugin line at bottom, bump SDKs.
   - Edit `AndroidManifest.xml`: add `POST_NOTIFICATIONS` permission, default channel meta-data.
5. **Web:**
   - Create `web/firebase-messaging-sw.js` with init + `onBackgroundMessage` skeleton. Use `firebase/compat` v10.13 for SW (matches index.html script version).
   - Edit `web/index.html`: add SDK script tags before `<app>`, add inline init block with VAPID public key placeholder `__VAPID_PUBLIC_KEY__`, add SW registration in a `<script>` after body.
   - Add VAPID key as `--dart-define=FIREBASE_VAPID_KEY=...` in build script (do not hardcode).
6. **Build verify (CRITICAL):**
   - `flutter clean && flutter pub get`
   - `flutter build apk --debug` → must succeed.
   - `flutter build ios --debug --no-codesign` → must succeed.
   - `flutter build web` → must succeed.
   - Launch on iOS simulator + Android emulator + Chrome — app must reach home screen without crash.
7. **Commit** with message `feat(permissions): add firebase + permission_handler foundation`.

## Todo List

- [ ] Confirm Firebase project + 3 config files available (Ops)
- [ ] Pin packages in `pubspec.yaml` and `pub get`
- [ ] iOS Info.plist + entitlements + GoogleService-Info.plist
- [ ] Android manifest + google-services.json + gradle plugin
- [ ] Web index.html + service worker skeleton + VAPID build flag
- [ ] Three-platform build verification
- [ ] Ops config doc `docs/features/permission-priming-config.md`

## Success Criteria

- All 3 platforms build green.
- App launches and existing flows (login, home, post-house) work unchanged.
- `flutter pub deps | grep firebase` shows pinned versions.
- No new runtime behavior visible to user (priming logic comes in Phase 4).

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Firebase config files unavailable | M | H | Create dev-only project to unblock; swap before release |
| `permission_handler` resolver fights existing deps | L | M | Pinned 10.4.5 verified compatible (researcher Task 1) |
| Web build breaks from Firebase JS SDK | M | M | Use compat SDK 10.13 (matches researcher example); test in Chrome first |
| Android Gradle plugin version mismatch | L | M | Use `gms:google-services:4.4.2` (current LTS) |
| iOS bundle ID drift between Firebase and Xcode | M | H | Verify Bundle ID matches Firebase iOS app config before adding plist |

## Security Considerations

- VAPID public key is public-safe but inject via `--dart-define`, never hardcode.
- `GoogleService-Info.plist` and `google-services.json` contain API keys that are **restricted by package name / bundle ID** — safe to commit (Firebase best practice), but verify restriction is set in console.
- No secrets in `firebase-messaging-sw.js`.
- iOS `aps-environment=development` MUST flip to `production` in release builds (use Xcode build configuration, not file edit).

## Next Steps

- Phase 2 (Core module) and Phase 3 (UI widgets) can begin in parallel.
- Ops confirms BE endpoints scaffolded for Phase 6.
