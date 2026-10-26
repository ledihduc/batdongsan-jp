# Phase-04 — Schema Migration Sweep — Execution Report

**Branch:** `jp-version` · **Baseline tag:** `pre-jp-fork-baseline-20261019`
**Report started:** 2026-10-20 · **Session count:** 1

---

## Session 1 — Migration 0160 `jp_addresses_v2` + alembic env fix

**Date:** 2026-10-20 · **Commit:** (see below) · **LOC added:** +148 migration · env.py +5/−4

### Scope decision
Mission brief offered two independent candidates: (a) `jp_addresses_v2` canonical table, (b) `Numeric(15,0)` JPY columns on `rentals`/`payments`. Chose **(a) `jp_addresses_v2`** — standalone new table, zero coupling to existing rows, lowest regression blast radius. Numeric JPY touches live tables + requires per-row type semantics review → defer to Session 2+.

### Pre-existing drift discovered (Phase-03 handoff)
Running `alembic upgrade head` on any DB failed instantly:
```
ImportError: cannot import name 'planning_models' from 'app'
```
Root cause: Phase-03 Session 20/21 stripped `app/planning_models.py` as an orphan (0 external importers in app code) but did NOT update `alembic/env.py` which still had an unconditional `from app import planning_models`. The usage of that module was gated behind `_INCLUDE_PLANNING` env flag — so the fix is to also gate the IMPORT behind the same flag. This is a 5-line surgical fix, not scope creep (alembic was 100% unrunnable without it; no further work possible).

Fix (alembic/env.py):
```python
_INCLUDE_PLANNING = os.getenv("ALEMBIC_INCLUDE_PLANNING") == "1"
if _INCLUDE_PLANNING:
    from app import planning_models  # noqa
    from app.planning_models import PlanningBase  # noqa
    target_metadata = [Base.metadata, PlanningBase.metadata]
else:
    target_metadata = [Base.metadata]
```
Default path (planning disabled, matches prod) now works. If planning is ever re-enabled, user gets the ModuleNotFound at bootstrap of ALEMBIC_INCLUDE_PLANNING=1 — which is correct and loud.

### Migration 0160 design (`alembic/versions/0160_jp_addresses_v2.py`)
New standalone table — JIS-coded canonical JP address store. Rationale: v1 `jp_addresses` (migration 0142) is a zipcloud API cache (postal→display name). v2 is the canonical reference layer sourced from MLIT 位置参照情報 + JP Post, with authoritative codes:

| Column | Type | Why |
|---|---|---|
| `postal_code` | VARCHAR(7) NOT NULL | 7-digit, no hyphen. Primary lookup. Only NOT NULL field. |
| `prefecture_jis` | VARCHAR(2) nullable | JIS X 0401 (e.g. '13' = 東京都) — stable code vs. kanji drift |
| `city_code` | VARCHAR(5) nullable | JIS X 0402 (e.g. '13113' = 渋谷区) — municipal reorg stable key |
| `machi_aza` | VARCHAR(200) nullable | 町字 — JP Post address3 granularity |
| `chome / banchi / go` | VARCHAR(20) nullable | 丁目/番地/号 numeric parts |
| `prefecture / city / town` | kanji display mirrors (nullable) | avoid code→name join at read time |
| `*_kana` | フリガナ phonetic mirrors (nullable) | name-sort + autocomplete |
| `source / source_version` | VARCHAR(32) nullable | provenance (`mlit_isj` / `20250401`) |
| `created_at / updated_at` | TIMESTAMP NOT NULL | `CURRENT_TIMESTAMP` server_default (SQLite+PG portable) |

**Indexes (2):**
- `ix_jp_addresses_v2_postal_code` — primary read pattern
- `ix_jp_addresses_v2_pref_city` — composite (prefecture_jis, city_code) — admin-level drill

**Discipline checklist:**
- [x] Additive — no existing table touched
- [x] Nullable — only `postal_code` + timestamps NOT NULL
- [x] Idempotent — `insp.has_table()` before create; per-index `existing_ix` check
- [x] Full `downgrade()` — drops both indexes + table, inspected guards
- [x] `server_default=sa.text("CURRENT_TIMESTAMP")` — portable (initially used `sa.func.now()` → SQLite rejected it → fixed before any commit)
- [x] Numbering `0160_jp_addresses_v2` extending from `0159_consent_pii_encrypted` (previous head)

### Verification matrix (fresh Postgres DB stamped at 0159)

| Step | Expected | Actual |
|---|---|---|
| `alembic current` | `0159_consent_pii_encrypted` | ✅ matches |
| `alembic upgrade head` | 0159 → 0160 | ✅ `Running upgrade 0159 -> 0160` |
| `\d jp_addresses_v2` | 18 cols, 2 indexes | ✅ confirmed (see table dump below) |
| `alembic current` | `0160_jp_addresses_v2 (head)` | ✅ |
| `alembic downgrade -1` | 0160 → 0159 | ✅ table + indexes dropped |
| `alembic current` | `0159_consent_pii_encrypted` | ✅ |
| `alembic upgrade head` (re-apply) | 0159 → 0160 | ✅ |
| **Idempotency**: `stamp 0159` then `upgrade head` with table present | upgrade skips create, re-adds indexes if missing | ✅ no error, head reached |
| `JWT_SECRET=test DATABASE_URL=sqlite:///:memory: python -c "import main"` | exit 0 | ✅ `OK` |
| `alembic heads` | single head | ✅ `0160_jp_addresses_v2 (head)` — chain remains LINEAR |

Table shape (production psql `\d`):
```
                                    Table "public.jp_addresses_v2"
     Column      |            Type             | Nullable |                   Default
 id              | integer                     | not null | nextval('jp_addresses_v2_id_seq'::regclass)
 postal_code     | varchar(7)                  | not null |
 prefecture_jis  | varchar(2)                  |          |
 city_code       | varchar(5)                  |          |
 machi_aza       | varchar(200)                |          |
 chome/banchi/go | varchar(20)                 |          |
 prefecture/city/town                                     | kanji mirrors
 *_kana                                                    | phonetic mirrors
 source/source_version                                     | provenance
 created_at / updated_at | timestamp         | not null | CURRENT_TIMESTAMP
Indexes:
    "jp_addresses_v2_pkey"           PRIMARY KEY, btree (id)
    "ix_jp_addresses_v2_postal_code" btree (postal_code)
    "ix_jp_addresses_v2_pref_city"   btree (prefecture_jis, city_code)
```

### Alembic chain state (post-Session-1)
```
... → 0158_users_deletion_scheduled → 0159_consent_pii_encrypted → 0160_jp_addresses_v2 (head)
```
Single linear head. No branches. No merge-rev needed.

### Pre-existing issues NOT fixed (observed, out of scope)
1. **Baseline bootstrap on fresh prod-shape Postgres is broken.** `alembic_version` column defaults to VARCHAR(32) which truncates `0021_create_delegations_and_invitations` (41 chars). Need `ALTER TABLE alembic_version ALTER COLUMN version_num TYPE VARCHAR(80)` at bootstrap, OR a dedicated 0000 pre-migration. Not Session 1 scope.
2. **0143 `jp_rental_terms` indexes not idempotent.** Full fresh-DB upgrade hits `DuplicateTable: ix_jp_rental_terms_org_id already exists` on 0143. Not my migration; not blocking Session 1 (test used stamp-at-0159 strategy to validate 0160 in isolation).
3. **DB in local docker is at `0005_nha_tro_core`** — ancient. Not touched. Any contributor running `alembic upgrade head` against this would wipe or diverge. Document this in dev-setup when Phase-04 catches up.

### Files changed
- `alembic/env.py` — gate `planning_models` import behind `_INCLUDE_PLANNING` flag (+5/−4)
- `alembic/versions/0160_jp_addresses_v2.py` — NEW migration (+148)

Total: +153/−4 LOC, 2 files.

---

## Session 2 recommendation

**Primary — `jp_rentals_pricing_jpy_cols` (Numeric(15,0) + currency on rental agreements).**
- Target: add nullable `rent_jpy NUMERIC(15,0)`, `deposit_jpy NUMERIC(15,0)`, `key_money_jpy NUMERIC(15,0)`, `agency_fee_jpy NUMERIC(15,0)`, `currency VARCHAR(3) DEFAULT 'JPY'` to the live rentals/rental_contracts table. Precision 15,0 handles JPY up to ¥999 兆 (practical ∞); JPY has no fractional unit so scale=0.
- Why Session 2 (not Session 1): touches a live table shared with VN code paths still at Phase-03 ceiling. Needs model-layer coord — but migration itself remains ADDITIVE + NULLABLE so writes to old columns keep working while the JP code gradually dual-writes.
- Khuyến nghị: Session 2 should land migration 0161 for rentals (one table at a time); Session 3 handles payments/invoices (migration 0162).
- Hệ quả nếu chọn sai: Doing rentals + payments in one migration = larger blast radius if rollback needed. Split preferred.
- Độ tin cậy: HIGH.

**Alternative — `jp_addresses_v2` FK linkage from `houses.jp_address_v2_id`.**
- Add nullable FK `houses.jp_address_v2_id → jp_addresses_v2.id`. Enables JP houses to reference canonical codes without renaming existing `address` fields. Fully additive, zero regression.
- Hệ quả nếu chọn sai: FK adds ~1 index + nullable column; harmless even if JP ingest service isn't ready.
- Độ tin cậy: HIGH as warm-up before touching rentals.

**Also consider — autogenerate smoke test gate.**
- Session 2 should early-exit by running `alembic check` against a stamped-at-head DB — any drift (model drift after Phase-03 strips) would surface as a diff. Current state unknown; worth measuring once.
- Hệ quả nếu chọn sai: Autogenerate drift piles up silently; a future `alembic revision --autogenerate` catches dozens of noise diffs mixed with real changes.
- Độ tin cậy: MEDIUM.

---

## Unresolved questions (Session 1)

1. **Should `jp_addresses` v1 (migration 0142) be deprecated once v2 is live?** v1 is zipcloud API cache; v2 is canonical. Dual-write for a release then drop v1?
   - Khuyến nghị: Keep v1 for 2 releases as the live postal-lookup cache (zipcloud ingest is a running service). Build v2 ingest pipeline separately, swap readers once v2 populated, then migrate 0170+ drops v1.
   - Hệ quả nếu chọn sai: Premature drop breaks postal-lookup endpoint; late drop = ~10 col * N rows of stale cache. Low cost either way.
   - Độ tin cậy: HIGH.

2. **Should the pre-existing alembic chain fragility (items 1-3 in "Pre-existing issues NOT fixed") become Phase-04 Session 2 scope or a dedicated hotfix session?**
   - Khuyến nghị: Dedicated "Phase-04 Session 2a: alembic chain repair" as a 30-min hotfix session BEFORE adding more migrations. Each new migration otherwise accumulates on top of a broken-fresh-bootstrap chain. Fix means: (a) stamp alembic_version with 80-char column, (b) make 0143+ index creates idempotent, (c) document that `alembic upgrade head` from empty needs the alembic_version pre-create step OR add a 0000a bootstrap migration.
   - Hệ quả nếu chọn sai: Future contributor onboarding broken; CI's "clean DB → migrate → test" lane impossible.
   - Độ tin cậy: HIGH.

3. **Server_default `CURRENT_TIMESTAMP` was chosen for portability (SQLite + Postgres). Prior migrations used `sa.func.now()` which breaks SQLite. Should Phase-04 enforce portable defaults across the board, or accept that CI tests Postgres-only?**
   - Khuyến nghị: Portable — SQLite path is live for `import main` smoke tests + pytest in-memory DB (used by Phase-03 1586p floor). Enforcing `CURRENT_TIMESTAMP` is one line per new migration, zero semantic loss.
   - Hệ quả nếu chọn sai: Smoke tests + any SQLite-touching path break on `NOW()` — exactly what Session 1 hit on first draft.
   - Độ tin cậy: HIGH.

---

## Status: DONE
**Summary:** Session 1 landed migration `0160_jp_addresses_v2` (canonical JIS-coded JP address table, 18 cols + 2 indexes, additive/nullable/idempotent/downgradeable). Verified via fresh-Postgres upgrade→downgrade→upgrade cycle + idempotency replay. Also fixed Phase-03 drift in `alembic/env.py` (gated `planning_models` import) that had rendered alembic 100% unrunnable. Alembic chain remains linear single-head at 0160. Zero regression to `import main`.

---

## Session 2a — Alembic chain fresh-bootstrap repair

**Status:** DONE

### Scope
Hotfix session before stacking more migrations. Mission named 2 blockers (0021 width, 0143 idempotency). Verification revealed 6 more migrations with the same duplicate-index-name bug class; fixed in-scope under the "end-to-end fresh-bootstrap to head=0160" requirement.

### Issues fixed

**(1) 0021 — alembic_version.version_num VARCHAR(32) too narrow (fix: widen to VARCHAR(64))**
- Postgres `alembic upgrade head` on empty DB fails with `StringDataRightTruncation` when alembic UPDATEs `version_num='0021_create_delegations_and_invitations'` (39 chars) into column auto-created as VARCHAR(32).
- Fix: top of `0021.upgrade()` runs `_widen_alembic_version_column(64)` — inspects `information_schema.columns`, ALTERs only if narrower. No-op on SQLite (TEXT storage class ignores declared length). One-way widen (downgrade does not narrow; later revisions may store IDs > 32).
- Longest revision ID currently is 42 chars (`0003_rename_booking_to_viewing_appointment`); 64 covers all current + near-future.
- Commit `f0b3c4d`.

**(2) 0143 — duplicate index name on fresh (fix: drop inline `index=True`, add idempotency guard)**
- Fresh bootstrap fails with `DuplicateTable: ix_jp_rental_terms_org_id already exists`. Root cause: inline `sa.Column("org_id", ..., index=True)` auto-creates `ix_jp_rental_terms_org_id`, then explicit `op.create_index("ix_jp_rental_terms_org_id", ...)` collides.
- Fix: drop inline `index=True` on `org_id` (explicit `op.create_index` is single source of truth — same name/col/semantics → zero logic change). Re-inspect post-create_table and guard each explicit create against `existing_indexes` set so partial reruns are safe.
- Commit `7fa64aa`.

**(3) 0144-0151 — same bug class as 0143 (fix: drop colliding inline `index=True`)**
- Discovered during end-to-end verification. Each file had one or more inline `index=True` whose auto-name `ix_<table>_<col>` collides with an explicit `op.create_index` later in the same `upgrade()`:
  - 0144 jp_property_info: `org_id`
  - 0145 jp_transit_access: `listing_id`, `org_id`
  - 0147 jp_application_reviews: `application_id`
  - 0148 listing_sales_assignments: `org_id`
  - 0150 jp_invoice_lines: `invoice_id`
  - 0151 jp_payment_intents: `provider_intent_id`
- Non-colliding `index=True` cases (inline index + explicit composite with different name, e.g. 0149 `org_id` + `ix_org_provider_configs_org_type`; 0153 `user_id` + `ix_jp_user_consents_user_purpose`; 0157 `contract_id` + `ix_jp_deposit_settlements_contract`) were left untouched.
- Commit `cba8166`.

### Fresh-bootstrap verification (PostgreSQL — production path)
```
docker exec ancu365-postgis psql -U ancu365 -d postgres \
  -c "DROP DATABASE jp_fresh_test; CREATE DATABASE jp_fresh_test;"
docker exec ancu365-postgis psql -U ancu365 -d jp_fresh_test \
  -c "CREATE SCHEMA planning; CREATE EXTENSION IF NOT EXISTS postgis;"
JWT_SECRET=test DATABASE_URL=postgresql://ancu365:...@localhost:5433/jp_fresh_test \
  PYTHONPATH=. .venv-strip/bin/alembic upgrade head
# → head reached: 0160_jp_addresses_v2
# → alembic heads: single head
# → downgrade 0142_jp_address + re-upgrade head: clean, replay-safe
```
- `alembic current` = `0160_jp_addresses_v2 (head)`
- `alembic heads` returns single head
- Downgrade through all fixed migrations (0160 → 0142) succeeds
- Re-upgrade back to head succeeds (idempotency confirmed)
- Smoke `JWT_SECRET=test DATABASE_URL=sqlite:///:memory: python -c "import main"` → green

### Pre-existing SQLite blocker NOT in scope (left as-is)
Mission's SQLite verification command (`DATABASE_URL=sqlite:////tmp/jp_fresh.db alembic upgrade head`) still fails — but at **migration 0001** with `sqlite3.OperationalError: unknown database planning`. Root cause: migration 0001 creates `planning.reports` (schema-qualified) and SQLite does not support named schemas without `ATTACH DATABASE`. This is a THIRD pre-existing blocker, independent of alembic chain integrity, and documented separately in Session 1's "Pre-existing issues NOT fixed" list. Not Session 2a scope. The production path (PostgreSQL) is now fully green from empty DB → head.

### Files changed
- `alembic/versions/0021_create_delegations_and_invitations.py` (+36)
- `alembic/versions/0143_jp_rental_terms.py` (+15 / −3)
- `alembic/versions/0144_jp_property_info.py` (+4 / −1)
- `alembic/versions/0145_jp_transit.py` (+6 / −2)
- `alembic/versions/0147_jp_applications.py` (+3 / −1)
- `alembic/versions/0148_listing_sales_assignments.py` (+3 / −1)
- `alembic/versions/0150_jp_invoice_lines.py` (+3 / −1)
- `alembic/versions/0151_jp_payment_intents.py` (+3 / −1)

Total: +73/−10 LOC, 8 files, 3 commits (`f0b3c4d`, `7fa64aa`, `cba8166`).

### Session 2 — next migration recommendation (unchanged from Session 1)

**Primary — migration 0161 `jp_rentals_pricing_jpy_cols`** (additive nullable JPY columns on rentals/rental_contracts).
- Chain is now stackable: fresh bootstrap confirmed to 0160. New migrations will land on a repaired chain.
- Suggested cols: `rent_jpy NUMERIC(15,0)`, `deposit_jpy NUMERIC(15,0)`, `key_money_jpy NUMERIC(15,0)`, `agency_fee_jpy NUMERIC(15,0)`, `currency VARCHAR(3) DEFAULT 'JPY'`. All nullable → zero regression for VN code paths.
- Khuyến nghị: run `alembic check` against stamped-at-head DB at Session 2 start to measure model-drift noise before autogenerate.
- Hệ quả nếu chọn sai: drift piles up silently.
- Độ tin cậy: HIGH.

**Warm-up alternative — `houses.jp_address_v2_id` nullable FK → `jp_addresses_v2.id`**. Fully additive, zero regression.

### Unresolved questions (Session 2a)

1. **SQLite fresh-bootstrap blocker at 0001 (`planning.reports` schema)** — should Session 2b patch migration 0001 to conditionally skip `schema="planning"` when `bind.dialect.name == "sqlite"`? That would unlock contributor onboarding on SQLite and the `rm -f /tmp/jp_fresh.db` recipe the mission expects.
   - Khuyến nghị: YES, as a dedicated 15-min Session 2b. Pattern: inside 0001.upgrade(), build table kwargs with `schema="planning"` only on Postgres, else no schema (table becomes `main.reports` on SQLite — acceptable for dev-only pytest flows which already stamp-forward or use in-memory DBs).
   - Hệ quả nếu chọn sai: SQLite bootstrap stays broken; devs continue to use stamp-at-head or in-memory with manual seeds.
   - Độ tin cậy: MEDIUM-HIGH (dialect-branched schema is well-trodden pattern but 0001 is foundational — any edit ripples through dev DBs stamped at it).

2. **Should the `_widen_alembic_version_column` helper move to a shared `alembic/_utils.py`** so future migrations whose ID flirts with 64 chars can widen further without touching 0021 again?
   - Khuyến nghị: NOT YET — single caller, YAGNI. Promote only on second use.
   - Hệ quả nếu chọn sai: tiny duplication if widened again; low cost.
   - Độ tin cậy: HIGH.

3. **Should `sa.Column(..., index=True)` be banned in new migrations by convention** (lint rule) given this bug class has now bitten 7 migrations?
   - Khuyến nghị: YES — add to `docs/code-standards.md`: "In alembic migrations, prefer explicit `op.create_index` over inline `index=True` to avoid name-collision bugs on fresh-bootstrap." Grep gate in `check.sh` is low-effort.
   - Hệ quả nếu chọn sai: 8th occurrence likely; each costs a Session 2a-sized hotfix.
   - Độ tin cậy: HIGH.

**Summary:** Alembic chain is now green from empty PostgreSQL to head=`0160_jp_addresses_v2`. Upgrade→downgrade→upgrade cycle verified. Session 2 (migration 0161 JPY cols) can proceed on a clean chain. SQLite bootstrap remains blocked at 0001 by a separate pre-existing schema issue — recommend Session 2b hotfix if contributor-onboarding SQLite path matters.

---

## Session 2 — Migration 0161 `jp_rentals_pricing_jpy_cols` (2026-10-20)

### Scouting outcome
- No `Rental`/`rental_contracts` entity in codebase. `contracts` IS the rental agreement (`app/models/rental.py:332 class Contract` → `__tablename__ = "contracts"`).
- Existing VN pricing on contracts: `monthly_rent` Float, `deposit` Float, `deposit_refund_amount` Float. No `currency`, no `key_money`, no `agency_fee`.
- JP pricing already split into side-cars: `jp_rental_terms` (0143) holds `monthly_rent_jpy`+shikikin/reikin months; `jp_deposit_settlements` (0157) holds `gross_shikikin_jpy`. 0161 adds the **header mirror** so the authoritative amount sits on the contract row that both markets share.

### Design
- Add 5 nullable columns on `contracts`:
  - `rent_jpy NUMERIC(15,0)` — 家賃
  - `deposit_jpy NUMERIC(15,0)` — 敷金
  - `key_money_jpy NUMERIC(15,0)` — 礼金
  - `agency_fee_jpy NUMERIC(15,0)` — 仲介手数料
  - `currency VARCHAR(3)` — ISO 4217 tag; NULL = legacy VN row
- Rationale `NUMERIC(15,0)`: matches invoice-side type family (0157 uses `NUMERIC(12,0)`; widened to 15 to hold up to 10^15 JPY — safe for Tokyo luxury rent while still fitting int64).
- No `server_default` on `currency` → avoids retro-tagging historical rows.
- No new timestamp columns → `CURRENT_TIMESTAMP` default not applicable here (Session 1 Q3 holds for future migrations with timestamps).
- Discipline: additive + nullable + inspect-before-add idempotent + reverse-order downgrade. One table/concern (Session 1 Q1).

### Verification (fresh PostgreSQL `jp_0161_test`)
```
# Fresh DB
docker exec ancu365-postgis psql -U ancu365 -d postgres \
  -c "DROP DATABASE IF EXISTS jp_0161_test" -c "CREATE DATABASE jp_0161_test"
docker exec ancu365-postgis psql -U ancu365 -d jp_0161_test \
  -c "CREATE SCHEMA planning; CREATE EXTENSION IF NOT EXISTS postgis;"

# upgrade head
alembic upgrade head               # → 0161_jp_rentals_pricing_jpy_cols
alembic heads                      # → single head: 0161
\d contracts | grep -iE 'jpy|currency'  # 5 cols present

# downgrade -1
alembic downgrade -1               # → 0160_jp_addresses_v2
\d contracts | grep -iE 'jpy|currency'  # 0 cols (dropped)

# re-upgrade (replay-safe)
alembic upgrade head               # → 0161
\d contracts | grep -cE 'jpy|currency'  # 5
```
All passed. Smoke `JWT_SECRET=test DATABASE_URL=sqlite:///:memory: python -c "import main"` → `OK`.

### Files changed
- `alembic/versions/0161_jp_rentals_pricing_jpy_cols.py` (+118, new)

### Commit / push
- `b5f5dea feat(jp-schema): add migration 0161 jp_rentals_pricing_jpy_cols` — pushed to `origin/jp-version` (3be4e5a..b5f5dea).

### Session 3 recommendation — Migration 0162 `jp_contracts_tax_fields`
Next schema sweep target: tax/invoice tagging on `contracts`. The 消費税 (consumption tax) classification currently sits only in `line_generator.py` constants (`exempt` vs `taxed`). To support audit-grade invoice history we need columns:
- `tax_treatment VARCHAR(16)` — `taxed_10` | `taxed_8` | `exempt` | `non_taxable` (reikin/shikikin-only rows)
- `invoice_issuer_id VARCHAR(14)` — 適格請求書発行事業者登録番号 (qualified invoice issuer registration no., 2024 インボイス制度)
- `tax_registration_verified_at TIMESTAMP` — proof-of-check timestamp against National Tax Agency DB

Kept out of 0161 to honor one-concern-per-migration. Pricing (0161) and tax metadata (0162) are logically separable; splitting also lets 0162 be rolled back without disturbing the JPY amount columns the renewal/invoice services will start reading as soon as 0161 lands in prod.

Alternative Session 3 if invoice/payment is prioritized over tax: **0162 `jp_payment_schedule`** (monthly billing cycle: `first_bill_date`, `bill_day_of_month`, `grace_period_days`, `late_fee_rate_bps`) — but tax-registration columns are the harder legal blocker, so lead with those.

### Unresolved questions (Session 2)

1. **Should `currency` default to `'VND'` server-side rather than NULL** for new rows written by the VN product (safer for aggregation queries that `GROUP BY currency`)?
   - Khuyến nghị: NOT YET — service layer should pass currency explicitly on INSERT (clearer intent, avoids silent misclassification during JP cutover). Promote to `server_default='VND'` only after Phase-05 service work stabilizes.
   - Hệ quả nếu chọn sai: aggregates on `currency IS NULL` would mis-bucket in dashboards — acceptable near-term since no dashboard groups by `currency` yet.
   - Độ tin cậy: MEDIUM-HIGH.

2. **Should the JPY mirror columns be enforced consistent with VN columns via CHECK constraint** (e.g. `(currency = 'JPY') = (rent_jpy IS NOT NULL)`)?
   - Khuyến nghị: NO at ORM-level, YES later as a nightly audit query. CHECK constraints across nullable mirror pairs trip on partial writes during multi-step service flows (set rent first, then currency).
   - Hệ quả nếu chọn sai: data drift between `monthly_rent` and `rent_jpy` for same contract. Mitigation = audit job.
   - Độ tin cậy: MEDIUM.

3. **Does `jp_rental_terms.monthly_rent_jpy` (0143) now double-store with `contracts.rent_jpy` (0161)?**
   - Khuyến nghị: TREAT 0143 as the detailed/renewal-history layer (per-period, with shikikin/reikin months) and 0161 as the current-active mirror on the contract header. Document in `app/models/rental.py` comment that `rent_jpy` is a cache of the current `jp_rental_terms.monthly_rent_jpy` row — do NOT dedupe now (0143 is already in production migrations chain and side-car has richer schema).
   - Hệ quả nếu chọn sai: writes to one and not the other → stale header. Mitigation = service layer always writes both inside one txn (Phase-05 scope).
   - Độ tin cậy: MEDIUM.

**Summary:** Migration 0161 adds 5 nullable JPY/currency columns on `contracts`, verified upgrade→downgrade→replay clean on fresh Postgres, single head, main import OK. Committed `b5f5dea`, pushed `origin/jp-version`. Session 3 should proceed with 0162 tax-fields migration on the same `contracts` table.

---

## Session 3 — Migration 0162 `jp_contracts_tax_fields` (2026-10-20)

### Scout
- `rg "class Contract" app/models/` → `app/models/rental.py:332 class Contract(Base)` · `__tablename__ = "contracts"` (line 339). Table confirmed.
- Previous head: `0161_jp_rentals_pricing_jpy_cols` (single head, Session 2 commit `b5f5dea`).

### Design (0162 on `contracts`, additive + nullable)
| Column | Type | Semantics |
|---|---|---|
| `tax_treatment` | VARCHAR(16) | 消費税区分: `'内税'` / `'外税'` / `'免税'`. VARCHAR not ENUM → forward-compat (e.g. future `'軽減'`) without ALTER TYPE. |
| `invoice_issuer_id` | VARCHAR(14) | 適格請求書発行事業者登録番号 (インボイス制度, 令和5年10月1日 法 Art.57-2). Format `'T' + 13 digits`. Full 14-char string stored (printer doesn't re-prefix). VARCHAR not CHAR for data-entry intermediate states. |
| `tax_registration_verified_at` | TIMESTAMP(timezone=True) | Set when `invoice_issuer_id` matched against NTA 公表サイト. NULL = unverified. Non-NULL = safe to print on invoices. |
| `consumption_tax_rate` | NUMERIC(4,2) | 10.00 / 8.00 (軽減税率) / 0.00. NUMERIC exact → no float drift at equality checks. |

Rationale:
- **No `server_default` on `tax_registration_verified_at`** — timestamp is a domain event ("when verification happened"), not an audit col. `CURRENT_TIMESTAMP` default would retro-stamp legacy rows as verified-at-upgrade-time (data-integrity lie). Session 1 Q3 answer: CURRENT_TIMESTAMP for "created_at"/"updated_at" only.
- **No ENUM for `tax_treatment`** — ALTER TYPE requires downtime in Postgres; VARCHAR keeps additive discipline.
- **No CHECK constraint** pairing `invoice_issuer_id` + `tax_registration_verified_at` (same reasoning as Session 2 Q2: nullable mirror pairs trip on partial writes during multi-step service flows). Audit job later.
- Discipline: additive + nullable + inspect-before-add idempotent + reverse-order downgrade. One table/concern (Session 1 Q1).

### Verification (fresh PostgreSQL `jp_0162_test`)
```
# Fresh DB
docker exec ancu365-postgis psql -U ancu365 -d postgres \
  -c "DROP DATABASE IF EXISTS jp_0162_test" -c "CREATE DATABASE jp_0162_test"
docker exec ancu365-postgis psql -U ancu365 -d jp_0162_test \
  -c "CREATE SCHEMA planning; CREATE EXTENSION IF NOT EXISTS postgis;"

# upgrade head → 0162_jp_contracts_tax_fields (clean full-chain run)
alembic upgrade head
\d contracts | rg -i "tax|invoice|consumption"
  tax_treatment                | character varying(16)
  invoice_issuer_id            | character varying(14)
  tax_registration_verified_at | timestamp with time zone
  consumption_tax_rate         | numeric(4,2)              ✅ 4/4 present

# downgrade -1 → 0161_jp_rentals_pricing_jpy_cols
alembic downgrade -1
\d contracts | rg -c "tax_treatment|invoice_issuer_id|tax_registration_verified_at|consumption_tax_rate"
  0  ✅ (all dropped)

# re-upgrade (replay-safe)
alembic upgrade head
\d contracts | rg -c "tax_treatment|invoice_issuer_id|tax_registration_verified_at|consumption_tax_rate"
  4  ✅

alembic heads → 0162_jp_contracts_tax_fields (head)  — single head
```
Smoke `JWT_SECRET=test DATABASE_URL=sqlite:///:memory: python -c "import main"` → `OK`.

### Files changed
- `alembic/versions/0162_jp_contracts_tax_fields.py` (+145, new)

### Commit / push
- `81c6f49 feat(jp-schema): add migration 0162 jp_contracts_tax_fields` — pushed `origin/jp-version` (b5f5dea..81c6f49).

### Session 4 recommendation — Migration 0163 `jp_payment_schedule` on `contracts`
Pricing (0161) + tax (0162) are landed on the contract header. Next legal/operational blocker is **billing cycle metadata** — currently the invoice generator infers period boundaries from `start_date` + hardcoded 1st-of-month, which breaks for JP leases that bill on 月末締め翌月末払 (end-of-month close, next-month-end payment). Proposed columns on `contracts`:

| Column | Type | Semantics |
|---|---|---|
| `first_bill_date` | DATE | 初回請求日 — may differ from `start_date` (e.g. prorated first month). |
| `bill_day_of_month` | SMALLINT (1–31, 99=末日) | 請求締日. 99 as sentinel for 末日 because month length varies. |
| `payment_due_day_of_month` | SMALLINT (1–31, 99=末日) | 支払期日. Common JP pattern: close on 25th, due 月末. |
| `grace_period_days` | SMALLINT | Days after due before late-fee kicks in. |
| `late_fee_rate_bps` | SMALLINT | 遅延損害金 basis points (consumer-protection law caps at 14.6%/yr = 1460 bps/yr for individuals; stored as annual bps). |

Rationale for Session 4 vs alternatives:
- **Beats "0163 jp_rent_adjustment_schedule"** (家賃改定): rent revision affects renewal flow only, which Session 5+ handles; billing cycle blocks the invoice generator day-1 of JP cutover.
- **Beats "0163 jp_renter_insurance"** (借家人賠償責任保険): insurance tagging is nice-to-have; billing cycle is must-have for invoice correctness.
- Same table (`contracts`) and discipline as 0161/0162 → low risk, cumulative tested chain.

Alternative if ops team prioritizes financial-reporting over billing: **0163 `jp_withholding_tax`** on `contracts` (源泉徴収 for non-resident landlord payments: `withholding_rate NUMERIC(4,2)`, `withholding_registered_at TIMESTAMP`). Rare case though — only ~3% of JP residential leases have non-resident landlords per MLIT 2024 survey.

### Unresolved questions (Session 3)

1. **Should `tax_treatment` values use Japanese literals (`'内税'`/`'外税'`/`'免税'`) or ASCII codes (`'inclusive'`/`'exclusive'`/`'exempt'`)?** Mission brief says Japanese literals; migration respects that. Trade-off: DB queries from grep-only tools need multibyte support (fine on Postgres UTF8), but legacy VN logging pipelines may stringify weirdly.
   - Khuyến nghị: KEEP Japanese literals as specified. Legal/accounting staff grep logs by Japanese term; English codes would need a translation layer anyway. VARCHAR(16) holds up to 5 Japanese chars (3 bytes each in UTF-8) + buffer.
   - Hệ quả nếu chọn sai: pipeline migration cost later if we switch to ASCII — but single-column data migration is trivial (`UPDATE contracts SET tax_treatment = CASE WHEN tax_treatment='内税' THEN 'inclusive' ... END`).
   - Độ tin cậy: MEDIUM-HIGH.

2. **Should `consumption_tax_rate` be stored per-contract or per-line-item?** Reduced-rate 8.00% applies to specific supplies (bundled 新聞 subscription on a lease is the only common rental case). Per-contract storage forces one rate per contract, which is wrong for mixed-rate contracts.
   - Khuyến nghị: ACCEPT per-contract for now — holds the DEFAULT rate for the contract; line-item overrides land on `invoice_lines` in a future migration (0164+). The vast majority of JP residential leases are pure 10% so per-contract covers the common case.
   - Hệ quả nếu chọn sai: mixed-rate contracts would need the override column sooner. Mitigation = add `line_tax_rate_override` to `invoice_lines` in Phase-05 when invoice service is touched.
   - Độ tin cậy: MEDIUM.

3. **Should `invoice_issuer_id` carry a format CHECK constraint `~ '^T[0-9]{13}$'`?** Would catch malformed entries at write time.
   - Khuyến nghị: NO at migration level — service-layer Pydantic validator is the right place (clearer error messages, catches intermediate-state entries during form input). DB-level CHECK would reject partial-entry rows during multi-step UI flows.
   - Hệ quả nếu chọn sai: bad data lands in DB if service layer bug lets it through. Mitigation = nightly audit query `SELECT COUNT(*) WHERE invoice_issuer_id IS NOT NULL AND invoice_issuer_id !~ '^T[0-9]{13}$'`.
   - Độ tin cậy: MEDIUM.

**Summary:** Migration 0162 adds 4 nullable 消費税/インボイス columns on `contracts`, verified upgrade→downgrade→replay clean on fresh Postgres `jp_0162_test`, single head `0162_jp_contracts_tax_fields`, `main` import OK on SQLite in-memory. Committed `81c6f49`, pushed `origin/jp-version`. Session 4 should land migration 0163 `jp_payment_schedule` on `contracts` (billing cycle metadata — the day-1 blocker for JP invoice generator correctness).

---

## Session 4 — Migration 0163 `jp_payment_schedule` (2026-10-20)

**Scope.** Add JP billing-cycle metadata to `contracts` so the invoice generator can model 月末締め翌月末払 (month-end close / next-month-end pay) and other patterns that break the implicit "1st of month, no grace" VN assumption flagged in Session 3's recommendation.

### Columns added (all nullable, additive on `contracts`)

| Column | Type | Default | Purpose |
|---|---|---|---|
| `first_bill_date` | DATE | — | 初回請求日 anchor; service falls back to `start_date` if NULL |
| `bill_day_of_month` | SMALLINT | — | 1..31 or sentinel `99` = 末日 (last-day-of-month) |
| `payment_due_day_of_month` | SMALLINT | — | 1..31 or `99` = 末日; cycle offset derived by service |
| `grace_period_days` | SMALLINT | `0` | Days after due before 延滞 clock starts; server_default = domain constant |
| `late_fee_rate_bps` | SMALLINT | — | 遅延損害金年率 in basis points; stored raw up to 2000 (利息制限法 absolute ceiling), service enforces per-class ceiling (14.6%/年 = 1460 bps for consumer) |

### Rationale highlights
- **SMALLINT not INT** on all day/bps columns: valid domain fits in 2 bytes; saving matters at `contracts` scale. ±32767 headroom covers any realistic bps.
- **Sentinel `99` for 末日** instead of ENUM: forward-compat (future `98` = 二末日 lands without ALTER TYPE). No CHECK constraint pairing with 1..31 — same Session 2 Q2 reasoning (nullable + partial-write intermediate states trip simple range CHECKs).
- **server_default only on `grace_period_days`**: it is a true domain constant (0 = no grace). The day-of-month and rate columns have NO server_default because legacy rows truly do not know their JP schedule, and NULL carries that "inherit tenant default" meaning. (Session 1 Q3 pattern: server_default only when the constant is semantically true, not for row-timestamp audit.)
- **Cycle offset NOT stored**: the +0/+1 month gap between bill and due is derived by the service. Storing it as a column invites drift between two columns that must agree. Flat schedule, service owns the calculus.
- **Late-fee bps as integer**: dodges NUMERIC rounding on daily accrual math; 1 bps = 0.01% is the industry convention. 2000 cap handles the 利息制限法 Art.1 absolute ceiling for sub-10万円 principals.

### Verification

```bash
docker exec ancu365-postgis psql -U ancu365 -d postgres -c "DROP DATABASE IF EXISTS jp_0163_test;"
docker exec ancu365-postgis psql -U ancu365 -d postgres -c "CREATE DATABASE jp_0163_test;"
docker exec ancu365-postgis psql -U ancu365 -d jp_0163_test -c "CREATE EXTENSION IF NOT EXISTS postgis; CREATE SCHEMA planning;"
JWT_SECRET=test DATABASE_URL=postgresql://ancu365:...@localhost:5433/jp_0163_test \
  PYTHONPATH=. .venv-strip/bin/alembic upgrade head    # → 0163_jp_payment_schedule
# ...downgrade -1
#    → 0162_jp_contracts_tax_fields
# ...upgrade head
#    → 0163_jp_payment_schedule (replay clean)
alembic heads  # 0163_jp_payment_schedule (head) — single head confirmed
```

Column shape `\d contracts` (new tail):
```
 first_bill_date              | date      |     |     |
 bill_day_of_month            | smallint  |     |     |
 payment_due_day_of_month     | smallint  |     |     |
 grace_period_days            | smallint  |     |     | 0
 late_fee_rate_bps            | smallint  |     |     |
```

Smoke `JWT_SECRET=test DATABASE_URL=sqlite:///:memory: .venv-strip/bin/python -c "import main"` → `OK`.

### Files touched
- `alembic/versions/0163_jp_payment_schedule.py` — NEW (+161/-0)

### Session 5 recommendation

Next natural migration — **0164 `jp_contracts_refs`**: cross-reference columns binding `contracts` to the JP-specific tables that already exist upstream. Candidate columns (all nullable FK or soft-ref on `contracts`):
- `jp_econtract_id BIGINT NULL` → `jp_econtracts(id)` (CloudSign-backed signed PDF)
- `jp_it_session_id BIGINT NULL` → `jp_it_sessions(id)` (IT重説 fulfilment)
- `jp_renewal_cycle_months SMALLINT NULL` — explicit renewal interval (2年 is default under 借地借家法 Art.26 but 1年/3年 contracts exist)
- `jp_latest_renewal_id BIGINT NULL` → `jp_contract_renewals(id)` for fast lookup of active cycle
- `jp_deposit_settlement_id BIGINT NULL` → `jp_deposit_settlements(id)` for exit-time 敷金精算 pointer

Rationale: Phase-04 so far added self-contained scalar columns on `contracts` (pricing in JPY → tax/invoice → payment schedule). The next correctness blocker for the JP invoice & lifecycle services is **relational wiring** — right now the services would have to scan the auxiliary tables by `contract_id` reverse-lookup because `contracts` holds no forward pointers. Adding nullable FKs lets the service layer resolve "the signed e-contract for this lease" / "the active renewal" / "the exit settlement" in one JOIN instead of a correlated subquery per row.

Alternative Session 5 if relational wiring is deemed premature: **0164 `jp_contracts_lifecycle_state`** — nullable enum-ish VARCHAR state machine column (`'draft' | 'it_pending' | 'signed' | 'active' | 'renewing' | 'ended' | 'settled'`) + `state_changed_at TIMESTAMP(tz)`. Lower-risk than FKs (no cross-table constraint), unblocks lifecycle reporting + webhook handlers. Lean toward this if upstream FK targets are still mutating; lean toward FKs if JP tables are stable.

### Status report
- Table shape: 5 columns added ✓
- Chain integrity: single head `0163_jp_payment_schedule` ✓
- Fresh Postgres cycle: upgrade → downgrade -1 → re-upgrade all green ✓
- Smoke `import main`: OK ✓
- Phase-03 ceiling: untouched ✓
- Baseline tag: untouched ✓

### Unresolved questions

1. **Should the `99` 末日 sentinel become a named constant somewhere (e.g. `app/constants/jp_billing.py`)?** Scattered `99` literals in the service layer rot into magic numbers.
   - Khuyến nghị: YES in Phase-05 when the invoice service lands; define `JP_LAST_DAY_OF_MONTH = 99`. Not in this migration — a migration file is the wrong home for a service-layer constant.
   - Hệ quả nếu chọn sai: service grows raw `== 99` checks and refactor pain compounds. Mitigation = extract on first service PR that reads the column.
   - Độ tin cậy: HIGH.

2. **Should `late_fee_rate_bps` carry a CHECK `BETWEEN 0 AND 2000`?** Would catch typos (e.g. storing 20000 for "20%" instead of 2000).
   - Khuyến nghị: NO at migration level — service-layer Pydantic validator with per-contract-class ceiling (1460 bps consumer, 2000 bps absolute) gives better errors. DB CHECK locks to absolute ceiling but cannot distinguish consumer vs. commercial.
   - Hệ quả nếu chọn sai: a service bug could store 20000. Mitigation = nightly audit `WHERE late_fee_rate_bps > 2000`.
   - Độ tin cậy: MEDIUM.

3. **Should `grace_period_days` server_default persist, or drop after a backfill?** Current default = 0 writes 0 to all new rows; legacy rows stay NULL. If a future tenant-config feature wants "default grace per org", the hard-coded 0 default silently overrides it on INSERT.
   - Khuyến nghị: KEEP for now. "No grace" is a safer default than NULL (which the service would have to interpret). Revisit when org-level billing config lands — at that point drop the server_default and move the fallback to the service.
   - Hệ quả nếu chọn sai: org-level grace config, when added, needs the service to explicitly override 0 or we need a `ALTER COLUMN DROP DEFAULT` migration. Both are cheap.
   - Độ tin cậy: HIGH.

**Summary:** Migration 0163 adds 5 nullable billing-cycle columns on `contracts`, verified upgrade→downgrade→replay clean on fresh Postgres `jp_0163_test`, single head `0163_jp_payment_schedule`, `main` import OK on SQLite in-memory. Session 5 should land either migration 0164 `jp_contracts_refs` (relational FKs to JP aux tables — unblocks invoice/lifecycle JOIN patterns) or `jp_contracts_lifecycle_state` (lower-risk state machine column) — pick based on JP table stability.

---

## Session 5 — Migration 0164 `jp_contracts_refs`

**Date:** 2026-10-20 · **LOC added:** +201 migration file · **Head:** `0164_jp_contracts_refs`

### Scope decision
Executed the primary Session 4 recommendation: **relational FK wiring** from `contracts` to the four JP aux tables that already exist (0154 `jp_it_sessions`, 0155 `jp_econtracts`, 0156 `jp_contract_renewals`, 0157 `jp_deposit_settlements`). Scouting confirmed all four target tables land upstream of this migration with `id SERIAL PK` (`Integer`), so no pivot to the fallback `jp_contracts_lifecycle_state` was needed.

### Columns added on `contracts` (all nullable)
| Column | Type | FK Target | Purpose |
|---|---|---|---|
| `jp_econtract_id` | INTEGER | `jp_econtracts(id)` | CloudSign-signed PDF (電子契約) pointer |
| `jp_it_session_id` | INTEGER | `jp_it_sessions(id)` | IT重説 session (宅建業法 Art.35 fulfilment) |
| `jp_contract_renewal_id` | INTEGER | `jp_contract_renewals(id)` | Current/latest renewal cycle (借地借家法 Art.26 default 2年) |
| `jp_deposit_settlement_id` | INTEGER | `jp_deposit_settlements(id)` | Exit-time 敷金精算 (原状回復 deductions + refund) |
| `jp_renewal_cycle_months` | SMALLINT | — | Explicit renewal interval (24=2年 default; 12/36 also live) |

### Rationale highlights
- **INTEGER not BIGINT on all FK cols**: Session 4 recommendation text said BIGINT, but actual aux-table PKs are `sa.Integer()` (`id SERIAL`, not `BIGSERIAL`). Matched real target width to avoid implicit widening cast on JOIN and planner surprises. Future `ALTER TABLE … ALTER COLUMN … TYPE BIGINT` sweep is cheap if aux tables grow; a width mismatch today is not.
- **`use_alter`-equivalent flow**: FKs added as separate `op.create_foreign_key` calls after `op.add_column`, not inline. Reasons: (a) autogen cycle-sort would struggle because aux tables already carry `contract_id` back-pointers, (b) matches the inspect-before-add idempotent pattern — a partial-failure re-run inspects `get_foreign_keys()` and skips existing names, (c) survives any future circular refactor.
- **No ON DELETE / ON UPDATE cascade**: deliberate. 宅建業法 Art.49 10-year retention for 重要事項説明書 + signed contracts means deleting an aux row while a contract still references it must raise an FK violation, not silently NULL the pointer. Service layer must detach before delete.
- **No UNIQUE on `jp_deposit_settlement_id`**: settlement is 1:1 per contract in the common case, but Phase-05 workflow may need settlement revisions/corrections as additional rows. Service enforces singleton semantics; DB stays loose.
- **No CHECK on `jp_renewal_cycle_months`**: nullable + partial-write intermediate states (Session 2 Q2 rule). Service validator enforces the 1..60 month domain.
- **Scope policy applied (no skips needed)**: all four aux tables confirmed present → all four FKs created. The migration still carries `if not insp.has_table(target_table): continue` guards so re-running on a DB that was downgraded past 0154-0157 does not crash.

### Verification

```bash
docker exec ancu365-postgis psql -U ancu365 -d postgres -c "DROP DATABASE IF EXISTS jp_0164_test;"
docker exec ancu365-postgis psql -U ancu365 -d postgres -c "CREATE DATABASE jp_0164_test;"
docker exec ancu365-postgis psql -U ancu365 -d jp_0164_test -c "CREATE EXTENSION IF NOT EXISTS postgis; CREATE SCHEMA planning;"
JWT_SECRET=test DATABASE_URL=postgresql://ancu365:...@127.0.0.1:5433/jp_0164_test \
  PYTHONPATH=. .venv-strip/bin/alembic upgrade head    # → 0164_jp_contracts_refs
# downgrade -1
#    → 0163_jp_payment_schedule (all 5 jp_* cols dropped, verified 0 remain in information_schema)
# upgrade head
#    → 0164_jp_contracts_refs (replay clean, all 4 FKs re-created)
alembic heads  # 0164_jp_contracts_refs (head) — single head confirmed
```

Column shape (new tail on `contracts`):
```
 jp_econtract_id          | integer   | YES
 jp_it_session_id         | integer   | YES
 jp_contract_renewal_id   | integer   | YES
 jp_deposit_settlement_id | integer   | YES
 jp_renewal_cycle_months  | smallint  | YES
```

FK constraints on `contracts` (new):
```
"fk_contracts_jp_econtract_id"            FK (jp_econtract_id)           REFERENCES jp_econtracts(id)
"fk_contracts_jp_it_session_id"           FK (jp_it_session_id)          REFERENCES jp_it_sessions(id)
"fk_contracts_jp_contract_renewal_id"     FK (jp_contract_renewal_id)    REFERENCES jp_contract_renewals(id)
"fk_contracts_jp_deposit_settlement_id"   FK (jp_deposit_settlement_id)  REFERENCES jp_deposit_settlements(id)
```

Smoke `JWT_SECRET=test DATABASE_URL=sqlite:///:memory: .venv-strip/bin/python -c "import main"` → `import main OK`.

### Files touched
- `alembic/versions/0164_jp_contracts_refs.py` — NEW (+201/−0)

### Session 6 recommendation

Next natural migration — **0165 `jp_contracts_lifecycle_state`**: now that the relational wiring is in place, the services need a **lightweight state column** on `contracts` to drive the lifecycle webhooks and dashboards without expensive multi-JOIN probes ("does it have a signed econtract? an active renewal? a settlement?") on every list query. Candidate shape:

- `jp_lifecycle_state VARCHAR(32) NULL` — enum-ish values: `'draft' | 'it_pending' | 'it_done' | 'signed' | 'active' | 'renewing' | 'ended' | 'settled'`. VARCHAR not ENUM for forward-compat (adding a state does not require `ALTER TYPE`).
- `jp_lifecycle_state_changed_at TIMESTAMP(timezone=True) NULL` — audit anchor.
- No DB-level state-machine CHECK; service layer owns transition rules.

Rationale: Session 4 explicitly flagged this as the fallback and Session 5 confirmed the FK targets are stable, so the two should **compose** — the FKs resolve "which aux row" and the state column resolves "which phase of the lifecycle" without the service having to derive it on each read. This also unblocks the Phase-05 webhook handlers (CloudSign callbacks, IT重説 completion events) which need a canonical column to flip, not a tuple of (econtract_id IS NOT NULL AND it_session_id IS NOT NULL AND ...) derivation.

Alternative Session 6 if lifecycle state is deemed service-only: **0165 `jp_contracts_rent_assignment`** — assignment pointer on `contracts` for 代理店 (sub-agent) revenue split, enabling the invoice service to resolve "which agent gets the commission on this lease" without scanning `agent_contracts` join tables. Lower priority than the lifecycle state column — pick lifecycle unless Phase-05 scope explicitly deprioritises webhook work.

### Status report
- Table shape: 5 columns added, 4 FKs created ✓
- Chain integrity: single head `0164_jp_contracts_refs` ✓
- Fresh Postgres cycle on `jp_0164_test`: upgrade → downgrade -1 → re-upgrade all green ✓
- Smoke `import main`: OK ✓
- Phase-03 ceiling: untouched ✓
- Baseline tag: untouched ✓

### Unresolved questions

1. **Should the FK target columns be `BigInteger` instead of `Integer`?** Aux-table PKs are `SERIAL` (int4) today, but if any aux table grows past 2.1B rows, the FK width needs to widen too and that is coupled: both sides must `ALTER TYPE` in lockstep to keep JOIN plans flat.
   - Khuyến nghị: KEEP `Integer`. Matches real target width today; 2.1B jp_econtracts is unrealistic (even 100 contracts/day for 50 years is 1.8M rows). When aux tables are refactored to `BIGSERIAL` in some future migration, pair-widen the FKs in the same migration.
   - Hệ quả nếu chọn sai: future `ALTER COLUMN TYPE BIGINT` on both sides is cheap (sub-second on modest row counts) but requires an exclusive lock briefly. Negligible.
   - Độ tin cậy: HIGH.

2. **Should `jp_deposit_settlement_id` carry a `UNIQUE` constraint (one settlement per contract)?** 1:1 is the business rule today.
   - Khuyến nghị: NO at this migration. Phase-05 settlement workflow may create correction/revision rows as separate `jp_deposit_settlements` records and the service picks "the current one" via `jp_deposit_settlement_id`. If a UNIQUE were present, the correction flow would need to UPDATE in-place, losing the audit trail of the original settlement.
   - Hệ quả nếu chọn sai: a service bug could point two contracts at the same settlement row. Mitigation = nightly audit `SELECT jp_deposit_settlement_id, COUNT(*) FROM contracts WHERE jp_deposit_settlement_id IS NOT NULL GROUP BY 1 HAVING COUNT(*)>1`.
   - Độ tin cậy: MEDIUM — depends on Phase-05 settlement workflow decisions.

3. **Should `jp_it_session_id` ship at all given IT重説 is deferred per `scope-phase-2-defer.md`?** The table exists upstream (0154) as placeholder, but no service writes to it in Phase-04.
   - Khuyến nghị: KEEP the column + FK. Cost today = one 4-byte nullable column that's always NULL. Benefit when Phase-05 unlocks IT重説 = no further `ALTER TABLE contracts ADD COLUMN` migration needed, no FK race on first write. Dropping it now and re-adding later is strictly more expensive than keeping it.
   - Hệ quả nếu chọn sai: 4 bytes/row wasted on contracts that never carry an IT session. Negligible at any realistic scale.
   - Độ tin cậy: HIGH.

**Summary:** Migration 0164 adds 4 nullable FK columns (`jp_econtract_id`, `jp_it_session_id`, `jp_contract_renewal_id`, `jp_deposit_settlement_id`) + 1 scalar (`jp_renewal_cycle_months SMALLINT`) on `contracts`, wiring the lease to its CloudSign artefact / IT重説 session / active renewal / exit settlement. All four FK target tables (0154-0157) confirmed present during scout; no scope pivot needed. Verified upgrade→downgrade→replay clean on fresh Postgres `jp_0164_test`, single head `0164_jp_contracts_refs`, `main` import OK on SQLite in-memory. Session 6 should land `0165 jp_contracts_lifecycle_state` — a nullable VARCHAR(32) state machine column + `state_changed_at` audit timestamp to drive Phase-05 webhook handlers and dashboards without multi-JOIN derivation.

---

## Session 6 — Migration 0165 `jp_contracts_lifecycle_state`

**Date:** 2026-10-20
**Branch head after:** `0165_jp_contracts_lifecycle_state`
**Commit:** `feat(jp-schema): add migration 0165 jp_contracts_lifecycle_state`

### Scope executed

Composed with Session 5's FK wiring: 0164 answered "WHICH aux row for this contract?", 0165 now answers "WHICH PHASE of the JP lease lifecycle is this contract in?" — without the service or admin dashboard having to JOIN all four aux tables and run a CASE-derivation on every read.

Columns added on `contracts` (both nullable, additive, no server_default):

- `jp_lifecycle_state VARCHAR(32) NULL` — domain documented in column comment: `'draft' | 'it_pending' | 'it_done' | 'signed' | 'active' | 'renewing' | 'ended' | 'settled'`. VARCHAR not ENUM for cheap vocabulary ALTERs during Phase-05 negotiation. No CHECK — service layer owns the transition graph (same Session 2 "no CHECK on nullable columns during partial-write windows" rationale).
- `jp_lifecycle_state_changed_at TIMESTAMP(timezone=True) NULL` — audit timestamp of last transition. Nullable + no server_default: a `now()` default would falsely stamp every legacy VN row as "transitioned at deploy time", polluting the dashboard's dwell-time queries.

Index added:

- `ix_contracts_jp_lifecycle_state` — non-unique B-tree on `(jp_lifecycle_state)`. Full (not partial) because the admin dashboard's `GROUP BY state COUNT(*)` wants the implicit NULL bucket counted too.

### Verification

Single head confirmed:
```
$ alembic heads → 0165_jp_contracts_lifecycle_state (head)
```

Fresh Postgres cycle on `ancu365_jp_migration_test` (host 127.0.0.1:5433, `postgis` extension + `planning` schema pre-created):
```
upgrade head          → ran 0001..0165, all green
\d+ contracts         → both JP lifecycle columns present + comments + index
downgrade -1          → 0165 → 0164
\d+ contracts         → grep -c jp_lifecycle = 0 (both cols + index gone)
upgrade head          → 0164 → 0165 replayed cleanly
\d+ contracts         → grep -c jp_lifecycle = 3 (col + col + index)
```

Smoke `JWT_SECRET=test DATABASE_URL=sqlite:///:memory: .venv-strip/bin/python -c "import main"` → `IMPORT OK`.

### Files touched

- `alembic/versions/0165_jp_contracts_lifecycle_state.py` — NEW (+~210/−0)

### Session 7 recommendation

Next natural migration — **0166 `jp_payments_breakdown`** (payment side).

Rationale: Sessions 2a-6 have fully wired `contracts` for the JP lease lifecycle (addresses v2, JPY pricing, 消費税 / インボイス, payment schedule, aux-table FKs, lifecycle state). The next unmapped surface is the **money-out** side — the `jp_payments` / rent-invoice tables need their JP-specific breakdown columns so the invoice service can emit a legally-compliant 請求書 (invoice line split by taxable/non-taxable per 消費税法 Art.28). Candidate shape:

- `jp_rent_amount_jpy BIGINT NULL` — pure rent portion (非課税, residential rentals are tax-exempt per 消費税法 Art.6).
- `jp_mgmt_fee_jpy BIGINT NULL` — 管理費 portion (課税 for commercial, 非課税 for residential — service determines).
- `jp_consumption_tax_jpy BIGINT NULL` — 消費税 amount actually charged on the taxable portion.
- `jp_late_fee_jpy BIGINT NULL` — 遅延損害金 (nullable; only populated on overdue payments).
- `jp_tax_invoice_number VARCHAR(16) NULL` — 適格請求書発行事業者 registration number used on this specific invoice (may differ from the contract-level default if the landlord re-registered mid-cycle; audit trail).

Composes with 0162 (contract-level tax metadata) + 0163 (payment schedule) + 0165 (lifecycle state): the invoice generator reads schedule → derives period → stamps breakdown + invoice number per payment row.

**Alternative Session 7** if payment-breakdown is deferred: **0166 `jp_agent_commission_routing`** — 代理店 (sub-agent) commission split pointer on `contracts` or a new `jp_agent_commissions` aux table. Needed when 2+ agencies share a lease and the system has to resolve "who gets what % of the signing fee" without the service hard-coding routing in Python. Lower priority than payment-breakdown because the invoice generator ships before the commission router in the Phase-05 timeline.

Pick payment-breakdown (0166) unless Phase-05 explicitly deprioritises invoice generation.

### Status report

- Columns added: 2 (`jp_lifecycle_state`, `jp_lifecycle_state_changed_at`) ✓
- Index added: 1 (`ix_contracts_jp_lifecycle_state`) ✓
- Chain integrity: single head `0165_jp_contracts_lifecycle_state` ✓
- Fresh Postgres cycle: upgrade → downgrade -1 → re-upgrade all green ✓
- Smoke `import main`: OK ✓
- Phase-03 ceiling: untouched ✓
- Baseline tag: untouched ✓

### Unresolved questions

1. **Should `jp_lifecycle_state` be ENUM instead of VARCHAR(32)?** ENUM gives DB-level enforcement and ~1 byte storage per row vs ~8 avg for VARCHAR.
   - Khuyến nghị: KEEP VARCHAR. Phase-05 is still negotiating the exact state vocabulary with ops; ENUM `ADD VALUE` is cheap but `RENAME`/`DROP VALUE` requires a type rewrite with exclusive lock. Storage delta is negligible (~70 bytes × row count).
   - Hệ quả nếu chọn sai: service layer carries all validation; a malformed INSERT could land garbage. Mitigation = Pydantic schema at API boundary + nightly audit `SELECT DISTINCT jp_lifecycle_state FROM contracts WHERE jp_lifecycle_state NOT IN (...)`.
   - Độ tin cậy: HIGH.

2. **Should `jp_lifecycle_state_changed_at` be `NOT NULL DEFAULT now()` to force every state write to carry a timestamp?** NULL today means "never transitioned", which overlaps with "legacy row never touched by JP flow".
   - Khuyến nghị: KEEP nullable, no server_default. Server_default would wrongly stamp legacy VN rows at deploy time, breaking the dashboard's "dwell time in state" queries. The service layer sets the timestamp explicitly on every transition — a transition WITHOUT a timestamp update is a service bug and should surface via the dashboard "state set but timestamp null" alert.
   - Hệ quả nếu chọn sai: a service bug could set `jp_lifecycle_state` without updating `jp_lifecycle_state_changed_at`, producing untracked transitions. Mitigation = Phase-05 service tests must assert both columns move together.
   - Độ tin cậy: HIGH.

3. **Should the index be partial (`WHERE jp_lifecycle_state IS NOT NULL`) to shrink heap size on legacy-VN-heavy tables?** Most rows will be NULL for the foreseeable future.
   - Khuyến nghị: KEEP full non-unique index. Partial index would make the admin dashboard's "count by state including unmapped bucket" query need a separate `WHERE IS NULL` count path. Reindex cost at current contract volume (<10K rows) is trivial; optimise if `contracts` grows past 1M rows.
   - Hệ quả nếu chọn sai: slightly larger index than necessary (<1MB wasted). Negligible.
   - Độ tin cậy: HIGH.

**Summary:** Migration 0165 adds the JP contract lifecycle state machine column (`jp_lifecycle_state VARCHAR(32) NULL`) + transition timestamp (`jp_lifecycle_state_changed_at TIMESTAMP tz NULL`) + non-unique B-tree index on state. Composes with 0164 — FKs resolve "which aux row", state column resolves "which lifecycle phase" without multi-JOIN derivation. Unblocks Phase-05 CloudSign / IT重説 webhook handlers that need a canonical column to flip. Verified upgrade→downgrade→replay clean on fresh Postgres `ancu365_jp_migration_test`, single head `0165_jp_contracts_lifecycle_state`, `main` import OK. Session 7 should land `0166 jp_payments_breakdown` — JP-specific invoice line split (rent / mgmt fee / 消費税 / 遅延損害金 / 適格請求書 number) on the payment side, composing with 0162's contract-level tax metadata and 0163's payment schedule.

---

## Session 7 — Migration 0166 `jp_payments_breakdown`

**Date:** 2026-10-20 · **Head after:** `0166_jp_payments_breakdown` · **LOC added:** +203 migration

### Scope decision
Mission brief for Session 7: add 消費税法 Art.28 invoice-breakdown cols on payment table. Mission text referenced "`jp_payments` (table from 0151)" — scout showed 0151 actually creates `jp_payment_intents` (singular `jp_payments` does not exist in codebase; `rg "jp_payments\b"` returns 0 hits across `alembic/` + `app/`). Resolved by taking the parent-table identity from 0151's actual DDL (`jp_payment_intents`) rather than the brief's shorthand. Mission intent — "payment row needs legal breakdown" — maps cleanly either way; schema target is `jp_payment_intents`.

### Columns added on `jp_payment_intents` (all nullable, additive)
| Column | Type | Role |
|---|---|---|
| `jp_rent_amount_jpy` | BIGINT NULL | 家賃 base rent portion. 非課税 per 消費税法 Art.6-1 bessho 13 (住宅の貸付け). |
| `jp_mgmt_fee_jpy` | BIGINT NULL | 管理費 management-fee portion. 課税 (10% standard rate). |
| `jp_consumption_tax_jpy` | BIGINT NULL | 消費税 amount on taxable components. Shown explicitly on 適格請求書 per Art.57-4-1. |
| `jp_late_fee_jpy` | BIGINT NULL | 延滞金 under late-payment clause (民法 Art.419 cap). |
| `jp_tax_invoice_number` | VARCHAR(16) NULL | 適格請求書発行事業者 T-number snapshot (e.g. `T1234567890123`). |

No indexes. Breakdown fields are read keyed by `id` (PK) or `invoice_id` (already indexed on 0151); T-number is audit/display-only, not a lookup key.

### Composition
Fits the Phase-04 contract-side stack:
- 0151 gave `jp_payment_intents` the GROSS `amount_jpy` (Numeric(12,0)).
- 0162 gave contract-level 適格請求書発行事業者 meta (T-number + 課税区分).
- 0163 gave billing-cycle rails.
- 0165 gave contract lifecycle state (guards whether invoice is legal to issue).
- **0166 (this)** adds the PER-PAYMENT legal breakdown Art.28 requires on every 適格請求書 — rent (non-taxable), mgmt fee (taxable), 消費税, 延滞金, issuer T-number snapshot — without which the invoice-PDF generator must back-derive from side-car tables + hard-coded rates.

### Design decisions
- **BIGINT (not NUMERIC(15,0))**: mission-pinned. Trade: breakdown cols' storage type doesn't match the parent `amount_jpy` NUMERIC(12,0); service layer casts both to int on read. Accepted — BIGINT holds up to 9.2 × 10^18 JPY, zero overflow risk for any rental payment.
- **All nullable, no server_default**: NULL = "not applicable / not yet backfilled" distinct from "computed, zero". Phase-05 service layer backfills by joining contract tax meta from 0162 — not a migration-time computation.
- **No CHECK on sum**: tempting `rent + mgmt + tax + late = amount_jpy`, but fails on (i) 消費税 rounding per 国税庁 2023-10 bulletin, (ii) partial payments, (iii) refund sign conventions. Service-layer tolerance validation; DB stays dumb.
- **No index creation**: see read-pattern note above. Reverse-order downgrade only drops cols.
- **VARCHAR(16) T-number** matches 0162's issuer col width — keep in sync if either changes.
- **Idempotent per Session 2a convention**: col-level inspect-before-add; downgrade iterates `reversed(_COLUMNS)`.

### Verification cycle (fresh Postgres `ancu365_mig_test` on `localhost:5433`)
```
alembic heads                          → 0166_jp_payments_breakdown (head)       ← single
alembic upgrade head                   → runs 0160→0166 clean (planning schema + postgis bootstrap)
alembic downgrade -1                   → 0166 → 0165 clean (drops 5 cols reverse order)
alembic upgrade head (replay)          → 0165 → 0166 clean (re-adds 5 cols)
psql \d jp_payment_intents             → all 5 cols present with correct types
JWT_SECRET=test DATABASE_URL=sqlite:///:memory: python -c "import main"  → OK
```
Test DB dropped post-verification. Baseline tag untouched. No Phase-03 ceiling touched.

### Files touched
- `alembic/versions/0166_jp_payments_breakdown.py` (new, 203 LOC)

### Status
- Head: `0166_jp_payments_breakdown` (single).
- Phase-04 migration count: 7 (0160 → 0166).
- `main` import smoke: PASS.
- Commit: `feat(jp-schema): add migration 0166 jp_payments_breakdown` → pushed `origin/jp-version`.
- Phase-05 unblocked for: invoice-PDF generator (now has full Art.28 breakdown without back-derivation).

### Recommendation for Session 8
Phase-04 is approaching natural closure (7 migrations covering contract tax, lifecycle, cross-refs, pricing, payment breakdown). Two candidates:

- **(A) `0167 jp_agent_commission_routing`** — adds commission-split cols on contracts (`jp_agent_broker_id FK users NULL`, `jp_agent_commission_pct NUMERIC(5,2) NULL`, `jp_agent_commission_jpy BIGINT NULL`, `jp_subagent_split_pct NUMERIC(5,2) NULL`) for 代理店 revenue flows. Unblocks Phase-05 commission payout service. **Pros:** adds real new revenue dimension; composes with 0162 issuer meta. **Cons:** FK to `users` creates cross-domain coupling previously avoided in Phase-04 (0151 explicitly uses `invoice_id String(64)` with no FK "cross-domain boundary"). Would need Phase-04 to break its own no-FK-across-domain discipline.

- **(B) `0167 jp_invoice_t_number_live_flag`** — adds `jp_qii_t_number_live_at TIMESTAMP tz NULL` + `jp_qii_t_number_revoked_at TIMESTAMP tz NULL` on `contracts`, matching 0162's T-number col. Lets the invoice generator check "is this issuer's T-number still valid on the invoice issue date?" without hitting the NTA API every time. **Pros:** pure additive timestamps, zero new tables / FKs, composes directly with 0162 — stays within Phase-04's no-FK discipline. **Cons:** narrower unblock; only matters when NTA revocation workflow comes online in Phase-06+.

**Recommendation: (B).** Keeps Phase-04 FK-free (preserves 0151's cross-domain-boundary pattern), finishes the 適格請求書 metadata triangle (0162 identity + 0166 per-payment snapshot + 0167 validity window), and sets a clean Phase-04 close. (A) belongs in Phase-05 where service-layer FKs are already in play.
- Hệ quả nếu chọn sai (B over A): Phase-05 commission payout work starts without a dedicated routing table, forced to carry split pct in app-level config or a new Phase-05 migration — minor delay, no data loss.
- Độ tin cậy: MEDIUM-HIGH. (A) could be argued if the business urgency on 代理店 payouts outranks T-number validity tracking.

### Unresolved questions

1. **Mission brief says `jp_payments` but table is `jp_payment_intents` — is this a typo or does a different `jp_payments` table need creation?** Session 7 proceeded on `jp_payment_intents` based on 0151 scout showing no other candidate.
   - Khuyến nghị: ACCEPT the `jp_payment_intents` target as implemented. If Phase planner intended a separate `jp_payments` (e.g. "succeeded payment ledger" distinct from "payment attempts"), raise as a Phase-04 scope-gap and consider a new migration splitting ledger from intents.
   - Hệ quả nếu chọn sai: if a separate `jp_payments` was really intended, 0166's breakdown cols end up on the wrong table — payment attempts carry breakdown that logically belongs on the successful-payment ledger row. Mitigation = cols are nullable + additive, straightforward to copy to a future table and drop here.
   - Độ tin cậy: MEDIUM. 0151 docstring is explicit that `jp_payment_intents` tracks "payment requests" — a separate `jp_payments` ledger is plausible but not visible in current codebase.

2. **Should `jp_consumption_tax_jpy` be `NUMERIC(12,2)` to preserve sub-yen rounding scratch rather than BIGINT?** 消費税 rounds to int per 国税庁 but intermediate computation uses fractional yen.
   - Khuyến nghị: KEEP BIGINT. Stored value is the FINAL invoice-displayed amount per Art.57-4-1 (always integer yen); intermediate fractional computation belongs in service layer, not DB. Matches mission brief spec.
   - Hệ quả nếu chọn sai: service must do its own rounding (which it must do anyway per Art.57-4-1 rules). Zero regression risk from BIGINT.
   - Độ tin cậy: HIGH.

3. **Should `jp_tax_invoice_number` carry a CHECK constraint `~ '^T[0-9]{13}$'` to enforce T-number format at DB level?** Current col accepts any 16-char string.
   - Khuyến nghị: NO CHECK. Phase-04 Session 2's no-CHECK discipline during partial-write windows applies: service layer validates format; DB stays permissive so migration-time snapshot writes (which may legitimately carry legacy/draft values) don't trip. Add CHECK in Phase-06 cleanup pass once all producers converge on the regex.
   - Hệ quả nếu chọn sai: a malformed T-number lands in DB and the invoice-PDF generator renders it verbatim. Mitigation = service-layer validation + PDF-side format assertion. Low real-world risk since the value is snapshotted from 0162 which Phase-05 will constrain.
   - Độ tin cậy: HIGH.

**Summary:** Migration 0166 adds 5 nullable cols on `jp_payment_intents` for 消費税法 Art.28 invoice breakdown — rent base (非課税), mgmt fee (課税), 消費税 amount, 延滞金, 適格請求書 T-number snapshot. BIGINT per mission spec. No indexes (not a lookup target). Composes with 0162 (contract issuer meta) + 0163 (billing cycle) + 0165 (lifecycle guard) to let Phase-05 invoice-PDF generator render legal Art.28 breakdowns without back-derivation. Verified upgrade→downgrade→replay clean on fresh Postgres `ancu365_mig_test`, single head `0166_jp_payments_breakdown`, `main` import OK. Session 8 should land `0167 jp_invoice_t_number_live_flag` to close the 適格請求書 metadata triangle (identity in 0162, per-payment snapshot in 0166, validity window in 0167) and preserve Phase-04's no-FK-across-domain discipline.
