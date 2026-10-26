---
title: "Phase 00 — Gate Conditions"
status: pending
priority: P0
estimated_effort: 2-3d
blocked_by: []
owner: TBD
---

## Context Links
- BA: `phase-00-ba-requirements.md` §11.1 (6 critical conditions), §11.3 (data privacy), R9, R10, R11, R12
- Researcher: `research/researcher-legacy-consumers.md`, `research/researcher-migration-safety.md` §Unresolved (6 Qs)

## Overview
- Priority: P0 — blocks all downstream phases
- Status: pending
- Brief: Clear 6 BA Leader pre-conditions + resolve 6 migration-safety questions before any code lands. Hard gate.

## Key Insights (from research)
- Legacy `report_service.py`: 4 routes + 1 Flutter repo + 8 tests; researcher confirms LOW risk but Tech Lead must re-verify no admin/cron consumers slipped (R9).
- Migration researcher recommends pre-flight read-only queries on prod-clone DB (R10).
- BA Leader explicit: AC-10 TT200 spec = "best-effort draft" until accountant signs off (R11).

## Requirements
### Functional
- Grep audit re-run + delta vs researcher findings.
- Tax accountant (2-3 pilots) booked + ETA + budget documented.
- Migration pre-flight queries executed on prod-clone DB; results stored.
- Heatmap mobile prototype proven on Samsung A14 + iPhone SE.
- Drill 4-level wireframe approved (paper/Figma OK).
- 6 unresolved migration Qs answered by Tech Lead.

### Non-functional
- Each output stored in `reports/phase-00-*.md` (traceability for audit).

## Architecture / Design
- No code. Gate enforced via report deliverables.

## Files
### Create
- `reports/phase-00-legacy-grep.md` — grep output + caller delta
- `reports/phase-00-accountant-booking.md` — pilot list, contract status, cost, ETA
- `reports/phase-00-migration-preflight.md` — query results from prod-clone (source distribution, host_id nulls, row counts)
- `reports/phase-00-heatmap-wireframe.md` — link/embed wireframe + device-test notes
- `reports/phase-00-drill-wireframe.md` — link/embed wireframe + breadcrumb + back-to-summary spec
- `reports/phase-00-migration-questions-resolved.md` — answers to 6 Qs (table form)

### Modify
- `plan.md` — add gate sign-off note when all 6 cleared

### Delete
- none

## Implementation Steps
1. **Grep audit:** run `grep -rn "report_service" ancu365-backend/` and `grep -rn "fetchRevenue\|fetchOccupancy\|exportInvoicesCsv" ancu365-app/`; cross-check vs `researcher-legacy-consumers.md` §Caller Code References; flag any missed caller.
2. **Accountant booking:** identify 2-3 kế toán via host pilot pool; capture: name, scope (review TT200 template + sample export), fee, ETA. Block Phase 09 until at least 1 sign-off committed.
3. **Migration pre-flight:** restore prod-clone DB on staging; run queries from `researcher-migration-safety.md` §Dry-Run Checklist Pre-flight; capture: source distribution, host_id NULL counts, total row counts. If any anomaly → escalate.
4. **Heatmap prototype:** spike Flutter widget (50 rows × 31 cols) with `ListView.builder` + `Container` cells + sticky first col via `Stack`; benchmark scroll fps on Samsung A14 (or emulator). If <30fps with 50 rows → confirm group-view fallback approach per AC-08.
5. **Drill wireframe:** sketch (paper / Figma) navigation Phòng → Contract → Tenant → Invoice w/ breadcrumb sticky top + "back to summary" CTA visible on all 4 levels.
6. **Resolve 6 migration Qs:** record decisions for each in `reports/phase-00-migration-questions-resolved.md`:
   - Q1 (hidden admin filter by source) → decide based on grep result.
   - Q2 (Invoice.commission_amount source) → Decision: computed from Reservation.commission_rate at invoice generation time; manual override allowed via admin tool (out of MVP scope).
   - Q3 (CreditNote vs commission adjustment) → Decision: commission LOCKED at Invoice.paid time; refund via CreditNote does NOT reverse commission (commission still owed to platform per business rule).
   - Q4 (cascade delete host → contract) → Decision: keep current RESTRICT; orphan prevention out of analytics scope.
   - Q5 (monthly_revenue_goal audit trail) → Decision: not logged; goal is host-mutable; ChangeLog defer to V2.
   - Q6 (split source per reservation) → Decision: NO; 1 source_id per row; document as known limitation.

## Todo List
- [ ] Grep audit done + report saved
- [ ] Accountant pilots contacted; ≥1 commitment documented
- [ ] Migration pre-flight queries executed on prod-clone + report saved
- [ ] Heatmap prototype runs ≥30fps on Samsung A14 OR group-view fallback confirmed
- [ ] Drill wireframe reviewed by 1 designer + 1 host pilot
- [ ] 6 migration Qs resolved + report saved
- [ ] `plan.md` updated w/ gate sign-off note

## Test Strategy
- N/A (no code). Validation = stakeholder review of each report.

## Success Criteria
- All 6 reports present in `reports/`.
- No "unknown source" rows in pre-flight (R10 cleared).
- ≥1 accountant signed engagement letter / informal commit (R11 cleared).
- Heatmap prototype demo recorded ≥30fps OR group-view fallback validated.
- Drill wireframe sign-off email/Slack screenshot attached.

## Risk Assessment
- **Accountant unavailable** → fallback: extend Phase 09 timeline 1 sprint; do NOT launch TT200 without sign-off.
- **Pre-flight reveals dirty source data** → escalate; add data-cleanup migration as revision 0010.5 before 0011.
- **Heatmap fails 30fps** → confirm group-view-only approach; communicate downscope to user.

## Security Considerations
- Pre-flight queries READ-ONLY; no writes to prod-clone.
- Accountant pilot data: anonymize tenant PII before sharing TT200 sample (BA §11.3).
- Wireframes: no real host/tenant names.

## Acceptance Criteria Coverage
- Indirect support for AC-08 (heatmap UX), AC-10 (TT200), AC-16 (no IDOR found in legacy grep).
- Enables R9, R10, R11, R12 mitigation.

## Definition of Done
- 6 reports saved + linked from `plan.md`.
- User explicit approval to start Phase 01.
