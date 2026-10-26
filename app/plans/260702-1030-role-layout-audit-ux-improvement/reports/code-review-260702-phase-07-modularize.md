# Code Review — Phase 07 Modularization

Date: 2026-07-02
Scope: 5 screen splits (analytics, room_detail, occupancy_heatmap, contract_form, plus host_home called out in phase)
Analyzer: 0 errors, 3 info-level `unnecessary_import` in contract_form_* trio (transitive `ds.dart` covers HD tokens)

## Findings

### CRITICAL
None.

### HIGH
None.

### MEDIUM

- **occupancy_heatmap_widgets.dart:6-15** — Public top-level constants `kRoomColWidth`, `kRowHeight`, `kCellWidth`, `kHeaderHeight` (were `_k…` private). They are geometry primitives, but exporting them from a `_widgets.dart` sibling means any future importer in the app can bind to them. Consider promoting to a `heatmap_layout.dart` constants file or wrapping in an abstract class `HeatmapLayout` for a proper namespace. Not blocking — usage is contained to sibling file today.

- **contract_form_billing_section.dart:3 / contract_form_parties_section.dart:3 / contract_form_screen.dart:13** — `unnecessary_import` of `host_dashboard_tokens.dart` (HD tokens re-exported via `ds.dart`). 3 lines, safe to delete. Not gate-blocking but flagged by analyzer.

### LOW

- **occupancy_heatmap_screen.dart:69-70** — New `TODO(phase-05a)` comment documents why raw `AppBar` remains (no `bottom:` slot on `DsAppBar`). Correct decision, but track this as an actionable ticket on `DsAppBar` so it doesn't rot.

- **room_detail_screen.dart:191-208** — `_editorialAppBar` is a private top-level function, not migrated to `DsAppBar`. Pre-existing (not introduced by phase-07), but worth adding an eyebrow-aware variant to `DsAppBar` since this pattern will recur.

- **room_detail_editorial_widgets.dart** filename suggests widgets only, but exports `EditorialDialog` (a dialog, not a widget composition unit). Cosmetic — consider `room_detail_dialogs.dart` split later if the file grows.

## Verification against review focus

1. **Pure move** — CONFIRMED. Diffs on all 5 mains show only: import add/remove, name change `_X` → `X`, class-body removal. No signature/behavior edits. `showMaintenanceDialog`, `endMaintenance`, `duplicate`, `_openCreateContract`, `_toast`, `dispose` all unchanged in `room_detail_screen.dart`. Analytics `initState` telemetry track, `_refresh`, `_onShift`, `_onTogglePeriod`, `_currentPeriodStart` intact.

2. **Imports** — Main files clean. Removed imports (`kpi_card`, `period_swiper`, `currency_formatter`, `go_router`, `offline_badge`, etc.) correctly migrated to sibling files. No stale imports lingering in mains.

3. **Visibility (dropped underscore)** — Acceptable. All promoted names (`AnalyticsDataView`, `AnalyticsKpiGrid`, `AnalyticsPeriodToggle`, `AnalyticsStatusBadgeRow`, `AnalyticsPeriodHeaderBar`, `EditorialDialog`, `RoomMasthead`, `RoomFactSheet`, `CreateContractCta`, `ContractHistorySection`, `HeatmapGridView`, `HeatmapGroupView`, `HeatmapRoomRowWidget`, `HeatmapDayHeader`, `HeatmapLegend`, `HeatmapErrorView`) are only consumed by their sibling within the same feature folder — grep confirms zero cross-feature imports. Effective encapsulation preserved by folder convention.

4. **DsAppBar preservation (Phase 05a)** — analytics_home = `DsAppBar` intact (line 90). contract_form = `DsAppBar` intact (line 290). room_detail = never used `DsAppBar` pre-phase-07 (`_editorialAppBar` custom, verified via `git show HEAD`). occupancy_heatmap = never migrated (documented reason: TabBar slot). No regressions.

5. **contract_form at 377 LOC** — JUSTIFIED. Form key, controllers (`_rentCtrl`, `_depositCtrl`), date picker state (`_startDate`, `_endDate`), tenant rows list, upload state, and permission-gated photo capture are one concern. Splitting further would fragment `setState` boundaries or force provider indirection for row lifecycle.

## Concerns worth noting

- `_verticalController` (occupancy_heatmap_screen:35) is created in the main file and passed by reference to sibling `HeatmapGridView` (line 115). Ownership stays in the parent (correct — `dispose()` at line 46 still runs). No leak.

- `analytics_kpi_cards.dart` misname: file also hosts `AnalyticsDataView` (the layout wrapper, not just KPI cards). Not blocking, but the filename undersells its contents; future maintainers grepping for `DataView` may miss it. Consider `analytics_data_view.dart` or split KPI grid into own file.

- host_home_screen, tin_dang_tab, nha_tro_tab, dialogs, khaibao_banner — listed in phase but not in review request. Not reviewed here.

## Verdict

**APPROVED** with the following recommended follow-ups (non-blocking):
1. Delete 3 `unnecessary_import` lines flagged by analyzer.
2. File a `DsAppBar.bottom` slot ticket to burn down the occupancy_heatmap TODO.
3. Consider renaming `analytics_kpi_cards.dart` → `analytics_data_view.dart` OR extracting `AnalyticsKpiGrid` into its own file.
4. Consider namespacing heatmap layout constants under a `HeatmapLayout` abstract class.

Modularization goal achieved — 4/5 files under 300 LOC, contract_form's 377 justified. Behavior preserved. No security, no regression, no API leak.

## Unresolved questions

- None. All review focus items answered.
