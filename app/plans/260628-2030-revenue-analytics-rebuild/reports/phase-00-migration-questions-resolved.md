---
title: "Phase 00 — 6 Migration Questions Resolved"
condition: "BA Leader §11.1 #6 — Tech Lead must answer before Phase 01"
status: completed
resolved_by: Tech Lead (Claude)
date: 2026-06-28
source: research/researcher-migration-safety.md §Unresolved Questions
---

# Phase 00 Gate — Migration Safety Questions Resolution

## Goal
Resolve 6 unresolved questions from migration researcher report so Phase 01 (DB Migration) has clear specification. Each answer becomes binding contract for migration revision authors.

---

## Decisions

| # | Question | Decision | Rationale | Phase to enforce |
|---|---|---|---|---|
| **Q1** | `Reservation.source` usage in real production? Hidden admin filter? | **No hidden filter found.** Legacy grep (`phase-00-legacy-grep.md`) confirms NO consumer reads `source` for business logic — only test asserts, marketplace_sync_service:334 (sets value), guest_reservation:56 (sets value), host_homestay:69, 241 (returns in response). All write-side; no read-side branching by enum value. | Grep evidence: zero `if reservation.source == "..."` branches found in production code. Safe to migrate. | Phase 01 — migration revision 0012 can drop dual-write fallback for `source` String column if desired (but keep for 1 sprint per Q4 below). |
| **Q2** | Invoice.commission_amount: computed or manual? | **Computed from `Reservation.commission_rate × total_amount` at Invoice generation time. NO manual override in MVP.** Admin override = V2 feature (out of scope). | KISS for MVP. Reservation level holds commission_rate; Invoice persists computed snapshot (denormalized for reconciliation + report perf). Avoids "which is source of truth" ambiguity. Manual override invites accounting drift. | Phase 02 — `analytics_service.compute_commission()` reads `Reservation.commission_rate` field, writes to `Invoice.commission_amount` on Invoice creation. Phase 01 migration adds both fields nullable default 0. |
| **Q3** | CreditNote / refund vs commission: reverse commission on refund? | **NO. Commission is LOCKED at `Invoice.paid_at` time. CreditNote (refund) does NOT reverse commission.** Reasoning: platform business rule — commission earned per booking completion; refund is host/tenant arrangement, platform retains fee. | Industry standard (Airbnb / Booking.com both charge commission on cancellations within penalty window). Reversal would create gaming vector (book → refund loop). Document as "Commission is non-refundable" in host T&C. | Phase 02 — `analytics_service.net_revenue()` formula: `Net = Gross − Refund − Tax` (NO `− Commission` reversal). Commission is constant once paid. Phase 09 TT200 export reflects this in CreditNote sheet. |
| **Q4** | Cascade behavior host deletion → contracts? | **KEEP CURRENT behavior: RESTRICT (no change in this migration).** Orphan prevention is out of analytics scope. If `host_id` becomes NULL (legacy data), revenue_sources backfill assigns to `host_id=NULL` row → orphan handling deferred to separate ops task. | Migration scope = analytics enablement, not data integrity refactor. Changing cascade in same migration mixes concerns → harder rollback. Document orphan count in Phase 00 pre-flight; if >0 → flag ops ticket (out of band). | Phase 01 — migration revision 0011 (revenue_sources) uses `host_id ondelete=CASCADE` (matches existing pattern); existing `contracts` and `reservations` cascade behavior UNCHANGED. |
| **Q5** | `monthly_revenue_goal` audit trail / ChangeLog? | **NOT logged. Goal is host-mutable, no audit trail in MVP.** Defer ChangeLog to V2 if host pilots request "history of goal changes". | KISS. Goal is aspirational target; if host changes goal mid-month it's their concern. Audit log adds ChangeLog table + writes on every update — disproportionate effort for low-value feature. | Phase 01 migration 0015 adds `monthly_revenue_goal: float? nullable` to `host_profiles`. Phase 05 UI = simple text input. NO trigger, NO audit. |
| **Q6** | Multiple revenue sources per booking (split 50/50)? | **NO. 1 source_id per row. Document as known limitation.** | Edge case used by <5% host (per market research). Implementation cost = N:M pivot table + UI complexity (split percentage entry) — not worth it for MVP. Workaround: host creates 2 invoices manually if needed. | Phase 01 — `source_id: int? nullable FK` on `reservations` AND `contracts`. NO pivot table. Phase 08 source CRUD UI single-select. Phase 09 TT200 reports treat each row as single-source. |

---

## Impact on Phase 01 Plan

These decisions modify `phase-01-db-migration-schema.md` as follows:

- **Revision 0011** — `revenue_sources` table: `host_id FK CASCADE` (per Q4 keep cascade pattern consistent)
- **Revision 0012** — `source_id` FK on `reservations` + `contracts` nullable, no pivot table (per Q6)
- **Revision 0013** — Data migration maps STRING enum → FK; no admin filter to preserve (per Q1)
- **Revision 0014** — `commission_rate` (Reservation only) + `commission_amount` (Reservation + Invoice, denormalized snapshot per Q2)
- **Revision 0015** — `host_profiles.monthly_revenue_goal: float? nullable` no ChangeLog (per Q5)
- **Revision 0016** — `source_id` NOT NULL after data backfill verified
- **Revision 0017** — drop old `Reservation.source` String column → **DEFERRED 1 sprint** (per Q1 grep finding: no hidden filter, so safe to drop sooner — but keep dual-write window as belt-and-suspenders)

## Impact on Phase 02 Plan

Service layer formulas locked:

```
gross_revenue   = SUM(invoice.total_amount) — refunds NOT subtracted here
refund_total    = SUM(credit_note.amount WHERE credit_note.issued_date IN period)
commission_total= SUM(invoice.commission_amount) — locked, NOT reversed by refund (Q3)
tax_total       = SUM(invoice.tax_amount IF any)
net_revenue     = gross_revenue − refund_total − tax_total   # NO commission subtraction
adr             = SUM(reservation.total_amount) / SUM(reservation.nights)  # gross-side
```

## Impact on Phase 09 (Excel TT200)

- Commission appears in TK 511 (revenue gross) AND TK 642 (operating expense paid to platform) — accountant convention
- CreditNote refund appears in TK 521 (revenue deduction) — does NOT touch commission line

---

## Sign-off
- Tech Lead Claude — resolved 2026-06-28
- All 6 questions answered with binding decisions
- Phase 01/02/09 plans require minor updates per "Impact" sections above (to be applied in Phase 01 implementation kickoff)

**Gate condition #6: ✅ CLEARED**
