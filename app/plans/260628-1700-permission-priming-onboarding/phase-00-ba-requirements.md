# Phase 00 — BA Requirements: Permission Priming & Notification Opt-in

**Plan:** 260628-1700-permission-priming-onboarding
**Author:** BA (Main Claude)
**Date:** 2026-06-28
**Status:** Draft → Awaiting user approval

---

## 1. Problem Statement

Hiện trạng `ancu365`:
- App đang sử dụng quyền **Camera + Photo Library** (qua `image_picker`) ở 6+ chỗ: CCCD onboarding, đăng tin nhà, edit profile, contract host, báo lỗi planning.
- App **chưa có push notification** — chỉ in-app fetch `/api/notifications`. Khi user không mở app → bỏ lỡ booking, chat, status update.
- Khi gọi `image_picker.pickImage(camera)`, OS bật **dialog quyền hệ thống NGAY LẬP TỨC** — user thấy popup lạnh lùng, không hiểu vì sao cần, dễ bấm **"Don't Allow"**.
- iOS: nếu user bấm "Don't Allow", **OS không bao giờ hiện lại popup** → muốn bật phải vào Settings thủ công → tỷ lệ phục hồi gần 0.
- Android 13+: notification permission là **runtime** (POST_NOTIFICATIONS), không còn auto-grant. Camera cũng runtime.

**Vấn đề cốt lõi:** Mất tỷ lệ opt-in vì user gặp dialog hệ thống mà không hiểu "tại sao app cần quyền này" và "tôi được lợi gì".

---

## 2. User Psychology Analysis (cốt lõi của yêu cầu)

### 2.1 Hành vi tâm lý khi gặp popup quyền

| Tâm lý | Phản ứng | Hệ quả nếu app không priming |
|---|---|---|
| **Loss aversion** (sợ mất) | "Cho quyền = app spam tôi / theo dõi tôi" | Bấm Deny theo phản xạ |
| **Cognitive load** | "Tôi không hiểu micro/camera/notification dùng làm gì" | Bấm Deny để cho xong |
| **Trust deficit** với app lạ | App vừa mở đã đòi quyền = "app này có vấn đề" | Uninstall hoặc Deny |
| **Default bias** | "Tôi không thay đổi gì cả" | Bấm Deny (nút bên trái OS) |
| **Reciprocity** | "Tôi đã thấy app làm gì có ích cho tôi rồi" | Sẵn sàng cho quyền |

### 2.2 Nguyên tắc UX priming đã chứng minh

Theo nghiên cứu Apple HIG, Google Material, và case study Cluster (2014): **priming screen tăng opt-in từ 40% → 65–90%**.

**Bốn nguyên lý áp dụng cho ancu365:**

1. **"Why first, ask later"** — Giải thích lợi ích CỤ THỂ cho user trước, OS dialog là confirm chứ không phải intro.
2. **Just-in-time** (JIT) — Xin quyền tại đúng thời điểm user cần tính năng đó, không xin hàng loạt ngay sau onboarding.
   - VD: chỉ xin camera khi user bấm **"Tải ảnh CCCD"** lần đầu, không xin ngay khi mở app.
3. **Soft ask trước, hard ask sau** — Custom sheet/dialog "do-it-yourself" với nút **"Để sau"** (không trigger OS) — nếu user OK mới gọi OS API.
4. **Recover path** — Khi user đã Deny, cung cấp UI hướng dẫn vào Settings + giải thích lại lợi ích.

### 2.3 Đặc thù user Việt Nam (insight quan trọng)

- User Việt **cảnh giác cao với notification** vì bị app vay tiền / e-commerce spam.
- Ngược lại, **chấp nhận camera dễ hơn** vì hiểu rõ "muốn upload ảnh thì phải dùng camera".
- Ngôn ngữ priming cần **rất cụ thể, tránh marketing fluff**:
  - ❌ "Để có trải nghiệm tốt nhất, hãy bật thông báo"
  - ✅ "Bật thông báo để biết ngay khi chủ nhà duyệt lịch xem nhà của bạn"

---

## 3. User Stories

### Epic 1: Notification Permission Priming

- **US-1.1** Là **khách thuê (guest)**, tôi muốn biết bật thông báo sẽ giúp tôi nhận được gì (chủ nhà duyệt lịch, có nhà mới phù hợp, chat reply), để tôi quyết định có bật hay không một cách có thông tin.
- **US-1.2** Là **chủ nhà (host)**, tôi muốn biết bật thông báo sẽ giúp tôi không bỏ lỡ booking mới, để không mất khách vì phản hồi chậm.
- **US-1.3** Là **admin**, tôi muốn nhận alert ngay khi có host pending duyệt / báo cáo vi phạm, để xử lý kịp thời mà không phải kiểm tra dashboard liên tục.
- **US-1.4** Là user **đã từ chối lần đầu**, tôi muốn có cách bật lại quyền dễ dàng từ trong app (không phải tự mò Settings).
- **US-1.5** Là user **iOS**, tôi vẫn muốn nhận một vài notification "thử" trước khi quyết định bật chính thức (provisional flow) — để đánh giá chất lượng notification của app trước.
- **US-1.6** Là user **web (PWA)** trên Chrome desktop / mobile, tôi muốn được giải thích lợi ích trước khi browser hiện popup quyền notification.

### Epic 2: Camera/Photo Permission Priming

- **US-2.1** Là user **đăng tin nhà / upload CCCD lần đầu**, tôi muốn hiểu vì sao app cần camera/thư viện ảnh trước khi OS hỏi, để không bấm Deny theo phản xạ.
- **US-2.2** Là user **đã Deny camera**, khi tôi cố upload ảnh, tôi muốn được hướng dẫn rõ cách bật lại trong Settings (deep link nếu được).

### Epic 3: Centralized Permission UX

- **US-3.1** Là user, tôi không muốn bị spam popup quyền **ngay lúc vừa mở app lần đầu** — tôi muốn dùng app vài phút trước đã (build trust).
- **US-3.2** Là user, tôi muốn các priming screen có **visual nhất quán** với brand ancu365 (màu, icon, tone).

---

## 4. Acceptance Criteria (testable)

### AC nhóm Notification

- **AC-N1** Có một priming screen riêng cho push notification, chứa:
  - 3 lợi ích cụ thể theo role (guest / host / admin — 3 variant copy khác nhau)
  - Nút primary "Bật thông báo" → trigger OS permission request (Android/Web) hoặc provisional+full request (iOS, xem AC-N5)
  - Nút secondary "Để sau" → đóng sheet, KHÔNG gọi OS API, lưu state để hỏi lại sau N ngày
- **AC-N2** Priming notification hiển thị **sau khi user login thành công lần đầu** (apply cho cả 3 role: guest/host/admin). Một lần duy nhất per install, trừ khi defer/deny qua hạn cooldown.
- **AC-N3** Nếu user bấm "Để sau", app **không hỏi lại trong ≥ 7 ngày**. Nếu user Deny ở OS dialog, app **không hỏi lại trong ≥ 30 ngày** và chỉ hỏi qua **soft re-ask** (banner in-app, không trigger OS).
- **AC-N4** Có deep-link helper mở Settings của app khi user Denied vĩnh viễn (`app_settings` package hoặc `permission_handler.openAppSettings()`).
- **AC-N5** **iOS provisional flow:** khi user bấm "Bật thông báo" trên iOS, request `[.alert, .badge, .sound, .provisional]` — notification sẽ deliver quiet trước. Sau khi user nhận ≥ 1 notification chất lượng → iOS tự hiện CTA "Keep / Turn Off". Nếu user "Keep" → upgrade lên full permission. Trên Android/Web không có khái niệm này, dùng flow chuẩn.
- **AC-N6** **Web (PWA)** notification priming: cùng sheet UI responsive, nhưng:
  - Trigger `Notification.requestPermission()` qua `firebase_messaging_web`
  - Service worker `firebase-messaging-sw.js` ở `/web` để nhận background push
  - VAPID key config trong `main.dart` web init
  - Nếu browser không support push (Safari iOS < 16.4) → ẩn priming, dùng in-app fetch như hiện tại

### AC nhóm Camera/Photo

- **AC-C1** Tại 4 điểm hiện đang gọi `image_picker.pickImage(camera)` (CCCD, post_house, edit_profile, contract, report_error), trước khi gọi `pickImage` LẦN ĐẦU:
  - Hiển thị bottom sheet priming giải thích cụ thể vì sao cần (vd CCCD: "Chúng tôi cần ảnh CCCD để xác minh bạn là chủ nhà thật — bảo vệ khách thuê khỏi lừa đảo").
  - Nút "Tiếp tục" → mới gọi `pickImage` (OS sẽ hiện popup).
  - Nút "Huỷ".
- **AC-C2** Priming bottom sheet **chỉ hiện lần đầu cho mỗi context** (CCCD upload, post house, …). Lần 2 trở đi đi thẳng vào picker.
- **AC-C3** Nếu user đã Deny camera/photo, khi cố dùng lại → hiện dialog "Bật quyền trong Settings" với CTA mở Settings.

### AC nhóm UX/Visual

- **AC-V1** Tất cả priming screen dùng cùng design system: brand colors (đỏ `#B71C1C` / xanh `#00A65A`), icon outline lớn 64px, tone copy thân thiện-cụ thể, có illustration hoặc icon (không photo).
- **AC-V2** Priming có thể test bằng cách reset flag (debug menu hoặc xoá secure-storage key).
- **AC-V3** Tất cả copy ở **tiếng Việt**, có placeholder để mở rộng EN sau (i18n-ready).

### AC nhóm Quantitative (đo lường)

- **AC-M1** Có **analytics event** cho mỗi priming, lưu **CẢ 2** layer:
  - **Local** (SQLite hoặc secure storage): events `prime_shown`, `prime_accept`, `prime_defer`, `os_grant`, `os_deny`, `os_provisional_upgrade`, `settings_opened` — với metadata `{ role, context, platform, ts }`.
  - **Backend:** batch upload qua endpoint mới `POST /api/analytics/permission-events` mỗi lần app foreground (sau khi đã có local). Retry nếu fail (offline-safe).
- **AC-M2** **Target opt-in:** ≥ 65% cho notification (baseline industry: ~40% nếu xin trực tiếp), ≥ 85% cho camera tại điểm có priming.
- **AC-M3** Endpoint BE phải authenticated (JWT) và schema-validated (whitelist event names + role enum).

---

## 5. Out of Scope (giai đoạn này)

- ❌ **Logic gửi push từ server** (FCM topic publishing, notification scheduling) — BA này CHỈ lo: xin quyền + nhận FCM token + lưu token lên BE + hiển thị notification khi nhận. Backend trigger là feature riêng.
- ❌ **Location permission** — app hiện không cần GPS user; bản đồ chỉ render, không cần "vị trí của tôi".
- ❌ **Microphone** — chưa có voice/video call.
- ❌ **Background location / Always-allow** — không cần.
- ❌ **Contacts / SMS** — không cần.
- ❌ Implement A/B test cho variants priming.
- ❌ Đa ngôn ngữ (chỉ chuẩn bị structure, không dịch).
- ❌ **Rich notification** (image, action buttons) — phase sau.
- ❌ **In-app notification center redesign** — vẫn dùng `notifications_screen.dart` hiện tại.

---

## 6. Open Questions (cần user clarify trước khi sang Phase 2)

1. **Push notification stack:** dùng **Firebase Cloud Messaging (FCM)** hay **OneSignal** hay **provider khác**? (BA recommend FCM vì free + cross-platform + Google Maps đã quen.)
2. **Khi nào trigger priming notification cho guest?** Lựa chọn (a) sau login, (b) sau gửi yêu cầu xem nhà đầu tiên, (c) sau xem ≥ 3 nhà. BA recommend **(b)** vì engagement cao nhất.
3. **iOS provisional notification** (delivered quietly without permission popup) có muốn dùng không? Pro: bypass dialog, Con: notification vào "Notification Center" thay vì lock screen.
4. **Notification cho admin role?** Có cần priming khác cho admin (e.g. moderation alert) không, hay admin dùng web?
5. **Camera trên web (PWA)?** Hiện code có `kIsWeb` branch — web có cần priming không (browser tự xin quyền)? BA recommend **skip web cho priming**, chỉ làm cho iOS/Android.
6. **Analytics backend:** event `prime_shown/accept/...` lưu local hay gửi lên BE (endpoint mới)? Có dashboard không?
7. **Đo lường thành công:** sau bao lâu sẽ review opt-in rate (1 tuần / 1 tháng)? Threshold rollback?

---

## 7. Decisions (user confirmed 2026-06-28)

| # | Decision | Impact |
|---|---|---|
| D1 | Push provider = **FCM** | Cần Firebase project + `google-services.json` / `GoogleService-Info.plist`; web cần Firebase JS SDK + VAPID key |
| D2 | Trigger priming notification (both guest + host + admin) = **sau login thành công lần đầu** | Đơn giản hoá: 1 trigger duy nhất cho mọi role; không phụ thuộc viewing flow |
| D3 | **Dùng iOS provisional notification** (`UNAuthorizationOptionProvisional`) | Trên iOS: gửi notification quietly vào Notification Center trước khi user grant; sau N notification user sẽ thấy CTA "Keep / Turn Off" từ OS |
| D4 | **Admin có priming riêng** (copy khác guest/host) | Cần variant: moderation alert, host approval queue, system event |
| D5 | **Web/PWA in scope** | Cần Web Push (FCM JS SDK + Service Worker), priming sheet phải responsive |
| D6 | **Analytics lưu CẢ 2** (local SQLite + push BE) | Cần endpoint mới `POST /api/analytics/permission-events` (batch upload) |
| D7 | Cooldown = **7 ngày defer / 30 ngày deny** | Lưu timestamp trong secure storage hoặc SharedPreferences |

### Consequences from decisions

- **D2 → tất cả role** show priming ngay sau login → cần ensure không spam (1 lần duy nhất per install, trừ khi defer/deny qua hạn cooldown).
- **D3 → iOS-only feature** — cần config riêng iOS, Android không có concept tương đương; fallback Android = priming sheet truyền thống.
- **D4 → cần 3 variants copy** (guest/host/admin), tách config thành map theo role.
- **D5 → web cần stack riêng:** `firebase_messaging_web`, service worker `firebase-messaging-sw.js`, không có camera permission priming (browser tự handle), chỉ có notification priming.
- **D6 → 2 storage layer:** local-first (offline-safe), background flush BE theo batch.

---

## 8. Impact / Risk Assessment

### Code impact (hiện trạng đã khảo sát)

| File / area | Impact |
|---|---|
| `pubspec.yaml` | Thêm `permission_handler`, `firebase_core`, `firebase_messaging`, `flutter_local_notifications`, optional `app_settings` |
| `ios/Runner/Info.plist` | Thêm `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, background mode `remote-notification` |
| `ios/Runner/Runner.entitlements` | `aps-environment` = `development` (dev) / `production` (release) |
| `ios/Runner/GoogleService-Info.plist` | Firebase config iOS (cần Firebase project) |
| `android/app/src/main/AndroidManifest.xml` | Thêm `POST_NOTIFICATIONS`, `CAMERA`, FCM intent filter |
| `android/app/google-services.json` | Firebase config Android |
| `android/app/build.gradle` | `com.google.gms:google-services` plugin |
| `web/index.html` | Firebase JS SDK script + service worker registration |
| `web/firebase-messaging-sw.js` (NEW) | Background message handler for web push |
| `lib/features/onboarding/` | **Không sửa** onboarding hiện tại — priming là module riêng |
| `lib/core/permissions/` (NEW) | Module mới: `permission_service.dart`, `priming_sheets.dart`, `permission_storage.dart` |
| `lib/features/host/onboarding/widgets/cccd_uploader.dart` | Wrap `_pickImage` với priming guard |
| `lib/features/guest/post/post_house_screen.dart` | Wrap picker với priming guard |
| `lib/features/guest/profile/edit_profile_screen.dart` | Wrap picker |
| `lib/features/host/property/screens/contract_*.dart` | Wrap picker |
| `lib/features/planning/report/report_error_screen.dart` | Wrap picker |
| `lib/providers/notification_provider.dart` | Thêm push token registration, foreground handler |
| `lib/main.dart` | Init Firebase, register background handler |
| BE | Endpoint mới `POST /api/users/me/push-token` để lưu FCM token (out of scope BA, ghi nhận) |

### Rủi ro

- **R1 — Permission decisions là one-shot trên iOS:** Nếu test sai sót → user thật bị Deny → không bao giờ priming lại được. **Mitigation:** test kỹ trên TestFlight + simulator, dev tool reset.
- **R2 — Firebase config:** cần `google-services.json` (Android) + `GoogleService-Info.plist` (iOS) — phải có Firebase project trước. **Mitigation:** clarify với user việc setup Firebase project.
- **R3 — Bundle size tăng** ~3–5MB khi add Firebase. **Mitigation:** acceptable trade-off cho push.
- **R4 — User Việt nhạy cảm với "spam" notification** — nếu copy priming không thuyết phục → opt-in thấp. **Mitigation:** copy review + A/B test sau.
- **R5 — Web build broken** sau khi add Firebase plugins nếu không config đúng platform. **Mitigation:** conditional import + test web build trong phase developer.

### Backward compatibility

- Không phá flow hiện tại (CCCD, post house vẫn upload được).
- Onboarding flow hiện tại không đổi.
- User đã đăng nhập sẵn (không xoá app) — sẽ thấy priming notification ở next trigger event.

---

## 9. Success Definition

Feature được coi là **done** khi:
1. ✅ Tất cả AC ở mục 4 pass.
2. ✅ Test trên iPhone (iOS 16+) và Android (13+ và 12) — cả 2 platform behave đúng.
3. ✅ Reset script chạy được để dev/QA test lại priming.
4. ✅ Có doc trong `./docs/features/permission-priming.md` mô tả copy + trigger logic + recover path.
5. ✅ FCM token được lưu lên BE và backend có thể gửi test notification.

---

## 10. Phase 2 — BA Leader Revisions (applied 2026-06-28)

Full review: `reports/ba-leader-review.md`. Rating: NEEDS_REVISION → revisions below address all 3 CRITICAL + 6 HIGH items. Open questions answered with BA recommendation pending user confirmation at Gate 3.

### 10.1 New ACs (added)

| ID | AC |
|---|---|
| **AC-N7** | Priming cooldown keyed by `(userId + installId)` in `flutter_secure_storage` key `priming_v1:{userId}`. On logout: do NOT clear previous user's cooldown. On new-user login: evaluate cooldown for that userId fresh. |
| **AC-N8** | On role upgrade (guest→host, host→admin): re-trigger priming **once** with new role copy if user previously **accepted**. If previously **denied** at OS level → soft re-ask banner only, no OS dialog re-trigger. |
| **AC-N9** | At startup on Android: detect GMS via `GoogleApiAvailability.isGooglePlayServicesAvailable()`. If unavailable: skip FCM init, hide notification priming, log `fcm_unavailable_gms_missing`, fallback to in-app polling (current behavior). Don't crash, don't promise feature. |
| **AC-T1** | FCM token registered per-device. BE endpoint `POST /api/users/me/push-token` accepts `{ token, deviceId, platform }` and stores as **list per user**. On logout: `DELETE /api/users/me/push-token` to unregister current device. On token refresh: re-register. |
| **AC-V4** | Debug menu (dev build only, `kDebugMode`) exposes "time-skip" toggle that advances stored cooldown timestamps by N days. Excluded from release via `kReleaseMode` guard. |

### 10.2 Revised ACs (replace previous wording)

- **AC-N2 (revised):** Priming triggers on **first successful login per `(userId, installId)` pair** (across all roles guest/host/admin), tracked in `flutter_secure_storage`. Reinstall = treat as first-time (state lives only in local storage).
- **AC-N5 (revised — iOS provisional + APNs reality):** Priming copy on iOS does NOT promise sample notification timing. Server sends "welcome" provisional notification within 5min of grant. If APNs feedback shows no delivery within 24h → automatically downgrade UX to soft re-ask banner (don't keep waiting).
- **AC-N6 (revised — web pre-check):** On web, check `Notification.permission` BEFORE rendering priming. `granted` → skip priming, just register FCM web token. `denied` → show recover-path UI instead of priming. Only `default` shows full priming.
- **AC-M3 (revised — analytics security):** Endpoint JWT-authenticated. Buffered events while logged out are **discarded on next login** (no retroactive send). Rate-limited 60 req/min/user. Payload whitelist server-side: reject unknown fields with HTTP 400. No PII (no userAgent/IP/deviceModel).
- **AC-M2 (revised — measurement window):** Measured over 14 days post-rollout, min 500 unique users per role; targets ≥65% notif / ≥85% camera.

### 10.3 New user stories

- **US-1.7** Là user dùng app trên nhiều thiết bị, tôi muốn nhận notification ở thiết bị đang active, không bị "ghost" notification sau khi logout.
- **US-1.8** Là user upgrade từ guest sang host, tôi muốn được nhắc bật notification cho event mới của host dù trước đó đã bật cho guest events.

### 10.4 New decisions (D8–D11) — **✅ CONFIRMED by user 2026-06-28 (Gate 3)**

| # | Question | BA recommendation | Rationale |
|---|---|---|---|
| **D8** | Multi-device model | **Allow multiple active devices simultaneously** (token list per user) | FCM SDK supports it natively; user expectation = "get notifications on whatever phone I'm using"; matches Airbnb/Grab UX |
| **D9** | Huawei / non-GMS Android | **Silently hide notification feature** (no error message) on devices without GMS | Surfacing "your phone can't get notifications" creates bad feeling for low-end users; in-app polling still works; instead log analytics to size the problem |
| **D10** | iOS provisional fallback on VN APNs failure | **Auto-escalate to soft re-ask banner after 24h of no APNs delivery** | Trust preservation: if user expects notif and doesn't get one → fix it; banner is non-intrusive recovery |

### 10.5 D2 contradiction resolution (per BA Leader C3)

D2 = "trigger after login" is intentionally a **relaxation of Section 2.2 JIT principle for notification ONLY**, with explicit rationale:
- Notification value depends on **future async events the user can't trigger himself** (chủ nhà duyệt, admin alert) — no natural JIT moment exists.
- Industry data (see `researcher-priming-ux-copy.md`): post-login asks outperform deep-funnel asks when copy is role-specific.
- **JIT remains FULLY PRESERVED for camera** (AC-C1): camera priming only at the moment user taps "Tải ảnh" — direct context.

### 10.6 New decision D11 — admin priming target

- **D11:** Admin uses **BOTH web (primary dashboard) and mobile (on-call alerts)**. Mobile admin priming **IS in scope** (resolves doc contradiction between Open Q4 and decision D4).

### 10.7 New risk

- **R6 — Huawei / non-GMS device crash:** ~3–8% of VN Android base. Without GMS check, `Firebase.initializeApp()` crashes → app won't launch. Mitigation = AC-N9 (detect + skip).

### 10.8 MEDIUM/LOW corrections applied inline

- **M1:** Count is **6 places** calling `image_picker` (lib/features/host/onboarding/widgets/cccd_uploader.dart, lib/features/host/property/screens/contract_form_screen.dart, lib/features/host/property/screens/contract_terminate_screen.dart, lib/features/guest/post/post_house_screen.dart, lib/features/guest/profile/edit_profile_screen.dart, lib/features/planning/report/report_error_screen.dart). All 6 in scope for AC-C1.
- **M2:** App killed mid-priming = treat as defer (7-day cooldown applies).
- **M3:** Storage backend = **`flutter_secure_storage` only** (consistent with `_onboardingKey` pattern in `onboarding_screen.dart`). Do NOT mix with SharedPreferences.
- **M5:** Add `flutter_local_notifications` channel setup for Android 8+ to AC-N1 (channel `ancu365_default` with importance HIGH for foreground display).
- **L2:** Impact table addition: `lib/core/router/app_router.dart` — register `/permission-debug` route (dev-only).

### 10.9 Tech stack pins (from researcher report)

- `permission_handler` = **^10.4.5** (NOT v12.x — incompatible with Flutter 3.12)
- `firebase_core` ≈ 3.1.x, `firebase_messaging` ≈ 15.x, `flutter_local_notifications` 17.x
- `flutter_secure_storage` 9.2.4 (already pinned)
- `app_settings` 5.2.x

### 10.10 Final BA rating after revisions

**READY → for Tech Lead Phase 3 planning.** Open items at Gate 3: user to confirm D8/D9/D10/D11.

---
