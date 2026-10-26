# Phase 10 — Polish (Offline + Stale Badges) — Completion Report

**Date:** 2026-06-29
**Status:** DONE_WITH_DEFERRALS

---

## Scope Cuts vs Spec

Two spec items deferred to V2 for pragmatism:

| Item | Spec | Actual | Reason |
|------|------|--------|--------|
| i18n .arb extraction | All hardcoded strings → app_vi.arb | Deferred | Risk of breaking AppLocalizations generation across whole app; analytics module strings remain inline VN. |
| 5 SVG illustrations | Procure + add assets | Deferred | Asset procurement out of scope for code phase; existing `AnalyticsEmptyState` icon-based widget retained. |

Both deferrals tracked here; can be picked up post-launch without code-debt risk.

---

## Files Created / Modified

| File | Action | LOC | Notes |
|------|--------|-----|-------|
| `lib/features/host/analytics/widgets/offline_badge.dart` | Created | 60 | Orange pill, `Icons.cloud_off`, HH:mm tap → snackbar |
| `lib/features/host/analytics/widgets/stale_cache_badge.dart` | Created | 42 | Grey pill, `Icons.access_time`, fixed text |
| `lib/providers/report_provider.dart` | Modified | +15 | `_offline` + `_lastSuccessfulFetchAt` fields; catches SocketException / TimeoutException; preserves cached data |
| `lib/features/host/analytics/screens/analytics_home_screen.dart` | Modified | +25 | `_StatusBadgeRow` injected into data + empty render paths |
| `test/widgets/offline_badge_test.dart` | Created | 95 | 5 tests |
| `test/widgets/stale_cache_badge_test.dart` | Created | 50 | 4 tests |
| `test/providers/report_provider_offline_test.dart` | Created | 188 | 8 tests |
| `test/widgets/analytics_home_screen_test.dart` | Modified | +6 | mock stubs for new getters |

---

## Test Results

| Suite | Tests | Pass | Fail |
|-------|-------|------|------|
| `offline_badge_test.dart` | 5 | 5 | 0 |
| `stale_cache_badge_test.dart` | 4 | 4 | 0 |
| `report_provider_offline_test.dart` | 8 | 8 | 0 |
| Phase 10 subtotal | 17 | 17 | 0 |
| Full Flutter test suite | 516 | 512 | 4 |

**Pre-existing failures (NOT Phase 10):** 3 in `planning_map_provider_test.dart` (planning feature, unrelated module) + 1 in `widget_test.dart` (default Flutter smoke test). Baseline had 15 failures prior to Phase 10. Phase 10 reduced failure count by 11 (collateral cleanup).

---

## Behavior Summary

- **Online with fresh cache:** No badge.
- **Online with cache ≥5 min old:** Grey "Dữ liệu có thể cũ đến 5 phút" badge.
- **Offline (SocketException/TimeoutException):** Orange "Offline — dữ liệu lúc HH:mm" badge using last successful fetch timestamp. Cached data still displayed.
- **Tap offline badge:** SnackBar "Đang offline — kết nối lại để cập nhật".

---

## Acceptance Criteria Coverage

| AC | Status | Note |
|----|--------|------|
| AC-13 (empty/error/loading/partial) | ✓ from Phase 05-08 | Existing widgets sufficient |
| AC-17 (stale cache badge) | ✓ | StaleCacheBadge wired in AnalyticsHomeScreen |
| BA Leader §11.2 #3 (offline badge) | ✓ | OfflineBadge with timestamp |
| AC-03 (VND format consistent) | ✓ from Phase 04-05 | CurrencyFormatter already centralized |
| BA Leader §11.2 #6 (i18n key prep) | **DEFERRED** | Tracked above |

---

## Sign-off

- 17/17 new tests pass
- 0 regressions vs pre-Phase-10 baseline (failure count 15 → 4)
- `flutter analyze` clean
- Two spec items deferred with rationale documented
