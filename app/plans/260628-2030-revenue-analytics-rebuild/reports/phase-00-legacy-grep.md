---
title: "Phase 00 — Legacy report_service.py Grep Verification"
condition: "BA Leader §11.1 #5 (R9)"
status: completed
verified_by: Tech Lead (Claude)
date: 2026-06-28
---

# Phase 00 Gate — Legacy report_service.py Caller Verification

## Goal
Re-run grep to detect any caller researcher missed before deleting `app/services/report_service.py` (Q10 rebuild decision). Confirms R9 risk mitigation.

## Method
Executed 4 greps on backend + Flutter:
1. `report_service` symbol — backend Python
2. Function names (`revenue_report`, `occupancy_report`, `adr_report`, `export_invoices_csv`) — backend Python
3. Background/cron/Zalo digest keywords — backend Python
4. Endpoint URL patterns (`/api/host/reports/*`) — Flutter Dart + endpoint declarations backend

## Findings — Confirmed Callers

### Backend Production Code (1 file, 4 endpoints)

| File:line | Endpoint | Function used | Auth |
|---|---|---|---|
| `app/routers/host_report.py:17` | `from app.services import report_service` | (import) | — |
| `app/routers/host_report.py:22-30` | `GET /api/host/reports/revenue` | `revenue_report` | `auth.require_host` |
| `app/routers/host_report.py:43` | `GET /api/host/reports/occupancy` | `occupancy_report` | `auth.require_host` |
| `app/routers/host_report.py:57` | `GET /api/host/reports/adr` | `adr_report` | `auth.require_host` |
| `app/routers/host_report.py:61-72` | `GET /api/host/reports/export` | `export_invoices_csv` | `auth.require_host` |

### Backend Tests (3 files — DELTA: +1 vs researcher)

| File | References | Functions tested |
|---|---|---|
| `tests/reports/test_revenue_report.py` | 6 (lines 18, 20, 38, 41, 53, 55) | `revenue_report` |
| `tests/reports/test_csv_export.py` | 4 (lines 20, 23, 48, 69) | `export_invoices_csv` |
| **`tests/reports/test_occupancy_report.py`** ⚠️ **MISSED BY RESEARCHER** | 7 (lines 18, 20, 37, 40, 50, 52, 57) | `occupancy_report` |

### Flutter Callers (3 files)

| File:line | Method | Endpoint |
|---|---|---|
| `lib/providers/report_provider.dart:24-65` | `fetchRevenue`, `fetchOccupancy`, `downloadInvoicesCsv` | wraps repo |
| `lib/data/repositories/api_report_repository.dart:14, 25, 37` | repo HTTP calls | `/api/host/reports/{revenue,occupancy,export}` |
| `lib/features/host/reports/screens/{revenue,occupancy,adr}_report_screen.dart`, `reports_home_screen.dart` | consumer UI | via provider |

## Findings — No-Hit (clean)

✅ **No cron / APScheduler caller** for report_service functions (only `planning_etl/scheduler.py` exists, unrelated)
✅ **No Zalo digest / hook** calling report_service — Zalo only used for `host_dashboard.py` invoice reminder + `host_invoice.py` zalo-link (separate flow)
✅ **No admin/staff router** importing report_service
✅ **No `httpx` / `requests` self-call** to `/api/host/reports/*`
✅ **No private helper leak** — `_period_prefix`, `_csv_row`, `_days_in_month` (private to report_service) NOT imported anywhere. Note: `availability_service.py:28` has its OWN `_days_in_month` — different scope, no collision.
✅ **No background_task** queues `report_service` functions

## Delta vs Researcher Report

| Item | Researcher | Tech Lead Verify | Delta |
|---|---|---|---|
| Backend routers | 1 file (`host_report.py`) | 1 file | ✅ Match |
| Backend test files | 3 (`test_revenue_report.py`, `test_csv_export.py`, `test_dashboard_action_items.py`) | 3 (`test_revenue_report.py`, `test_csv_export.py`, **`test_occupancy_report.py`**) | ⚠️ **Different file** — researcher listed `test_dashboard_action_items.py` but it uses `zalo`, NOT `report_service`. Actual third file is `test_occupancy_report.py`. |
| External integrations | 0 | 0 | ✅ Match |
| Flutter consumers | 1 repo | 3 files (repo + provider + screens) | Minor — provider/screens are indirect (via repo), researcher counted repo only. OK. |

## Conclusion

**R9 risk: CLEARED ✅**

- Rebuild path is LOW risk as researcher claimed.
- **Required test file rewrite list** (rebuild Phase 02 must port these):
  1. `tests/reports/test_revenue_report.py` — port assertions to new `analytics_service.revenue_summary`
  2. `tests/reports/test_csv_export.py` — port to new `excel_exporter_tt200` (CSV → TT200 Excel)
  3. **`tests/reports/test_occupancy_report.py`** — port to new `analytics_service.occupancy_heatmap` ⚠️ (newly identified, Phase 02 must include)
- **Required Flutter migration:** `api_report_repository.dart` v2 + `report_provider.dart` extended methods (already in Phase 04 plan)
- **No cron/Zalo/admin migration needed** — clean delete

## Recommended Phase 02 Update

Phase 02 todo list MUST include:
- [ ] Port `test_occupancy_report.py` assertions to new occupancy_heatmap test (was implicit, now explicit)

## Sign-off
- Tech Lead Claude — verified 2026-06-28
- Researcher report at `research/researcher-legacy-consumers.md` requires minor correction (third test file misidentified)

**Gate condition #5 (R9): ✅ CLEARED**
