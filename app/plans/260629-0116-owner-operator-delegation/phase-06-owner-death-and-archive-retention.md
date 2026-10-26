# Phase 06 — Owner Death Workflow, Archive & PDPL Retention

## Context Links

- BA v4 §6.7 (AC-42..AC-46 termination + archive), §6.10 (AC-58..AC-58d owner death/heir), §10.5 (PDPL 4-tier retention), §13 D2 (owner death channel), §13 D9 (PDPL retention)
- US-O18 (heir/executor tiếp quản), US-A6 (admin processes owner death), US-A7 (24h death-cert verification runbook)
- Research: `researcher-01-backend-auth-kyc.md` §D (audit logs — extend with retention tier), §G (migrations precedent for cron jobs); `researcher-02-backend-money-flows.md` §D (ChangeLog/AuditLog/CCCDAccessLog), §G (APScheduler)
- Prereq phases: 01 (schema columns for `paused_reason`, `archived_at`, `retention_tier`, `owner_death_certificates` table), 02 (actor context for admin-as-actor logging), 03 (delegation state machine — pause/terminate states already implemented)

## Overview

**Priority:** P0 (legal/compliance + data integrity)
**Status:** Pending
**Brief:** Implement owner death admin workflow (AC-58 + AC-58b + AC-58c + AC-58d) — manual admin upload of death cert + notarized POA, 24h business-hour verification SLA, 7-day delegation pause, executor onboarding, in-flight auto-reject (with optional executor-exception per O3). Implement AC-44 30-day archive cron (soft-delete with `archived_at`) and §10.5 4-tier PDPL retention transitions (Tier A 10y / Tier B 7+3y / Tier C 24mo+redact / Tier D 90d purge). Implement AC-59 PDPL Right-of-Deletion request flow.

## Key Insights from Research

- **APScheduler ready** (researcher-02 §G): existing `app/services/planning_etl/scheduler.py` accepts new cron jobs (timezone UTC, `misfire_grace_time` already configured). Add jobs for: 30d archive, 7d owner-death-pause auto-unpause/transition, PDPL retention transitions (daily monthly).
- **No prior retention pattern** (researcher-02 §G): no tiered archival cron exists; first-class implementation. Column `retention_tier` added in phase-01 on `change_logs` + `audit_logs` + `delegation_audits` (whichever final design).
- **CCCDAccessLog precedent** (researcher-02 §D): for Tier C redaction (CCCD numbers, addresses, biometric photos), pattern = NULL out raw fields, keep hash anchor for audit chain. Existing `cccd_number_hash` column is the model.
- **Admin endpoints precedent** (researcher-01 §A): `require_admin` exists; no full admin UI in Flutter (researcher-03 §B). Therefore phase-06 ships admin endpoints + CLI scripts only; full admin UI in phase-10.
- **Owner death table is new** (researcher-01 §B): `owner_death_certificates` table created in phase-01 (id, owner_id, uploaded_by_admin_id, death_cert_path, notarized_poa_path, executor_user_id nullable, verified_at, verification_status, in_flight_handling_policy enum, created_at).

## Requirements (mapped to BA v4)

| AC / NFR / US | Covered by step |
|---------------|-----------------|
| AC-42 | Step 6 (30d countdown cron + state) |
| AC-43 | Inherited from phase-03 (lockdown rules); phase-06 only handles the END (transition to `terminated` + archived) |
| AC-43b | Inherited from phase-04 (24h fraud SLA); phase-06 only audits decision in retention tier |
| AC-44 | Step 6 (archive cron — soft-delete with `archived_at` timestamp) |
| AC-45 | Step 3 (admin-initiated immediate revoke path) |
| AC-46 | Step 7 (read-only history 90d for terminated operator) + Tier C redaction interaction |
| AC-58 (heir) | Steps 1–4 (admin upload death cert, 24h verification SLA, 7d pause state) |
| AC-58b | Step 4 (executor onboarding flow via admin-assisted KYC; downstream of phase-05 KYC engine) |
| AC-58c | Step 5 (tax-frozen account state — payout auto-paused, ops escalation) |
| AC-58d | Step 4 (in-flight approval auto-reject default; executor-exception activated only after O3 legal sign-off) |
| AC-59 | Step 8 (PDPL ROD request endpoint + 30d admin processing flow) |
| §10.5 4-tier retention | Step 9 (cron jobs for tier transitions) |
| US-O18 | Steps 1–4 (heir/executor lifecycle) |
| US-A6 | Steps 1–3 (admin receives + processes notification) |
| US-A7 | Step 2 (24h business-hour verification SLA; documented runbook in phase-10) |

## Architecture

### State machine — owner death lifecycle

```
[normal] --owner_death_reported--> [death_pending_admin_verify]
   |                                       |
   |                                       v (admin verifies <= 24h business hours)
   |                              [death_verified]
   |                                       |
   |                                       v (auto-trigger)
   |                              [pause_state] (delegation.status='paused', reason='owner_death')
   |                                       |
   |                              <----7 days-----+
   |                                       v
   |                              [executor_onboarded?]
   |                                  |          |
   |                                  yes        no
   |                                  v          v
   |                       [transferred_to_executor]  [terminated_admin_review]
   |
   v
[tax_frozen_account] (parallel state — payout pause only, delegation continues)
```

### Retention tier transitions (cron, daily 03:00 UTC)

```
Tier D (operational logs)  : created_at + 90 days     → PURGE (hard delete)
Tier C (PII payloads)      : rental_ended_at + 24 months → REDACT (NULL raw, keep hash)
Tier B (audit metadata)    : created_at + 7 years     → COLD ARCHIVE (move to cold table)
Tier B (cold)              : cold_archived_at + 3 years → PURGE
Tier A (financial records) : created_at + 10 years    → COLD ARCHIVE (mark only — preserve)
```

`retention_tier` column added in phase-01 = enum {`tier_a`, `tier_b`, `tier_b_cold`, `tier_c`, `tier_d`}. Cron updates tier based on age.

### In-flight approval at death registration (AC-58d)

```
DELEGATION.STATUS=active, DELEGATION.PAUSED_REASON=NULL
   |
   v (death registered, AC-58 transition)
DELEGATION.STATUS=paused, DELEGATION.PAUSED_REASON='owner_death'
   |
   +-- All delegation_approvals where status='pending_owner_approval' and delegation_id=this
   |     |
   |     v
   |   [default policy from owner_death_certificates.in_flight_handling_policy]
   |     |
   |     +-- 'auto_reject' (default, O3 NOT confirmed)
   |     |     status='rejected', reason='owner_death_auto_reject'
   |     |
   |     +-- 'executor_may_decide' (if O3 confirmed AND executor onboarded within 7d)
   |           status='pending_executor_approval', assigned_to=executor_user_id
```

## Related Code Files

### Create
- `app/services/owner_death_service.py` (new) — handles AC-58 lifecycle
- `app/services/retention_service.py` (new) — Tier transitions + ROD processor
- `app/routers/admin_owner_death.py` (new) — POST /admin/owner-deaths (upload), POST /admin/owner-deaths/{id}/verify, GET list
- `app/routers/admin_retention.py` (new) — admin manual tier-override + ROD processor
- `app/routers/pdpl_rod.py` (new) — public-ish (auth-required) POST /api/pdpl/rod-request
- `scripts/cron/run_retention_transitions.py` (new) — CLI entry for daily cron (also wired via APScheduler)
- `scripts/cron/run_archive_terminated_delegations.py` (new) — AC-44 30d archive

### Modify
- `app/services/planning_etl/scheduler.py` — add 4 new jobs (archive, owner-death-pause, retention transitions, ROD processor)
- `app/services/delegation_service.py` (from phase-03) — extend `pause_delegation()` to accept `reason='owner_death'`; extend `terminate_delegation()` to set `archived_at`
- `app/services/approval_service.py` (from phase-04) — extend `cancel_in_flight_approvals(delegation_id, reason, policy)` for AC-58d
- `app/models.py` — ensure `OwnerDeathCertificate`, `PdplRodRequest` SQLAlchemy classes (schemas created in phase-01)

### Delete
- None.

## Implementation Steps

1. **Admin upload death cert + POA** — POST `/admin/owner-deaths` accepts: owner_id, death_cert file (PDF), notarized_poa file (PDF), executor_candidate_user_id (optional), in_flight_policy (default `auto_reject`). Stores files via existing `upload_path` pattern (mirrors CCCD). Inserts `owner_death_certificates` row with `verification_status='pending'`.
2. **Admin verifies within 24h business hours (US-A7)** — POST `/admin/owner-deaths/{id}/verify` with body `{approved: bool, notes: str}`. If approved → trigger `owner_death_service.activate_death_workflow(owner_id)`. Compute SLA via `business_hours_elapsed(uploaded_at, now)`; emit warning notification to ops if > 20h, escalate if > 24h.
3. **Activate death workflow** — `owner_death_service.activate_death_workflow(owner_id)`:
   - Set `delegation.status='paused'`, `paused_reason='owner_death'`, `paused_until=now+7d`.
   - Trigger `approval_service.cancel_in_flight_approvals(delegation_id, reason='owner_death_pending', policy=in_flight_handling_policy)`.
   - Send notifications: tenant (in-app + SMS via phase-08, 24h SLA), operator (in-app + email, 24h SLA), admin team broadcast (Slack hook).
   - Write `change_logs` row: action=`owner_death_workflow_activated`, actor=admin, on_behalf_of=owner.
   - Audit retention `tier_a` (financial historicity).
4. **Executor onboarding (AC-58b)** — handled by phase-05 KYC engine; phase-06 provides the **trigger**: `owner_death_service.start_executor_onboarding(death_cert_id, executor_user_id)`. Onboards executor into existing `host_profiles` flow (re-uses CCCD upload). On completion → `transfer_delegation_to_executor(old_owner_id, new_user_id)`: clones delegation with new owner, audit retention `tier_b`, all historic mutations remain `read_only=true` (enforced by phase-02 audit filter).
5. **AC-58c tax-frozen** — POST `/admin/owners/{id}/tax-freeze` sets `host_profile.payout_paused=true`. Delegation continues, but payouts blocked (phase-09 commission service consumes the flag). Independent from death workflow (can co-occur).
6. **AC-42 + AC-44 archive cron** — daily job `archive_terminated_delegations()`: find `delegations where status='terminated' and archived_at IS NULL and terminated_at < now - 30d` → set `archived_at=now`. Soft-delete only (rows remain in DB; ORM filter excludes from active queries). Index `delegations(status, terminated_at)` added in phase-01.
7. **AC-46 read-only post-terminate** — phase-02 actor context already enforces "operator can view audit history for 90 days post-terminate". Phase-06 adds the **expiry**: cron `expire_post_terminate_readonly()` → after 90d, remove read-only access. Coordinated with Tier C redaction (any tenant data viewed under read-only is auto-redacted if Tier C transitions hit in those 90d).
8. **AC-59 PDPL ROD endpoint** — POST `/api/pdpl/rod-request` accepts: requester_user_id (auth), target_data_category ∈ {`my_pii`, `tenant_pii`, `cccd`}, reason text. Inserts `pdpl_rod_requests` row. Admin processes within 30d via `/admin/pdpl/rod-requests/{id}/process` — invokes `retention_service.redact_tier_c(user_id, category)` which NULL-out raw PII fields, keeps hash anchor.
9. **Retention tier cron (daily 03:00 UTC)** — `retention_service.run_daily_transitions()`:
   - Tier D purge (90d): `delete from change_logs where retention_tier='tier_d' and created_at < now - 90d` (use phase-01 partition strategy — if monthly partitioned, just drop expired partitions; else batch delete with `LIMIT 10000`).
   - Tier C redact (rental_end + 24mo): for each `change_logs.before_json` and `after_json` containing PII patterns, redact; mark `retention_tier='tier_c_redacted'`.
   - Tier B cold archive (7y): move rows to `change_logs_cold` table; update primary table marker.
   - Tier B cold purge (10y total = cold_archived 3y): delete from `change_logs_cold`.
   - Tier A → no auto-delete; mark `retention_tier='tier_a_cold'` only.
   - Acceptance: ≥99.5% success rate (BA NFR §10.5 cron reliability).

## Todo List

- [ ] Create `app/services/owner_death_service.py` with state machine functions
- [ ] Create `app/services/retention_service.py` with tier-transition + redaction functions
- [ ] Create `app/routers/admin_owner_death.py` (3 endpoints: upload, verify, list)
- [ ] Create `app/routers/admin_retention.py` (manual tier override + ROD processor)
- [ ] Create `app/routers/pdpl_rod.py` (public ROD request endpoint)
- [ ] Wire 4 APScheduler jobs in `scheduler.py`
- [ ] Extend `delegation_service.terminate_delegation()` to set `archived_at` chain
- [ ] Extend `approval_service.cancel_in_flight_approvals()` for AC-58d policy enum
- [ ] CLI scripts in `scripts/cron/` for manual/test invocation
- [ ] Notification templates for tenant/operator/admin (delegated to phase-08)
- [ ] Unit tests: state transitions, AC-58d policy branches, tier cron idempotency
- [ ] Integration tests: end-to-end admin upload → verify → 7d pause → executor onboard

## Success Criteria

- **AC-58:** Admin uploads death cert + POA, system creates pending row; verification within 24h business hours triggers delegation pause + notifications within 30s; audit shows actor=admin, on_behalf_of=owner.
- **AC-58b:** Executor completes KYC flow; delegation transferred to executor; all historic audit rows tagged `read_only=true`.
- **AC-58c:** Tax-freeze flag pauses payouts but delegation operations continue; admin/owner notified.
- **AC-58d:** Default `auto_reject` policy rejects all in-flight approvals on activation; `executor_may_decide` (post-O3) re-routes to executor.
- **AC-44 archive:** Cron flips `archived_at` after 30d; UI active views exclude archived rows; DB rows remain queryable by admin.
- **§10.5 retention:** Daily cron job succeeds ≥99.5% of the time; Tier D purge keeps table size bounded; Tier C redaction zeroes raw PII but preserves hash chain.
- **AC-59 ROD:** Tenant/operator can file request; admin processes ≤ 30d; raw PII redacted; audit row remains with hash anchor.

## Risk Assessment

- **R1 — Death cert verification fraud:** Admin verifies via document inspection only (no API to gov DB v1). Mitigation: require notarized POA + admin runbook (phase-10) + audit log of all admin verifications. Future: integrate gov death-registry API (v2).
- **R2 — Executor exception (AC-58d) without legal sign-off:** Default `auto_reject` is safe. Enabling `executor_may_decide` BEFORE O3 sign-off creates legal exposure. Mitigation: feature flag `ENABLE_EXECUTOR_DECIDE_EXCEPTION=false` until O3 confirms.
- **R3 — Tier C redaction breaks foreign keys:** Redacting CCCD hash on tenant row could orphan KB04 rows. Mitigation: redact only `cccd_number_hash`, `cccd_front_path`, `cccd_back_path`, `address_origin`; keep `id` + `host_id` intact so FK integrity preserved.
- **R4 — Retention cron failure leaves bloat:** Mitigation: alerting if `retention_run_log.success=false`; manual `admin_retention.run-now` endpoint for ops to invoke.
- **R5 — Archive cron interferes with in-flight legal disputes:** AC-46 says 90d read-only for dispute. Mitigation: archive cron checks `dispute_active=true` flag on delegation; skip archive if any active dispute or admin hold.
- **R6 — Cross-timezone business-hours SLA:** "24h business hours" is fuzzy. Mitigation: define as 24h excluding weekends + VN public holidays (table in phase-10 runbook); compute via `business_hours_elapsed()` util.

## Security Considerations

- **Admin-only routes:** All `/admin/owner-deaths/*` and `/admin/retention/*` and `/admin/pdpl/*` require `require_admin` + audit log (actor=admin user, action=`admin_*`).
- **CCCDAccessLog parity:** Every read of death-cert or POA file → `CCCDAccessLog` entry (extend to include `file_type='death_cert'|'poa'`).
- **ROD verification:** Requester must auth + answer security question (DOB or phone OTP). Prevents IDOR (one user requesting deletion of another's data).
- **Redaction irreversibility:** Tier C redaction is destructive. Mitigation: 7-day soft-redaction (flag + filter from queries) before hard-redact; admin can roll back in window.
- **In-flight approval reject audit:** Every auto-reject under AC-58d must carry `audit_log.extra.reason='owner_death_auto_reject'` + `policy_at_decision_time` for downstream legal review.

## Estimated Effort

**5 dev-days** = 1 BE × 5d. Includes APScheduler wiring, 3 admin routers, 2 services, ROD endpoint, redaction logic, and integration tests for state machine. Cron reliability instrumentation (logs + alerts) included.

## Next Steps / Dependencies

- **Blocks:** Phase 10 (admin UI + runbooks for death-cert verification, retention manual override, ROD processing).
- **Blocked by:** Phase 01 (schema columns + `owner_death_certificates`, `pdpl_rod_requests` tables, `retention_tier` enum on audit tables); Phase 03 (delegation pause/terminate state machine); Phase 04 (in-flight approval cancellation hook); Phase 05 (KYC engine for executor onboarding).
- **Pre-launch validation gates:** O3 (legal counsel sign-off on AC-58d executor-exception path) — required before flipping `ENABLE_EXECUTOR_DECIDE_EXCEPTION=true`. Phase ships with default `false`.

## Open items flagged

- **Q2a / O3** — legal counsel on AC-58d executor-exception scope (still pending).
- **Q-DD8** — admin team scaling for 24h business-hour SLA at >1000 delegations (ops budget).
- **Q-DD2** — red book OCR for v2 — informs Tier C redaction extensibility, not v1 work.
