---
title: "Phase 06 — Charts: Trend + Heatmap + Source Breakdown"
status: pending
priority: P0
estimated_effort: 5-7d
blocked_by: [phase-00, phase-05]
owner: TBD
---

## Context Links
- BA: US-04 (trend), US-05 (heatmap), US-06 (source), US-09 (tap cell), US-10 (MoM/YoY), AC-08 (heatmap UX), AC-15 (perf)
- BA Leader: §11.1 #2 (heatmap feasibility), §11.4 color-blind safe + virtualize
- Researcher: `research/researcher-market-revenue-analytics.md` §2 chart matrix; Phase 00 `reports/phase-00-heatmap-wireframe.md`

## Overview
- Priority: P0
- Status: pending
- Brief: Three chart screens — dual-line trend (12 months), occupancy heatmap (room×day, virtualized), source breakdown stacked bar. Uses `fl_chart`. Heatmap fallback to group-view per AC-08 if device cannot sustain 30fps.

## Key Insights (from research)
- Market researcher recommends dual-line (current vs prior period) for trend; heatmap calendar (room×day) for occupancy; stacked bar for source.
- `fl_chart ^0.68.0` MIT, mobile-optimized, lightweight (codebase audit §6).
- Heatmap virtualize via `ListView.builder` w/ sticky first col (Phase 00 prototype confirmed).

## Requirements
### Functional
- `RevenueTrendScreen`: dual-line chart (current period orange, prior period grey), 12 buckets, tap point → tooltip w/ exact value; toggle gross/net (AC-04).
- `OccupancyHeatmapScreen`: matrix row=room × col=day; virtualized list; sticky first col w/ room name; color-blind safe palette (white→light blue→dark blue→red+stripe per AC-08); tap cell → bottom sheet w/ booking detail (US-09); group-view fallback if >30 rooms ("Tòa A: 80% occupied", expand on tap).
- `SourceBreakdownChart` (widget, embedded in source detail screen): stacked bar by month × source; top 8 + "Khác" bucket; legend below.
- All charts respect AC-15: 60fps on 30 rooms, 30fps acceptable on 50-100 rooms.
- Pinch-to-zoom + horizontal pan on heatmap (AC-08).

### Non-functional
- Charts deferred-loaded (chunk split per AC-14).
- All colors via HD design tokens + pattern overlay where needed (color-blind safe).
- Heatmap cell min 24×24pt tap target.

## Architecture / Design
- `fl_chart` for trend + source breakdown.
- Heatmap: custom widget using `ListView.builder` w/ horizontal `SingleChildScrollView` inner row + `Stack` for sticky col.
- Bottom sheet for cell detail uses existing `showModalBottomSheet`.
- Provider already exposes data via Phase 04.

### Key decisions
- **Group-view fallback threshold:** auto-trigger when room count > 30 (per AC-08); user can expand individual building via tap.
- **Color-blind safe:** add stripe pattern to "overdue" red cells (use `CustomPaint`).
- **fl_chart version pinned to ^0.68.0**; fallback table view if breaking change (R6).

## Files
### Modify
- `pubspec.yaml` — add `fl_chart: ^0.68.0`
- `lib/core/router/app_router.dart` — add deferred routes `/host/analytics/revenue/:period/:date`, `/host/analytics/occupancy/:buildingId?/:month`

### Create
- `lib/features/host/analytics/screens/revenue_trend_screen.dart`
- `lib/features/host/analytics/screens/occupancy_heatmap_screen.dart`
- `lib/features/host/analytics/widgets/source_breakdown_chart.dart`
- `lib/features/host/analytics/widgets/heatmap_cell.dart`
- `lib/features/host/analytics/widgets/heatmap_sticky_col.dart`
- `lib/features/host/analytics/widgets/heatmap_group_row.dart` (group-view fallback)
- `lib/features/host/analytics/widgets/heatmap_cell_detail_sheet.dart` (tap → bottom sheet)
- `lib/features/host/analytics/widgets/trend_chart.dart` (fl_chart wrapper)
- `lib/features/host/analytics/widgets/color_palette.dart` (color-blind safe palette + pattern helper)
- `test/widgets/revenue_trend_screen_test.dart`
- `test/widgets/occupancy_heatmap_screen_test.dart`
- `test/widgets/source_breakdown_chart_test.dart`
- `test/widgets/heatmap_virtualization_test.dart` (asserts only visible cells built)

### Delete
- `lib/features/host/reports/widgets/revenue_breakdown_table.dart` — replaced by `SourceBreakdownChart`

## Implementation Steps
1. Add `fl_chart` to `pubspec.yaml`; run `flutter pub get`.
2. Build `ColorPalette` widget helper (color-blind safe values + stripe `CustomPainter`).
3. Build `TrendChart` wrapper around `fl_chart` LineChart — dual-line, tooltip, toggle gross/net.
4. Build `RevenueTrendScreen` w/ provider Consumer.
5. Build heatmap widgets:
   - `HeatmapCell` — 24×24pt, color per status, stripe for overdue.
   - `HeatmapStickyCol` — `Positioned` overlay w/ room names.
   - `HeatmapGroupRow` — fallback aggregated row (>30 rooms).
   - `HeatmapCellDetailSheet` — tap → modal bottom sheet w/ booking info.
6. Build `OccupancyHeatmapScreen` — orchestrates heatmap + InteractiveViewer (pinch/pan) + group-view threshold detection.
7. Build `SourceBreakdownChart` widget — fl_chart BarChart stacked, embedded in revenue trend screen (default tab "By Source").
8. Wire routes + entry from KPI tap.
9. Profile heatmap on Samsung A14 (50 rooms × 31 days); if <30fps → confirm group-view auto-trigger.

## Todo List
- [ ] `fl_chart` added
- [ ] `ColorPalette` helper + tests
- [ ] `TrendChart` widget + screen + tests
- [ ] Heatmap widgets (cell/sticky/group/sheet) + tests
- [ ] `OccupancyHeatmapScreen` + tests
- [ ] `SourceBreakdownChart` widget + tests
- [ ] Routes wired + deferred imports
- [ ] Old `revenue_breakdown_table.dart` deleted
- [ ] Perf benchmark recorded on A14

## Test Strategy
### Unit
- `ColorPalette.statusToColor(status)` mapping.
- Group-view threshold logic (>30 rooms → fallback).

### Integration
- Widget test: provider w/ 50-room heatmap data → assert only ~10 cells built initially (virtualization).
- Tap cell → bottom sheet opens w/ correct data.
- Tap point on trend chart → tooltip shows formatted VND value.
- Toggle gross/net → chart line data updates.

### E2E
- Phase 11 covers full perf benchmark.

## Success Criteria
- All 3 chart screens render w/ live data from provider.
- Heatmap 60fps scroll w/ 30 rooms; ≥30fps w/ 50 rooms (else fallback to group view).
- Color-blind palette verified (stripe pattern visible in greyscale screenshot).
- Pinch-to-zoom works on heatmap.
- Tap cell opens detail sheet.
- `flutter analyze` clean.

## Risk Assessment
- **R4 — heatmap lag 100+ rooms** → group-view auto-trigger; Phase 00 wireframe validated approach.
- **R6 — fl_chart breaking change** → version pinned; fallback table view code path exists.
- **AC-08 color-blind compliance** → stripe pattern + manual greyscale review.

## Security Considerations
- Bottom sheet content includes tenant name (PII) → enforce via existing auth gate (no anonymous access).

## Acceptance Criteria Coverage
- US-04 (dual-line trend) ✓
- US-05 (heatmap) ✓
- US-06 (stacked bar source) ✓
- US-09 (tap cell detail) ✓
- US-10 (MoM/YoY dual-line) ✓
- AC-08 (virtualize, group view, color-blind, pinch, tap) ✓
- AC-15 (perf benchmark) ✓ (initial measurement; final in Phase 11)

## Definition of Done
- Screens render correctly on Samsung A14 + iPhone SE.
- Heatmap perf documented.
- Widget tests pass.
- Code reviewed.
