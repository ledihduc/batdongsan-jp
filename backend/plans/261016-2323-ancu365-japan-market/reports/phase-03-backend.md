# Phase 03 Backend — Completion Report

**Status:** DONE
**Date:** 2026-10-17
**Docker test final count:** 249 passed / 249 collected (171 pre-existing + 78 new)

---

## Workstream Summary

### 1. 更新 Renewal Cycle
**Shipped:**
- Migration `0156_contract_renewals` — jp_contract_renewals table with indexes
- Domain model `app/domain/jp/contract_renewal.py` — RENEWAL_STATUS_VALUES, org-scoped
- Repository `app/repositories/jp/renewal.py` — idempotent exists_for_contract check
- Pure fn `app/services/renewal/invoice_builder.py` — compute_renewal_lines returning InvoiceLineDraft list
- APScheduler cron `app/services/renewal/cron.py` — daily 02:00 JST, 3600s misfire grace, idempotent inserts
- Routes `POST /api/jp/renewals/{id}/invoice`, `POST /api/jp/renewals/{id}/confirm`
- Schemas `app/schemas/jp/renewal.py`

**Tests:** 9 (test_renewal.py) — all pure function, no DB required

### 2. 敷金精算 Deposit Settlement
**Shipped:**
- Migration `0157_deposit_settlements` — jp_deposit_settlements with deductions_json (JSON), dual-timestamp approval
- Domain model `app/domain/jp/deposit_settlement.py` — SETTLEMENT_STATUS_VALUES
- Repository `app/repositories/jp/settlement.py` — tenant_sign, owner_sign, mark_payout methods
- Pure fn `app/services/deposit_settlement/itemizer.py` — compute_net_refund with full validation
- ORM wrapper `app/services/deposit_settlement/refund_invoice.py` — invoice ID generation
- 4 routes: POST create, PATCH items, POST tenant-sign, POST payout (dual-approval enforced)
- Schemas `app/schemas/jp/settlement.py`

**Tests:** 10 (test_deposit_settlement.py) — all pure function

### 3. DSR Real Cross-Domain Export
**Shipped:**
- `app/services/privacy/dsr_exporter.py` — collect() aggregator querying: profile, consents (with decrypt), viewings, applications, payments, owned listings
- APPI 2-year retention applied to time-bounded queries
- Route `GET /api/jp/me/export` returns real structured JSON (DsrExportResponse v2.0)
- Legacy `GET /api/jp/me/data-export` kept for backward compat

**Tests:** 7 (test_dsr_export.py) — mocked DB, all sections verified

### 4. User Deletion Schedule
**Shipped:**
- Migration `0158_users_deletion_scheduled` — adds deletion_scheduled_at TIMESTAMPTZ NULL + index to users table
- `POST /api/jp/me/schedule-deletion` — sets now()+30d, marks consent rows legal_hold=True
- `DELETE /api/jp/me/cancel-deletion` — nulls deletion_scheduled_at
- `app/services/privacy/deletion_cron.py` — APScheduler daily 03:00 JST, soft-anonymize (email SHA-256 hash, clear name/phone), preserves id for FK integrity, 3600s misfire grace
- Schemas `app/schemas/jp/dsr.py`

**Tests:** 6 (test_deletion_cron.py) — anonymization purity tests, cron registration test

### 5. Consent PII Encryption
**Shipped:**
- Migration `0159_consent_pii_encrypted` — adds ip_address_encrypted BYTEA + user_agent_encrypted BYTEA to jp_user_consents; backfill in batches of 1000 (skips gracefully if crypto unavailable during offline migration)
- Domain model updated: LargeBinary fields for encrypted columns, plaintext kept for P4 drop
- `app/services/privacy/consent_pii_encrypt.py` — encrypt_ip, encrypt_ua, decrypt_ip, decrypt_ua (DSR only), encrypt_on_write
- `app/services/consent/capture.py` updated — wraps grant() with encrypt_on_write (non-fatal on failure)
- DSR exporter calls decrypt_ip/decrypt_ua for export

**Tests:** 12 (test_consent_pii_encrypt.py) — round-trip, fallback to plaintext, Fernet IV randomness

### 6. Admin KPIs
**Shipped:**
- `app/services/admin_kpi/queries.py` — 5 parameterized functions: application_count, success_rate, avg_review_days, guarantor_approval_rate, vacancy_rate
- All take (org_id, prefecture, start, end) — prefecture is optional filter
- compute_all_kpis() runs all 5 in sequence
- Route `GET /api/jp/admin/kpis?prefecture=...&start=...&end=...` — admin role enforced, org-scoped
- Schema `app/schemas/jp/admin_kpi.py`
- No materialized views — direct indexed queries per spec

**Tests:** 8 (test_admin_kpi.py) — mocked DB, all 5 metrics + compute_all verified

### 7. Nominatim JP Geocoding Fallback
**Shipped:**
- `app/services/geocoding/nominatim_client.py` — httpx async, User-Agent: Ancu365/1.0 (ops@ancu365.com), 10s timeout, single-flight per address (asyncio.Lock), global 1 req/s floor
- `app/services/geocoding/resolver.py` — postal → Nominatim chain, 7-day cache via JpAddress upsert, _cache_fresh() TTL check
- Mock-first safe: geocode_address() returns None on any error (caller decides fallback)

**Tests:** 10 (test_nominatim.py) — timeout→None, no-results→None, round-trip, cache TTL, postal regex routing, no real HTTP calls

### 8. Multi-Org Webhook HMAC
**Shipped:**
- `app/services/webhook/hmac_resolver.py` — resolve() dispatches to komoju/cloudsign, _lookup_org_secret() scans OrgProviderConfig with Fernet decrypt, _verify_hmac_sha256() with constant-time compare, supports sha256= prefix format
- `webhooks_komoju.py` updated — calls hmac_resolve() before adapter, falls back to legacy adapter on resolution failure (backward compat during migration)
- `webhooks_cloudsign.py` updated — calls hmac_resolve() before adapter

**Tests:** 16 (test_webhook_multi_org.py) — HMAC verify, tamper detection, unknown org raises, unsupported provider raises, valid end-to-end

---

## Files Modified
| File | Action |
|------|--------|
| `alembic/versions/0156_contract_renewals.py` | create |
| `alembic/versions/0157_deposit_settlements.py` | create |
| `alembic/versions/0158_users_deletion_scheduled.py` | create |
| `alembic/versions/0159_consent_pii_encrypted.py` | create |
| `app/domain/jp/contract_renewal.py` | create |
| `app/domain/jp/deposit_settlement.py` | create |
| `app/domain/jp/user_consent.py` | modify (+LargeBinary fields) |
| `app/repositories/jp/renewal.py` | create |
| `app/repositories/jp/settlement.py` | create |
| `app/services/renewal/__init__.py` | create |
| `app/services/renewal/invoice_builder.py` | create |
| `app/services/renewal/cron.py` | create |
| `app/services/deposit_settlement/__init__.py` | create |
| `app/services/deposit_settlement/itemizer.py` | create |
| `app/services/deposit_settlement/refund_invoice.py` | create |
| `app/services/admin_kpi/__init__.py` | create |
| `app/services/admin_kpi/queries.py` | create |
| `app/services/geocoding/__init__.py` | create |
| `app/services/geocoding/nominatim_client.py` | create |
| `app/services/geocoding/resolver.py` | create |
| `app/services/privacy/dsr_exporter.py` | create |
| `app/services/privacy/deletion_cron.py` | create |
| `app/services/privacy/consent_pii_encrypt.py` | create |
| `app/services/webhook/__init__.py` | create |
| `app/services/webhook/hmac_resolver.py` | create |
| `app/services/consent/capture.py` | modify (+encrypt_on_write wrap) |
| `app/api/routes/jp/renewals.py` | create |
| `app/api/routes/jp/deposit_settlements.py` | create |
| `app/api/routes/jp/admin_kpi.py` | create |
| `app/api/routes/jp/me.py` | rewrite (real DSR + deletion endpoints) |
| `app/api/routes/jp/webhooks_komoju.py` | modify (+hmac_resolve) |
| `app/api/routes/jp/webhooks_cloudsign.py` | modify (+hmac_resolve) |
| `app/schemas/jp/renewal.py` | create |
| `app/schemas/jp/settlement.py` | create |
| `app/schemas/jp/admin_kpi.py` | create |
| `app/schemas/jp/dsr.py` | create |
| `main.py` | modify (+3 new JP routers) |
| `tests/jp/test_renewal.py` | create |
| `tests/jp/test_deposit_settlement.py` | create |
| `tests/jp/test_admin_kpi.py` | create |
| `tests/jp/test_nominatim.py` | create |
| `tests/jp/test_dsr_export.py` | create |
| `tests/jp/test_deletion_cron.py` | create |
| `tests/jp/test_consent_pii_encrypt.py` | create |
| `tests/jp/test_webhook_multi_org.py` | create |

---

## Deferred Items

1. **APScheduler integration in main.py** — renewal cron and deletion cron expose `start_renewal_cron(scheduler)` and `start_deletion_cron(scheduler)` but are not yet wired into the startup event. Reason: main.py uses the planning module scheduler (APScheduler) only in Postgres mode. Wiring requires reading that scheduler instance, which risks drift with VN planning cron. Recommendation: add to P4 launch readiness task with ops sign-off.

2. **Nominatim self-hosted** — deferred to P4 infra per plan. Public endpoint used with 1 req/s rate limit + 7-day cache.

3. **Key rotation tooling for Fernet** — tracked in P4 per phase file. Current: bump CRYPTO_SALT env + re-encrypt.

4. **Plaintext ip_address/user_agent columns on jp_user_consents** — kept for 1 release; drop in P4 (migration 0159 adds encrypted cols, plaintext cols survive until drop migration).

5. **DSR export ZIP format for large payloads** — legacy ZIP endpoint kept; new /me/export returns JSON. ARQ background job for large orgs deferred to P4.

6. **KPI query performance benchmarking** — queries use direct indexed scans. Benchmark at 10k rows; add materialized views if p95 > 500ms (as per plan risk section).

---

## Open Concerns

1. **main.py cron wiring** — `start_renewal_cron` and `start_deletion_cron` are not called from startup. File:line ref: `app/services/renewal/cron.py:start_renewal_cron`, `app/services/privacy/deletion_cron.py:start_deletion_cron`. Must add before P4 launch.

2. **Webhook HMAC resolver backward compat** — On HMAC resolution failure, komoju webhook falls back to legacy single-org adapter. This is intentional migration safety but means multi-org enforcement is advisory until all orgs have OrgProviderConfig rows with `provider_account_id` + `webhook_secret`. Ref: `app/api/routes/jp/webhooks_komoju.py:69`.

3. **contracts table cross-domain query** — renewal cron and invoice route query `contracts` table via raw SQL. If contracts table doesn't exist in JP deployment (JP uses different contract model), these will fail silently. Route returns 422 with clear message; cron logs the error. Needs validation in staging.

---

## Next Step

Wire `start_renewal_cron` and `start_deletion_cron` into main.py startup event (P4 launch readiness). All other P3 items are complete and tested.
