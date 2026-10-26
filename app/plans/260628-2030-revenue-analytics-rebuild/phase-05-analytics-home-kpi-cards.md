---
title: "Phase 05 — Analytics Home Screen + KPI Cards"
status: pending
priority: P0
estimated_effort: 4-5d
blocked_by: [phase-04]
owner: TBD
---

## Context Links
- BA: US-01, US-02, US-03, US-11, US-11b, AC-01, AC-02, AC-03, AC-13, AC-14, AC-18
- Researcher: `research/researcher-architecture-patterns.md` §Screen Pattern, §Design Tokens; `research/researcher-market-revenue-analytics.md` §1 (KPI list)

## Overview
- Priority: P0
- Status: pending
- Brief: Analytics home screen showing 5 KPI cards (Gross, Net, Occupancy %, ADR, Booking Pace) w/ delta vs prior, swipe period gesture, loading skeletons, empty/error states, goal progress bar placeholder.

## Key Insights (from research)
- HD design tokens already provide masthead/sectionTitle/body/tabular text styles + paper/ink/accent colors.
- `Consumer<ReportProvider>` pattern w/ `isLoading`/`error`/`data` triage already standard.

## Requirements
### Functional
- `AnalyticsHomeScreen` w/ AppBar + period swiper + 5 KPI cards grid (2-col on phone) + goal progress bar (if set).
- Each KPI: label + value (abbreviated AC-03) + delta chip (↑/↓ % per AC-02) + tap → drill (Phase 07 handover).
- Swipe gesture (left/right) on hero card → change period (US-03).
- Skeleton card on initial load (AC-13).
- Empty state for new host (US-11b): illustration + CTA "Tạo invoice đầu tiên" / "Thêm phòng".
- Error state w/ retry CTA.
- Partial error handling: if 1 of 5 KPIs failed (e.g., booking_pace), show warning icon + inline retry on that card only (AC-13).
- Goal progress bar on Gross KPI card (AC-18): if `monthlyRevenueGoal` set → show `current/goal` bar; else show "Đặt mục tiêu" CTA → navigate Settings.
- Deep link `/host/analytics` (AC-14).

### Non-functional
- KPI render <1.5s on Samsung A14 (AC-15).
- Reuse HD design tokens (no new color/font).

## Architecture / Design
- `StatefulWidget` w/ local state for `_selectedPeriod`, `_anchorDate`.
- `initState` triggers `_refresh()` via `WidgetsBinding.addPostFrameCallback`.
- `Consumer<ReportProvider>` for reactive build.
- `GestureDetector` w/ `onHorizontalDragEnd` → `PeriodHelper.shift(period, anchorDate, +1/-1)`.
- KPI cards as separate widget for reusability.

### Key decisions
- **Goal CTA**: navigate to existing Settings screen (deep-link route `/host/settings`); placeholder until full Settings update in Phase 10.
- **Empty state detection:** check `summary.gross == 0 && invoice_count == 0` (from backend flag — request added in Phase 03).
- **Period swiper:** swipe distance > 80px → trigger shift; haptic feedback.
- **KPI tap target:** ≥44pt (a11y).

## Files
### Modify
- `lib/core/router/app_router.dart` — add deferred route `/host/analytics`
- `lib/features/host/host_home_screen.dart` — add entry point button/card → `/host/analytics`

### Create
- `lib/features/host/analytics/screens/analytics_home_screen.dart`
- `lib/features/host/analytics/widgets/kpi_card.dart`
- `lib/features/host/analytics/widgets/delta_chip.dart`
- `lib/features/host/analytics/widgets/period_swiper.dart`
- `lib/features/host/analytics/widgets/goal_progress_bar.dart`
- `lib/features/host/analytics/widgets/analytics_skeleton.dart`
- `lib/features/host/analytics/widgets/analytics_empty_state.dart`
- `lib/features/host/analytics/widgets/analytics_error_state.dart`
- `test/widgets/analytics_home_screen_test.dart`
- `test/widgets/kpi_card_test.dart`
- `test/widgets/delta_chip_test.dart`
- `test/widgets/period_swiper_test.dart`

### Delete
- none

## Implementation Steps
1. Add route `/host/analytics` to `app_router.dart` w/ deferred import.
2. Scaffold `AnalyticsHomeScreen` w/ AppBar + Consumer wrapper.
3. Build `KpiCard` widget — accepts label, value (formatted via `CurrencyFormatter`), delta (`DeltaChip`), onTap callback.
4. Build `DeltaChip` widget — green ↑ / red ↓ / muted "—" per AC-02 rules.
5. Build `PeriodSwiper` — gesture detector + arrow buttons; emits period+date.
6. Build `GoalProgressBar` — linear progress + label "X% mục tiêu" or "Đặt mục tiêu" CTA.
7. Implement skeleton + empty + error widgets.
8. Wire `initState` → `_refresh()` → `provider.fetchAnalyticsSummary(period, date)`.
9. Wire entry point in `host_home_screen.dart`.

## Todo List
- [ ] Route added + deferred import
- [ ] `AnalyticsHomeScreen` scaffolded
- [ ] `KpiCard` + `DeltaChip` + `PeriodSwiper` widgets
- [ ] `GoalProgressBar` w/ CTA fallback
- [ ] Skeleton + empty + error widgets
- [ ] `initState` + `_refresh` wired
- [ ] Entry point on host home
- [ ] Widget tests pass

## Test Strategy
### Unit
- `DeltaChip` rendering for `prev=0` (shows "—" per AC-02).
- `CurrencyFormatter` integration in `KpiCard` (1.25M ₫ display).

### Integration
- Widget test: mock provider → `isLoading=true` → skeleton; data → 5 KPI cards visible.
- Empty state when `summary.gross==0 && invoice_count==0`.
- Period swipe right → `_anchorDate` shifts back 1 month; `fetchAnalyticsSummary` called w/ new date.

### E2E
- Deferred to Phase 11.

## Success Criteria
- All 5 KPI cards render w/ value + delta + tap handler.
- Swipe gesture functional w/ haptic.
- Skeleton displays during fetch.
- Empty state for new host w/ CTA.
- Goal progress bar shows when goal set; CTA when null.
- Deep link `/host/analytics` opens screen.
- `flutter analyze` clean.

## Risk Assessment
- **Swipe gesture conflicts w/ scroll** → mitigate via `onHorizontalDragEnd` only when velocity > threshold.
- **A14 perf <1.5s** → measure early; if exceeded, reduce parallel render via `RepaintBoundary`.
- **Goal CTA stub** → confirm Settings route exists or add placeholder screen in Phase 10.

## Security Considerations
- No PII on this screen (KPI values aggregate).
- Deep link auth enforced by existing router redirect.

## Acceptance Criteria Coverage
- US-01 (5 KPI cards) ✓
- US-02 (delta) ✓
- US-03 (swipe) ✓
- US-11 (goal display) ✓ (UI; backend already in Phase 01)
- US-11b (empty state) ✓
- AC-01 (cache via provider) ✓
- AC-02 (delta logic) ✓
- AC-03 (currency format) ✓
- AC-13 (states) ✓
- AC-14 (deep link) ✓
- AC-18 (goal UI) ✓

## Definition of Done
- Screen renders correctly on Samsung A14 + iPhone SE.
- Widget tests pass.
- Code reviewed.
- Updated entry point in host home.
