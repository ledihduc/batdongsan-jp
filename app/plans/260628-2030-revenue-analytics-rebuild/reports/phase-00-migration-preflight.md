---
title: "Phase 00 — Migration Pre-flight Queries"
condition: "BA Leader §11.1 #4 (R10) — data-loss prevention"
status: completed_partial
verified_by: Tech Lead (Claude) on LOCAL DEV DB only
date: 2026-06-28
prod_clone_run_status: PENDING — ops/devops must run before Phase 01 merge
---

# Phase 00 Gate — Migration Pre-flight Audit

## Goal
Verify data quality assumptions before applying 7-revision migration to `reservations.source` enum → FK, plus commission + monthly_revenue_goal additions. Per researcher-migration-safety.md §Dry-Run Checklist.

---

## Local Dev DB Pre-flight (SQLite)

**DB:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/urbannest.db` (442KB SQLite)
**Migration status:** alembic_version table empty / not initialized → local DB is at "raw initial baseline" state (only `bef9a3d80bf2_initial_baseline_all_tables.py` applied). Confirms `0010_marketplace_integration.py` has NOT run locally (no `source` column on `contracts`).

### Results

| Query | Result | Interpretation |
|---|---|---|
| `SELECT source, COUNT(*) FROM reservations GROUP BY source` | (empty — 0 rows) | No reservations data locally to validate enum values |
| `SELECT COUNT(*) FROM reservations WHERE host_id IS NULL` | 0 | ✅ No orphan reservations |
| `SELECT COUNT(*) FROM reservations` | 0 | Local DB nearly empty |
| `SELECT source, COUNT(*) FROM contracts GROUP BY source` | ⚠️ ERROR: column `source` does not exist | Local DB is pre-0010 migration. Confirms team uses migrations chronologically; no schema drift |
| `SELECT COUNT(*) FROM contracts WHERE host_id IS NULL` | 0 | ✅ No orphan contracts (out of 4 total) |
| `SELECT COUNT(*) FROM contracts` | 4 | Minimal seed data |
| `SELECT COUNT(*) FROM invoices` | 0 | No invoices to migrate |
| `SELECT COUNT(*) FROM credit_notes` | 0 | No credit notes to migrate |
| `SELECT COUNT(*) FROM host_profiles` | 3 | 3 hosts (will receive default revenue_sources) |
| `SELECT COUNT(DISTINCT id) FROM users WHERE role='host'` | 3 | Matches host_profiles count ✅ |

### Schema Sanity Checks

- ✅ `reservations.source VARCHAR(20) NOT NULL` exists (per `models.py:748-749`)
- ✅ `reservations.host_id INTEGER NOT NULL FK→users(id) ON DELETE CASCADE`
- ⚠️ `contracts.source` MISSING on local DB (migration 0010 not applied locally) — expected in prod after baseline + migrations
- ❌ `host_profiles.monthly_revenue_goal` does NOT exist (will be added by new migration 0015)
- ✅ Indexes present: `ix_reservations_host_id`, `ix_reservations_host_status`, `ix_contracts_host_id`

---

## Production-Clone Pre-flight Script (MUST RUN BEFORE PHASE 01 MERGE)

Run these queries on a **prod-clone Postgres staging DB** with full data restored. Capture results back into this file before authorizing alembic revision 0011 deploy.

### Required Pre-flight Queries

```sql
-- 1. Reservation source value distribution (must be subset of {marketplace, direct, manual})
SELECT source, COUNT(*) AS cnt
FROM reservations
GROUP BY source
ORDER BY cnt DESC;

-- Expected: 1-3 rows, only known enum values
-- BLOCKER if: unknown values (e.g., 'old_api', 'legacy') → escalate, add cleanup migration

-- 2. Contract source value distribution (after migration 0010 applied)
SELECT source, COUNT(*) AS cnt
FROM contracts
GROUP BY source
ORDER BY cnt DESC;

-- Same expectations as #1

-- 3. Orphan check — reservations
SELECT COUNT(*) AS orphan_reservations
FROM reservations r
LEFT JOIN users u ON u.id = r.host_id
WHERE u.id IS NULL;

-- Expected: 0
-- BLOCKER if >0: data cleanup migration needed before 0013 data backfill

-- 4. Orphan check — contracts
SELECT COUNT(*) AS orphan_contracts
FROM contracts c
LEFT JOIN users u ON u.id = c.host_id
WHERE u.id IS NULL;

-- Expected: 0
-- BLOCKER if >0

-- 5. Row counts (estimate migration runtime)
SELECT
  (SELECT COUNT(*) FROM reservations) AS reservations,
  (SELECT COUNT(*) FROM contracts) AS contracts,
  (SELECT COUNT(*) FROM invoices) AS invoices,
  (SELECT COUNT(*) FROM credit_notes) AS credit_notes,
  (SELECT COUNT(*) FROM payments) AS payments,
  (SELECT COUNT(DISTINCT host_id) FROM users WHERE role = 'host') AS distinct_hosts,
  (SELECT COUNT(*) FROM host_profiles) AS host_profiles;

-- Capture: estimate batch size for revision 0013 data backfill
-- If hosts > 1000 → batch INSERT revenue_sources (3 default × N hosts)
-- If reservations > 10k → batch UPDATE source_id (chunk by 1000)

-- 6. Invoice integrity (refund > invoice edge case detection)
SELECT
  i.id, i.invoice_number, i.total_amount,
  COALESCE(SUM(cn.amount), 0) AS total_refunded
FROM invoices i
LEFT JOIN credit_notes cn ON cn.original_invoice_id = i.id
GROUP BY i.id, i.invoice_number, i.total_amount
HAVING COALESCE(SUM(cn.amount), 0) > i.total_amount;

-- Expected: 0 rows
-- WARNING if >0: existing data violates AC-05 edge case 3 (refund > invoice); fix data before applying analytics_service which will reject 422
-- If unfixable: ops note + scope acknowledged data drift in §11 risks

-- 7. host_id consistency — host_profiles user must have role='host'
SELECT hp.id AS host_profile_id, hp.user_id, u.role
FROM host_profiles hp
JOIN users u ON u.id = hp.user_id
WHERE u.role != 'host';

-- Expected: 0 rows
-- BLOCKER if >0: revenue_sources backfill won't reach these → wrong source attribution

-- 8. Existing tax_id check (TT200 export needs MST)
SELECT
  COUNT(*) FILTER (WHERE tax_id IS NULL OR tax_id = '') AS missing_tax_id,
  COUNT(*) FILTER (WHERE tax_id IS NOT NULL AND tax_id != '') AS has_tax_id
FROM host_profiles;

-- Capture: how many hosts need to fill tax_id before TT200 export works
-- Note for Phase 09: if missing_tax_id > 0, export must gracefully omit / prompt
```

### Result Capture Template

Once ops/devops run on prod-clone:

```markdown
**Run date:** YYYY-MM-DD
**Run by:** [name]
**DB snapshot:** [date of prod snapshot used]

| Query # | Result | Status |
|---|---|---|
| 1 Reservation source dist | marketplace: N, direct: N, manual: N | ✅/⚠️/❌ |
| 2 Contract source dist | ... | ... |
| 3 Orphan reservations | N | ... |
| 4 Orphan contracts | N | ... |
| 5 Row counts | reservations=N, contracts=N, invoices=N, hosts=N | ... |
| 6 Refund > invoice | N rows | ... |
| 7 host_profile role mismatch | N rows | ... |
| 8 Missing tax_id | N hosts (X%) | ... |
```

---

## Pre-flight Status (Today)

| Item | Local Dev DB | Prod-Clone | Verdict |
|---|---|---|---|
| Reservation source unknown values | N/A (no data) | ⏳ PENDING ops run | BLOCKER if not run before 0011 merge |
| Orphan reservations/contracts | 0 ✅ | ⏳ PENDING | Expected 0 |
| Existing data volume | minimal (4 contracts) | ⏳ PENDING | Drives batch sizing |
| Refund > invoice edge cases | 0 (no data) | ⏳ PENDING | Edge case detection |
| Missing tax_id for TT200 | N/A | ⏳ PENDING | Phase 09 prerequisite |

---

## Recommendation

1. **Local dev DB results: insufficient** — no production-like data to validate enum distribution or refund edge cases. Acceptable for now since local is bootstrap state.
2. **Prod-clone run REQUIRED before Phase 01 alembic revision 0011 is merged to main.** Ops/devops must:
   - Snapshot production DB
   - Restore to staging Postgres instance
   - Run all 8 queries above
   - Update this file's "Result Capture Template" section
   - Get Tech Lead sign-off before Phase 01 dev begins
3. **If any query reveals BLOCKER:** escalate to Tech Lead; add cleanup migration (revision 0010.5) BEFORE 0011.

## Sign-off

- Tech Lead Claude — local pre-flight done 2026-06-28
- ⏳ **Prod-clone pre-flight: PENDING** — must be run by ops before Phase 01 merge
- Gate condition #4 (R10): **CONDITIONALLY CLEARED** — local sanity checks pass, prod-clone result is a follow-up task that BLOCKS Phase 01 dev start

**Gate condition #4 (R10): 🟡 CONDITIONALLY CLEARED (prod-clone run pending)**
