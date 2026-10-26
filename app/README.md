# ancu365 Flutter App

## Requirements

- Flutter stable with Dart SDK compatible with `pubspec.yaml`
- Chrome for web builds/tests
- Backend API running and reachable from the target device/browser

Check toolchain:

```powershell
flutter doctor -v
flutter --version
```

Install packages:

```powershell
flutter pub get
```

## Run Locally

Run web in Chrome against a local backend:

```powershell
flutter run -d chrome --web-port=5000 --dart-define=API_BASE_URL=http://localhost:3000
```

If the backend is served from the same origin as the web app, `API_BASE_URL` can be omitted.

## Build Web

Build production web assets:

```powershell
flutter build web --release --dart-define=API_BASE_URL=https://ancu365.ddns.net
```

For same-origin deployment through Nginx or another reverse proxy:

```powershell
flutter build web --release
```

The output is written to:

```text
build/web
```

Serve the built web folder locally:

```powershell
node serve_web_static.cjs
```

Then open:

```text
http://localhost:5000
```

## Build Android

Build a release APK:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://ancu365.ddns.net
```

Build an Android App Bundle for Play Store:

```powershell
flutter build appbundle --release --dart-define=API_BASE_URL=https://ancu365.ddns.net
```

Outputs:

```text
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
```

## Build iOS

iOS builds must be run on macOS with Xcode installed. Windows cannot build or archive an iOS app directly.

Check iOS toolchain on the Mac:

```bash
flutter doctor -v
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

Install Flutter and iOS packages:

```bash
flutter pub get
cd ios
pod install
cd ..
```

Run on an iOS simulator:

```bash
flutter run -d ios --dart-define=API_BASE_URL=https://ancu365.ddns.net
```

Build a release app for a connected iPhone:

```bash
flutter build ios --release --dart-define=API_BASE_URL=https://ancu365.ddns.net
```

Build an App Store archive. Open the generated project in Xcode, then use Product > Archive:

```bash
flutter build ipa --release --dart-define=API_BASE_URL=https://ancu365.ddns.net
open ios/Runner.xcworkspace
```

> **⚠️ Các lệnh iOS/Android ở trên đã LỖI THỜI.** Từ 03/09/2026 môi trường
> production cũ (`digilab.ddns.net`, `ancu.digi-lab.vn`) đã bị gỡ; chỉ còn
> `https://ancu365.ddns.net`. Ngoài `API_BASE_URL` còn phải truyền thêm
> `PUBLIC_SITE_URL` và `LEGAL_BASE_URL` — hai cái đó mặc định trỏ vào domain đã
> tắt.
>
> **Lệnh đúng + lý do từng tham số: [`docs/BUILD.md`](docs/BUILD.md).**

Before uploading to App Store Connect:

```bash
flutter analyze --no-fatal-infos
```

In Xcode, set:

```text
Runner > Signing & Capabilities > Team
Runner > Bundle Identifier = vn.ancu365.app
```

Use the same Bundle Identifier in Apple Developer, Firebase, and App Store Connect.

Firebase iOS setup:

```text
Firebase Console > Project settings > Add app > iOS
iOS bundle ID: vn.ancu365.app
App nickname: ancu365 iOS
Download GoogleService-Info.plist
Place it at ios/Runner/GoogleService-Info.plist
```

Outputs:

```text
build/ios/iphoneos/Runner.app
build/ios/ipa/*.ipa
```

## Notes

- Web push/Firebase is optional right now. The app can run without Firebase config.
- If using web push later, configure Firebase web app values in `web/index.html`, `web/firebase-messaging-sw.js`, and wire the VAPID key before building.
- On Windows, enable Developer Mode if Flutter plugin symlink support is required.
