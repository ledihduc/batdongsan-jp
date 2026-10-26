---
title: "Phase 07 — Drill-down 4 Levels + Filter Bottom Sheet"
status: pending
priority: P0
estimated_effort: 5-6d
blocked_by: [phase-00, phase-05]
owner: TBD
---

## Context Links
- BA: US-07 (drill), US-08 (filter), US-09 (tap heatmap), AC-09 (filter), AC-14 (deep link), Q8 (4-level depth)
- BA Leader: §11.1 #3 (drill UX risk), R12; Phase 00 `reports/phase-00-drill-wireframe.md`

## Overview
- Priority: P0
- Status: pending
- Brief: Four-level drill navigation Phòng → Contract → Tenant → Invoice w/ sticky breadcrumb + "back to summary" shortcut. Filter bottom sheet for multi-select building/source/period.

## Key Insights (from research)
- Q8 chose full depth (4 levels). BA Leader §11.1 #3 flagged mobile UX risk → breadcrumb mandatory.
- Existing `showModalBottomSheet` pattern used for invoice actions.
- Filter persist via session memory only (per AC-09).

## Requirements
### Functional
- 4 screens or 1 screen w/ 4 modes — each level shows list of items at that level + tap → next level.
- Sticky breadcrumb top: "Tổng quan / Phòng 101 / HĐ #42 / Nguyễn A / INV-202607-C42".
- "Back to summary" CTA visible on each level (top-right or floating).
- Filter bottom sheet: multi-select building (chip), single/multi-bed type chip (loại phòng), multi-select source (chip), date-range picker (kỳ).
- "Áp dụng" triggers refetch; "Reset" clears filter.
- Filter persists via session (in-memory; cleared on app restart per AC-09 KISS).
- Deep links per AC-14: `/host/analytics/drill/:level/:filterEncoded`.

### Non-functional
- Navigation transitions <300ms.
- Breadcrumb truncates long names w/ ellipsis.
- Tap targets ≥44pt.

## Architecture / Design
- Use `go_router` w/ nested routes; each level its own route for deep linking + Android back-stack correctness.
- Single `DrillState` provider tracking breadcrumb stack + current filter (separate from `ReportProvider` to avoid pollution).
- Filter encoded as JSON in URL (compact) — base64 encoded.

### Key decisions
- **Separate `DrillProvider`** for breadcrumb + filter state — clean separation from data fetching.
- **Breadcrumb tap** → pops to that level (consistent w/ go_router `pop`).
- **Filter scope:** applies to drill-down only; KPI cards unaffected.
- **Date-range picker:** use Material `showDateRangePicker` (no new dep).

## Files
### Modify
- `lib/core/router/app_router.dart` — 4 nested routes under `/host/analytics/drill`
- `lib/features/host/analytics/screens/occupancy_heatmap_screen.dart` — tap heatmap cell → navigate to drill (US-09)
- `lib/features/host/analytics/screens/analytics_home_screen.dart` — KPI tap → drill room level (US-07)

### Create
- `lib/features/host/analytics/screens/drill_room_screen.dart` (level 1)
- `lib/features/host/analytics/screens/drill_contract_screen.dart` (level 2)
- `lib/features/host/analytics/screens/drill_tenant_screen.dart` (level 3)
- `lib/features/host/analytics/screens/drill_invoice_screen.dart` (level 4)
- `lib/features/host/analytics/widgets/breadcrumb.dart` (sticky)
- `lib/features/host/analytics/widgets/back_to_summary_button.dart`
- `lib/features/host/analytics/widgets/filter_bottom_sheet.dart`
- `lib/features/host/analytics/widgets/filter_chip_group.dart`
- `lib/features/host/analytics/providers/drill_provider.dart`
- `lib/features/host/analytics/services/filter_codec.dart` (URL encode/decode filter JSON)
- `test/widgets/drill_navigation_test.dart`
- `test/widgets/breadcrumb_test.dart`
- `test/widgets/filter_bottom_sheet_test.dart`
- `test/services/filter_codec_test.dart`

### Delete
- none

## Implementation Steps
1. Define `DrillProvider` w/ `breadcrumb: List<BreadcrumbItem>`, `filter: FilterState`, `currentLevel: int`.
2. Build `Breadcrumb` widget — `Row` of `TextButton` items separated by `/`; truncate w/ ellipsis at >20 chars.
3. Build `BackToSummaryButton` (floating top-right) → `context.go('/host/analytics')`.
4. Scaffold 4 drill screens — each reads `DrillProvider.currentLevel` data via `ReportProvider.fetchDrill(level, filter)`.
5. Build `FilterBottomSheet` — chip groups for building/source, type chip for room type, `showDateRangePicker` for kỳ; Reset + Áp dụng buttons.
6. Build `FilterCodec` — `encode(FilterState) → base64 JSON`, `decode(String) → FilterState`.
7. Register 4 nested routes in `app_router.dart` w/ deferred imports.
8. Wire entry points: KPI card tap → level 1; heatmap cell tap → level 2 (contract) w/ filter pre-applied.

## Todo List
- [ ] `DrillProvider` w/ breadcrumb stack
- [ ] `Breadcrumb` widget + tests
- [ ] `BackToSummaryButton` + tests
- [ ] 4 drill screens + tests
- [ ] `FilterBottomSheet` + chip group + date range
- [ ] `FilterCodec` + tests
- [ ] Routes wired + deep link tested
- [ ] Entry points from KPI + heatmap

## Test Strategy
### Unit
- `FilterCodec.encode/decode` round-trip.
- `Breadcrumb` truncation logic.
- Filter state persists across screen transitions in same session; resets on `DrillProvider.reset()`.

### Integration
- Widget test: tap KPI → drill level 1 → tap room → level 2 → breadcrumb shows 2 items.
- Tap breadcrumb item → pop to that level.
- Filter applied → `fetchDrill` called w/ filter param.
- Deep link `/host/analytics/drill/2/<base64>` opens correct screen w/ filter.

### E2E
- Phase 11.

## Success Criteria
- 4 levels navigable; breadcrumb correct at each.
- Filter bottom sheet functional; persists in session.
- Deep links work.
- `flutter analyze` clean.

## Risk Assessment
- **R12 — drill UX lost user** → mitigated by sticky breadcrumb + back-to-summary CTA + Phase 00 wireframe pilot review w/ 3 hosts.
- **Filter encoding bloat in URL** → mitigated by base64 + only include non-default values.
- **Android hardware back behavior** → use `go_router` native pop (handles automatically).

## Security Considerations
- Drill level 3-4 exposes tenant PII → auth-gated (existing).
- Filter encoded in URL: contains building_id only (no PII).

## Acceptance Criteria Coverage
- US-07 (drill KPI) ✓
- US-08 (filter bottom sheet) ✓
- US-09 (tap heatmap → drill) ✓
- AC-09 (filter persist session) ✓
- AC-14 (deep link) ✓
- Q8 (4 levels) ✓
- R12 mitigation ✓

## Definition of Done
- 4 screens render correctly.
- Pilot review w/ 3 hosts confirms navigation clarity (per Phase 00 wireframe pilot).
- Widget tests pass.
- Code reviewed.
