# Phase 04 — Launch Backend

**Priority:** P3 · **Status:** 🚀 Starting · **Est:** 1.5 weeks BE · **Depends on:** P3 BE

## Overview

Launch readiness: seed JP listings, E2E API scripts cho 4 personas, Tokyo (ap-northeast-1) deploy configs + runbook, compliance evidence endpoints.

## Scope

### 1. Seed JP listings (3–5 broker partners)
- `scripts/seed_jp_launch.py` → idempotent seeder:
  - 3 broker orgs (Shinjuku, Shibuya, Setagaya) + 1 admin verified status
  - 15–20 realistic listings (chintai), mix 1R/1K/1LDK/2LDK, rent 70,000–220,000 ¥
  - Geocoded addresses (real postal codes), amenities, 敷金/礼金/更新料 fields populated
  - Linked `OrgProviderConfig` with placeholder payment provider (sandbox mode)
- Guarded by `--env=staging` flag. Refuses `production` unless `--confirm-prod` passed.

### 2. E2E API scripts cho 4 personas
- `tests/e2e/jp/` using `pytest` + `httpx.AsyncClient` + staging DB:
  - `test_persona_owner.py` — list property, approve application, settle deposit
  - `test_persona_broker.py` — invite tenant, submit application, confirm renewal
  - `test_persona_tenant.py` — browse, apply, sign contract, review settlement
  - `test_persona_admin.py` — view KPIs, export DSR, trigger deletion cron
- Each script hits real BE (`JP_STAGING_URL`), reports pass/fail + timing.

### 3. Tokyo infra deploy configs
- `deploy/jp/` folder:
  - `docker-compose.jp.yml` — JP-only overrides (region=jp, timezone Asia/Tokyo, encrypted volumes)
  - `nginx.jp.conf` — JP-specific rate limits, APPI consent banner header injection
  - `env.jp.template` — all JP envs: `REGION=jp`, `NOMINATIM_UA`, `TOKYO_RDS_HOST`, Fernet key placeholder
  - `runbook-tokyo-deploy.md` — step-by-step: RDS setup, PITR, backup策略, cron verification, rollback drill

### 4. Compliance evidence endpoints
- `GET /jp/compliance/evidence` (admin-only) → returns:
  - Count of users with APPI consent
  - Last deletion cron run timestamp + purged count
  - PII encryption key rotation date
  - Multi-org HMAC webhook secret rotation ledger
- Used by legal team for audit trail.

## Files

**New:**
- `scripts/seed_jp_launch.py`
- `tests/e2e/jp/test_persona_{owner,broker,tenant,admin}.py`
- `tests/e2e/jp/conftest.py`
- `deploy/jp/docker-compose.jp.yml`
- `deploy/jp/nginx.jp.conf`
- `deploy/jp/env.jp.template`
- `deploy/jp/runbook-tokyo-deploy.md`
- `app/api/routes/jp/compliance.py`
- `app/services/compliance/evidence.py`

**Modified:**
- `main.py` — mount compliance router under JP region guard

## Success Criteria
- Seed script runs cleanly against fresh staging DB, idempotent on 2nd run
- All 4 persona E2E scripts pass against staging in <5 min
- Deploy runbook rehearsed end-to-end (dry run OK)
- Compliance evidence endpoint returns valid JSON

## Open Questions
- Exact Tokyo AWS region: ap-northeast-1 (confirmed) or ap-northeast-3 (Osaka DR)?
- RDS size for launch: db.t4g.medium Multi-AZ (recommended) vs single-AZ to save cost?
