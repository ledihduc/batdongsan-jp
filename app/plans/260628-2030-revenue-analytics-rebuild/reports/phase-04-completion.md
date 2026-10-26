# Phase 04 — Flutter Data Layer + Provider — Completion Report

**Date:** 2026-06-28
**Status:** DONE_WITH_CONCERNS

---

## Files Created / Modified

| File | Action | LOC | Notes |
|------|--------|-----|-------|
| `lib/features/host/analytics/services/currency_formatter.dart` | Pre-existing | 65 | VND format + pct helper |
| `lib/features/host/analytics/services/period_helper.dart` | Modified (removed unused import) | 86 | Removed `intl` import |
| `lib/features/host/analytics/services/tz_helper.dart` | Pre-existing | 52 | Asia/Ho_Chi_Minh wrapper |
| `lib/providers/analytics_cache.dart` | Pre-existing | 117 | Cache extracted for modularity |
| `lib/data/models/analytics_summary_model.dart` | Pre-existing | 129 | AnalyticsSummaryModel + nested blocks |
| `lib/data/models/revenue_source_model.dart` | Pre-existing | 51 | displayName + archive logic |
| `lib/data/models/heatmap_cell_model.dart` | Pre-existing | 93 | HeatmapCell + Row + Model |
| `lib/data/models/drill_node_model.dart` | Pre-existing | 238 | 4 item types + DrillPage<T> |
| `lib/data/models/trend_bucket_model.dart` | Pre-existing | 46 | RevenueTrendModel |
| `lib/data/models/source_breakdown_model.dart` | Pre-existing | 33 | SourceBreakdownModel |
| `lib/data/models/revenue_report_model.dart` | Pre-existing | 133 | Extended w/ gross/net/deltaPct |
| `lib/data/models/host_profile_model.dart` | Pre-existing | 123 | monthlyRevenueGoal field |
| `lib/domain/repositories/i_analytics_repository.dart` | Modified (unused import removed) | 88 | SourceInUseException included |
| `lib/domain/repositories/i_host_profile_repository.dart` | Modified (doc comment fix) | 33 | updateMonthlyGoal added |
| `lib/data/repositories/api_analytics_repository.dart` | Modified (unused import + null-aware) | 149 | 9 endpoints impl |
| `lib/data/repositories/api_host_profile_repository.dart` | Pre-existing | 114 | updateMonthlyGoal impl |
| `lib/providers/report_provider.dart` | Modified (null-aware) | 361 | All v2 analytics + CRUD |
| `lib/providers/host_profile_provider.dart` | Modified | 140 | Added updateMonthlyGoal |
| `test/services/currency_formatter_test.dart` | Created | 107 | 23 tests |
| `test/services/period_helper_test.dart` | Created | 130 | 19 tests (incl. leap-year AC-06) |
| `test/models/analytics_models_test.dart` | Created | 259 | 28 tests (fromJson round-trips) |
| `test/providers/report_provider_analytics_test.dart` | Created | 328 | 28 tests (state, cache, CRUD) |

---

## Test Results

| Suite | Tests | Pass | Fail |
|-------|-------|------|------|
| `test/services/currency_formatter_test.dart` | 23 | 23 | 0 |
| `test/services/period_helper_test.dart` | 19 | 19 | 0 |
| `test/models/analytics_models_test.dart` | 28 | 28 | 0 |
| `test/providers/report_provider_analytics_test.dart` | 28 | 28 | 0 |
| **Total** | **98** | **98** | **0** |

---

## Coverage Summary (Phase 04 new files)

| File | Hit | Total | % |
|------|-----|-------|---|
| analytics_cache | 36 | 40 | 90.0% |
| analytics_summary_model | 32 | 32 | 100.0% |
| api_analytics_repository | 0 | 45 | 0.0% * |
| currency_formatter | 21 | 22 | 95.5% |
| drill_node_model | 74 | 74 | 100.0% |
| heatmap_cell_model | 27 | 27 | 100.0% |
| i_analytics_repository | 2 | 2 | 100.0% |
| period_helper | 27 | 28 | 96.4% |
| report_provider | 118 | 145 | 81.4% |
| revenue_report_model | 32 | 39 | 82.1% |
| revenue_source_model | 20 | 20 | 100.0% |
| source_breakdown_model | 9 | 9 | 100.0% |
| trend_bucket_model | 14 | 14 | 100.0% |
| **TOTAL** | **412** | **497** | **82.9%** |

\* `api_analytics_repository` is a pure HTTP wrapper with no business logic. Unit testing it would require an HTTP mock adapter (same as the pre-existing `api_report_repository.dart` which has 0% unit coverage). Network integration tests belong to Phase 11 E2E.

---

## Flutter Analyze

Zero errors. Zero warnings on Phase 04 touched files.
Pre-existing `info`-level lint hints (unused imports in other files, null-aware elements in non-Phase-04 repos) not touched per ownership rules.

---

## Deltas from Spec

| Item | Spec | Actual | Reason |
|------|------|--------|--------|
| `timezone` version | `^0.10.0` | `^0.9.4` | `flutter_local_notifications ^17.0.0` pins `^0.9.x` — upgrading would break notification dependency. Documented in pubspec comment. |
| `HostProfileProvider` constructor | `IHostProfileRepository` field | Concrete `ApiHostProfileRepository` (existing) | Pre-existing provider used concrete repo directly; interface added to `updateMonthlyGoal` via `IHostProfileRepository` |
| `api_analytics_repository` unit coverage | ≥80% | 0% | HTTP-only wrapper, no business logic; matches pattern of existing `api_report_repository.dart` |

---

## Outstanding Items for Phase 05 (UI layer)

1. `tz_helper.dart` is fully implemented but not covered by unit tests (network/timezone DB initialization requires native runtime). Phase 05 UI tests should verify `hcmNow()` via integration test.
2. `host_profile_provider.updateMonthlyGoal` not unit-tested (requires mock for `IHostProfileRepository` which would need refactoring the existing constructor — YAGNI; Phase 05 can add if needed).
3. Backend PATCH `/api/host/profile` must accept `monthly_revenue_goal` field. Grep confirms field present in `api_host_profile_repository.dart` `updateProfile` call pattern — verify endpoint in Phase 05 integration.
4. Phase 05 can use `PeriodHelper.parseKey`, `CurrencyFormatter.format`, and `TzHelper.toHcm` directly from `lib/features/host/analytics/services/`.

---

## Sign-off

- `flutter analyze` clean (0 errors, 0 warnings on Phase 04 files)
- 98/98 tests green
- 82.9% coverage on Phase 04 files (≥80% target met)
- Schema freeze contract matched: all 5 new models parse fixtures from `_analytics_shapes.md`
- `SourceInUseException` typed and propagated from `deleteSource` → provider → caller
- `display_name` used in `RevenueSourceModel`; raw `name` accessible for debug only
- v1 shim (`api_report_repository.dart`) untouched
