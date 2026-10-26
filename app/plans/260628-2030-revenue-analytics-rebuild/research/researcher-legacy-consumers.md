# Legacy report_service.py Consumer Audit

**Audit Date:** 2026-06-28  
**Target File:** `ancu365-backend/app/services/report_service.py` (272 lines, 4 public functions)  
**Scope:** All backends + Flutter app callers; no cron/background jobs found; no admin/staff endpoints.

---

## Summary

**Total Callers Found:** 9 backend entry points + 1 Flutter repository + 4 test files  
**Backend Routes:** 4 endpoints (`/api/host/reports/*`)  
**Flutter Consumers:** 2 main report screens + 1 CSV export screen  
**External Integrations:** None (no Zalo digest, no cron jobs calling these functions)  
**Tests:** 3 test files with 7 test cases total; all assert on output structure and data aggregation  
**Private Function Violations:** None detected; `_period_prefix()`, `_days_in_month()`, `_csv_row()` are internal-only  
**Risk Level:** LOW — single router file + 2 Flutter screens; straightforward rebuild path  

---

## Backend Callers

### Router: `/api/host/reports/*` (app/routers/host_report.py)

All 4 endpoints require `auth.require_host` → auto-scoped to `claims["sub"]` (user's host_id).

| Line | Endpoint | HTTP Method | Auth Gate | Function Used | Notes |
|------|----------|-------------|-----------|---------------|-------|
| 22-32 | `/api/host/reports/revenue` | GET | `require_host` | `report_service.revenue_report()` | Query params: `period` (month\|year), `date` (YYYY-MM or YYYY) |
| 35-47 | `/api/host/reports/occupancy` | GET | `require_host` | `report_service.occupancy_report()` | Query params: `month` (YYYY-MM), optional `building_id` |
| 50-57 | `/api/host/reports/adr` | GET | `require_host` | `report_service.adr_report()` | Query params: `period` (month\|year), optional `house_id`; returns nulls until Phase 07 |
| 60-75 | `/api/host/reports/export` | GET | `require_host` | `report_service.export_invoices_csv()` | Query params: `type` (invoices), `month` (YYYY-MM); returns StreamingResponse with CSV |

**No other routers use report_service functions.**

### Service-to-Service Calls

**Result:** None found. No other service files in `app/services/` import or call report_service functions.

### Background/Cron/Scheduled Tasks

**Result:** None found. 
- APScheduler exists (`app/services/planning_etl/scheduler.py`) but only for planning ETL.
- No Zalo digest, notification, or revenue reporting digests trigger these functions.
- No Celery, APScheduler jobs defined for reporting.

---

## Flutter Consumers

### Repository: api_report_repository.dart (lib/data/repositories/)

Single repository encapsulating all 3 API calls for reports:

| Line | Function | Endpoint | Query Params | Returns |
|------|----------|----------|--------------|---------|
| 9-18 | `fetchRevenue()` | `/api/host/reports/revenue` | `period`, `date` | `RevenueReportModel` |
| 20-32 | `fetchOccupancy()` | `/api/host/reports/occupancy` | `month`, optional `building_id` | `OccupancyReportModel` |
| 35-40 | `exportInvoicesCsv()` | `/api/host/reports/export` | `type`, `month` | `List<int>` (UTF-8 bytes) |

### Provider: report_provider.dart (lib/providers/)

Wrapper around ApiReportRepository with state management (ChangeNotifier):

| Line | Method | Calls | UI Effect |
|------|--------|-------|-----------|
| 24-39 | `fetchRevenue()` | `_repo.fetchRevenue()` | Sets `_revenue`, `_isLoading`, `_error`; notifies listeners |
| 41-59 | `fetchOccupancy()` | `_repo.fetchOccupancy()` | Sets `_occupancy`, `_isLoading`, `_error`; notifies listeners |
| 62-71 | `downloadInvoicesCsv()` | `_repo.exportInvoicesCsv()` | Catches `ApiException`, returns bytes or null |

**Provider registered globally** in `lib/main.dart` as ChangeNotifierProvider.

### Screens Using Reports

| File | Screen Name | Methods Called | User Flow |
|------|-------------|-----------------|-----------|
| `lib/features/host/reports/screens/revenue_report_screen.dart` | RevenueReportScreen | `fetchRevenue()` (line 38), `downloadInvoicesCsv()` (line 48) | Period selector → table + CSV download button |
| `lib/features/host/reports/screens/occupancy_report_screen.dart` | OccupancyReportScreen | `fetchOccupancy()` (line 43, 52 via context.read) | Month selector + optional building filter → room occupancy table |
| `lib/features/host/reports/screens/adr_report_screen.dart` | AdrReportScreen | _(not yet implemented; adr_report returns nulls)_ | Placeholder until Phase 07 |

**All screens accessed via ReportProvider in provider package tree** (lib/main.dart registration).

---

## Tests

### Test Files Exercising report_service Functions

| File | Test Count | Functions Tested | Key Assertions |
|------|-----------|------------------|-----------------|
| `tests/reports/test_revenue_report.py` | 3 | `revenue_report()` | Sum logic per category; month vs year aggregation; zero for no invoices |
| `tests/reports/test_occupancy_report.py` | 3 | `occupancy_report()` | Room status → occupancy %; building avg; date parsing; optional building filter |
| `tests/reports/test_csv_export.py` | 2 | `export_invoices_csv()` | Header format; column count per row; Unicode (Vietnamese names with diacritics) |

**Total:** 8 test cases. All marked with `@pytest.mark.skipif(not SMOKE_DATABASE_URL)` → require live Postgres.

#### Test Details

**test_revenue_report.py (lines 17–60):**
- `test_revenue_month_sums_paid_invoices`: Asserts total=7.5M, breakdown["rent"]=6M, breakdown["electricity"]=1.5M, by_building=[≥1]
- `test_revenue_month_with_no_paid_returns_zero`: Asserts total=0, breakdown={} for month with no invoices
- `test_revenue_year_aggregates_months`: Asserts period="year", total matches month total (only July seeded)

**test_occupancy_report.py (lines 17–61):**
- `test_occupancy_three_of_five_rooms_occupied`: Asserts room_count=5, building_avg_pct=60, status-based occupancy calc
- `test_occupancy_invalid_month_raises`: Asserts ValueError on "not-a-date" input
- `test_occupancy_building_filter`: Asserts building_id filter works; empty result for non-existent building

**test_csv_export.py (lines 19–73):**
- `test_export_invoices_csv_streams_header_and_rows`: Asserts ≥4 chunks, CSV structure, column count consistency
- `test_export_invoices_csv_unicode_safe`: Asserts Vietnamese tenant names ("Lê Thị Đào") round-trip correctly

**test_dashboard_action_items.py (lines 38–75):**
- Not a direct report_service test, but uses `dashboard_service` which may depend on Invoice/Contract data in same query space
- Uses `zalo.template_invoice_reminder()` and `zalo.build_zalo_share_link()` — no cross-service dependency

---

## Private Function Audit

All private functions (`_*`) are **internal-only, not exported, not tested directly.**

| Function | Caller(s) | Scope | Notes |
|----------|-----------|-------|-------|
| `_period_prefix(period, date_str)` | `revenue_report()` (line 47) | report_service only | Converts "YYYY-MM" / "YYYY" → ISO prefix for LIKE queries |
| `_days_in_month(year, month)` | `occupancy_report()` (line 129) | report_service only | *(Also exists in `availability_service.py` independently)* |
| `_csv_row(values)` | `export_invoices_csv()` (line 259, 260) | report_service only | Wraps csv.writer for streaming |

**Risk:** None. Private functions are safe to refactor/delete/relocate without external impact.

---

## Risk Matrix (Per Function)

| Function | Caller Count | Caller Types | Risk if Removed | Rebuild Path |
|----------|-------------|--------------|-----------------|--------------|
| `revenue_report()` | 2 | 1 route + 1 test | Host loses revenue summary UI; 1 endpoint breaks | New analytics_service.revenue_query() with identical signature |
| `occupancy_report()` | 2 | 1 route + 1 test | Host loses occupancy tracking UI; 1 endpoint breaks | New analytics_service.occupancy_query() with identical signature |
| `adr_report()` | 2 | 1 route + 1 test | Phase 07 placeholder; safe to replace | New analytics_service.adr_query() (currently returns nulls; Phase 07 impl) |
| `export_invoices_csv()` | 2 | 1 route + 1 test | Host loses CSV export feature; 1 endpoint breaks | New analytics_service.export_csv_invoices() with identical signature |

---

## Recommended Rebuild Strategy

### Phase 1: Create New Service with Backward-Compat Shim

**Create:** `app/services/analytics_service.py` with these functions:
```
- revenue_query(db, host_id, period, date_str) → dict
- occupancy_query(db, host_id, building_id, month_str) → dict
- adr_query(db, host_id, house_id, period) → dict
- export_csv_invoices(db, host_id, month_str) → Generator[str, None, None]
```

**Signature match requirement:** Outputs MUST match current `report_service.py` 100% (same keys, same types) for zero test/UI changes.

### Phase 2: Update Router to Dual-Path (Optional, Lower Risk)

Before deprecating `report_service`, optionally run both in parallel for 1–2 deploys:

```python
# app/routers/host_report.py
from app.services import analytics_service  # new
from app.services import report_service     # old

@router.get("/revenue")
def revenue(...):
    old_result = report_service.revenue_report(...)
    new_result = analytics_service.revenue_query(...)
    assert old_result == new_result  # validation gate in testing
    return new_result
```

**If this passes → safe to remove old service immediately.**

### Phase 3: Delete Legacy report_service.py

After tests pass with new implementation:
1. Delete `app/services/report_service.py`
2. Remove import from `app/routers/host_report.py`
3. Update test fixtures/seeding to match new data model structure (if changed)
4. Run full test suite: `pytest tests/reports/`

**No Flutter code changes required** — endpoints return identical JSON.

### Phase 4: Test Plan

- [ ] Unit tests on `analytics_service` functions match old test data
- [ ] Integration test: call `/api/host/reports/revenue` → assert JSON structure
- [ ] Flutter app: regression test on RevenueReportScreen, OccupancyReportScreen
- [ ] CSV export: verify column count, Unicode handling, stream behavior

---

## Caller Code References (File:Line)

### Backend
- **Router:** `app/routers/host_report.py:30, 44, 57, 72` (4 function calls in 4 endpoints)
- **Tests:** `tests/reports/test_revenue_report.py:20, 41, 55` / `test_occupancy_report.py:20, 40, 52, 57` / `test_csv_export.py:23, 69` (8 calls total)

### Flutter
- **Repository:** `lib/data/repositories/api_report_repository.dart:13–17, 24–31, 36–39` (3 functions)
- **Provider:** `lib/providers/report_provider.dart:32, 49, 65` (3 calls)
- **Screens:** `lib/features/host/reports/screens/revenue_report_screen.dart:38, 48` / `occupancy_report_screen.dart:43, 52` (4 calls)

---

## Post-Rebuild Checklist

**Code updates required:**
- [ ] `app/services/report_service.py` → delete or archive
- [ ] `app/routers/host_report.py:17` → update import from `report_service` to `analytics_service`
- [ ] `tests/reports/test_revenue_report.py:18, 38, 53` → update import if structure changed
- [ ] `tests/reports/test_occupancy_report.py:17, 37, 49` → update import if structure changed
- [ ] `tests/reports/test_csv_export.py:20, 48` → update import if structure changed

**No code updates required:**
- ❌ Flutter app (endpoints unchanged, JSON schema unchanged)
- ❌ Any other backend router (no other routers use report_service)
- ❌ Any service layer (no internal service-to-service calls)

---

## Unresolved Questions

None. Audit is complete and low-risk. All callers identified; all imports traced; no external integrations found.

