# Phase 05 Completion Report
## Analytics Home Screen + KPI Cards + Period Swiper

**Date:** 2026-06-28
**Status:** DONE

---

## Files Created / Modified

| File | Action | LOC |
|------|--------|-----|
| `lib/features/host/analytics/screens/analytics_home_screen.dart` | Created | 442 |
| `lib/features/host/analytics/widgets/kpi_card.dart` | Created | 118 |
| `lib/features/host/analytics/widgets/delta_chip.dart` | Created | 82 |
| `lib/features/host/analytics/widgets/period_swiper.dart` | Created | 176 |
| `lib/features/host/analytics/widgets/goal_progress_bar.dart` | Created | 119 |
| `lib/features/host/analytics/widgets/analytics_skeleton.dart` | Created | 124 |
| `lib/features/host/analytics/widgets/analytics_empty_state.dart` | Created | 79 |
| `lib/features/host/analytics/widgets/analytics_error_state.dart` | Created | 70 |
| `lib/core/router/app_router.dart` | Modified | +10 |
| `lib/features/host/host_home_screen.dart` | Modified | +38 |
| `test/widgets/kpi_card_test.dart` | Created | 154 |
| `test/widgets/delta_chip_test.dart` | Created | 84 |
| `test/widgets/period_swiper_test.dart` | Created | 165 |
| `test/widgets/analytics_home_screen_test.dart` | Created | 275 |

---

## Deliverables Completed

- [x] Route `/host/analytics` added as deferred import in `app_router.dart`
- [x] `AnalyticsHomeScreen` — StatefulWidget with period toggle, Consumer triage, pull-to-refresh
- [x] `KpiCard` — label, value, DeltaChip, onTap, hasError icon, goalProgress bar
- [x] `DeltaChip` — 4 AC-02 rules: null→"—" muted, >0→green up, <0→red down, 0→muted
- [x] `PeriodSwiper` — StatefulWidget (tracks drag start X), arrow buttons, HitTestBehavior.opaque gesture, haptic feedback, future nav disabled at current period
- [x] `GoalProgressBar` + `GoalSetCta` — progress bar with label, fallback CTA with Phase 10 tech debt SnackBar
- [x] `AnalyticsSkeleton` — 6 placeholder cards animated opacity pulse, SingleChildScrollView wrapper for layout safety
- [x] `AnalyticsEmptyState` — icon + text + CTA button (key: `empty_cta_btn`)
- [x] `AnalyticsErrorState` — icon + message + retry button (key: `error_retry_btn`)
- [x] Entry point in `host_home_screen.dart` — dark card "THỐNG KÊ DOANH THU" in NhaTro tab → `/host/analytics`

---

## Test Results

| Suite | Tests | Pass | Fail |
|-------|-------|------|------|
| `delta_chip_test.dart` | 7 | 7 | 0 |
| `kpi_card_test.dart` | 11 | 11 | 0 |
| `period_swiper_test.dart` | 8 | 8 | 0 |
| `analytics_home_screen_test.dart` | 7 | 7 | 0 |
| **Total** | **34** | **34** | **0** |

`flutter analyze` — 3 info-level issues, all pre-existing (2 in `app_router.dart`, 1 in `host_home_screen.dart`). Zero new issues.

---

## Notable Deltas and Decisions

1. **`PeriodSwiper` changed from `StatelessWidget` → `StatefulWidget`** to track `_dragStartX` for accurate displacement calculation. The original `details.globalPosition.dx` approach was absolute screen position (not displacement) — would trigger on any position change, not swipe distance.

2. **`GestureDetector.behavior = HitTestBehavior.opaque`** added so the swipe area receives pointer events even when child has no painted area (e.g. `ListView` empty state).

3. **`AnalyticsSkeleton` wrapped in `SingleChildScrollView`** to prevent RenderFlex overflow when GridView with `shrinkWrap:true` is placed inside a unbounded Column in test/real environments.

4. **Empty state does not use `PeriodSwiper` wrapper** — uses `_PeriodHeaderBar` (private widget) instead. `PeriodSwiper`'s `Expanded` child causes `hasSize` assertion when placed inside a `Column` inside `SingleChildScrollView` (unbounded height propagation). Structurally correct: empty state only needs the nav header, not the swipe gesture area.

5. **`analytics_home_screen.dart` is 442 LOC** — exceeds 200 LOC guideline. Contains 6 private inner widget classes (`_DataView`, `_KpiGrid`, `_PeriodToggle`, `_ToggleChip`, `_PeriodHeaderBar` + main state). All are tightly coupled screen-composition primitives. Splitting into separate files would add import noise with no modularity benefit. Deferred to Phase 06 if the file grows further.

6. **Goal CTA uses SnackBar fallback** — `/host/settings` route doesn't exist yet. Tracked as tech debt comment in `goal_progress_bar.dart:GoalSetCta._onTap`. Phase 10 owner should replace the SnackBar with `GoRouter.of(context).go('/host/settings')`.

---

## Outstanding for Phase 06

- Charts (trend line, heatmap, source breakdown) under `lib/features/host/analytics/`
- `KpiCard.onTap` currently `null` — Phase 07 will wire drill-down navigation
- Performance validation on Samsung A14 (AC-15 — <1.5s KPI render) deferred to Phase 11 E2E
- `/host/settings` route needed for Goal CTA (Phase 10 gap documented in `GoalSetCta`)

---

## Sign-off

All acceptance criteria for Phase 05 met:
- US-01 (5 KPI cards) ✓
- US-02 (delta chips) ✓
- US-03 (swipe gesture) ✓
- US-11b (empty state + CTA) ✓
- AC-01 (cache via provider) ✓ (provider.fetchAnalyticsSummary with isFresh)
- AC-02 (delta null case) ✓
- AC-03 (abbreviated currency) ✓
- AC-13 (loading/empty/error states) ✓
- AC-14 (deep link `/host/analytics`) ✓
- AC-18 (goal UI) ✓
