---
title: "Phase 04 — Flutter Data Layer + Provider"
status: pending
priority: P0
estimated_effort: 3-4d
blocked_by: [phase-02]
owner: TBD
---

## Context Links
- BA: AC-01 (5-min cache), AC-03 (VND format), AC-13 (states), AC-18 (goal field)
- Researcher: `research/researcher-architecture-patterns.md` §Flutter Patterns; `research/researcher-codebase-audit.md` §Provider section + §Currency/Period gaps

## Overview
- Priority: P0
- Status: pending
- Brief: Update Flutter data layer to consume new v2 endpoints. New/updated models, repository, ReportProvider extension w/ 5-min cache, helper services (currency, period, tz). Can start in parallel w/ Phase 02 after schemas frozen (Phase 02 day 3).

## Key Insights (from research)
- Existing pattern: Provider + ChangeNotifier (NOT Riverpod); manual `fromJson`; `ApiClient` wrapper for HTTP.
- No charting library yet; no cache `isFresh()`; no timezone handling.
- Period selector currently uses fragile manual date math (`_shiftDate`) — to be replaced by `period_helper.dart`.

## Requirements
### Functional
- Update `RevenueReportModel` w/ `gross`, `net`, `delta_pct`, `source_breakdown[]`, `commission_total` fields.
- New models: `RevenueSourceModel`, `AnalyticsSummaryModel`, `HeatmapCellModel`, `DrillNodeModel`, `TrendBucketModel`.
- Replace `ApiReportRepository` v1 methods w/ v2 endpoints (rename → `ApiAnalyticsRepository`).
- `ReportProvider` extended w/ `fetchAnalyticsSummary`, `fetchTrend`, `fetchHeatmap`, `fetchSources`, `fetchDrill`; add `isFresh(maxAge: Duration)` method; 5-min cache per metric.
- Source CRUD methods on provider: `createSource`, `updateSource`, `archiveSource`, `deleteSource`.
- Helpers: `currency_formatter.dart` (VND `vi_VN` per AC-03), `period_helper.dart` (TZ-safe shift), `tz_helper.dart` (`Asia/Ho_Chi_Minh`).

### Non-functional
- All models manual `fromJson` (no freezed — match existing).
- ChangeNotifier pattern (NOT Riverpod).
- Cache evicts on swipe to different period.

## Architecture / Design
- Single `IAnalyticsRepository` interface + `ApiAnalyticsRepository` impl (mirror existing repo pattern from `researcher-architecture-patterns.md`).
- Keep `ApiReportRepository` v1 deprecated for 1 sprint (legacy report screens still use it until cleanup).
- Provider holds last-fetch timestamp + data per metric type; `isFresh()` compares against `DateTime.now().difference(_lastFetch) < maxAge`.
- TZ helper wraps `package:timezone` for HCM conversion if needed for date display.

### Key decisions
- **Cache key:** `(metric, period, date)` tuple → invalidate when any changes.
- **Goal field in `HostProfile` model:** add `monthlyRevenueGoal: double?` (AC-18).
- **Source archive UI logic:** filter dropdown shows `!is_archived`; reports show all (historical compat).

## Files
### Modify
- `lib/data/models/revenue_report_model.dart` — add `gross`, `net`, `deltaPct`, `sourceBreakdown`, `commissionTotal`
- `lib/data/repositories/api_report_repository.dart` — deprecate or rename → keep file as v1 shim
- `lib/providers/report_provider.dart` — extend w/ analytics methods + `isFresh()` + 5-min cache
- `lib/data/models/host_profile_model.dart` — add `monthlyRevenueGoal: double?`
- `lib/data/repositories/api_host_profile_repository.dart` — patch endpoint to update goal
- `lib/providers/host_profile_provider.dart` — `updateMonthlyGoal(double)`

### Create
- `lib/data/models/revenue_source_model.dart`
- `lib/data/models/analytics_summary_model.dart`
- `lib/data/models/heatmap_cell_model.dart`
- `lib/data/models/drill_node_model.dart`
- `lib/data/models/trend_bucket_model.dart`
- `lib/domain/repositories/i_analytics_repository.dart` — interface
- `lib/data/repositories/api_analytics_repository.dart` — v2 impl (5 analytics + 4 source endpoints)
- `lib/features/host/analytics/services/currency_formatter.dart`
- `lib/features/host/analytics/services/period_helper.dart`
- `lib/features/host/analytics/services/tz_helper.dart`
- `test/providers/report_provider_analytics_test.dart`
- `test/models/analytics_models_test.dart` (fromJson round-trip)
- `test/services/currency_formatter_test.dart`
- `test/services/period_helper_test.dart` (incl. cross-year boundary AC-06)

### Delete
- none (v1 repo kept as shim 1 sprint)

## Implementation Steps
1. Add `intl: ^0.20.0` (already present), `timezone: ^0.10.0` (add) to `pubspec.yaml`. NOTE: skip `fl_chart` here (added in Phase 06).
2. Scaffold helpers: `currency_formatter`, `period_helper`, `tz_helper` w/ tests first.
3. Write models w/ manual `fromJson` matching Pydantic schemas (Phase 03 output).
4. Define `IAnalyticsRepository` interface; implement `ApiAnalyticsRepository` calling 9 new endpoints.
5. Extend `ReportProvider`:
   - Add fields: `_summary`, `_trend`, `_heatmap`, `_sources`, `_lastFetchSummary`, `_lastFetchTrend`...
   - Add methods: `fetchAnalyticsSummary(period, date)`, `fetchTrend(...)`, `fetchHeatmap(...)`, `fetchSources()`, `fetchDrill(level, filter)`.
   - Add `isFresh(metric, maxAge)` helper.
   - Add source CRUD: `createSource`, `updateSource`, `archiveSource`, `deleteSource`.
6. Update `HostProfileProvider` w/ `updateMonthlyGoal`.
7. Write tests: provider state transitions, cache freshness, model fromJson round-trip, period_helper cross-year.

## Todo List
- [ ] `pubspec.yaml` updated (timezone)
- [ ] Helpers + tests
- [ ] 5 new models + tests
- [ ] `IAnalyticsRepository` + `ApiAnalyticsRepository` + tests
- [ ] `ReportProvider` extended + cache + tests
- [ ] `HostProfileProvider.updateMonthlyGoal` + test
- [ ] `revenue_report_model.dart` updated w/ new fields
- [ ] All flutter analyze clean

## Test Strategy
### Unit
- Model `fromJson` / `toJson` round-trip.
- `CurrencyFormatter.format()` — VND, abbreviated, locale `vi_VN` (AC-03 examples).
- `PeriodHelper.shift(period, date, delta)` — cross-year, leap-year Feb (AC-06).
- `ReportProvider.isFresh()` — boundary at 5 min.
- Cache eviction on period change.

### Integration
- Mock `ApiAnalyticsRepository` via `_mocks.dart`; assert provider state transitions (`isLoading=true → data set → notifyListeners called`).

### E2E
- N/A (Phase 11).

## Success Criteria
- All new models parse sample JSON from Phase 03 contract tests.
- `flutter analyze` clean.
- Test coverage for new code ≥80%.
- Provider cache verified (no double-fetch within 5 min).

## Risk Assessment
- **Schema drift vs Phase 03** → freeze on Phase 02 day 3; weekly sync if schemas change.
- **TZ helper bugs** → mitigated by `timezone` package + dedicated cross-year tests.
- **Backwards compat for legacy report screens** → v1 repo kept as shim until Phase 11.

## Security Considerations
- No PII stored client-side beyond what's already cached in InvoiceProvider.
- ApiClient already enforces JWT bearer (existing pattern).
- Source CRUD requires login (handled by `ApiClient` interceptor).

## Acceptance Criteria Coverage
- AC-01 (5-min cache via `isFresh()`) ✓
- AC-03 (VND format helper) ✓
- AC-06 (period_helper cross-year) ✓
- AC-18 (goal field in HostProfile) ✓

## Definition of Done
- All files created/modified per list.
- Tests green + coverage ≥80% on new code.
- Flutter analyze clean.
- Shared schema doc updated for Phase 05-08 consumption.
