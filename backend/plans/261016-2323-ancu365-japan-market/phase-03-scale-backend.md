# Phase 03 — Scale Backend

**Priority:** P2 · **Status:** 🏗️ In Progress · **Est:** 2 weeks BE · **Depends on:** P2 BE
**Context:** [Gap matrix §2.4, §2.5, §2.8](../../../plans/261016-2323-ancu365-japan-market/research/gap-matrix.md)

> **Scope change 2026-10-17:** AI NLU search **CUT** (yak-shaving risk per debate review).
> Replace with structured facet search enhancements (already in P1). NLU revisited post-launch.
> P2 deferred items folded in: DSR cross-domain export, user deletion cron, PII encryption on consent, multi-org webhook HMAC.

## Overview

更新 renewal cycle · 敷金精算 deposit refund · DSR polish (real cross-domain export + deletion cron) · admin KPIs · Nominatim JP geocoding fallback · consent PII encryption · multi-org webhook HMAC routing.

## Requirements

**Functional**
- `ContractRenewal` cron: 60d before expiry → issue 更新料 invoice + notify tenant.
- `DepositSettlement` endpoint: owner itemizes deductions → generates refund invoice → tenant signs → payout.
- Admin KPI endpoints: 申込件数, 成約率, 平均審査日数, 保証会社通過率, 空室率 (by prefecture + period).
- Nominatim fallback for addresses not resolvable via 日本郵便.
- DSR `/me/export` returns real cross-domain JSON (profile + listings + applications + viewings + payments + consents).
- `users.deletion_scheduled_at` field + daily cron purges accounts >30d past schedule.
- `jp_user_consents.ip_address` + `user_agent` encrypted with Fernet at rest.
- Webhook HMAC: provider_id → org lookup → per-org secret resolution.

## Architecture

```
app/
  services/
    renewal/
      cron.py              ← APScheduler daily job
      invoice_builder.py   ← pure fn: contract → invoice lines
    deposit_settlement/
      itemizer.py          ← pure fn: itemized deductions → refund calc
      refund_invoice.py    ← ORM wrapper
    admin_kpi/
      queries.py           ← parameterized SQL, prefecture + date range
    geocoding/
      nominatim_client.py  ← httpx + 7d cache
      resolver.py          ← postal → nominatim fallback
    privacy/
      dsr_exporter.py      ← cross-domain aggregator (keep pure)
      deletion_cron.py     ← nightly purge
      consent_pii_encrypt.py ← encrypt ip/UA on write
    webhook/
      hmac_resolver.py     ← provider_id → org_id → secret
  api/routes/jp/
    renewals.py
    deposit_settlements.py
    admin_kpi.py
    (me.py updated — real export)
  domain/jp/
    contract_renewal.py
    deposit_settlement.py
  (migrations)
    0156_contract_renewals.py
    0157_deposit_settlements.py
    0158_users_deletion_scheduled.py
    0159_consent_pii_encrypted_cols.py (rename + backfill encrypt)
```

## Implementation steps

1. **Renewals**
   - Migration `0156_contract_renewals` — `id, org_id, contract_id FK, scheduled_at, renewal_fee_jpy, status(pending|invoiced|confirmed|renewed|expired), notified_at`.
   - `invoice_builder.compute_renewal_lines(contract) -> list[InvoiceLineDraft]` (pure).
   - `cron.py` daily at 02:00 JST: scan contracts `expires_at BETWEEN now+59d AND now+61d` + no renewal row yet → create row + enqueue notification.
   - Routes: `POST /api/jp/renewals/{id}/invoice`, `POST /api/jp/renewals/{id}/confirm`.
2. **Deposit settlement**
   - Migration `0157_deposit_settlements` — `id, org_id, contract_id, status(draft|tenant_review|accepted|disputed|refunded), gross_shikikin_jpy, deductions_json, refund_jpy, owner_signed_at, tenant_signed_at`.
   - `itemizer.compute_net_refund(gross, deductions) -> (net, breakdown)` (pure).
   - `refund_invoice.generate(settlement) -> JpInvoice`.
   - Routes: `POST /api/jp/deposit-settlements`, `PATCH .../items`, `POST .../tenant-sign`, `POST .../payout`.
3. **Admin KPIs**
   - `queries.py` with 5 fns, each takes `(org_id, prefecture, start, end)`:
     `application_count`, `success_rate`, `avg_review_days`, `guarantor_approval_rate`, `vacancy_rate`.
   - Route `GET /api/jp/admin/kpis?prefecture=...&start=...&end=...` returns `{kpis: {...}, computed_at}`.
   - **No materialized views for MVP** — direct queries with indexed filters. Benchmark; add if p95>500ms.
4. **Nominatim**
   - `nominatim_client.py` — httpx async, `User-Agent: Ancu365/1.0 (ops@ancu365.com)`, 10s timeout.
   - `resolver.lookup(postal_or_address)` — try postal first, Nominatim on empty result; cache 7d via `JpAddress` upsert.
   - Rate limit: single-flight per address string + 1 req/s global.
5. **DSR real export**
   - `dsr_exporter.collect(user_id, org_id) -> dict` aggregates: profile, consents, viewings, applications, payments (last 2y per APPI), listings owned.
   - Replace stub `/api/jp/me/export` with real serialization; stream as `application/json`.
6. **Deletion cron**
   - Migration `0158_users_deletion_scheduled` — add `deletion_scheduled_at TIMESTAMPTZ NULL` on `users`.
   - `POST /api/jp/me/schedule-deletion` sets `now()+30d`; `DELETE /api/jp/me/cancel-deletion` nulls.
   - `deletion_cron.py` daily at 03:00 JST: find users where `deletion_scheduled_at < now()`; soft-anonymize (hash email, clear name/phone, keep `id` for FK integrity, mark `deleted_at`).
7. **Consent PII encryption**
   - Migration `0159_consent_pii_encrypted` — add `ip_address_encrypted BYTEA NULL`, `user_agent_encrypted BYTEA NULL`; backfill from existing plaintext cols, keep plaintext cols for 1 release then drop in P4.
   - `consent_pii_encrypt.encrypt_on_write` wrapper on `ConsentRepo.create`; `decrypt_on_read` for DSR export only.
8. **Multi-org webhook HMAC**
   - `hmac_resolver.resolve(provider, headers, body) -> (org_id, verified: bool)`.
   - Komoju: use event payload `account_id` field → map to `OrgProviderConfig(provider='komoju', provider_account_id=...)` → look up secret.
   - CloudSign: use `X-CloudSign-Account` header; same pattern.
   - Fall back to deny (401) if no org match.

## Related code files

**Create**
- `app/domain/jp/contract_renewal.py`, `deposit_settlement.py`
- `app/schemas/jp/renewal.py`, `settlement.py`, `admin_kpi.py`, `dsr.py`
- `app/repositories/jp/renewal.py`, `settlement.py`
- `app/services/renewal/{cron,invoice_builder}.py`
- `app/services/deposit_settlement/{itemizer,refund_invoice}.py`
- `app/services/admin_kpi/queries.py`
- `app/services/geocoding/{nominatim_client,resolver}.py`
- `app/services/privacy/{dsr_exporter,deletion_cron,consent_pii_encrypt}.py`
- `app/services/webhook/hmac_resolver.py`
- `app/api/routes/jp/{renewals,deposit_settlements,admin_kpi}.py`
- `alembic/versions/{0156,0157,0158,0159}_*.py`
- `tests/jp/{test_renewal,test_deposit_settlement,test_admin_kpi,test_nominatim,test_dsr_export,test_deletion_cron,test_consent_pii_encrypt,test_webhook_multi_org}.py`

**Modify**
- `app/api/routes/jp/me.py` — real DSR export + deletion scheduling endpoints
- `app/api/routes/jp/webhooks_komoju.py`, `webhooks_cloudsign.py` — use `hmac_resolver`
- `app/services/consent/capture.py` — wrap with `consent_pii_encrypt`
- `app/services/address/jp_postal_client.py` — chain to Nominatim resolver on 404
- `main.py` — mount new routers under `require_region('jp')`

## Todo list

- [ ] 0156 renewal migration + model + repo + service + routes + tests
- [ ] 0157 settlement migration + model + repo + service + routes + tests
- [ ] 0158 user deletion schedule migration + endpoints + cron + tests
- [ ] 0159 consent PII encrypt migration + encrypt-wrapper + tests
- [ ] Admin KPI queries + route + tests (5 metrics × prefecture filter)
- [ ] Nominatim client + resolver + chain into postal lookup + tests
- [ ] DSR real cross-domain exporter + route + tests
- [ ] Multi-org webhook HMAC resolver + Komoju + CloudSign + tests
- [ ] `./check.sh` green on Docker
- [ ] 192+ JP suite still passing

## Success criteria

- Contract 60d before expiry triggers renewal invoice automatically; tenant can confirm.
- Deposit settlement: owner itemizes → tenant signs → refund invoice generated.
- Admin GET KPIs returns 5 metrics filterable by prefecture + date range.
- DSR export returns real cross-domain JSON (not stub).
- Consent writes encrypt ip/UA at rest; DSR decrypt only.
- Webhook from unknown org → 401; known org → verified + processed.

## Risk

- **Nominatim rate limits** on public API — self-hosted deferred to P4 infra; use conservative 1 req/s + 7d cache.
- **Cron drift** if container restarts — APScheduler misfire_grace_time=3600; idempotent inserts.
- **Encryption migration backfill** on live data — do batched 1000-row chunks + log progress.
- **KPI query perf** without materialized views — add indexes on `(org_id, prefecture, created_at)` on applications/contracts/listings.

## Security

- Deposit refund requires owner + tenant dual-approval before payout.
- Deletion cron is irreversible — add 72h grace + confirmation email.
- Multi-org HMAC: zero-trust on untrusted account IDs — always verify HMAC after lookup, not before.
- PII encryption uses same Fernet key as `OrgProviderConfig`; key rotation tooling deferred (tracked in P4).

## Next steps

- Unblocks: P4 Launch readiness.
