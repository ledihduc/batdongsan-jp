---
title: "Phase 01 — DB Migration + Schema — Completion Report"
status: completed
date: 2026-06-28
implemented_by: fullstack-developer (Claude)
verified_by: Tech Lead (Claude)
blocks_unblocked: [phase-02-backend-analytics-service]
---

# Phase 01 Completion Report

## Status: ✅ DONE

All 6 alembic revisions applied cleanly on local SQLite. Migration tests 11/11 pass. Models updated. Existing test suite still green (3 pre-existing planning test failures unrelated).

---

## Delta from Spec

| Spec said | Actual | Reason |
|---|---|---|
| Revisions 0011-0016 | **0012-0017** | Existing `0011_reservation_exclude_constraint` (Phase 01h Postgres concurrency hardening) — re-numbered chain |
| Revision 0015 = monthly_revenue_goal | Revision 0016 = monthly_revenue_goal | Same content, shifted +1 |
| Revision 0016 = source_id NOT NULL | Revision 0017 = source_id NOT NULL | Same content, shifted +1 |
| `sa.func.now()` in seed INSERT | `datetime.utcnow()` Python-side bind param | SQLAlchemy doesn't support `func.now()` as Python value param |
| ALTER COLUMN SET NOT NULL (Postgres) | `op.batch_alter_table(...)` (SQLite-compat) | SQLite limited ALTER; batch mode handles both dialects |

---

## Files Changed

### Modified
- `ancu365-backend/app/models.py` — added `RevenueSource` ORM class, `relationship` import, `source_id`/`commission_rate`/`commission_amount` columns on Reservation+Contract+Invoice, `monthly_revenue_goal` on HostProfile

### Created (alembic)
- `alembic/versions/0012_create_revenue_sources.py` (91 lines)
- `alembic/versions/0013_add_source_id_fk_nullable.py` (121 lines, SQLite batch_alter_table)
- `alembic/versions/0014_data_migration_source_string_to_fk.py` (111 lines, verify-raise pattern)
- `alembic/versions/0015_add_commission_columns.py` (70 lines)
- `alembic/versions/0016_add_monthly_revenue_goal.py` (38 lines)
- `alembic/versions/0017_source_id_not_null.py` (76 lines, batch_alter_table for SQLite)

### Created (tests)
- `tests/migrations/__init__.py`
- `tests/migrations/conftest.py` (263 lines)
- `tests/migrations/test_revision_0012_seed.py` (3 tests)
- `tests/migrations/test_revision_0014_backfill.py` (4 tests incl. unknown-source raise)
- `tests/migrations/test_revision_0017_not_null.py` (2 tests)
- `tests/migrations/test_full_chain.py` (2 tests sequential upgrade)

---

## Verification

### alembic current
```
0017_source_id_not_null (head)
```

### Migration test suite
```
11/11 passed in 0.39s
```

### Existing test suite
- 29 passed
- 18 skipped (Postgres-only smoke tests requiring `SMOKE_DATABASE_URL`)
- 0 new failures (3 pre-existing planning test failures: bbox geometry edge cases — unrelated to this phase)

### Post-flight queries (local SQLite)
| Query | Result | Status |
|---|---|---|
| `SELECT COUNT(*) FROM revenue_sources` | 3 | ✅ (3 per host × 1 host w/ contracts) |
| `SELECT name FROM revenue_sources` | Trực tiếp / Marketplace nội bộ / Khác | ✅ all 3 defaults |
| `SELECT COUNT(*) FROM reservations WHERE source_id IS NULL` | 0 | ✅ |
| `SELECT COUNT(*) FROM contracts WHERE source_id IS NULL` | 0 | ✅ |
| Contract source mapping | 4 × `manual`→`Khác` | ✅ CASE backfill correct |
| commission_rate/amount type | Float, NULL default | ✅ backward-compat |
| monthly_revenue_goal type | Float, NULL default | ✅ Option A |

---

## Acceptance Criteria Met

- **AC-07 (revenue_sources CRUD foundation):** table + UNIQUE(host_id, name) + soft-delete `is_archived` column ✅
- **AC-18 (goal storage Option A):** `HostProfile.monthly_revenue_goal` nullable ✅
- **AC-04 (gross/net split DB foundation):** commission_rate + commission_amount on Reservation + Invoice ✅
- **R10 (data-loss mitigation):** verify-raise pattern in revision 0014 ✅; dual-write window preserved (old `source` String column intact) ✅

---

## Outstanding for Phase 02

1. Service layer must dual-write both `source` (string) AND `source_id` (FK) for backward compat per Q1 resolution.
2. Pydantic schemas not bumped in this phase (kept stable per spec); Phase 02-03 will add `source_id` to response models as optional.
3. Phase 09's `tt200_exports` audit table NOT created in this phase (per spec) — will be added in revision 0018 alongside Phase 09 work.

## External Action Still Pending (R10 sign-off)

⚠️ **Ops/DevOps must run prod-clone pre-flight SQL** (`reports/phase-00-migration-preflight.md` §Required Pre-flight Queries) BEFORE merging revisions 0012-0017 to main. Local SQLite has minimal data (0 reservations, 4 contracts) — cannot validate distribution of `source` enum values on production scale.

---

## Sign-off

- Implementation by `fullstack-developer` agent (~3-4h work)
- Tech Lead verified: alembic upgrade head clean ✅, migration tests 11/11 ✅, post-flight queries clean ✅, contract source mapping correct ✅
- Phase 02 (Backend `analytics_service.py` rebuild) **UNBLOCKED** on local dev side
- Phase 02 merge to main still BLOCKED until prod-clone pre-flight by ops
