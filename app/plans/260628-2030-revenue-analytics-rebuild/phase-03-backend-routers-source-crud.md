---
title: "Phase 03 — Backend Routers + Source CRUD"
status: pending
priority: P0
estimated_effort: 3-4d
blocked_by: [phase-02]
owner: TBD
---

## Context Links
- BA: AC-01 (KPI <1.5s), AC-07 (source CRUD), AC-16 (IDOR)
- Researcher: `research/researcher-architecture-patterns.md` §Router Pattern, §Auth & IDOR Pattern; `research/researcher-legacy-consumers.md` §Backend Callers

## Overview
- Priority: P0
- Status: pending
- Brief: Wrap `analytics_service` + `source_service` in FastAPI routers w/ Pydantic v2 response schemas + auth gate. Remove old `host_report.py` calls to `report_service`; replace with `analytics_service`. Delete `host_report.py` after consumers verified.

## Key Insights (from research)
- Existing pattern: `APIRouter(prefix="/api/host/<feature>", tags=["host-<feature>"])` + `Depends(auth.require_host)` + `int(claims["sub"])` for host_id.
- Pydantic v2: `model_config = {"from_attributes": True}`, `Literal[...]` for enums.

## Requirements
### Functional
- `host_analytics.py` router w/ 5 endpoints:
  - `GET /api/host/analytics/summary?period&date` → SummaryResponse (5 KPI + delta)
  - `GET /api/host/analytics/revenue-trend?period&anchor_date` → TrendResponse (12 buckets dual-line)
  - `GET /api/host/analytics/occupancy-heatmap?month&building_id?` → HeatmapResponse (matrix)
  - `GET /api/host/analytics/source-breakdown?period&date` → SourceBreakdownResponse (stacked bar)
  - `GET /api/host/analytics/drill-down?level&filter[...]` → DrillResponse (paged list)
- `host_sources.py` router w/ 4 endpoints:
  - `GET /api/host/sources` → list (active + archived flag)
  - `POST /api/host/sources` → create
  - `PATCH /api/host/sources/{id}` → rename / color update / archive toggle
  - `DELETE /api/host/sources/{id}` → hard-delete (only if count=0); else 409 Conflict
- Migrate `host_report.py` callers to `analytics_service` (keep legacy `/api/host/reports/revenue`, `/occupancy`, `/export` endpoints as thin shims pointing at new service for 1 sprint — backward compat for Flutter pre-update).

### Non-functional
- All endpoints respond 4xx for unauthorized; 422 for validation; never 500 leak stack trace.
- Pydantic schemas in `app/schemas/analytics.py` + `app/schemas/source.py`.

## Architecture / Design
- Mirror existing router pattern (sync, dependency injection).
- Auth gate: `Depends(auth.require_host)` on every endpoint.
- Host_id: `int(claims["sub"])`.
- Query params validated via `Query(...)` w/ regex pattern.
- Response model = Pydantic class w/ `from_attributes=True`.
- `model_dump()` not needed (FastAPI auto-serializes).

### Key decisions
- Legacy `/api/host/reports/*` endpoints kept 1 sprint as shim → reduce Flutter breakage during Phase 04 rollout; remove in Phase 11 cleanup.
- `drill-down` single endpoint w/ `level` enum query param (1-4) — avoids 4 separate routes.
- `/source-breakdown` returns top 8 + "Khác" aggregated bucket (UI logic stays simple).
- Excel TT200 export = Phase 09 separate router; NOT in this phase.

## Files
### Modify
- `ancu365-backend/app/main.py` — register new routers
- `ancu365-backend/app/routers/host_report.py` — replace `report_service` imports w/ `analytics_service` shim; mark legacy endpoints as deprecated (header `X-Deprecated: true`).

### Create
- `ancu365-backend/app/routers/host_analytics.py` — 5 endpoints
- `ancu365-backend/app/routers/host_sources.py` — 4 endpoints
- `ancu365-backend/app/schemas/analytics.py` — `SummaryResponse`, `TrendResponse`, `HeatmapResponse`, `SourceBreakdownResponse`, `DrillResponse`, sub-models
- `ancu365-backend/app/schemas/source.py` — `SourceResponse`, `SourceCreate`, `SourceUpdate`
- `ancu365-backend/tests/analytics/test_router_summary.py`
- `ancu365-backend/tests/analytics/test_router_trend.py`
- `ancu365-backend/tests/analytics/test_router_heatmap.py`
- `ancu365-backend/tests/analytics/test_router_source_breakdown.py`
- `ancu365-backend/tests/analytics/test_router_drill.py`
- `ancu365-backend/tests/sources/test_router_sources_crud.py`
- `ancu365-backend/tests/analytics/test_idor_coverage.py` — host_A cannot read host_B data

### Delete
- `ancu365-backend/tests/reports/test_revenue_report.py`, `test_occupancy_report.py`, `test_csv_export.py` — archive (move to `tests/_archive/`) or rewrite as integration tests targeting new endpoints.

## Implementation Steps
1. Define Pydantic v2 schemas matching dict shape from Phase 02.
2. Implement `host_analytics.py` — 5 endpoints w/ `Depends(auth.require_host)`, `Query` validation.
3. Implement `host_sources.py` — 4 CRUD endpoints; DELETE checks count via `source_service`.
4. Register routers in `app/main.py`.
5. Modify `host_report.py` — swap `report_service` → `analytics_service` calls; add deprecation header; preserve legacy JSON shape via adapter.
6. Write IDOR test: seed 2 hosts × 3 sources each; assert host_A GET sources returns only own.
7. Write contract tests for each endpoint (200, 401, 403, 422 cases).
8. Update OpenAPI tags + descriptions.

## Todo List
- [ ] `app/schemas/analytics.py` + `app/schemas/source.py` written
- [ ] `host_analytics.py` 5 endpoints + tests
- [ ] `host_sources.py` 4 endpoints + tests
- [ ] `host_report.py` legacy adapter + deprecation header
- [ ] IDOR test passes for sources + analytics
- [ ] Routers registered in `main.py`
- [ ] Legacy tests archived
- [ ] Flutter contract docs updated (share dict shape w/ Phase 04)

## Test Strategy
### Unit
- Pydantic schema validation (round-trip serialization).
- Query param regex (period `^(month|year)$`, date `^\d{4}-\d{2}$` or `^\d{4}$`).

### Integration
- Each endpoint: 200 happy path, 401 missing token, 403 wrong role, 422 invalid params.
- IDOR coverage: host_A vs host_B isolation across all 9 endpoints.
- Source CRUD: 409 Conflict on DELETE w/ linked reservations.

### E2E
- N/A (Phase 11).

## Success Criteria
- All endpoints respond w/ documented schema.
- All test pass; IDOR coverage 100%.
- Legacy `/api/host/reports/*` shim returns identical JSON to old impl (verified vs archived test snapshots).
- OpenAPI docs render cleanly at `/docs`.

## Risk Assessment
- **Pydantic schema mismatch w/ dict from Phase 02** → mitigated by day-3 schema freeze + adapter pattern.
- **Legacy endpoint shim drift** → kept only 1 sprint, removed in Phase 11.
- **CRUD race conditions on archive** → covered by AC-17 test cases.

## Security Considerations
- IDOR: explicit test per endpoint (AC-16).
- Auth: `Depends(auth.require_host)` mandatory; no anonymous access.
- 422 details do NOT leak DB schema (use generic messages).
- `DELETE /sources/{id}` ownership check via host_id filter in `source_service`.

## Acceptance Criteria Coverage
- AC-01 (KPI <1.5s — backend slice) ✓
- AC-07 (source CRUD endpoints) ✓
- AC-16 (IDOR on all endpoints) ✓

## Definition of Done
- 9 new endpoints live + tests green.
- Legacy shim verified (Flutter pre-update still works).
- OpenAPI docs reviewed.
- Coverage ≥80% on routers.
