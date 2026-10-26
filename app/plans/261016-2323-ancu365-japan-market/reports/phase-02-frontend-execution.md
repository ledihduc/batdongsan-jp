# Phase 02 — Frontend Execution Report
**Date:** 2026-10-16  
**Plan:** `plans/261016-2323-ancu365-japan-market/`  
**Status:** DONE

---

## Summary

Implemented all 6 priority groups (P1–P6) for the Japan market frontend in `ancu365-app`.  
All new screens gated behind `FeatureFlags.isJapan`. All routes use `deferred as` imports.  
37 new tests written + passing. 0 new `error`/`warning` lines from P2 code in `flutter analyze`.

---

## Files Created

### P1 — APPI Consent

| File | Description |
|------|-------------|
| `lib/features/consent/models/consent_purpose.dart` | `ConsentPurpose` enum (5 purposes), `ConsentRecord`, `ConsentGrantRequest`, `isConsentPurposeRequired()` |
| `lib/domain/repositories/jp/i_consent_repository.dart` | Interface: listConsents, grantConsents, revokeConsent, requestExport, getExportStatus, requestDeletion |
| `lib/data/repositories/jp/mock_consent_repository.dart` | In-memory mock; throws on required-purpose revoke; async export simulation |
| `lib/data/repositories/jp/api_consent_repository.dart` | HTTP: `/api/jp/consent`, `/api/jp/consent/:purpose`, export, delete endpoints |
| `lib/features/consent/consent_banner_sheet.dart` | `showConsentBannerSheet()` — modal, non-dismissible, per-purpose checkboxes; required purposes must be checked |
| `lib/features/consent/consent_settings_screen.dart` | Route `/settings/privacy` — list consents with revoke, links to export + delete |
| `lib/features/consent/data_export_request_screen.dart` | Polls `getExportStatus` every 5s; shows download link when ready |
| `lib/features/consent/data_delete_confirmation_sheet.dart` | Requires user type "DELETE"; 30-day cooling-off notice |

### P2 — Checkout + Payments

| File | Description |
|------|-------------|
| `lib/features/checkout/models/payment_intent.dart` | `JpPaymentMethod`, `JpPaymentIntentStatus`, `kTerminalPaymentStatuses`, `JpPaymentIntent`, `JpInvoiceSummary` |
| `lib/features/checkout/models/konbini_voucher.dart` | `KonbiniStore` enum, `KonbiniVoucher` model |
| `lib/features/checkout/repositories/i_payment_repository.dart` | Interface: createPaymentIntent, getPaymentIntent, getKonbiniVoucher, getInvoiceSummary |
| `lib/features/checkout/repositories/mock_payment_repository.dart` | In-memory; konbini creates voucher; bank-transfer creates intent without voucher |
| `lib/features/checkout/repositories/api_payment_repository.dart` | HTTP: `/api/jp/payments`, `/api/jp/invoices` |
| `lib/features/checkout/jp_checkout_screen.dart` | Route `/checkout/:invoiceId`; 3 tabs コンビニ/振込/カード; invoice summary card; pay button → voucher or status |
| `lib/features/checkout/konbini_voucher_screen.dart` | Route `/payments/:intentId/voucher`; voucher number + copy, countdown, store chips |
| `lib/features/checkout/payment_status_screen.dart` | Route `/payments/:intentId/status`; 3s polling via `Timer.periodic`; FCM topic subscribe |

### P3 — Application Review

| File | Description |
|------|-------------|
| `lib/features/sales/application_review_screen.dart` | Route `/applications/:id/review`; readonly applicant/employer/guarantor/docs; approve/reject/needs_info radio; sticky submit |

### P4 — IT 重説

| File | Description |
|------|-------------|
| `lib/features/it_session/models/it_session.dart` | `ItSession` model: takkenShi name, license, zoomUrl |
| `lib/features/it_session/it_session_join_screen.dart` | Route `/viewings/:viewingId/it-session`; 宅建士 card; consent checkbox; `url_launcher` for Zoom |

### P5 — eContract

| File | Description |
|------|-------------|
| `lib/features/econtract/models/econtract.dart` | `EcontractStatus` enum (pending/signed/expired/cancelled), `kTerminalEcontractStatuses`, `Econtract` model |
| `lib/features/econtract/econtract_signing_screen.dart` | Route `/econtracts/:id`; status pill; 5s polling; `url_launcher` external browser for CloudSign |

### P0 — ARB Keys (all 4 locales)

71 new keys added across: APPI consent, DSR flows, checkout/payments, konbini, bank transfer, card (stub), application review, IT session, eContract.

Files modified:
- `lib/l10n/app_en.arb` + `app_ja.arb` + `app_vi.arb` + `app_zh.arb`
- `lib/l10n/app_localizations.dart` (abstract getters)
- `lib/l10n/app_localizations_en.dart` / `_ja.dart` / `_vi.dart` / `_zh.dart` (implementations)

### Router

`lib/core/router/app_router.dart` — 7 deferred imports + 7 `GoRoute` entries (all inside `if (FeatureFlags.isJapan)` block):

| Route | Screen |
|-------|--------|
| `/checkout/:invoiceId` | `JpCheckoutScreen` |
| `/payments/:intentId/voucher` | `KonbiniVoucherScreen` |
| `/payments/:intentId/status` | `PaymentStatusScreen` |
| `/settings/privacy` | `ConsentSettingsScreen` |
| `/applications/:id/review` | `ApplicationReviewScreen` |
| `/viewings/:id/it-session` | `ItSessionJoinScreen` |
| `/econtracts/:id` | `EcontractSigningScreen` |

### Wiring

- `lib/features/auth/register_screen.dart` — calls `showConsentBannerSheet()` after successful registration when `FeatureFlags.isJapan`
- `lib/features/guest/profile/settings_screen.dart` — privacy settings `ListTile` added inside `if (FeatureFlags.isJapan)` block

---

## Tests (P6)

| Test File | Tests | Status |
|-----------|-------|--------|
| `test/features/consent/consent_purpose_test.dart` | 10 | PASS |
| `test/features/checkout/payment_intent_test.dart` | 9 | PASS |
| `test/features/checkout/jp_checkout_tab_test.dart` | 3 | PASS |
| `test/features/sales/application_review_test.dart` | 5 | PASS |
| `test/features/econtract/econtract_test.dart` | 6 | PASS |
| `test/features/it_session/it_session_join_test.dart` | 4 | PASS |
| **Total** | **37** | **ALL PASS** |

---

## Constraints Honored

- `webview_flutter` not in `pubspec.yaml` → `url_launcher` with `LaunchMode.externalApplication` used in both `EcontractSigningScreen` (CloudSign) and `ItSessionJoinScreen` (Zoom). Noted in file docstrings.
- `print()` not used — logger pattern or no logging in new files.
- No commits, no push.
- All JP screens gated: `if (FeatureFlags.isJapan)` in router + banner wiring.
- All routes use `deferred as` imports in `app_router.dart`.
- Card tab is a stub: shows placeholder text `カードは近日対応予定です` — no Stripe integration (P2 scope).
- Ds* widgets used throughout (`DsButton`, `DsAppBar`, `DsTextField`, `DsListTile`, `DsFormSection`, `DsEmptyState`).

---

## Flutter Analyze

`flutter analyze` run clean — **0 errors, 0 warnings** from P2 files.  
~300 pre-existing info/warning lines in old files (unnecessary casts in `api_jp_*`, unused elements in existing screens) — unchanged.

---

## Decisions + Notes

1. **IT session + eContract inline mocks**: `MockItSessionRepository` and `MockEcontractRepository` are inline in their screen files. Proper domain interfaces (`i_it_session_repository.dart`, `i_econtract_repository.dart`) are deferred to when BE endpoints `/api/jp/it-sessions` and `/api/jp/econtracts` are live. This matches "mock repository impl when BE not yet live" guidance.

2. **Widget test locale**: `pumpApp()` defaults to locale `'vi'`. Tests assert on widget type presence (`find.byType(...)`) rather than Japanese string matching to avoid locale-mismatch failures. Unit tests use `fromJson` directly and are locale-independent.

3. **Application review test fix**: Original `_seed()` called `saveDraft` (300ms delay) + `submit` (400ms delay) before any pump, causing `Cannot close sink while adding stream` crash in test harness. Fixed by introducing `_FastMockRepo` (implements interface, zero async delays) — widget tests now complete in ~50ms per test case.

4. **FCM topic subscription**: `payment_status_screen.dart` calls `FirebaseMessaging.instance.subscribeToTopic('invoice-$intentId')` fire-and-forget on init. No FCM initialization is done in the screen — assumes `main.dart` already initialized Firebase at app start.

5. **Polling timers in tests**: `EcontractSigningScreen` uses `Timer.periodic(5s)` and `PaymentStatusScreen` uses `Timer.periodic(3s)`. Widget tests use `pump(300ms)` + `pumpAndSettle` to avoid entering the polling loop. `addTearDown` should be added if flakiness observed on CI — deferred for now.

---

## Open Questions

1. **Card tab**: Stripe integration scope — needs Stripe PublishableKey, `flutter_stripe` package addition. Currently stub. When is this scheduled?
2. **IT session API**: `/api/jp/it-sessions/:viewingId` endpoint — when will it be live? The inline mock returns hardcoded "山田 太郎 / 東京都知事". Should the mock data be injected from viewing fixture?
3. **eContract CloudSign URL format**: Current mock returns `https://app.cloudsign.jp/documents/doc-id/sign`. Real format from backend — confirm structure so deep-link can be validated.
4. **Zoom URL scheme**: `zoomphoneapp://` vs `zoommtg://` — confirm which the app should use for iOS/Android deep-link vs `https://zoom.us/j/...` web fallback.
5. **FCM topic namespace**: Is `invoice-{invoiceId}` correct? Backend should subscribe tenant to this topic on invoice creation.
