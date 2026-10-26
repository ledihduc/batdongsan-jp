# Phase 02 — Transactions Backend

**Priority:** P1 · **Status:** 📋 Ready · **Est:** 3 weeks BE · **Depends on:** P1 BE
**Context:** [Gap matrix §2.6, §2.5](../../../plans/261016-2323-ancu365-japan-market/research/gap-matrix.md) · [Spec §5, §7](../../../plans/261016-2323-ancu365-japan-market/research/researcher-01-japan-spec-extract.md)

## Overview

Wire the money flow (JP payment provider + konbini + bank transfer), 消費税 line items, 入居審査 workflow, APPI consent + DSR, IT重説 session capture, electronic contract.

## Decisions required before start
- D1 Payment provider (default: **Komoju**)
- D2 Hoshou-gaisha (default: **manual MVP**)
- D3 eSign (default: **CloudSign**)
- D4 IT重説 (default: **Zoom + in-app consent capture**)

## Requirements

**Functional**
- `JpPaymentProvider` adapter interface + Komoju implementation (card, konbini, bank-transfer).
- Invoice: multi-line JP (家賃+管理費+敷金+礼金+仲介+保証), 消費税計算, 課税/非課税 flag.
- Konbini voucher issuance endpoint + webhook receiver (idempotent, HMAC verified).
- `ApplicationReview` workflow (sales/owner → approve/reject/pending, state log).
- `UserConsent` model (purpose, version, timestamp, IP), consent capture at register + settings page.
- DSR endpoints: `GET /api/jp/me/data-export` (async job), `POST /api/jp/me/data-delete` (soft delete + 30d purge).
- `ItSessionRecord` (session_id, participants, consent_timestamps, zoom_meeting_id, recording_url).
- `EContractDoc` (listing_id, application_id, provider='cloudsign', remote_doc_id, status, signed_pdf_url).
- CloudSign webhook receiver.

## Architecture

```
app/
  services/
    payment/jp/
      base.py                ← provider interface
      komoju/
        client.py
        webhook.py
    econtract/
      cloudsign/
        client.py
        webhook.py
    consent/
      capture.py
      dsr.py                 ← export + delete
    it_session/
      scheduler.py
      consent.py
  domain/jp/
    invoice_lines.py
    application_review.py
    consent.py
    it_session.py
    econtract.py
  api/routes/jp/
    payments.py
    webhooks_komoju.py
    reviews.py
    consent.py
    it_sessions.py
    econtracts.py
    webhooks_cloudsign.py
```

## Related code files

**Modify**
- `app/domain/jp/rental_terms.py` — invoice generation hook
- `app/services/notification/` — payment events (voucher issued, paid), review decisions, consent updates
- `app/api/routes/jp/applications.py` — triggers `ApplicationReview` on submit

**Create** — see Architecture

## Implementation steps

1. Payment adapter interface — 3 methods: `create_payment_intent`, `issue_konbini_voucher`, `handle_webhook`.
2. Komoju client (API key env, sandbox mode).
3. Invoice line generator from `JpRentalTerms` + tax config.
4. Webhook endpoints — HMAC verify, idempotent on `event_id`, log every event to `WebhookEvent` audit table.
5. `ApplicationReview` state machine (pending → in_review → approved/rejected) + notification hooks.
6. `UserConsent` capture middleware on `/api/auth/register` + settings endpoints.
7. DSR export: async job → zip user data (user, listings, applications, payments, consents) → signed URL (24h expiry).
8. DSR delete: soft-flag → cron purges after 30 days (except legal-hold rows).
9. IT重説 session: create → Zoom meeting via API → store IDs → capture 宅建士 ID + consent timestamps → store recording URL.
10. CloudSign: create document from PDF template → send → poll + webhook → store signed PDF.

## Todo list

- [ ] Payment adapter + Komoju + tests
- [ ] Multi-line JP invoice + tax
- [ ] Konbini voucher + webhook
- [ ] ApplicationReview workflow + tests
- [ ] UserConsent model + capture + DSR export + delete
- [ ] IT重説 session scheduler + Zoom integration
- [ ] EContract CloudSign flow
- [ ] Audit log for all transactions
- [ ] `./check.sh` green

## Success criteria

- Full flow: 申込 → approve → eContract sent → signed → invoice issued → konbini voucher → paid webhook → confirmation.
- DSR export returns zip; DSR delete flags user, scheduler purges after 30d.
- IT重説 session scheduled, Zoom link issued, consent captured, recording URL stored.

## Risk assessment

- Komoju sandbox parity — allocate 3 days for integration quirks.
- CloudSign PDF template — require content from BA (JP contract template).
- Zoom API rate limits — cache meeting creation; one meeting per session.

## Security

- All webhooks HMAC-verified, event idempotency keyed on provider event_id.
- Consent timestamps immutable (append-only).
- IT重説 recording URL short-lived signed, access logged.
- DSR delete does NOT bypass legal hold (invoice retention per JP tax law 7y).

## Next steps

- Unblocks: P3 (renewal cycle consumes invoice; AI search independent).
