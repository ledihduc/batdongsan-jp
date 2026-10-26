---
title: "Phase 01 — DB Migration + Schema"
status: pending
priority: P0
estimated_effort: 3-4d
blocked_by: [phase-00]
owner: TBD
---

## Context Links
- BA: `phase-00-ba-requirements.md` §6.1, §6.2 (Option A), AC-07 (revenue_sources), AC-18 (goal), R10 (data-loss)
- Researcher: `research/researcher-migration-safety.md` (full 7-revision plan)

## Overview
- Priority: P0 — foundation for backend rebuild
- Status: pending
- Brief: Land alembic revisions 0011-0016: `revenue_sources` table + seed 3 default per host, `source_id` FK on reservations+contracts (nullable→backfill→NOT NULL), `commission_rate/amount` on reservations+invoices, `monthly_revenue_goal` on host_profiles. Keep old `Reservation.source` String column for 1 sprint (drop = revision 0017 deferred to Phase 3.5 follow-up).

## Key Insights (from research)
- 15 backend consumers + Flutter model assume `source` is String (`researcher-migration-safety.md` §Backend Consumers). Dual-write window mandatory.
- Pre-flight on prod-clone (Phase 00 output) must confirm only 3 enum values present.
- Data migration revision 0013 uses transaction-safe UPDATE with verify-or-raise pattern.

## Requirements
### Functional
- 6 alembic revisions (0011-0016) applied successfully on staging then production.
- Backfill 3 default revenue_sources per host w/ Vietnamese names + color hex (per AC-07).
- Backward-compat: existing `Reservation.source` String column remains; service layer dual-writes both `source` and `source_id` in Phase 02-03 (out of this phase scope).
- `monthly_revenue_goal` nullable on `host_profiles` (Option A).
- Commission columns nullable, default NULL → legacy data treated as net=gross (AC-04 backward-compat per BA §6.1).

### Non-functional
- Zero downtime (nullable FK + dual-column window).
- Each revision rollback-safe.
- Production migration runtime <5 min for 100k rows.

## Architecture / Design
- Per `researcher-migration-safety.md` §Proposed Migration Plan.
- 6 sequential alembic revisions (drop-old = revision 0017 NOT in this phase, Phase 3.5 follow-up).
- Revision 0013 (data migration) wrapped in transaction; raise RuntimeError if any source_id NULL after backfill.
- Revision 0016 (NOT NULL) pre-checks for null source_id before altering column.

### Key decisions
- Keep `source` String column = dual-write window (1 sprint).
- `revenue_sources.id` auto-increment (no UUID — simpler indexing).
- `ondelete=SET NULL` on source FK (deleting a source doesn't cascade-delete reservations).
- `ondelete=CASCADE` on `revenue_sources.host_id` → users.id (host deletion cleans up sources; matches existing host_profiles cascade).
- Color stored as `VARCHAR(7)` hex w/ default `#666666`.
- `UNIQUE(host_id, name)` constraint; archive uses `is_archived` flag (per AC-07: name can be reused after archive — clarify with partial unique index `WHERE is_archived=FALSE`).

## Files
### Modify
- `ancu365-backend/app/models.py` — add SQLAlchemy mappings: `RevenueSource` model; add `source_id`, `commission_rate`, `commission_amount` columns on `Reservation` + `Contract` + `Invoice`; add `monthly_revenue_goal` on `HostProfile`.
- `ancu365-backend/app/schemas/reservation.py` — bump response schema to optionally serialize `source_id` (keep `source` String for backward compat).

### Create
- `ancu365-backend/alembic/versions/0011_create_revenue_sources.py` — create table + seed 3 defaults per host
- `ancu365-backend/alembic/versions/0012_add_source_id_fk_nullable.py` — add nullable FK on reservations + contracts
- `ancu365-backend/alembic/versions/0013_data_migration_source_string_to_fk.py` — backfill source_id via UPDATE...CASE
- `ancu365-backend/alembic/versions/0014_add_commission_columns.py` — commission_rate + commission_amount on reservations + invoices
- `ancu365-backend/alembic/versions/0015_add_monthly_revenue_goal.py` — host_profiles.monthly_revenue_goal
- `ancu365-backend/alembic/versions/0016_source_id_not_null.py` — enforce NOT NULL on reservations.source_id + contracts.source_id

### Delete
- none (revision 0017 drop-old-column is Phase 3.5 follow-up — separate PR)

## Implementation Steps
1. Refresh model file w/ new columns + new `RevenueSource` ORM class; add relationships (`Reservation.revenue_source`, `RevenueSource.reservations`).
2. Write revision 0011 per `researcher-migration-safety.md` §0011 example; include seed INSERT in `upgrade()`.
3. Write revision 0012 — nullable FK; both reservations + contracts.
4. Write revision 0013 — UPDATE...CASE backfill + post-verify raise RuntimeError if NULL count > 0.
5. Write revision 0014 — commission columns nullable.
6. Write revision 0015 — monthly_revenue_goal.
7. Write revision 0016 — NOT NULL alter w/ pre-check.
8. Run `alembic upgrade head` locally; assert post-flight queries from researcher §Post-flight match.
9. Dry-run on prod-clone (Phase 00 #3 output should already verify pre-flight clean); record runtime + row counts.
10. Update `app/seed.py` if seed reservations need source_id mapping (avoid breaking seed reset).

## Todo List
- [ ] models.py updated w/ RevenueSource + new columns
- [ ] Revision 0011 written + seed verified (3 sources per host)
- [ ] Revision 0012 written + nullable FK applied
- [ ] Revision 0013 written + verify-raise pattern tested
- [ ] Revision 0014 written
- [ ] Revision 0015 written
- [ ] Revision 0016 written + NOT NULL enforced
- [ ] `alembic upgrade head` clean on local
- [ ] Dry-run on prod-clone documented (runtime + row counts)
- [ ] Seed file compatible (no break on `pytest`)

## Test Strategy
### Unit
- `tests/migrations/test_revision_0011.py` — assert seed creates 3 sources per host w/ correct Vietnamese names + color.
- `tests/migrations/test_revision_0013_backfill.py` — fixture w/ 3 reservations (1 per enum value); assert all source_id populated correctly; assert RuntimeError raised on unknown enum.
- `tests/migrations/test_revision_0016_not_null.py` — assert raises if any source_id NULL before alter.

### Integration
- `tests/migrations/test_full_chain.py` — apply 0011→0016 sequentially, assert post-flight queries from researcher §Post-flight verification.

### E2E
- N/A (covered by Phase 02-03 endpoint tests).

## Success Criteria
- All 6 revisions apply + rollback cleanly on test DB.
- Post-flight: zero NULL source_id on reservations + contracts; revenue_sources.host_id index present; commission columns NULL by default.
- Prod-clone dry-run <5 min for ≥100k rows.
- Seed reset still passes existing test suite.

## Risk Assessment
- **R10 — data loss on enum→FK** → mitigated by pre-flight (Phase 00) + revision 0013 verify-raise + nullable window + dual-column dual-write.
- **Schema break in Pydantic schemas** → mitigated by keeping `source` String column (dual-write); Pydantic response schema unchanged in this phase.
- **Production runtime exceeds window** → mitigated by index pre-creation + small batch test; fallback = run in maintenance window.

## Security Considerations
- `revenue_sources.host_id` enforces ownership via FK (AC-16).
- No PII in this phase.
- Migration runs as DB owner; no exposure to user input.

## Acceptance Criteria Coverage
- AC-07 (revenue_sources CRUD foundation) ✓
- AC-18 (goal storage Option A) ✓
- AC-04 (gross/net split DB foundation) ✓
- R10 mitigation ✓

## Definition of Done
- Revisions 0011-0016 merged.
- Migration applied on staging successfully.
- All migration tests pass.
- Existing test suite green.
- Note in `plan.md` updating Phase 01 status=completed + link to deploy log.
