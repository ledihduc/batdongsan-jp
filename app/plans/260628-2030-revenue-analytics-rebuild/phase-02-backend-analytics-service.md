---
title: "Phase 02 — Backend Analytics Service Rebuild"
status: pending
priority: P0
estimated_effort: 7-9d
blocked_by: [phase-01]
owner: TBD
---

## Context Links
- BA: AC-04 (gross/net), AC-05 (refund), AC-06 (multi-month prorate), AC-16 (IDOR), AC-17 (race), Q10 (rebuild from scratch)
- Researcher: `research/researcher-legacy-consumers.md` §Risk Matrix (LOW); `research/researcher-architecture-patterns.md` §Service Layer Pattern

## Overview
- Priority: P0
- Status: pending
- Brief: Delete `app/services/report_service.py`. Create `app/services/analytics_service.py` with gross/net split, multi-month prorate, refund-by-CreditNote-date attribution, TZ-aware (Asia/Ho_Chi_Minh) aggregation. Plus `app/services/source_service.py` for CRUD revenue_sources.

## Key Insights (from research)
- Legacy `report_service.py` consumed by exactly 4 backend routes + 1 Flutter repo + 8 tests (LOW risk delete).
- All existing services are sync SQLAlchemy; router owns commit; service receives `host_id: int` explicitly (`researcher-architecture-patterns.md` §Service Layer Pattern).
- IDOR pattern: every query `.filter(Model.host_id == host_id)` or via Building→host_id join.

## Requirements
### Functional
- `analytics_service.summary(db, host_id, period, date_str)` → 5 KPI (gross, net, occupancy_pct, adr, booking_pace) + delta vs prior period.
- `analytics_service.revenue_trend(db, host_id, period, anchor_date)` → 12-month dual-line (current vs prior).
- `analytics_service.occupancy_heatmap(db, host_id, month, building_id?)` → matrix [room_id][day] → status (vacant/booked/paid/overdue).
- `analytics_service.source_breakdown(db, host_id, period, date_str)` → stacked bar data grouped by source_id (max 8 + "Khác" bucket).
- `analytics_service.drill_down(db, host_id, level, filter)` → 4 levels (room→contract→tenant→invoice).
- `source_service.list/create/update/archive/delete(db, host_id, ...)` w/ validation per AC-07.
- Gross/Net formula: `net = gross − refund − commission − tax` (commission default 0 for legacy; tax field deferred — assume 0 in MVP).
- Refund attribution: `CreditNote.issued_date` not `Invoice.issued_at`.
- Prorate: `prorate_amount = total / total_nights × nights_in_period` for homestay; `monthly_rent / days_in_month × days_active_in_period` for long-term contracts.

### Non-functional
- p95 server response <800ms with 1000-invoice/host dataset (AC-15).
- All aggregation queries TZ-converted to Asia/Ho_Chi_Minh before `date_trunc()`.
- Zero N+1: use `joinedload`/single aggregation query.
- Coverage ≥80% on `analytics_service.py`.

## Architecture / Design
- Pure functions, sync, no commit (per `researcher-architecture-patterns.md`).
- Helpers in `app/services/_analytics_helpers.py`: `_period_range_hcm(period, date_str) → (start_utc, end_utc)`, `_prorate(amount, nights_total, nights_in_period)`, `_apply_credit_notes(invoice_rows, period_start_utc, period_end_utc)`.
- TZ: use `zoneinfo.ZoneInfo("Asia/Ho_Chi_Minh")`; convert HCM local day boundary → UTC before SQL filter.
- Service returns dict (not Pydantic); router wraps.

### Key decisions
- **Schema freeze checkpoint (day 3):** dict shape locked → Phase 04 (Flutter data layer) can start in parallel.
- Gross/Net split: backend returns BOTH values; Flutter toggles display.
- Reject `refund_amount > invoice.total` w/ HTTP 422 + log (AC-05 edge 3).
- Voided invoice immutability: TT200 export uses snapshot from `tt200_exports` table — invoice void post-export does NOT mutate prior version (AC-05 edge 4 — actual immutability lives in Phase 09; service layer just exposes `status` field).
- Cross-year prorate (31/12→01/01): split per HCM calendar day; YoY queries treat 2025-12 + 2026-01 separately (AC-06 edge c).
- Helper `_apply_credit_notes` filters by `CreditNote.issued_date BETWEEN period_start AND period_end` (NOT invoice date) → mitigates AC-05 edge 1/2.

## Files
### Modify
- (none in this phase — phase 01 already updated models)

### Create
- `ancu365-backend/app/services/analytics_service.py` — 5 public functions + private helpers
- `ancu365-backend/app/services/source_service.py` — CRUD revenue_sources
- `ancu365-backend/app/services/_analytics_helpers.py` — `_period_range_hcm`, `_prorate`, `_apply_credit_notes`
- `ancu365-backend/tests/analytics/test_summary.py`
- `ancu365-backend/tests/analytics/test_revenue_trend.py`
- `ancu365-backend/tests/analytics/test_occupancy_heatmap.py`
- `ancu365-backend/tests/analytics/test_source_breakdown.py`
- `ancu365-backend/tests/analytics/test_drill_down.py`
- `ancu365-backend/tests/analytics/test_prorate_helper.py` — covers AC-06 a/b/c/d/e
- `ancu365-backend/tests/analytics/test_credit_note_attribution.py` — covers AC-05 edge 1/2/3/4
- `ancu365-backend/tests/sources/test_source_service.py` — covers AC-07 archive vs hard-delete

### Delete
- `ancu365-backend/app/services/report_service.py` — per Q10 (after Phase 03 router migration completes; coordinate file deletion in Phase 03 PR)
- Note: tests in `tests/reports/` will be archived / rewritten in Phase 03.

## Implementation Steps
1. Scaffold `_analytics_helpers.py`: `_period_range_hcm`, `_prorate`, `_apply_credit_notes` w/ unit tests first (TDD).
2. Implement `analytics_service.summary()` — query Invoice + CreditNote + Reservation grouped by HCM period; compute gross, net, occupancy, ADR, booking_pace; compute delta vs prior period (n-1).
3. Implement `revenue_trend()` — 12-period rolling, dual-line current vs prior.
4. Implement `occupancy_heatmap()` — matrix per room×day; build via single Reservation+Contract query, prorate per day; aggregate-row fallback (per AC-08) deferred to Flutter, backend always returns full matrix.
5. Implement `source_breakdown()` — group by source_id; cap at top 8 + "Khác" bucket; respect archived sources (still show in historical periods).
6. Implement `drill_down(level, filter)` — 4 levels: room → contract → tenant → invoice. Each returns paged list.
7. Implement `source_service.list/create/update/archive/delete` — w/ AC-07 validation (cannot hard-delete if linked; archive instead; partial unique constraint `WHERE is_archived=FALSE`).
8. Day 3: lock dict response shape; share w/ Phase 04 owner so Flutter models can scaffold.
9. Run pytest suite; aim ≥80% coverage on `analytics_service.py`.
10. Profile p95 against 1000-invoice fixture; tune indices if >800ms.

## Todo List
- [ ] `_analytics_helpers.py` w/ tests covering AC-06 a/b/c/d/e
- [ ] `summary()` + tests (gross/net split, delta math, AC-02 previous=0 case)
- [ ] `revenue_trend()` + tests (12 months, dual-line, missing-period zero-fill)
- [ ] `occupancy_heatmap()` + tests (matrix shape, vacant/booked/paid/overdue status, cross-year boundary)
- [ ] `source_breakdown()` + tests (top 8 + Khác, archived source historical visibility)
- [ ] `drill_down()` + tests (4 levels, paging, IDOR)
- [ ] `source_service` + tests (AC-07 archive vs delete, partial unique constraint)
- [ ] CreditNote attribution tests (AC-05 1/2/3/4)
- [ ] Delete `report_service.py` (coordinate w/ Phase 03)
- [ ] Coverage ≥80% verified

## Test Strategy
### Unit
- Helper functions (prorate cross-year, leap year Feb 28/29, boundary edge).
- Gross/Net formula correctness (legacy data w/ commission=NULL → net=gross).
- AC-05 refund>invoice → raises HTTPException(422).
- AC-17 archived source still groups historical reservations correctly.

### Integration
- Full pipeline test: seed 10 invoices + 2 credit notes + 3 reservations → call `summary()` → assert KPI values match hand-computed.
- IDOR: host_A summary call → assert no host_B data leak.

### E2E
- N/A (Phase 11).

## Success Criteria
- All public functions return dict matching schema-frozen shape (day 3).
- Test suite pass + coverage ≥80%.
- p95 latency <800ms on 1000-invoice/host fixture (BA AC-15).
- `report_service.py` deleted; legacy tests archived.

## Risk Assessment
- **R7 — slow aggregation w/ 50+ rooms** → indexed query on (host_id, period_start), profile early; fallback Redis cache deferred V2.
- **AC-05 edge 4 immutability** → tested at service-layer status field only; full immutability in Phase 09 (tt200_exports table).
- **Schema freeze slip** → if dict shape changes after day 3, must notify Phase 04 owner immediately.

## Security Considerations
- IDOR: every query filters `host_id`; explicit test cases for cross-host leakage.
- No PII in service response except tenant name (used only in drill_down level 3+).
- 422 on bad input prevents negative net write.

## Acceptance Criteria Coverage
- AC-04 (gross/net) ✓
- AC-05 (refund attribution edges 1-4) ✓
- AC-06 (multi-month prorate edges a-e) ✓
- AC-16 (IDOR) ✓
- AC-17 (archived source consistency) ✓
- AC-07 (source CRUD validation) ✓

## Definition of Done
- All functions implemented + tests green + coverage ≥80%.
- Dict response shape documented in `app/schemas/analytics.py` (Phase 03 will wrap in Pydantic).
- `report_service.py` removed.
- p95 benchmark report attached.
