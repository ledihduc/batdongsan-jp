# Phase 02 Backend Execution Report

**Date:** 2026-10-16
**Phase:** Phase 02 — Transactions Backend
**Plan:** plans/261016-2323-ancu365-japan-market/
**Status:** DONE_WITH_CONCERNS

---

## Files Modified / Created

### Migrations (alembic/versions/)
| File | Table | #Rows added |
|------|-------|-------------|
| `0149_org_provider_configs.py` | `org_provider_configs` | new |
| `0150_jp_invoice_lines.py` | `jp_invoice_lines` | new |
| `0151_jp_payment_intents.py` | `jp_payment_intents` | new |
| `0152_jp_webhook_events.py` | `jp_webhook_events` | new |
| `0153_jp_user_consents.py` | `jp_user_consents` | new |
| `0154_jp_it_sessions.py` | `jp_it_sessions` | new |
| `0155_jp_econtracts.py` | `jp_econtracts` | new |

All 7 migrations: additive, nullable, idempotent, have `downgrade()`.

### Domain Models (app/domain/jp/)
- `provider_config.py` — OrgProviderConfig
- `invoice_line.py` — JpInvoiceLine
- `payment_intent.py` — JpPaymentIntent
- `webhook_event.py` — JpWebhookEvent
- `user_consent.py` — JpUserConsent
- `it_session.py` — JpItSession
- `econtract.py` — JpEContract

### Services
- `app/services/crypto.py` — Fernet encryption helper
- `app/services/payment/jp/base.py` — JpPaymentAdapter Protocol
- `app/services/payment/jp/komoju/client.py` — KomojuMockClient + KomojuClient
- `app/services/payment/jp/provider_resolver.py` — per-org adapter factory
- `app/services/jp/invoice/line_generator.py` — compute_line_drafts() + JP tax rules
- `app/services/consent/capture.py` — record_consent() + revoke_consent()
- `app/services/consent/dsr.py` — export_user_data() + request_user_deletion()
- `app/services/it_session/zoom_adapter.py` — ZoomMockAdapter + ZoomClient (stub)
- `app/services/it_session/scheduler.py` — create_session() + capture_tenant_consent()
- `app/services/econtract/cloudsign_adapter.py` — CloudSignMockAdapter + CloudSignClient (stub)

### Repositories (app/repositories/jp/)
- `provider_config.py` — OrgProviderConfigRepository
- `payment_intent.py` — JpPaymentIntentRepository
- `webhook_event.py` — JpWebhookEventRepository (try_insert_idempotent)
- `invoice_line.py` — JpInvoiceLineRepository
- `user_consent.py` — JpUserConsentRepository
- `it_session.py` — JpItSessionRepository
- `econtract.py` — JpEContractRepository

### Schemas (app/schemas/jp/)
- `payment.py` — CreatePaymentIntentRequest, PaymentIntentResponse, InvoiceDetailResponse etc.
- `consent.py` — GrantConsentRequest, ConsentStatusResponse, DataExportResponse, DataDeleteResponse
- `it_session.py` — CreateItSessionRequest, ItSessionResponse, CreateEContractRequest, EContractResponse

### Routes (app/api/routes/jp/)
- `payments.py` — POST /api/jp/payments/intents, GET, POST konbini-voucher
- `webhooks_komoju.py` — POST /api/jp/webhooks/komoju
- `invoices.py` — GET /api/jp/invoices/{invoice_id}
- `consent.py` — POST grant, GET, POST revoke
- `me.py` — GET /api/jp/me/data-export, POST /api/jp/me/data-delete
- `it_sessions.py` — POST create, POST consent, GET detail
- `econtracts.py` — POST create, GET detail
- `webhooks_cloudsign.py` — POST /api/jp/webhooks/cloudsign

### Config / Main
- `app/config.py` — added `use_mock_providers: bool = True`
- `main.py` — registered all 8 new JP Phase 02 routers

### Tests (39 new, all pass)
- `tests/jp/invoice/test_line_generator.py` — 13 tests (compute_line_drafts, compute_totals_from_drafts)
- `tests/jp/payments/test_komoju_adapter.py` — 12 tests (mock adapter, konbini, HMAC, idempotency)
- `tests/jp/consent/test_consent_capture.py` — 14 tests (capture, revoke, status, DSR export/delete)

### Docs
- `docs/model_tables.txt` — 8 new tables appended (sorted)
- `docs/ARCHITECTURE.generated.md` — Phase 02 section appended

---

## Migration Numbers

| # | Table |
|---|-------|
| 0149 | org_provider_configs |
| 0150 | jp_invoice_lines |
| 0151 | jp_payment_intents |
| 0152 | jp_webhook_events |
| 0153 | jp_user_consents |
| 0154 | jp_it_sessions |
| 0155 | jp_econtracts |

---

## Encryption Choice

**Fernet (cryptography package, AES-128-CBC + HMAC-SHA256)**

Rationale:
1. Already in requirements (cryptography is a transitive dep of many packages).
2. Authenticated encryption — prevents silent tampering (unlike raw AES).
3. Timestamp embedded — enables key rotation without re-keying all rows at once.
4. Single import: `from cryptography.fernet import Fernet`.

Key derivation: `PBKDF2-HMAC-SHA256(settings.jwt_secret, salt=b"ancu365-provider-config-v1", 100k iterations)` → 32-byte base64url key.

Storage: `config_encrypted` JSONB column stores `{"ciphertext": "<base64url Fernet token>"}`.

Key rotation: bump `CRYPTO_SALT` constant + re-encrypt all `OrgProviderConfig` rows. Script not yet implemented (deferred).

---

## Mock-vs-Real Adapter Strategy

| Setting | Behavior |
|---------|----------|
| `USE_MOCK_PROVIDERS=true` (default) | KomojuMockClient, ZoomMockAdapter, CloudSignMockAdapter — no HTTP, realistic payloads |
| `USE_MOCK_PROVIDERS=false` | Real adapters — reads creds from OrgProviderConfig, calls external APIs |

In mock mode: HMAC verification is skipped in KomojuMockClient/CloudSignMockAdapter (signatures are accepted unconditionally). In real mode: HMAC-SHA256 verification is enforced before any processing.

---

## Known Concerns / Deferred Items

### Webhook Multi-Tenant Limitation
Komoju embeds `org_id` in payment session metadata. The webhook handler extracts
`org_id` from the payload (before HMAC check) to resolve the provider adapter.
In a true multi-org setup where each org has a different `webhook_secret`, this
means HMAC check happens after payload parse — an accepted trade-off documented
in ARCHITECTURE.generated.md. Mitigated in practice: the payload is trusted only
for org_id lookup; all business logic still happens after HMAC passes.

### DSR Export — Production Completeness
`export_user_data()` currently includes consent records fully but uses placeholder
stubs for profile/listings/applications/payments. These require cross-domain
repository calls that are deferred to P3 (full DSR compliance sprint). The current
implementation satisfies the route contract and is clearly documented in the code.

### DSR Deletion — User Table Field
`request_user_deletion()` marks consent rows as `legal_hold=True` but does NOT
yet set `deletion_scheduled_at` on the `users` table (field not yet in schema).
The 30-day purge cron job integration is deferred to P3 infrastructure work.
This is documented with a comment in `dsr.py`.

### Real Zoom/CloudSign Adapters
`ZoomClient.create_meeting()` and `CloudSignClient.*` raise `NotImplementedError`.
Deferred to production readiness phase. Production deployment MUST set
`USE_MOCK_PROVIDERS=false` and configure `OrgProviderConfig` rows.

### APPI Consent — PII Field Encryption
`ip_address` and `user_agent` in `jp_user_consents` are tagged `pii=True` in
comments but not yet field-level encrypted. Deferred to P3 APPI compliance sprint
(same as application PII fields from Phase 01).

---

## Test Results

```
compile:     PASS (python3 -m compileall -q app main.py → exit 0)
new tests:   39/39 PASS
jp suite:    168/171 PASS (3 pre-existing failures unrelated to Phase 02)
```

Pre-existing failures (confirmed pre-Phase 02):
1. `test_application_models.py::test_create_draft` — SA mapper init issue (requires full model registry)
2. `test_currency_migration.py::TestMigrationChain::test_revision_metadata` — alembic.op import mock
3. `test_currency_migration.py::TestMigrationChain::test_jp_address_migration_chain` — same

---

**Status:** DONE_WITH_CONCERNS
**Summary:** All Priority 1-4 backend work shipped: 7 migrations, 7 domain models, 10 services, 7 repositories, 8 routes (16 endpoints), 3 test files (39 tests green). Concerns: DSR export is a stub for cross-domain data, Zoom/CloudSign real adapters are NotImplementedError, webhook multi-tenant HMAC strategy is documented.
**Deferred:** Real Zoom/CloudSign API integration; DSR full cross-domain export; user.deletion_scheduled_at field; PII field encryption for consent records; key rotation tooling.
