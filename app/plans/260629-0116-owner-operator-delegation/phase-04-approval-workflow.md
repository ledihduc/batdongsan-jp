# Phase 04 — Approval Workflow + KB04 Carve-out

## Context Links
- BA v4: §6.4 (Approval), §6.7 (Termination), §6.8 KB04 (AC-55..AC-55d), §13 D1 (KB04 SLA 6h), §13 D5 (lockdown), §10.6 (KB04 timeline)
- ACs: AC-24, AC-25, AC-26, AC-27, AC-28, AC-29, AC-29b, AC-30, AC-30b, AC-31, AC-31b, AC-32b (cash receipt), AC-43, AC-43b (24h fraud-term SLA), AC-55, AC-55b, AC-55c, AC-55d, AC-56 (dual-approval — out of scope check), AC-58d (executor exception)
- NFRs: NFR-06 (push p95 < 30s), NFR-14 (email read-receipt early SMS for high-value)
- Research: `researcher-02-backend-money-flows.md` §F (state machine pattern), §G (APScheduler); `researcher-01-backend-auth-kyc.md` §C (notification), §F (KB04 current state)
- Dependent on phases: 01 (`delegation_approvals` table), 02 (decorator + lockdown), 03 (delegation status)
- Blocks: 07 (Flutter approval inbox), 10 (admin escalation dashboard)

## Overview
- **Priority:** P0
- **Status:** Pending
- **Effort:** 7 dev-days (1 senior BE + 0.5 BE for KB04 form integration)
- **Type:** backend
- **Description:** Build the threshold-based approval queue with notification escalation ladder. Includes KB04 6h fast-track + pre-file pathway + district fallback + POA format. Implements the in-flight cancellation on revocation. Background jobs drive the SLA expiry + auto-reject + escalation.

## Key Insights from Research
- No approval state machine framework today (researcher-02 §F). Use enum + service guard pattern (same as `KhaiBaoTamTru`).
- KB04 ~60% implemented for owner (researcher-01 §F, researcher-02 §E). Operator path 0%. Pre-file path 0%.
- Existing `KhaiBaoTamTru.public_token` → owner submits screenshot at police portal manually (researcher-02 §E). v1 keeps manual police filing; system only manages workflow + audit.
- APScheduler available (researcher-02 §G). New jobs needed.
- Notifications today are in-app only (researcher-01 §C). Phase-08 wires email/SMS. This phase emits events; phase-08 implements delivery.

## Requirements (mapped to BA v4)

### Functional ACs covered

| AC | Implementation |
|----|----------------|
| AC-24 | When operator creates contract via `POST /api/contracts`: service inspects `term_months` and `monthly_rent`; if either ≥ delegation threshold → create approval (`action_type='contract_create'`), contract stored `status='pending_owner_approval'` |
| AC-25 | `POST /api/invoices` / `POST /api/expenses`: if `amount ≥ threshold_expense_vnd` → approval `action_type='invoice_high_amount'` / `'expense_high_amount'`; entity stays `status='draft'` until approved |
| AC-26 | `PATCH /api/contracts/{id}` rent change: compute `delta_pct = (new_rent - old_rent) / old_rent`; if `≥ threshold_rent_change_pct` → approval `action_type='rent_change'`; entity update deferred |
| AC-27 | Contract termination (early): ALWAYS approval (`action_type='contract_terminate'`); no threshold gate; not blocked by AC-43 lockdown |
| AC-28 | Refund: if `amount ≥ threshold_refund_vnd` → approval `action_type='refund_high_amount'` |
| AC-29 | Approval delivery: enqueue notification event `approval_requested` (push + in-app) — phase-08 fans out |
| AC-29b | If `requested_amount_vnd ≥ 50_000_000` → `requires_biometric=True`. Owner approve endpoint requires biometric step (Flutter prompts; backend re-validates with a `biometric_token` from local_auth) |
| AC-30 | Approval `default_72h` SLA. Cron `approval_expirer` runs every 15 min; expired = auto-rejected + admin notification |
| AC-30b | Escalation ladder cron: at 24h gate add email; at 48h gate add reminder email (high-value: intensified subject); at 60h gate add SMS. Tracked in `escalation_state` column. Zalo deferred to v1.1 (D8) — no-op placeholder |
| AC-31 | Audit fields populated on every approval create + decision + escalation step |
| AC-31b | Validation at delegation invite time (phase-03) — no defaults; here we just trust the columns are populated |
| AC-32b | Cash payment evidence: dedicated approval `action_type='cash_payment'` (auto-approve if amount < threshold AND location+photo provided; otherwise normal approval flow) — for ≥ 2M VND, sends SMS to tenant for counter-confirm (phase-08 hook); graceful degrade if location/photo fail |
| AC-43 (lockdown) | Approval creation guarded by phase-02 decorator (`_is_lockdown_blocked`); allowed-with-approval-during-lockdown actions (fraud-termination, fraud-refund, data-correction) explicitly whitelisted in the decorator |
| AC-43b | Fraud-termination approval gets `sla_class='fraud_termination_24h'` + `lockdown_fraud_termination=True`. Cron uses sla_class to compute `expires_at`. Escalation ladder uses tighter gates (4h push+email / 12h SMS / 20h admin) |
| AC-55 | KB04 submission approval: `sla_class='kb04_fast_track_6h'`. If `delegation.role_preset='operator_full'` → DEFAULT AUTO-APPROVE (BA §13 D1) but approval row still created (status='approved', `decided_by=system_auto'`) for full audit. Other presets need owner approval. |
| AC-55b | KB04 pre-file: `POST /api/kb04/pre-file` — operator submits CT01 form data BEFORE move-in. Creates approval `action_type='kb04_pre_file'` + sets `contracts.kb04_pre_filed=True, kb04_form_data_json={...}`. Owner approval is post-facto (6h from submission). If owner rejects within 6h, system marks `kb04_form_data_json.withdrawn_at = now` and notifies operator to withdraw with police within 24h |
| AC-55c | District flag check: if `buildings.district_pre_file_accepted IS FALSE` → API rejects pre-file with 400 + offers approve-then-file workflow path. If `NULL` (unknown) → allow but log warning |
| AC-55d | POA format honored at approval time: when approval action `kb04_*` is approved, system reads `delegation.poa_format`; if `digital` → fetch FastCA/VinaCA signature reference; if `notarized` → check `poa_document_path` exists. Failed POA check → approval stuck `pending` with admin alert |
| AC-58d | Default in-flight handling at owner death: cron marks pending approvals `auto_rejected` reason `owner_deceased`. EXCEPT executor-exception (phase-06 sets `decided_by_executor_id`, gated on O3 legal sign-off). Until O3 confirmed, default-auto-reject is absolute. |

### NFRs

- **NFR-06 push p95 < 30s** — service queues event synchronously; phase-08 delivery is async but FCM target SLA matches (push is fire-and-forget at vendor layer).
- **NFR-14 email read-receipt early SMS** — phase-08 implements the read-receipt webhook; this phase reads the `read_receipt_opened_at` column and, if NULL at 24h gate on high-value, escalates SMS at 24h instead of 60h.

### Out-of-scope check

- **AC-56 dual-approval co-actor** — BA §7 "out-of-scope" indicates multi-tier delegation not in v1. AC-56 is the *self-owner-self-operator* user identity case (single user, multiple roles), not dual-approval. CONFIRMED out-of-scope from BA §6.11 reading — the original AC-56 text speaks to user identity (1 user is both host and active operator for someone else). No conflict with AC-58d (executor exception = different mechanism: the executor replaces owner, not approves alongside).

### User Stories satisfied
- US-O7 (notification only for threshold actions)
- US-O8 (1-tap approve from notification)
- US-P8 (operator daily ops free; only threshold = approval)
- US-P9 (operator sees ETA after submission)

## Architecture

### Approval creation flow

```
Operator calls mutation endpoint (e.g., POST /api/contracts)
    │
    ├─► Permission decorator (phase-02) — passes
    │
    ├─► Service layer (e.g., contract_service.create()):
    │      threshold_check = compute_threshold(actor_ctx.delegation, payload)
    │      IF threshold_check.requires_approval:
    │          # Don't commit entity yet; create approval first
    │          approval = approval_service.create(
    │              delegation=actor_ctx.delegation,
    │              action_type='contract_create',
    │              action_payload=payload.dict(),
    │              entity_type='contract', entity_id=None,
    │              requested_amount_vnd=payload.monthly_rent * payload.term_months,
    │              sla_class='default_72h'
    │          )
    │          # Persist pending entity with reference to approval
    │          contract = Contract(..., status='pending_owner_approval', pending_approval_id=approval.id)
    │          db.add(contract)
    │          # On approval decision (phase callback below), contract becomes 'draft' or 'rejected'
    │          return ContractResponse(status='pending_owner_approval', approval_id=approval.id)
    │      ELSE:
    │          # Direct commit
    │          contract = Contract(..., status='draft')
    │          db.add(contract)
    │          return ContractResponse(status='draft')
```

NEW columns for entities that can be approval-deferred (defer to phase-04 — schema migration sub-step):
- `contracts.pending_approval_id` UUID FK → `delegation_approvals.id` nullable
- `invoices.pending_approval_id` UUID FK nullable
- `payments.pending_approval_id` UUID FK nullable (for refund flow)

Add to `contracts.status` enum value: `'pending_owner_approval'` (in addition to existing draft/active/expired/terminated).

These are small schema deltas — pack into a NEW migration `0036_add_pending_approval_id_to_entities` shipped with phase-04 (not phase-01) because they're approval-layer concerns.

### Approval decision flow

```
Owner taps "Approve" or "Reject" → POST /api/approvals/{id}/decide
    │
    ├─► Permission: must be owner_id of approval
    │
    ├─► AC-29b biometric gate: if requires_biometric AND no valid biometric_token → 401 BIOMETRIC_REQUIRED
    │
    ├─► Transaction:
    │      approval.status = decision  # 'approved' or 'rejected'
    │      approval.decided_at = now
    │      approval.decided_by_user_id = actor.user_id
    │      approval.decision_reason = body.reason
    │      
    │      IF approved:
    │          dispatch to action_handler[action_type](approval) — see handler table
    │      ELSE (rejected):
    │          mark associated entity (if any) status='rejected'
    │          notify operator
    │
    │      write_change_log(... actor_ctx=owner_ctx ...)
    │      commit
```

### Action handler table (one per `action_type`)

| `action_type` | On approve | On reject |
|---------------|------------|-----------|
| `contract_create` | Move pending contract to `status='draft'` (or `'active'` if start_date ≤ today) | Delete pending contract or mark `'rejected'`; notify operator |
| `contract_terminate` | Run normal termination service on referenced contract | No-op; notify operator |
| `invoice_high_amount` | Commit invoice draft to `status='sent'` | Delete invoice draft; notify |
| `expense_high_amount` | Commit expense record | Discard |
| `rent_change` | Apply contract update with new monthly_rent | Discard pending update |
| `refund_high_amount` | Issue refund (existing service) | Discard |
| `kb04_fast_track` | Update `KhaiBaoTamTru` `declared_at` (treats approval = owner-confirmed CT01 ready); operator can now download/print public_token to submit at police | Notify operator that approval rejected |
| `kb04_pre_file` | Mark contract `kb04_pre_filed=True, kb04_form_data_json.owner_approval_state='approved'` | Mark `withdrawn_at`; instruct operator to withdraw from police within 24h |
| `cash_payment` | Commit Payment record | Discard payment claim; operator must collect again |
| `fraud_termination` | Terminate delegation immediately (override 30d notice) | No-op; delegation stays in `terminating` |
| `threshold_change` | Update `delegations.threshold_*` columns | No-op |

### SLA computation

| `sla_class` | Expiry from `created_at` | Escalation gates |
|-------------|--------------------------|------------------|
| `default_72h` | +72h | 24h email / 48h reminder email / 60h SMS / 72h auto-reject + admin |
| `kb04_fast_track_6h` | +6h | 2h push + email / 4h SMS / 6h auto-reject + admin alert |
| `fraud_termination_24h` | +24h | 4h push + email / 12h SMS / 20h admin / 24h auto-reject |

NFR-14 high-value early SMS rule applied on default_72h + when `requested_amount_vnd ≥ 20_000_000` (per AC-30b): if `read_receipt_opened_at IS NULL` at 24h, fire SMS instead of waiting for 60h.

### Background scheduler jobs

| Job ID | Cron | Action |
|--------|------|--------|
| `approval_escalation_runner` | every 15 min | Read all `pending` approvals; for each, compute current escalation gate from `created_at + sla_class` and current `escalation_state`; if next gate crossed, emit notification event (push/email/sms) + update `escalation_state` + `last_notified_at` |
| `approval_expirer` | every 15 min | `pending AND expires_at < now()` → `status='auto_rejected', decision_reason='sla_expired'`; emit admin alert event; emit operator notification |
| `approval_in_flight_canceller` | event-driven (called by phase-03 service) | When delegation transitions to `terminated` (immediate) or `revoked`: bulk-cancel `pending` approvals with `delegation_id` match → `status='cancelled', decision_reason='delegation_terminated'` |
| `approval_owner_death_canceller` | event-driven (called by phase-06) | When owner death verified: bulk auto-reject `pending` approvals where `delegation.owner_id = deceased_owner_id` UNLESS executor exception activated (AC-58d, O3 gated) |

### Endpoint surface

| Method | Path | Permission | Description |
|--------|------|------------|-------------|
| `GET` | `/api/approvals?role=owner&status=pending` | owner self | Owner inbox |
| `GET` | `/api/approvals?role=operator&status=pending` | operator self | Operator outbound queue (their submitted approvals) |
| `GET` | `/api/approvals/{id}` | participant | Detail + action_payload |
| `POST` | `/api/approvals/{id}/decide` | owner self (or executor in phase-06) | Body: `{decision, reason?, biometric_token?}` |
| `POST` | `/api/approvals/{id}/cancel` | requester operator self | Operator can cancel before owner decides |
| `POST` | `/api/kb04/pre-file` | operator (requires `khaibao.submit` permission) | Pre-file CT01 — body includes full form data + contract_id |
| `POST` | `/api/kb04/{khai_bao_id}/submit-fast-track` | operator (requires `khaibao.submit`) | Operator-initiated KB04 (existing or new tenant); creates `kb04_fast_track` approval |

### KB04 specifics

**Pre-file workflow (AC-55b):**

```
T-N (lease signing day):
    Operator: POST /api/kb04/pre-file with contract_id + CT01 form data
        → validates contracts.building.district_pre_file_accepted
        → creates KhaiBaoTamTru row (if missing) with check_in_at = expected_move_in_datetime
        → stores form_data in contracts.kb04_form_data_json + sets kb04_pre_filed=True
        → creates approval (sla_class=kb04_fast_track_6h, action_type=kb04_pre_file)
        → notifies owner (push+in-app+email)

T-N + up to 6h:
    Owner approves OR
    System auto-rejects + admin alert OR
    Owner rejects → instruct operator withdraw from police within 24h (manual; admin tracks)

T0 (tenant moves in):
    Tenant marked moved-in; KhaiBaoTamTru.declared_at = T0 (or earlier if pre-filed approved)

T0 + 12h:
    KhaiBaoTamTru.status = overdue if declared_at IS NULL (existing logic)
```

**Fast-track workflow (AC-55):**
- For `operator_full` preset: approval created with `decided_by_system_auto=True` (default auto-approve per BA §13 D1); audit row still written for evidence.
- For other presets: full 6h approval flow.

**District flag (AC-55c):**
- `buildings.district_pre_file_accepted` (phase-01) drives pre-file pathway availability.
- Admin can update via `PATCH /admin/buildings/{id}/district-pre-file-flag` (phase-10).

**POA format (AC-55d):**
- At delegation creation (phase-03), `delegation.poa_format` is `digital` or `notarized`.
- Approval handler `kb04_*` reads this; if `digital`: backend calls FastCA/VinaCA via `app/integrations/digital_signature.py` (NEW thin client, defined here, vendor mock for v1.0).
- If vendor unavailable (AS-14 contract delayed): fallback to `notarized` requires `poa_document_path` not NULL.

### Notification event payloads (for phase-08)

This phase emits events; phase-08 implements delivery. Events:

```
event: approval_requested
payload: {approval_id, owner_user_id, operator_user_id, action_type, amount_vnd, sla_class, expires_at, requires_biometric}

event: approval_escalation_gate_crossed
payload: {approval_id, gate_label, channels_to_use[], message_template}

event: approval_decided
payload: {approval_id, decision, reason, decided_by_user_id, original_requester_user_id}

event: approval_auto_rejected
payload: {approval_id, reason, sla_class}

event: cash_payment_counter_confirm_request  (AC-32b ≥ 2M VND)
payload: {payment_id, tenant_user_id, amount_vnd, link}
```

## Related Code Files

### To create
- `alembic/versions/0036_add_pending_approval_id_to_entities.py` — `contracts.pending_approval_id`, `invoices.pending_approval_id`, `payments.pending_approval_id`; add `'pending_owner_approval'` to `contracts.status` whitelist (string enum, no DB type change)
- `app/services/approval_service.py` — create/decide/cancel + action_handler dispatch
- `app/services/approval_scheduler.py` — escalation + expirer + in-flight canceller jobs
- `app/services/kb04_operator_service.py` — pre-file + fast-track operator workflows
- `app/services/threshold_check_service.py` — `compute_threshold(delegation, payload, action_type)` returns `{requires_approval, reason}`
- `app/integrations/digital_signature.py` — FastCA/VinaCA thin client (mockable for tests + early-phase before AS-14 vendor contract)
- `app/repositories/approval_repository.py`
- `app/routers/approvals.py`
- `app/routers/kb04_operator.py`
- `app/schemas/approval.py` — Pydantic
- `app/exceptions/approval_exceptions.py` — `ApprovalExpired`, `BiometricRequired`, `ApprovalAlreadyDecided`
- `tests/services/test_approval_service.py`
- `tests/services/test_threshold_check.py`
- `tests/services/test_kb04_operator.py`
- `tests/scheduler/test_approval_jobs.py`
- `tests/routers/test_approvals_router.py`

### To modify
- `app/services/contract_service.py` (existing) — threshold gate on create/update/terminate
- `app/services/invoice_service.py` — threshold gate on create
- `app/services/khai_bao_service.py` (researcher-02 §E) — gate operator-initiated submissions through approval queue
- `app/services/planning_etl/scheduler.py` — register new jobs
- `app/main.py` — include new routers
- (phase-08 will modify notification dispatcher to consume events)

### To delete
- None.

## Implementation Steps

1. **Branch `feat/p04-approval-workflow`** off phase-03 merge.
2. **Migration 0036** (small additive): nullable `pending_approval_id` FK columns + status whitelist update.
3. **`threshold_check_service`**: pure-function checks per `action_type`. Unit tests cover all 6 action types × above/below threshold.
4. **`digital_signature` integration**: define interface + provide `MockSignatureProvider` for tests + `FastCASignatureProvider` stub (raises `VendorNotConfigured` if `FASTCA_API_KEY` not set — caller can fallback to notarized path).
5. **`approval_service`**:
   - `create(delegation, action_type, payload, ...) -> Approval` — sets `sla_class` from `action_type`, computes `expires_at`, emits `approval_requested` event.
   - `decide(approval, owner_ctx, decision, biometric_token=None) -> Approval` — validates biometric if required, runs action handler.
   - `cancel(approval, operator_ctx) -> Approval` — operator-initiated withdraw.
   - Action handlers as private methods.
6. **`kb04_operator_service`**:
   - `pre_file(actor_ctx, contract_id, form_data) -> KhaiBaoTamTru + Approval`
   - `submit_fast_track(actor_ctx, khai_bao_id) -> Approval`
   - Both write to `contracts.kb04_form_data_json` + `kb04_pre_filed`.
7. **`approval_scheduler`**:
   - `approval_escalation_runner` job: iterates pending approvals, computes current gate from age + sla_class, emits events.
   - `approval_expirer` job: marks expired.
   - Register via `planning_etl/scheduler.py`.
8. **Modify `contract_service.py`, `invoice_service.py`**: insert threshold check at top of create/update/terminate methods. If approval required → return pending entity with `pending_approval_id`; if direct → existing path.
9. **Routers**: `app/routers/approvals.py` (5 endpoints), `app/routers/kb04_operator.py` (2 endpoints). Wire `require_actor_with_permission`.
10. **In-flight cancellation hook**: in phase-03 service `terminate_delegation()` and `pause_delegation()`, call `approval_service.cancel_in_flight_for_delegation(delegation_id, reason)`. Implement that method here.
11. **Tests:**
   - All action handlers (positive + reject).
   - SLA classes have correct `expires_at`.
   - Escalation cron correctly transitions states.
   - AC-29b biometric required for ≥ 50M.
   - AC-55b pre-file → owner reject → withdrawal flag.
   - AC-55c district flag rejection.
   - AC-55d POA digital + notarized branches.
   - AC-43b 24h SLA on fraud-termination + 4/12/20h gates.
   - AC-58d in-flight auto-reject default (executor exception NOT activated in v1.0 unit tests).
   - In-flight cancellation when delegation revoked.
12. **Document API surface** in `docs/system-architecture.md`.
13. **PR review + merge.**

## Todo List
- [ ] Branch `feat/p04-approval-workflow` from phase-03
- [ ] Write migration `0036_add_pending_approval_id_to_entities.py`
- [ ] Write `app/services/threshold_check_service.py` + unit tests
- [ ] Write `app/integrations/digital_signature.py` (interface + Mock + FastCA stub)
- [ ] Write `app/services/approval_service.py` (create/decide/cancel + action handlers)
- [ ] Write `app/services/kb04_operator_service.py` (pre-file + fast-track)
- [ ] Write `app/services/approval_scheduler.py` (escalation + expirer)
- [ ] Modify `app/services/contract_service.py` (threshold gates)
- [ ] Modify `app/services/invoice_service.py` (threshold gates)
- [ ] Modify `app/services/khai_bao_service.py` (operator submissions through approval)
- [ ] Modify `app/services/planning_etl/scheduler.py` (register new jobs)
- [ ] Write `app/routers/approvals.py`
- [ ] Write `app/routers/kb04_operator.py`
- [ ] Add Pydantic schemas in `app/schemas/approval.py`
- [ ] Unit tests: threshold_check, approval state machine
- [ ] Integration tests: AC-29b biometric, AC-55b pre-file, AC-55c district, AC-55d POA, AC-43b fraud-term 24h
- [ ] Integration test: in-flight cancellation
- [ ] Document in `docs/system-architecture.md`
- [ ] PR review + merge

## Success Criteria
- All 7 endpoint integration tests pass.
- All 8 action handlers tested (approve + reject paths).
- Cron `approval_escalation_runner` ticks through gates correctly (mock now()).
- AC-29b biometric required + rejected without valid token.
- AC-55b end-to-end: pre-file → owner reject → withdrawal flag set.
- AC-55c district=False → 400 with fallback hint.
- AC-55d digital path successfully calls signature provider mock; notarized path checks `poa_document_path` non-NULL.
- AC-43b 24h SLA with 4/12/20h gates fires correctly.
- AC-58d default auto-reject works; executor-exception path test left disabled (gated on O3 sign-off).
- In-flight cancellation tested via phase-03 service call.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Pending entity (contract draft `pending_owner_approval`) gets edited by operator before owner decides | Med | Med | Service guard: any UPDATE on pending entity by operator while `pending_owner_approval` → 409. Owner can cancel approval to free entity. |
| Approval `decide` and `approval_expirer` race | Low | Med | `SELECT ... FOR UPDATE` on approval row in `decide`; expirer also locks. |
| Owner decides `approve` but action handler fails (e.g., contract create blocked by invariant) | Med | High | Wrap handler in transaction; if handler raises → mark approval `decided_with_error`, leave entity unchanged, notify owner + admin. |
| FastCA vendor down → KB04 approvals stuck | Med | High | Vendor circuit breaker: 3 consecutive failures → mark vendor down for 5min, queue retries. Approvals where digital fails → admin alert + manual escalation. |
| Operator submits pre-file 5 min before move-in → no 6h owner buffer | Med | Med | UI warn + API soft-warn (allows but flags `audit.warning='late_pre_file'`). Owner sees urgency badge. |
| `requires_biometric` flag wrong if amount calculated incorrectly | Med | High | Test matrix every action_type × amount-tier × biometric expected; default-deny on missing amount. |
| Escalation cron storms (15 min tick × many pending) | Med | Med | Notification dispatcher (phase-08) coalesces per-owner (NFR-anti-spam). Track `last_notified_at` to skip if < 5min ago. |
| KB04 pre-file approved but tenant doesn't move in | Low | Low | After 30 days from pre-file with no move-in → cron flags for owner attention. |
| Auto-approve in `operator_full` preset for KB04 bypasses owner awareness | Low (BA decided) | Med | Owner still gets in-app notification + weekly digest entry (AC-41); audit log shows `decided_by='system_auto'`. |

## Security Considerations

- **Biometric token (AC-29b):** Flutter `local_auth` returns OS-attested boolean; we generate a server-side `biometric_token` JWT (60s TTL) on successful prompt, owner sends back on approve. Backend re-validates JWT. NEVER trust client claim alone.
- **Action payload tamper:** `delegation_approvals.action_payload_json` is the source of truth. Handler reads from there, NOT from current request body. Prevents "owner approves at lower amount, operator changes amount after".
- **Idempotency:** `decide` accepts `Idempotency-Key` header; same key returns cached response (prevents double-approve on retry).
- **AC-55d POA fallback:** if digital fails AND no notarized doc, approval stays pending — never auto-approves with missing legal cover.
- **AC-31 audit:** every transition writes ChangeLog with full delivery channel record per AC-31 requirement.
- **Cash payment counter-confirm (AC-32b):** SMS link to tenant uses signed token (15 min TTL); tenant click = counter-confirm. Phishing-resistant.

## Next Steps / Dependencies

- **Blocks:** Phase 07 (Flutter approval inbox), Phase 10 (admin dispute escalation queue).
- **Depends on phase-08 for actual notification delivery (events emitted here)** — phase-08 must ship before phase-04 escalation cron is enabled in production.
- **Parallel-safe with:** Phase 05 (KYC), Phase 06 (owner death — uses approval_service.cancel_in_flight, which this phase exposes).

## Open items flagged
- O3 (legal counsel on AC-58d executor exception) — must resolve BEFORE enabling executor approval path in production. Phase-04 ships with default-auto-reject only; executor-exception code present but feature-flagged OFF.
- Q1b (KB04 revocation during 12h pre-file window — legal) — phase-04 ships withdrawal-notification flow; legal answer determines whether police-API auto-withdraw is mandatory in v1.5.
- Q6.5 (KB04 notarized POA required by some districts) — phase-04 supports both digital + notarized; admin tooling for district-level escalation is phase-10.
