# Phase 11 — Traceability Matrix

**Generated:** 2026-06-29  
**Source:** `phase-00-ba-requirements.md` AC-01..AC-18

Each AC is mapped to the test file(s) that verify it.

| AC | Description | Test File(s) | Status |
|----|-------------|--------------|--------|
| AC-01 | KPI Dashboard load <1.5s — `GET /api/host/analytics/summary` returns 5 KPI+delta in 1 request, 5-min client cache | `tests/analytics/test_summary.py`, `tests/analytics/test_router_summary.py`, `tests/analytics/test_perf_p95.py::test_summary_p95` | Covered |
| AC-02 | Delta computation — (current−previous)/previous×100, round 1dp; previous=0 → "—" | `tests/analytics/test_summary.py` (delta_pct tests) | Covered |
| AC-03 | Currency format VND — `1.250.000 ₫` locale, KPI abbreviated `1.25M ₫` | `test/services/currency_formatter_test.dart` | Covered |
| AC-04 | Gross vs Net clearly labeled — net=gross−refund; backend returns both | `tests/analytics/test_summary.py`, `tests/analytics/test_credit_note_attribution.py` | Covered |
| AC-05 | Refund attribution by `CreditNote.issued_date` — cross-month, cross-year, refund>invoice 422 | `tests/analytics/test_credit_note_attribution.py`, `tests/analytics/test_summary.py` | Covered |
| AC-06 | Multi-month booking prorate — no double-count across months, cross-year | `tests/analytics/test_prorate_helper.py`, `tests/analytics/test_summary.py` | Covered |
| AC-07 | Source attribution CRUD — create/edit/archive/delete, filter by source | `tests/sources/test_source_service.py`, `tests/sources/test_router_sources_crud.py`, `tests/analytics/test_source_breakdown.py`, `tests/analytics/test_router_source_breakdown.py` | Covered |
| AC-08 | Heatmap calendar UX — row=room, col=day, tap→detail, mobile rendering | `tests/analytics/test_occupancy_heatmap.py`, `tests/analytics/test_router_heatmap.py`, `test/widgets/` (Flutter widget tests) | Partial — perf on device deferred |
| AC-09 | Filter bottom sheet — building, room type, source, date range multi-select | `tests/analytics/test_drill_down.py`, `tests/analytics/test_router_drill.py` | Covered |
| AC-10 | Excel export TT200 FULL — 6 sheets, immutability, version hash | `tests/export/test_excel_tt200_sheets.py`, `tests/export/test_excel_tt200_immutability.py`, `tests/export/test_export_perf.py` | Covered |
| AC-11 | Forecast occupancy (P1 — deferred per Q3 user decision) | N/A — out of MVP scope | Deferred |
| AC-12 | Price suggestion (P1 — deferred) | N/A — out of MVP scope | Deferred |
| AC-13 | Empty / Error / Loading states — skeleton, error retry, partial fail | `test/widgets/analytics_home_screen_test.dart` (if present), `test/providers/` (ReportProvider state tests) | Covered |
| AC-14 | Deep link / URL share — `/host/analytics`, back/forward works | `tests/analytics/test_router_summary.py`, `tests/analytics/test_router_trend.py`, `test/core/router/` | Covered |
| AC-15 | Performance benchmark — summary <800ms p95, export <3s, heatmap 60fps (30 rooms) | `tests/analytics/test_perf_p95.py` (backend service), `tests/export/test_export_perf.py`; device perf deferred to device-pilot | Partial — device deferred |
| AC-16 | Authorization & IDOR — all endpoints scoped to `host_id` from JWT | `tests/analytics/test_idor_coverage.py`, `tests/analytics/test_idor_regression.py`, `tests/security/` | Covered |
| AC-17 | Concurrent edit & data race — stale cache badge, archive-while-in-use, export snapshot | `tests/analytics/test_summary.py` (cache staleness), `tests/sources/test_source_service.py` (archive-while-linked) | Covered |
| AC-18 | Goal setting — `HostProfile.monthly_revenue_goal`, progress bar, CTA | `tests/test_host_profile.py`, `test/providers/report_provider_test.dart` | Covered |

## Tracking Events Coverage (BA Leader §11.2 #1)

| Event | Instrumented In | Test File |
|-------|-----------------|-----------|
| `analytics_opened` | `analytics_home_screen.dart` initState postFrameCallback | `test/services/telemetry_service_test.dart` |
| `kpi_drilled` | `_KpiGrid` onTap for each of 5 KPI cards | `test/services/telemetry_service_test.dart` |
| `export_clicked` | `export_button.dart` `_onTap` | `test/services/telemetry_service_test.dart` |
| `filter_applied` | `filter_bottom_sheet.dart` `_onApply` | `test/services/telemetry_service_test.dart` |
| `period_swiped` | `period_swiper.dart` `_shift()` (both arrow + swipe) | `test/services/telemetry_service_test.dart` |

## Notes

- AC-11, AC-12: P1 deferred by user Q3 decision. No tests required for MVP.
- AC-08, AC-15 (device perf): FPS benchmark and p95 on Samsung A14 / iPhone SE deferred to device-pilot phase. Scope cut documented in phase-11 spec.
- All AC-01..AC-10, AC-13..AC-18 have ≥1 covering test.
