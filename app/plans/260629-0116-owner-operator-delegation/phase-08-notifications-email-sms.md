# Phase 08 — Notifications, Email & SMS (greenfield channels)

## Context Links

- BA v4 AC-29 (push + in-app + 1-tap approve), AC-30 (72h expire + auto-REJECT), AC-30b (delivery escalation ladder — push → email → SMS), AC-41 (weekly digest), §10.4 (notification impact — 7 new notification types), §10.9 (cost estimate), NFR-14 (email deliverability ≥95% + read-receipt for high-value)
- §13 D8 (Zalo ZNS deferred to v1.1 Q4 2026); AS-11, AS-13 (Zalo budget v1.1 projection)
- Research: `researcher-01-backend-auth-kyc.md` §C (Notification model, no email/SMS provider configured, Zalo zalo.py builds share links only — does NOT send ZNS)
- Prereq phases: 01 (schema columns for `notification.channel` enum + `notification.delivery_attempts`)

## Overview

**Priority:** P0 (without escalation ladder, AC-30 72h auto-REJECT is the only mechanism — owners lose money)
**Status:** Pending
**Brief:** Greenfield integration of AWS SES (email) + eSMS.vn or FPT.AI (SMS) into the notification escalation ladder (AC-30b). Wire 7 new notification types into existing `Notification` model + extend with `channel` enum + delivery tracking. Implement read-receipt detection for high-value approvals (NFR-14). Zalo ZNS hooks placeholder (deferred to v1.1 per D8). Build weekly digest job (AC-41).

## Key Insights from Research

- **No email/SMS provider configured** (researcher-01 §C): grep confirms zero SES/Sendgrid/Twilio refs. Greenfield wiring.
- **Notification model is in-app only** (researcher-01 §C): existing `Notification(user_id, type, title, body, related_id, read)`. Extend with `channel`, `delivery_status`, `delivery_attempts`, `external_message_id` (vendor reference for read-receipt).
- **Zalo placeholder exists** (`app/utils/zalo.py`): `build_zalo_share_link()` builds `zalo.me/{phone}?body=...` deep-link only. Does NOT call Zalo ZNS API. v1.1 will replace with Official Zalo Notification Service.
- **APScheduler ready** (researcher-02 §G): existing scheduler. Add daily digest job + escalation timer.
- **No retry/failure tracking** (researcher-01 §C): notification model has no resilience. Add `delivery_attempts INT DEFAULT 0`, `last_attempt_at`, `failure_reason TEXT NULL`.

## Requirements (mapped to BA v4)

| AC / NFR / US | Covered by step |
|---------------|-----------------|
| AC-29 | Step 4 (push + in-app via FCM — already infra-ready) |
| AC-30 | Phase 04 owns 72h expiry; phase-08 owns SMS escalation channel at 60h |
| AC-30b | Steps 4–6 (full ladder: 0h push → 24h push+email → 48h push+email final reminder → 60h SMS; high-value early SMS at 24h if email unread) |
| AC-31 | Step 4 (audit log: `delivery_channels_used` on every approval decision) |
| AC-41 | Step 7 (weekly Monday 08:00 digest email — owner) |
| NFR-06 | Step 4 (push p95 < 30s) |
| NFR-14 | Step 5 (SES SPF+DKIM+DMARC config + read-receipt webhook) |
| §10.4 notification types | Step 3 (7 new types: delegation_invited, delegation_accepted, approval_requested, approval_decided, delegation_paused, delegation_terminated, kyc_expiring_soon; plus owner_death_delegation_paused, heir_onboarding_initiated, gpkd_revoked_delegation_paused) |

## Architecture

### Notification delivery pipeline

```
[event source: approval_service / delegation_service / ...]
    |
    v
[notification_service.create(user_id, type, payload, channels=['in_app','push','email'])]
    |
    +-- writes Notification row (in_app + push)
    +-- enqueues delivery via APScheduler one-off job
    |
    v
[delivery_worker]
    |
    +-- channel='in_app': mark delivered_at=now (no external call)
    +-- channel='push':    FCM send() → external_message_id, log delivery_status
    +-- channel='email':   SES send() → external_message_id, log delivery_status; SNS bounce webhook updates row
    +-- channel='sms':     vendor.send() → external_message_id, log delivery_status
```

### Escalation ladder (per pending approval)

```
T+0h    : push + in-app                                    (initial)
T+24h   : push + email                                     (reminder; high-value subject prefix)
T+24h*  : SMS                                              (* only if NFR-14 read-receipt shows email NOT opened AND amount ≥ 20M VND/month)
T+48h   : push + email (final reminder)
T+60h   : SMS                                              (default last gate)
T+72h   : auto-REJECT + SMS owner + admin dashboard alert  (AC-30, AC-30b, US-A5)
```

KB04 fast-track override (AC-55, 6h SLA): compressed ladder → T+1h push, T+3h push+email+SMS, T+6h auto-action.

Fraud-termination lockdown override (AC-43b, 24h SLA): T+0h push+email+SMS, T+12h push+SMS reminder, T+24h auto-REJECT.

### Vendor abstraction

```python
# app/services/notifications/channels/base.py
class NotificationChannel(ABC):
    async def send(self, recipient: str, subject: str, body: str, metadata: dict) -> SendResult: ...

# Implementations
class InAppChannel: ...
class FcmPushChannel: ...
class SesEmailChannel: ...      # AWS SES via boto3
class EsmsSmsChannel: ...       # primary
class FptSmsChannel: ...        # fallback (failover when eSMS errors)
class ZaloZnsChannel: ...       # NotImplementedError placeholder for v1.1
```

## Related Code Files

### Create

- `app/services/notifications/notification_service.py` — facade orchestrating channel selection + escalation
- `app/services/notifications/channels/base.py`, `in_app.py`, `fcm_push.py`, `ses_email.py`, `esms_sms.py`, `fpt_sms.py`, `zalo_zns_placeholder.py`
- `app/services/notifications/escalation_service.py` — schedules timed escalations per approval
- `app/services/notifications/digest_service.py` — weekly Monday 08:00 digest (AC-41)
- `app/services/notifications/templates/` — email + SMS templates (Jinja2), Vietnamese + English
- `app/routers/webhooks_email.py` — SES bounce + open + click webhooks (SNS subscription)
- `app/repositories/notification_repository.py` — extends existing for delivery_status updates
- `scripts/configure_ses.sh` — admin script for SPF/DKIM/DMARC config + verified-sender registration
- `app/utils/env.py` — extend for `SES_REGION`, `ESMS_API_KEY`, `FPT_API_KEY`, `ZALO_OA_TOKEN`

### Modify

- `app/models.py` — extend `Notification` with `channel`, `delivery_status`, `delivery_attempts`, `last_attempt_at`, `failure_reason`, `external_message_id`, `opened_at` (NFR-14)
- `app/services/planning_etl/scheduler.py` — register weekly digest job + per-approval escalation timers
- `app/utils/zalo.py` — mark `build_zalo_share_link` as v1.1 placeholder, no functional change
- `app/services/approval_service.py` (phase-04) — calls `notification_service.create(...)` instead of direct DB write
- `requirements.txt` — add `boto3` (SES), HTTP client for SMS vendors (existing `httpx` likely)

### Delete

- None.

## Implementation Steps

1. **Schema extensions** (handled in phase-01 — verify columns present):
   - `notifications.channel` ENUM('in_app', 'push', 'email', 'sms', 'zalo_zns')
   - `notifications.delivery_status` ENUM('pending', 'sent', 'delivered', 'failed', 'bounced')
   - `notifications.delivery_attempts INT DEFAULT 0`
   - `notifications.last_attempt_at TIMESTAMP NULL`
   - `notifications.failure_reason TEXT NULL`
   - `notifications.external_message_id VARCHAR(255) NULL` (SES message ID, SMS vendor ID)
   - `notifications.opened_at TIMESTAMP NULL` (NFR-14 read-receipt)

2. **NotificationChannel ABC + 5 implementations**:
   - `InAppChannel.send()` — writes Notification row + websocket/poll signals (existing pattern)
   - `FcmPushChannel.send()` — already infra-ready (researcher-01 §C); uses `firebase-admin` SDK
   - `SesEmailChannel.send()` — boto3 SES `send_email()` with configuration set for tracking; returns `MessageId`
   - `EsmsSmsChannel.send()` — POST to eSMS API with brand name + content + recipient; returns `MessageID`
   - `FptSmsChannel.send()` — fallback when eSMS returns 5xx or error after 2 retries
   - `ZaloZnsChannel.send()` — `raise NotImplementedError("Deferred to v1.1 Q4 2026 per D8")`

3. **Notification types** — define 10 type strings + Vietnamese + English templates:
   - `delegation_invited` (operator), `delegation_accepted` (owner), `delegation_paused` (operator + tenants), `delegation_terminated` (operator + tenants), `approval_requested` (owner), `approval_decided` (operator), `kyc_expiring_soon` (operator), `owner_death_delegation_paused` (operator + tenants), `heir_onboarding_initiated` (operator), `gpkd_revoked_delegation_paused` (operator + owner). Each has a Jinja2 template `templates/{type}.{channel}.{lang}.j2`.

4. **NotificationService facade** — `create(user_id, type, payload, channels=['in_app','push'])`:
   - Inserts notification rows for each channel (or single row with `channels[]` array — design choice TBD; default = separate row per channel for clean delivery tracking).
   - Immediately invokes channel.send() for in_app + push (synchronous; p95 <30s per NFR-06).
   - Enqueues email/sms via APScheduler `add_job(send_delayed_email, run_date=now)` (async non-blocking).
   - Records `change_logs` audit entry: action=`notification_sent`, actor=system, on_behalf_of=user.

5. **AWS SES config** (`scripts/configure_ses.sh`):
   - Verify sender domain `noreply@ancu365.com` via DNS TXT record (SPF + DKIM)
   - Set up DMARC policy `v=DMARC1; p=quarantine; rua=mailto:dmarc@ancu365.com`
   - Configure SNS topic for bounce/complaint/open/click events
   - Subscribe `app/routers/webhooks_email.py:/webhooks/ses` to SNS topic
   - Production access request (SES sandbox → production) — pre-launch validation gate

6. **SES read-receipt webhook** (`app/routers/webhooks_email.py`):
   - Verify SNS signature (boto3 helper)
   - On `Open` event → update `notification.opened_at`
   - On `Bounce`/`Complaint` → update `delivery_status='bounced'`, escalate to SMS earlier (NFR-14 trigger: if high-value approval AND not opened in 24h → SMS at 24h instead of 60h)
   - Idempotent (re-delivery of webhook events is normal)

7. **Weekly digest** (AC-41) — APScheduler cron Monday 08:00 ICT:
   - Per active owner: aggregate week's deltas (new contracts, new invoices, total revenue, alerts).
   - Skip if `host_profile.weekly_digest_enabled=false` (AS-05 toggle).
   - Send via `SesEmailChannel` with template `templates/weekly_digest.email.vi.j2`.
   - Audit: `change_logs` row per send.

8. **Escalation service** — for each `approval_requests where status='pending_owner_approval'`:
   - Schedule 4 future jobs: `+24h`, `+48h`, `+60h`, `+72h` (or fast-track schedule).
   - Each job: re-check status; if still pending → escalate next channel; if decided → cancel future jobs.
   - Use APScheduler job IDs `escalate_approval_{approval_id}_{stage}` for idempotent re-creation.
   - On `approval.status` change (via service callback): cancel pending jobs.

9. **SMS vendor failover** — `SmsRouterChannel.send()` tries eSMS first; on HTTP 5xx or vendor error code → retry with FPT.AI; logs `failure_reason` if both fail. Recipient phone normalized to E.164 (`+84...`). DLT registration with VN MIC for brand name `ANCU365` — pre-launch validation gate (~5 business days).

10. **In-app polling alignment** (researcher-03 §C): NotificationProvider polls 30s. Email/SMS don't change in-app behavior; they augment external channels.

11. **Zalo placeholder** — keep `app/utils/zalo.py:build_zalo_share_link()` unchanged. `ZaloZnsChannel` raises NotImplementedError. Notification UI may show "Zalo (sắp ra mắt v1.1)" if channel listed.

## Todo List

- [ ] Verify phase-01 added notification table columns (channel, delivery_status, attempts, external_id, opened_at)
- [ ] Create NotificationChannel ABC + 5 channel implementations
- [ ] Create notification_service facade with create() + ladder scheduling
- [ ] Create escalation_service with APScheduler job management
- [ ] Create digest_service for weekly Monday email
- [ ] Create 10 type × 3 channel × 2 lang = ~30 Jinja2 templates (some channels not applicable)
- [ ] Configure AWS SES: domain verify, DKIM, DMARC, SNS topic, sandbox-to-production
- [ ] Implement SES bounce/open webhook handler with SNS signature verification
- [ ] Register eSMS.vn account + DLT brand name (5 business days lead time)
- [ ] Set up FPT.AI failover account
- [ ] Wire escalation_service into approval_service (phase-04 hook point)
- [ ] Replace approval_service direct Notification writes with notification_service.create()
- [ ] Unit tests: each channel send() with mocked vendor
- [ ] Integration tests: full ladder simulated with time-mock (freezegun)
- [ ] Monitoring: NFR-14 deliverability dashboard (Grafana / CloudWatch)
- [ ] Vendor contracts: SES production approval + eSMS + FPT.AI account credentials

## Success Criteria

- **AC-30b ladder:** Pending approval at T+24h → push + email sent (verified in delivery log); T+60h → SMS; T+72h → auto-REJECT + SMS owner.
- **NFR-06:** Push notification delivered p95 < 30s from `notification_service.create()` to FCM ack.
- **NFR-14:** Email deliverability ≥95% inbox (measured via Postmark/SES inbox-placement testing); read-receipt webhook updates `opened_at` within 60s; high-value approval (rent ≥20M VND/month) triggers SMS at T+24h if not opened.
- **AC-41:** Monday 08:00 ICT weekly digest email delivered to opted-in owners; skip flag respected.
- **AC-31:** Every approval decision audit row includes `delivery_channels_used` array (e.g., `['in_app','push','email','sms']`).
- **Zalo deferred:** ZaloZnsChannel raises NotImplementedError; no Zalo ZNS in v1 production.

## Risk Assessment

- **R1 — SES production access delay:** AWS sandbox → production approval can take 3-5 business days. Mitigation: file request at phase-08 kickoff (Day 1); use Sendgrid as emergency fallback if SES delayed.
- **R2 — DLT brand registration delay** (VN MIC): SMS brand name registration ~5 business days. Mitigation: same — start at kickoff; pre-launch validation gate.
- **R3 — Vendor lock-in:** Choosing wrong SMS vendor = costly switch later. Mitigation: ABC channel abstraction makes vendor swap = 1-day change.
- **R4 — APScheduler job loss on restart:** In-memory scheduler loses jobs on app restart. Mitigation: SQLAlchemy job store (`SQLAlchemyJobStore`) instead of in-memory `MemoryJobStore` for production. Also persist `approval_requests.next_escalation_at` column so we can re-schedule from DB on startup.
- **R5 — SNS webhook signature spoofing:** Attacker forges bounce events to mark our messages as bounced. Mitigation: boto3 `verify_message_signature()` mandatory; reject any unverified message.
- **R6 — Bounce on legitimate owner email:** owner mistypes email → all approvals lost. Mitigation: on first bounce → admin dashboard alert + SMS owner asking to confirm/update email.
- **R7 — Cost overrun on SMS escalation:** if 30% approvals trigger SMS (vs budgeted 5%) → 6× cost. Mitigation: monthly SMS volume alert; if > 10% of approvals trigger SMS, redesign notification thresholds.
- **R8 — Zalo template not registered by v1.1:** AS-13 risk. Phase-08 v1 unaffected (Zalo deferred), but Q4 2026 v1.1 launch may slip.

## Security Considerations

- **PII in notification body:** approval body may include tenant name + CCCD partial. Mitigation: templates never include full CCCD; only masked `****1234`. Email subject never includes PII (visible in lock screen).
- **Email phishing risk:** attackers spoof `noreply@ancu365.com`. Mitigation: SPF + DKIM + DMARC enforced; reject mode for unauthorized senders.
- **SMS injection:** user-controlled text in template → SMS gateway exploitation. Mitigation: Jinja2 strict auto-escape; whitelisted variables only.
- **Webhook DoS:** attacker floods `/webhooks/ses` endpoint. Mitigation: rate-limit by IP + SNS signature verification; reject unverified within 50ms.
- **Vendor credentials:** AWS access key, eSMS API key, FPT API key in `.env` — must NEVER be committed (verify `.gitignore`); rotated quarterly.

## Estimated Effort

**5 dev-days** = 1 BE × 5d. Includes channel abstraction, 5 vendor adapters, 30+ templates, SES + SMS vendor setup, webhook handler, escalation service, weekly digest, and integration tests with time-mocking. Vendor approvals (SES production, DLT registration) run in parallel as ops tasks.

## Next Steps / Dependencies

- **Blocks:** Phase 04 (approval workflow needs escalation hook); Phase 06 (owner-death notifications); Phase 09 (commission digest extension).
- **Blocked by:** Phase 01 (schema columns extending Notification table).
- **Independent:** Phase 02, 03, 05, 07 — phase-08 is wire-up only; UI just consumes notifications.

## Open items flagged

- **AS-13** — Zalo ZNS template registration cost projection v1.1 (Q4 2026); not a v1 blocker.
- **Q-DD4** — email deliverability liability for absentee owners (legal/risk decision; phase-08 maximizes reach but cannot guarantee).
- **Vendor contracts** — SES + eSMS + FPT.AI vendor sign-up; pre-launch validation gate.
