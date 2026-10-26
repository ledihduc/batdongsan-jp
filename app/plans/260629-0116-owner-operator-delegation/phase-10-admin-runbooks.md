# Phase 10 — Admin Endpoints & Operational Runbooks

## Context Links

- BA v4 §5.5 (Admin user stories US-A1..US-A7), §6.10 (AC-58/58b/58c/58d admin workflow), §6.11 (AC-61 GPKD revoked, AC-63 tenant unauthorized-operator flag, AC-65 PMC legal-rep change, AC-66 shared-login disclosure)
- §13 D2 (manual admin upload + 24h SLA), §13 D3 (POA digital + notarized fallback), §13 D4 (refuse co-owned via AC-64), §13 D6 (PMC RBAC defer v2)
- US-A1 (list active delegations), US-A2 (force-revoke), US-A3 (operator verification), US-A5 (SMS stuck approvals dashboard), US-A6 (owner death/incapacity processing), US-A7 (24h verification runbook)
- Research: `researcher-01-backend-auth-kyc.md` §A (require_admin pattern), §E (admin bypass in require_host); `researcher-03-flutter-app.md` §B (no full Flutter admin UI v1)
- Prereq phases: 03 (delegation entities), 04 (approval queue), 05 (KYC engine), 06 (owner death + retention services)

## Overview

**Priority:** P0 for admin endpoints supporting AC-58/61/65/66 + dispute resolution; P1 for runbook documentation
**Status:** Pending
**Brief:** Build minimal FastAPI admin endpoints + CLI scripts + documented runbooks for delegation oversight, KYC review, death-cert + POA verification, GPKD revocation, legal-rep change (AC-65), dispute escalation (AC-63), stuck-approvals dashboard (US-A5). **No full Flutter admin UI in v1** (researcher-03 §B + BA scope); reuse existing admin route family with light HTML/JSON responses. Runbooks live in `docs/runbooks/` and link from admin endpoint responses.

## Key Insights from Research

- **`require_admin` exists** (researcher-01 §A): role-based; admin can access any host endpoint. Phase-10 adds **admin-scoped** routes that explicitly mark `actor_context.actor_id=admin_user_id, on_behalf_of=affected_user_id` in audit (per phase-02 contract).
- **Admin bypass in require_host** (researcher-01 §E): admin currently treated as super-host; audit unclear. Phase-10 fixes: admin actions on host data must log via `change_logs.extra.admin_action=true` + reason.
- **No full Flutter admin UI v1** (researcher-03 §B + BA spec): admin endpoints return JSON + minimal Jinja2 HTML pages (existing precedent in some routers). Full admin web UI planned v2.
- **AdminHomeScreen (deferred) exists in Flutter** (researcher-03 §B): leave as-is; phase-10 does NOT extend Flutter admin.
- **Audit trail expectations** (researcher-02 §D): all admin mutations on user data must write `change_logs` row with action prefixed `admin_*` + `extra.reason`.

## Requirements (mapped to BA v4)

| AC / US | Covered by step |
|---------|-----------------|
| US-A1 | Step 2 (`GET /admin/delegations?status=...` list with filters) |
| US-A2 | Step 3 (`POST /admin/delegations/{id}/force-revoke`) |
| US-A3 | Step 4 (operator verification endpoints + KYC review queue) |
| US-A5 | Step 5 (stuck approvals dashboard for AC-30 60h+ SMS escalation) |
| US-A6 | Step 6 (owner death intake — wraps phase-06 service) |
| US-A7 | Step 7 (24h death-cert verification runbook + admin endpoint) |
| AC-58 (heir) | Phase 06 implements service; phase-10 adds admin UX layer |
| AC-58b | Step 6 (executor onboarding admin flow) |
| AC-61 | Step 8 (GPKD revocation admin endpoint + 15d re-verify timer) |
| AC-63 | Step 9 (tenant unauthorized-operator dispute review within 48h) |
| AC-65 | Step 10 (PMC legal-rep change workflow — 48h admin verification) |
| AC-66 | Verified at phase-05 onboarding; phase-10 documents ack audit query |

## Architecture

### Admin endpoint surface

```
GET    /admin/delegations                       — list, filters (status, owner, operator, date range)
GET    /admin/delegations/{id}                  — detail + audit timeline
POST   /admin/delegations/{id}/force-revoke     — emergency revoke (AC-45 fraud)
POST   /admin/delegations/{id}/admin-pause      — admin pause (US-A2)
GET    /admin/kyc-queue                         — operator KYC submissions pending review
POST   /admin/kyc/{id}/approve                  — approve operator KYC
POST   /admin/kyc/{id}/reject                   — reject with reason
GET    /admin/stuck-approvals                   — US-A5 dashboard (approvals > 60h pending)
POST   /admin/approvals/{id}/escalate           — manual escalation override
GET    /admin/owner-deaths                      — list pending verifications
POST   /admin/owner-deaths                      — upload death cert + POA (US-A6)
POST   /admin/owner-deaths/{id}/verify          — verify within 24h (US-A7)
POST   /admin/executor-onboard                  — trigger executor KYC (AC-58b)
POST   /admin/operators/{id}/gpkd-revoke        — AC-61 admin action
GET    /admin/disputes                          — AC-63 tenant unauthorized-operator queue
POST   /admin/disputes/{id}/resolve             — admin decision
POST   /admin/operators/{id}/legal-rep-change   — AC-65 PMC legal-rep workflow
POST   /admin/operators/{id}/legal-rep-change/{change_id}/verify
GET    /admin/audit/delegation/{id}             — full audit log dump for support
POST   /admin/audit/court-export                — AC-40 unlimited horizon export
POST   /admin/retention/run-now                 — manual cron invoke (ops escape hatch)
POST   /admin/pdpl/rod-requests/{id}/process    — AC-59 ROD processor (admin only)
```

### Admin actor context contract (extends phase-02)

```
admin_user logs in (role='admin') →
  request comes in with NO X-Acting-As-Delegation-Id (admin acts on platform side) →
  resolve_actor_context() returns ActorContext(actor=admin_user, on_behalf_of=NULL, permissions={admin_*})
  for routes under /admin/* :
    - require_admin guard
    - on mutations: write change_logs row with actor_id=admin_user, action='admin_<verb>', extra={target_user_id, reason}
```

### Runbook structure

```
docs/runbooks/
├── README.md                              — index + on-call rotation
├── 01-death-cert-verification.md          — US-A7 24h SLA process
├── 02-poa-review.md                       — digital vs notarized POA inspection
├── 03-gpkd-revocation.md                  — AC-61 detection sources + 15d re-verify
├── 04-tenant-unauthorized-operator.md     — AC-63 48h review process
├── 05-pmc-legal-rep-change.md             — AC-65 verification checklist
├── 06-stuck-approval-escalation.md        — US-A5 SMS + manual override
├── 07-retention-cron-failure.md           — phase-06 retention service alerting
├── 08-fraud-suspected-revoke.md           — AC-45 emergency revoke + admin escalation
└── 09-business-hours-table.md             — VN public holidays + business-hour calc
```

## Related Code Files

### Create

- `app/routers/admin_delegation_router.py` — list, detail, force-revoke, admin-pause
- `app/routers/admin_kyc_router.py` — KYC queue + approve/reject
- `app/routers/admin_approvals_router.py` — stuck dashboard + escalate
- `app/routers/admin_disputes_router.py` — AC-63 + AC-65 workflows
- `app/routers/admin_audit_router.py` — court-export + audit dump
- `app/services/admin_service.py` — orchestrator for admin mutations (writes audit + invokes phase-3/4/5/6 services)
- `app/services/business_hours.py` — `elapsed_business_hours(start, end)` + holiday table
- `scripts/admin/run_retention_now.py` — CLI for manual cron invoke
- `scripts/admin/list_stuck_approvals.py` — CLI version of dashboard
- `scripts/admin/export_court_audit.py` — CLI for AC-40 court-evidence export
- `docs/runbooks/` — 9 markdown runbook files

### Modify

- `app/dependencies/actor_context.py` (from phase-02) — extend resolution for admin routes (no X-Acting-As header expected)
- `app/services/delegation_service.py` (from phase-03) — expose `force_revoke()` callable from admin path
- `app/services/owner_death_service.py` (from phase-06) — expose verification entry points to admin router
- `app/services/approval_service.py` (from phase-04) — expose `admin_escalate()` callable

### Delete

- None.

## Implementation Steps

1. **Admin router family setup** — register all admin routers under prefix `/admin` with `require_admin` dependency. Mount as new section in `app/main.py` (existing pattern).

2. **US-A1 list delegations** — `GET /admin/delegations`:
   - Query params: `status`, `owner_id`, `operator_id`, `created_after`, `created_before`, page, page_size.
   - Returns paginated list with key fields + counts (active approvals, audit volume, last activity).
   - Index requirements verified in phase-01 (composite index on `delegations(status, created_at)`).

3. **US-A2 force-revoke** — `POST /admin/delegations/{id}/force-revoke`:
   - Body: `{reason: str, immediate: bool}`.
   - Calls `delegation_service.force_revoke(delegation_id, admin_user, reason)`.
   - Trigger phase-06 archive + phase-04 in-flight cancellation (immediate, no 30d notice for `fraud_suspected`).
   - Audit row: action=`admin_force_revoke`, extra=`{reason, immediate, ip, ua}`.
   - Notifies owner + operator via phase-08 notification service.

4. **US-A3 KYC review queue** — `GET /admin/kyc-queue`:
   - Lists operator-individual + operator-business KYC submissions with status `pending_admin_review`.
   - 24h SLA target (D2 referenced for death; KYC has 48h per BA §10.7 — operator can't activate until verified).
   - `POST /admin/kyc/{id}/approve` and `/reject` (with reason) → sets `host_profile.verified=true|false` + `verified_at` + invokes phase-05 hooks.

5. **US-A5 stuck approvals dashboard** — `GET /admin/stuck-approvals?threshold_hours=60`:
   - Lists `approval_requests` where `status='pending_owner_approval'` AND `now - created_at > threshold_hours`.
   - Shows owner contact channels attempted (push, email, SMS) + last_attempt_at.
   - `POST /admin/approvals/{id}/escalate` triggers immediate SMS + email + admin Slack notification.

6. **US-A6 owner death intake** — `POST /admin/owner-deaths` (multipart/form-data):
   - Fields: `owner_id`, `death_cert_file`, `notarized_poa_file`, `executor_candidate_user_id` (optional), `in_flight_handling_policy` (default `auto_reject`).
   - Stores files via existing upload pattern (`upload_path` config), enforces `CCCDAccessLog`-equivalent.
   - Inserts `owner_death_certificates` row, status=`pending_verification`.
   - Notifies admin team (Slack + admin dashboard).
   - Returns the row ID + verification deadline (`uploaded_at + 24h business hours`).

7. **US-A7 24h verification runbook + endpoint** — `POST /admin/owner-deaths/{id}/verify`:
   - Body: `{approved: bool, notes: str, executor_user_id?: int}`.
   - Computes `elapsed_business_hours(uploaded_at, now)`; warn if > 20h, escalate if > 24h.
   - If approved → invokes `owner_death_service.activate_death_workflow(owner_id)` (phase-06).
   - Writes runbook check list timestamps: identity_verified_at, document_authenticity_verified_at, sla_compliant.
   - Runbook `docs/runbooks/01-death-cert-verification.md` documents required checks (notary stamp, civil registry verification, owner identity cross-check).

8. **AC-61 GPKD revocation admin endpoint** — `POST /admin/operators/{id}/gpkd-revoke`:
   - Body: `{revocation_evidence_path: str, revoked_at: datetime, reason: str}`.
   - Sets `operator_business_profiles.gpkd_revoked_at`, pauses all delegations operated by this entity with `paused_reason='gpkd_revoked'`.
   - Notifies owner(s) + tenants within 24h (phase-08).
   - Starts 15d re-verify timer; if not re-verified → auto-terminate (APScheduler job).

9. **AC-63 tenant dispute review** — `GET /admin/disputes` lists unauthorized-operator reports.
   - `POST /admin/disputes/{id}/resolve` body: `{outcome: 'prima_facie_valid'|'invalid'|'requires_evidence', action: 'pause_delegation'|'no_action'|'request_more_info', reason: str}`.
   - 48h SLA tracking; admin Slack alert if > 36h.
   - On `pause_delegation`: invokes `delegation_service.pause(reason='disputed_authority')` + notifies owner.

10. **AC-65 PMC legal-rep change** — multi-step:
    - `POST /admin/operators/{id}/legal-rep-change` body: notarized POA file + new legal rep CCCD scan + new rep user_id.
    - Creates `legal_rep_change_requests` row (schema in phase-01) with `status='pending_admin_verify'`.
    - `POST /admin/operators/{id}/legal-rep-change/{change_id}/verify` body: `{approved, notes}`.
    - On approval: marks old user.is_active=false (disabled), new rep becomes active legal rep, in-flight approvals re-routed via `approval_service.reassign_to_new_legal_rep()`.
    - Audit: action=`legal_rep_changed`, extra=`{previous_rep_id, new_rep_id, change_id, verified_by_admin}`.
    - 48h SLA per AC-65.

11. **AC-40 court-evidence export** — `POST /admin/audit/court-export` (unlimited horizon):
    - Body: `{entity_type, entity_id, date_from, date_to, court_case_ref, requesting_authority, reason}`.
    - Generates audit dump (PDF + .xlsx) with full chain (change_logs + audit_logs + cccd_access_logs).
    - Logs the export itself in `audit_logs` with action=`admin_court_export`, extra=`{requesting_authority, reason, case_ref}`.
    - Returns signed URL (24h TTL).

12. **Operational runbooks** — write 9 markdown files documenting:
    - Step-by-step verification checklists
    - Vendor contact points (notary, KYC vendor if applicable)
    - Escalation contacts (legal counsel, ops lead)
    - SLA deadlines + business-hour calc rules
    - Sample audit log entries
    - Reset / rollback procedures
    - Required signing offices

13. **Business hours utility** — `business_hours.py`:
    - Function: `elapsed_business_hours(start: datetime, end: datetime) -> float`
    - Considers VN public holidays (Tết, Quốc khánh, etc.) via static table (refreshed annually).
    - Considers weekends (Sat + Sun).
    - Working hours: 08:00–18:00 ICT (configurable per ops decision).
    - Used by all 24h/48h SLA checks across phases.

## Todo List

- [ ] Create 5 admin routers + admin_service orchestrator
- [ ] Implement business_hours utility with VN holidays table
- [ ] Build all 16+ admin endpoints listed above
- [ ] Create 3 admin CLI scripts (retention, stuck approvals, court export)
- [ ] Write 9 runbook markdown files in `docs/runbooks/`
- [ ] Ensure admin actor context fix: actor=admin, on_behalf_of=target_user, audit action prefixed `admin_*`
- [ ] Integrate stuck-approvals dashboard with phase-08 manual escalation
- [ ] Integrate KYC queue with phase-05 verification engine
- [ ] Integrate owner-death endpoints with phase-06 service
- [ ] Wire 15d re-verify timer for AC-61 GPKD revocation
- [ ] Wire 48h SLA timer for AC-63 dispute + AC-65 legal-rep change
- [ ] Slack/email admin alerts for SLA approaching breach
- [ ] Unit tests: admin service mutations + audit log assertions
- [ ] Integration tests: end-to-end admin workflows for AC-58, AC-61, AC-63, AC-65
- [ ] Document runbook on-call rotation (link to docs/runbooks/README.md)

## Success Criteria

- **US-A1:** Admin can list delegations with filters; pagination works for >1000 rows.
- **US-A2:** Force-revoke completes within p95 < 5s; audit trail visible.
- **US-A3:** KYC queue shows pending; approve/reject paths set `host_profile.verified` correctly.
- **US-A5:** Stuck approvals dashboard returns rows where `now - created_at > 60h` AND status pending.
- **US-A6 + US-A7:** Death-cert upload + verification flow completes; SLA tracker shows compliance; runbook documents process.
- **AC-58 family:** Triggered via admin endpoint → phase-06 service correctly transitions state machine.
- **AC-61:** Admin marks GPKD revoked → delegation pauses + 15d timer scheduled.
- **AC-63:** Dispute resolves within 48h tracked; admin decision affects delegation state.
- **AC-65:** Legal-rep change verified within 48h; old credentials disabled; new rep gets in-flight approvals.
- **AC-40:** Court-evidence export returns full audit chain; export itself is logged.
- **Runbooks:** 9 markdown files exist; on-call rotation documented; admin team trained.

## Risk Assessment

- **R1 — Admin endpoints become security weak point** (broad permissions, often bypass IDOR). Mitigation: comprehensive integration tests asserting (a) non-admin role gets 403 on every admin endpoint, (b) audit log entry created with `admin_*` action prefix, (c) reason field required for mutations.
- **R2 — Runbooks go stale** (rare admin actions; checks become outdated). Mitigation: quarterly review on docs/runbooks/; link from each admin endpoint response so ops sees latest version on every action.
- **R3 — Founder-on-call burnout at scale** (Q-DD8): manual admin SLA at 24h is fine at 50-100 delegations; >1000 requires dedicated admin team. Mitigation: phase-10 instruments SLA breach rate; alert if breach rate > 10% for ops scaling decision.
- **R4 — No full Flutter admin UI**: ops uses JSON endpoints + curl/postman v1. Mitigation: provide minimal HTML page templates (Jinja2) on read-only endpoints for ease-of-use; full admin web UI is v2 roadmap.
- **R5 — Inconsistent admin audit logging** across phases 03/04/05/06: each phase service exposes mutation primitives; admin router calls them with `actor=admin_user`. Mitigation: centralize via `admin_service.execute_with_audit(admin_user, target_user, action, callable, reason)` wrapper.
- **R6 — Business hours computation edge cases** (DST not applicable to VN, but Tết dates shift annually): mitigation: explicit holiday table, refreshed annually as ops task, unit-tested with known examples.
- **R7 — Court-export endpoint abuse** (admin self-querying for non-legal reasons): mitigation: `requesting_authority` + `case_ref` required; audit-log the export itself; quarterly audit review of court exports.

## Security Considerations

- **All `/admin/*` routes require `require_admin`** — no bypass.
- **Admin actions audited under their own identity**, never under target user's. Audit `actor_id=admin_user`, `on_behalf_of=target_user`.
- **Reason field mandatory** on all mutating admin endpoints; stored in `change_logs.extra.reason`.
- **File uploads for death-cert/POA** — virus scan (ClamAV or similar) before storage; encrypted at rest.
- **Court-evidence export** signed URL TTL = 24h; revoke list maintained; access count logged.
- **CCCDAccessLog-equivalent for every PII view** by admin (death cert, CCCD, POA, GPKD).
- **No admin shoulder-surf risk:** admin cannot impersonate a user (no "login as user" feature v1) — only audit + force-revoke + verify.

## Estimated Effort

**4 dev-days** = 1 BE × 3d + 1 ops/admin × 1d. Includes 16+ endpoints, business hours utility, 9 runbooks, CLI scripts, and admin audit wrapper. Runbook documentation co-owned with ops lead.

## Next Steps / Dependencies

- **Blocks:** Phase 11 testing (admin endpoints are core test surface for compliance scenarios).
- **Blocked by:** Phase 03 (delegation service primitives), Phase 04 (approval primitives), Phase 05 (KYC engine), Phase 06 (death + retention services).
- **Independent:** Phase 07 (no Flutter admin UI), Phase 08 (admin alerts wire into notification service), Phase 09 (admin can export commission reports as court evidence).

## Open items flagged

- **Q-DD8** — admin team scaling threshold + budget (ops decision).
- **Q2.1, Q2.2, Q2.3** — operator pre-verification model + curated list + dispute mediation depth (product decision; admin endpoints support either model).
- **Court-export legal framework** — VN court order requirements for audit data subpoenas (legal counsel).
