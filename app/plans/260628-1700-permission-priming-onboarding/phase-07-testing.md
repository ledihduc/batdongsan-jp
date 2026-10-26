# Phase 07 — Testing

**Status:** pending | **Effort:** 6h | **Depends on:** Phase 4 + 5 + 6 | **Blocks:** — (final phase)

## Context Links

- BA Section 9 (Success Definition), Section 10.1 AC-V4 (debug time-skip)
- All AC IDs (22 total)
- Phases 2–6 deliver code under test

## Overview

Comprehensive test suite covering unit (cooldown + role-upgrade logic), widget (priming sheets per role/context), integration (login → priming → grant; deny → recover), and manual matrix across 12 platforms/browsers. Includes debug time-skip menu for cooldown verification.

## Key Insights

- **Time-dependent logic** (cooldown 7d / 30d) is hardest to test — use AC-V4 debug skip + injected `Clock` dependency.
- **Widget golden tests** verify per-role copy renders correctly (catches copy drift).
- **Integration tests** focus on 3 paths: golden (accept), deny path (recover banner), Huawei skip (no sheet ever).
- **Manual matrix** is the only way to test real OS permission dialogs — automation can't drive them.
- **No live FCM** in integration tests — mock `FirebaseMessaging` via wrapper interface from Phase 2.

## Requirements

### Functional

- Unit tests: ≥85% coverage of `lib/core/permissions/`.
- Widget tests: 1 golden per role variant (3) + 1 per camera context (6) = 9 goldens minimum.
- Integration tests: 3 e2e flows (golden, deny, Huawei).
- Manual matrix: 12 platforms × key flows, signed off in `docs/features/permission-priming-test-report.md`.

### Non-functional

- All tests deterministic — inject `Clock`, inject mock storage.
- Tests run under `flutter test` < 60s total (excluding integration).
- Integration tests run via `flutter test integration_test/` < 5min.
- No flake on CI from time/timezone.

## Architecture (test layout)

```
test/
├── core/
│   └── permissions/
│       ├── permission_storage_test.dart       (CRUD + key namespacing)
│       ├── permission_service_test.dart       (cooldown + role upgrade)
│       ├── permission_events_test.dart        (queue cap + clear)
│       ├── fcm_service_test.dart              (token register/refresh, provisional)
│       ├── gms_detector_test.dart             (platform branches)
│       └── permission_analytics_uploader_test.dart (batch + backoff)
├── features/
│   └── permissions/
│       └── widgets/
│           ├── notification_priming_sheet_test.dart  (3 role goldens + interactions)
│           ├── camera_priming_sheet_test.dart        (6 context goldens)
│           ├── soft_reask_banner_test.dart
│           └── permission_settings_card_test.dart
└── helpers/
    ├── mock_storage.dart       (in-memory FlutterSecureStorage stub)
    ├── mock_fcm.dart           (FakeFirebaseMessaging)
    ├── mock_dio.dart           (MockAdapter for analytics endpoint)
    └── clock_test_helper.dart  (injectable Clock)

integration_test/
├── golden_path_test.dart       (login → sheet → grant → token registered)
├── deny_path_test.dart         (login → sheet → deny → recover banner appears later)
└── huawei_skip_test.dart       (GMS unavailable → no sheet → polling continues)
```

## Test Cases by AC

### Unit tests

| AC | Test |
|----|------|
| AC-N2 | `permission_service_test`: first-login → `shouldShow` returns true; second-login same userId → false |
| AC-N3 | `permission_service_test`: defer → skip 6 days → false; skip 1 more day → true; deny → skip 29 days → false; skip 1 more → true |
| AC-N7 | `permission_storage_test`: write userId=1, read userId=2 → empty (per-user keys) |
| AC-N7 | `permission_storage_test`: `clearUser(1)` does not touch userId=2 keys |
| AC-N8 | `permission_service_test`: user accepted as guest, role→host → `shouldRetriggerOnRoleUpgrade` true |
| AC-N8 | `permission_service_test`: user denied as guest, role→host → returns false (banner only) |
| AC-N9 | `gms_detector_test`: mock `GoogleApiAvailability.SERVICE_MISSING` → false; iOS → true; web → check `supportsWebPush` |
| AC-N5 | `fcm_service_test`: provisional grant → 24h skip → `checkFallbackTimer` returns true |
| AC-N5 | `fcm_service_test`: provisional grant → message received within 24h → fallback never triggers |
| AC-T1 | `fcm_service_test`: register on device1 then device2 → 2 POSTs sent; logout device1 → 1 DELETE only |
| AC-M1 | `permission_events_test`: capture 250 events → queue cap at 200 (oldest 50 dropped) |
| AC-M3 | `uploader_test`: 401 response → queue cleared; 429 → backoff state set |
| AC-C2 | `permission_service_test`: first call `shouldShowCameraPriming(cccdUpload)` true; second false |
| AC-V4 | `permission_storage_test`: `skipDays(7)` advances stored timestamps by 7d |

### Widget tests

| AC | Test |
|----|------|
| AC-N1 | `notification_priming_sheet_test`: pump with role=guest → contains exact VN copy from `priming_copy.dart` |
| AC-N1 | Same for host, admin (3 golden files) |
| AC-N1 | Tap "Bật thông báo" → `onAccept` called; tap "Để sau" → `onDefer` |
| AC-C1 | `camera_priming_sheet_test`: pump with each `CameraContext` → 6 golden files |
| AC-C1 | Tap "Tiếp tục" → `onContinue` called; tap "Huỷ" → `onCancel` |
| AC-V1 | Visual snapshot — brand red primary button, brand color icon circle |
| AC-V3 | Semantic test: all interactive widgets have `Semantics.label` |
| AC-N4 | `soft_reask_banner_test`: tap "Mở Cài đặt" → `onOpenSettings` called |

### Integration tests (`integration_test/`)

| AC | Test |
|----|------|
| AC-N2 + AC-T1 | `golden_path_test`: fresh install → login → priming sheet visible → tap "Bật" → mock OS returns granted → token POST sent to mock BE |
| AC-N3 + AC-N4 | `deny_path_test`: login → priming → tap "Bật" → OS returns denied → close sheet → trigger second app-foreground → soft re-ask banner visible |
| AC-N9 | `huawei_skip_test`: inject `GmsDetector.isFcmAvailable() = false` → login → NO priming sheet → existing polling Provider still runs |
| AC-C1 + AC-C2 | (Manual — image_picker can't be automated): user taps "Tải ảnh CCCD" → sheet appears → tap "Tiếp tục" → OS dialog → cancel; second tap → sheet appears AGAIN if user cancelled (sheet only persists on accept) |

## Manual Test Matrix (sign-off in test-report.md)

Run once before release. Reference Phase 5 matrix table.

| # | Platform | Test | Pass? | Notes |
|---|----------|------|-------|-------|
| 1 | iOS 16 sim | Login → sheet → grant | | |
| 2 | iOS 17 sim | Login → sheet → defer → reopen app same day → no sheet | | |
| 3 | iOS 18 sim | Login → sheet → dismiss (swipe down) → treated as defer | | |
| 4 | iOS 18 sim | Provisional grant → background → server pushes test notif → tap → opens correct screen | | |
| 5 | iOS 18 sim | Provisional grant → 24h debug skip → soft re-ask appears | | |
| 6 | Android 12 emu | Login → sheet → grant → no OS dialog (auto-granted on <33) | | |
| 7 | Android 13 emu | Login → sheet → "Bật" → OS POST_NOTIFICATIONS dialog → grant | | |
| 8 | Android 14 emu | Same as Android 13 | | |
| 9 | Android 15 emu | Same as Android 13 + verify no cooldown clash | | |
| 10 | Chrome desktop | Login → sheet → "Bật" → browser permission popup → grant → SW receives test bg msg | | |
| 11 | Chrome mobile | Same as desktop | | |
| 12 | Firefox | Same | | |
| 13 | Safari 16.4+ (PWA installed) | Same | | |
| 14 | Safari <16.4 | Login → NO sheet (hidden) | | |
| 15 | Huawei Mate 30 (no GMS) | Login → NO sheet → in-app polling still fetches new notifications | | |
| 16 | All — Image picker | At each of 6 sites: first tap shows sheet, second tap skips | | |
| 17 | All — Settings deep link | Deny camera → cancel sheet → see settings dialog → tap opens OS settings | | |
| 18 | All — Logout | Logout → BE log shows DELETE push-token call | | |
| 19 | All — Role upgrade | Mock guest→host upgrade → sheet re-shows with host copy | | |
| 20 | Debug menu | `/permission-debug` reachable in debug, returns 404 in release | | |

## Debug Time-Skip Menu (AC-V4)

Implementation note for tester:
- Navigate to `/permission-debug` (debug build only).
- Tap "Skip 7 days" — advances stored `lastDeferAt` and `lastShownAt` back by 7 days.
- Tap "Skip 30 days" — advances by 30 days (use to test AC-N3 deny cooldown).
- Tap "Reset all" — clears all priming state for current user.
- Tap "Force show notification sheet [guest|host|admin]" — bypasses cooldown, presents sheet immediately.

Code guard verification:
```dart
// In app_router.dart
if (kDebugMode) GoRoute(path: '/permission-debug', builder: ...)
```
Build release APK → attempt navigation → expect "no route" error. Confirms AC-V4 release exclusion.

## Implementation Steps

1. Set up `test/helpers/` mocks (in-memory storage, fake FCM, mock Dio).
2. Write `permission_storage_test.dart` — most foundational.
3. Write `permission_service_test.dart` — cover all cooldown branches.
4. Write `fcm_service_test.dart` — mock token register/refresh.
5. Write `permission_analytics_uploader_test.dart` — backoff + chunking.
6. Write 9 widget tests with golden file generation: `flutter test --update-goldens` once, commit golden PNGs.
7. Write 3 integration tests in `integration_test/`.
8. Run full suite locally: `flutter test && flutter test integration_test/`.
9. Execute manual matrix on real devices/emulators; fill `docs/features/permission-priming-test-report.md`.
10. Fix any failures → re-run.

## Todo List

- [ ] Test helpers (mock storage, FCM, dio, clock)
- [ ] `permission_storage_test.dart` (CRUD + namespacing)
- [ ] `permission_service_test.dart` (cooldown + role upgrade — AC-N2/N3/N7/N8)
- [ ] `permission_events_test.dart` (queue cap 200, clear by ts)
- [ ] `fcm_service_test.dart` (token register/refresh, provisional, 24h fallback)
- [ ] `gms_detector_test.dart` (platform branches)
- [ ] `permission_analytics_uploader_test.dart` (batch, 401, 429, 5xx)
- [ ] 3 notification priming sheet widget tests + goldens
- [ ] 6 camera priming sheet widget tests + goldens
- [ ] `soft_reask_banner_test.dart`
- [ ] `permission_settings_card_test.dart`
- [ ] `integration_test/golden_path_test.dart`
- [ ] `integration_test/deny_path_test.dart`
- [ ] `integration_test/huawei_skip_test.dart`
- [ ] Manual test matrix execution + sign-off
- [ ] `docs/features/permission-priming-test-report.md` filed

## Success Criteria

- 100% of automated tests pass on CI.
- ≥85% line coverage on `lib/core/permissions/`.
- All 22 ACs traceable to at least 1 test case (matrix above).
- Manual matrix 20 rows complete with PASS or documented FAIL+ticket.
- Test report committed and approved by tech lead.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Golden tests flake across platforms (font rendering) | H | M | Generate goldens on Linux CI only; skip on Windows/macOS dev machines; use `goldenFileComparator` tolerance |
| Real device unavailable (Huawei) | M | H | Mock GMS detector returns false in integration test as proxy; manual test in TestFlight-equivalent later |
| Integration test can't mock OS permission dialog | H | M | Test up to dialog trigger; manual matrix covers OS response |
| Time-dependent tests flake on slow CI | M | M | Inject `Clock` in `PermissionService`; tests use `Clock.fixed` |
| Coverage gap on platform branches (kIsWeb, Platform.isIOS) | M | M | Use `--platform vm` for unit, `chrome` for web tests; split tests by platform tag |

## Security Considerations

- Test fixtures must NOT contain real JWT tokens, real FCM tokens, real user emails. Use `test-token-1234`.
- Manual test report must not commit screenshots containing real user data.
- Debug `skipDays` and `resetAll` MUST be unreachable in release (test #20 verifies).
- CI must run `flutter analyze` with `--fatal-warnings` to catch any leaked `print(token)` calls.

## Next Steps

- Feature complete → Phase 5 of important-task-workflow (Tech Lead code review via `code-reviewer`).
- Post-launch monitoring (AC-M2): 14-day window, ≥500 users per role, dashboard for opt-in rates.
- If opt-in <65%: revisit copy variants (research Section 3 has Short/Long alternatives).
