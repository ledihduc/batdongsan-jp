---
title: "Phase 11 — E2E Tests + Performance Benchmark"
status: pending
priority: P0
estimated_effort: 3-4d
blocked_by: [phase-09, phase-10]
owner: TBD
---

## Context Links
- BA: AC-15 (perf), AC-16 (IDOR), all AC validation
- BA Leader: §11.2 #1 (analytics tracking events)
- All prior phases

## Overview
- Priority: P0
- Status: pending
- Brief: Full E2E coverage, perf benchmark on baseline devices, IDOR regression, analytics tracking events instrumented, coverage ≥80% verified, legacy `host_report.py` shim removed.

## Key Insights (from research)
- Existing test infrastructure: `pytest` + `pytest-postgresql` (backend); `flutter_test` + widget tests (Flutter).
- AC-15 baseline devices: Samsung A14 (Android 13, 4GB) + iPhone SE 2020 (3GB).
- Analytics tracking: `analytics_opened`, `kpi_drilled`, `export_clicked` (BA Leader §11.2 #1).

## Requirements
### Functional
- E2E flow tests:
  1. Login → analytics home → 5 KPI render w/ data.
  2. Swipe period → KPI refresh.
  3. Tap KPI → drill level 1 → tap row → level 2 → breadcrumb → back-to-summary.
  4. Filter by source + building → drill refetched.
  5. Open occupancy heatmap → tap cell → bottom sheet.
  6. Source management — add/edit/archive/delete (linked vs unlinked).
  7. Export TT200 → re-auth → download → share.
  8. Offline mode — disconnect network, badge appears, cached data shown.
- Perf benchmarks (recorded in `reports/phase-11-perf-benchmark.md`):
  - KPI summary fetch <800ms p95 server (1000-invoice fixture).
  - KPI render <1.5s on Samsung A14 + iPhone SE.
  - Heatmap 60fps w/ 30 rooms; ≥30fps w/ 50-100 rooms.
  - Excel export 12 months <3s server-side.
- Analytics tracking instrumented (`analytics_opened`, `kpi_drilled`, `export_clicked`, `filter_applied`, `period_swiped`).
- IDOR regression suite re-run.
- Legacy `/api/host/reports/*` shim removed (Phase 03 deferred cleanup).
- Coverage report: `analytics_service.py` ≥80%, `excel_exporter_tt200.py` ≥80%.

### Non-functional
- All benchmarks reproducible via documented script.
- Tracking events documented in `docs/system-architecture.md`.

## Architecture / Design
- Use existing `integration_test/` folder (already present).
- Perf benchmark via `integration_test` w/ `WidgetsBinding.endOfFrame` timestamps.
- Analytics events sent to existing telemetry endpoint (check if exists; else add stub `_telemetry_service.dart`).

### Key decisions
- **Backend perf:** use `pytest-benchmark` for service layer; locust optional for endpoint load (defer).
- **Flutter perf:** `integration_test` w/ frame-timing assertions.
- **Tracking provider:** lightweight `TelemetryService` w/ `track(event, props)`; backend telemetry sink existing or stub.

## Files
### Modify
- `ancu365-backend/app/routers/host_report.py` — REMOVE (legacy shim cleanup); update `main.py`
- `lib/data/repositories/api_report_repository.dart` — REMOVE (legacy v1 shim); ensure no callers remain
- `docs/system-architecture.md` — add analytics tracking events table

### Create
- `integration_test/analytics_e2e_test.dart` — 8 E2E flows
- `integration_test/heatmap_perf_test.dart` — fps assertion
- `integration_test/idor_regression_test.dart` — host_A vs host_B
- `ancu365-backend/tests/analytics/test_perf_p95.py` — pytest-benchmark
- `ancu365-backend/tests/export/test_export_perf.py` — 12-month <3s
- `lib/core/telemetry/telemetry_service.dart` (or extend if exists)
- `test/services/telemetry_service_test.dart`
- `reports/phase-11-perf-benchmark.md`
- `reports/phase-11-coverage-report.md`
- `reports/phase-11-tracking-events.md`
- `reports/phase-11-traceability-matrix.md` (AC-01..AC-18 ↔ test file mapping)

### Delete
- `ancu365-backend/app/routers/host_report.py` (after Flutter v1 repo confirmed removed)
- `lib/data/repositories/api_report_repository.dart` (v1 — replaced by ApiAnalyticsRepository in Phase 04)
- `lib/features/host/reports/screens/revenue_report_screen.dart` (old screen, replaced by analytics_home_screen)
- `lib/features/host/reports/screens/occupancy_report_screen.dart` (old screen)
- `lib/features/host/reports/screens/adr_report_screen.dart` (old screen)
- `lib/features/host/reports/widgets/period_selector.dart` (replaced by period_swiper)

## Implementation Steps
1. Build `TelemetryService` skeleton; emit 5 events; backend sink optional (log-only OK MVP).
2. Instrument analytics screens w/ tracking calls.
3. Write 8 E2E flow tests in `integration_test/analytics_e2e_test.dart`.
4. Write heatmap fps test (frame timing assertions for 30 + 50 rooms).
5. Write backend perf tests (`pytest-benchmark` on `analytics_service.summary` w/ 1000-invoice fixture).
6. Write export perf test (12-month dataset <3s).
7. Run IDOR regression test on all 9 analytics + 4 source endpoints.
8. Generate coverage report (`pytest --cov=app.services.analytics_service --cov-report=html`); confirm ≥80%.
9. Delete legacy files (host_report router, v1 repo, old screens, old widgets).
10. Update routing: remove `/host/reports` route; redirect to `/host/analytics`.
11. Build traceability matrix (AC ↔ test file).
12. Update docs.

## Todo List
- [ ] `TelemetryService` + tests
- [ ] Tracking calls instrumented in screens
- [ ] 8 E2E flow tests pass
- [ ] Heatmap perf test passes on Samsung A14
- [ ] Backend perf tests pass (<800ms p95, <3s export)
- [ ] IDOR regression covers 13 endpoints (9 analytics + 4 sources)
- [ ] Coverage ≥80% verified + report attached
- [ ] Legacy files deleted; no compile errors
- [ ] `/host/reports` route removed/redirected
- [ ] Traceability matrix complete
- [ ] Docs updated

## Test Strategy
### Unit
- `TelemetryService.track()` enqueues event correctly.

### Integration
- All endpoints respond w/ documented schema.
- IDOR host_A vs host_B.

### E2E
- 8 user flows above.
- Perf benchmarks.

## Success Criteria
- All E2E tests pass on both Samsung A14 + iPhone SE.
- Perf benchmarks meet targets in AC-15.
- Coverage ≥80% on analytics_service.py + excel_exporter_tt200.py.
- IDOR regression suite 100% pass.
- Traceability matrix shows every AC-01..AC-18 covered by ≥1 test.
- Legacy code removed; no dead code.

## Risk Assessment
- **Perf miss on iPhone SE** → reduce concurrent fetches; lazy-load heatmap.
- **Telemetry endpoint missing** → log-only MVP; backend sink V2.
- **Legacy delete breaks unknown caller** → run full app smoke test before delete; final go/no-go.

## Security Considerations
- IDOR regression mandatory.
- Telemetry payloads must NOT include PII (tenant names, MST).
- Audit log (Phase 09) reviewed for sensitive data hygiene.

## Acceptance Criteria Coverage
- AC-01..AC-18 all validated via traceability matrix ✓
- AC-15 (perf) ✓
- AC-16 (IDOR) ✓
- BA Leader §11.2 #1 (tracking events) ✓

## Definition of Done
- All E2E + perf + coverage + IDOR criteria met.
- Reports attached in `reports/`.
- Legacy code removed.
- Final code review + security review complete.
- User UAT sign-off.
