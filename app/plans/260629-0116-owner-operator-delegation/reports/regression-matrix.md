# Regression Matrix — Owner-Operator Delegation v1

**Plan:** `plans/260629-0116-owner-operator-delegation/`
**Date:** 2026-06-29
**Purpose:** Cross-phase compatibility — which phases interact, what tests cover the interactions

---

## How to Read This Matrix

- Rows = Phase that may be affected by another phase
- Columns = Phase that introduces a change
- Cell = Risk level + test coverage

**Risk levels:**
- `LOW` — No shared state; accidental coupling unlikely
- `MED` — Shared schema/service; interaction possible
- `HIGH` — Direct dependency; regression likely without explicit test

---

## Phase-to-Phase Interaction Matrix

|  | **P01 Data Model** | **P02 Actor Context** | **P03 Delegation API** | **P04 Approval** | **P05 KYC** | **P06 Death/Archive** | **P07 Flutter UI** | **P08 Notifications** | **P09 Commission** | **P10 Admin** |
|--|--------------------|-----------------------|------------------------|------------------|-------------|----------------------|--------------------|----------------------|-------------------|---------------|
| **P01 Data Model** | — | LOW: schema consumed | HIGH: schema owner | HIGH: schema owner | MED: user tables | HIGH: schema owner | LOW | LOW | HIGH: invoices | LOW |
| **P02 Actor Context** | LOW | — | HIGH: every route uses actor_ctx | HIGH: approval decides use actor_ctx | MED: KYC onboarding bypasses operator | HIGH: death uses actor_ctx for pause | HIGH: Flutter injects header | MED: notifications carry actor identity | MED: commission reads actor_ctx | MED: admin bypasses actor_ctx |
| **P03 Delegation API** | LOW | HIGH: route depends on actor layer | — | HIGH: approval created against delegation | MED: accept invitation triggers KYC check | HIGH: death pauses delegations | HIGH: UI displays delegation state | MED: notifications sent on lifecycle events | MED: commission computed when delegation active | MED: admin views/modifies delegations |
| **P04 Approval** | LOW | HIGH: decision uses actor_ctx IDOR guard | HIGH: approvals FK to delegations | — | LOW | HIGH: death bulk-cancels approvals (AC-58d) | HIGH: UI displays approval inbox | HIGH: notifications trigger on approval events | LOW | MED: admin can override approvals |
| **P05 KYC** | MED: operator_business_profiles table | MED: KYC status read in actor resolution | HIGH: delegation.accept checks KYC status | LOW | — | LOW | HIGH: KYC flow is Flutter screens | MED: email/SMS used in KYC verification | LOW | HIGH: admin reviews KYC |
| **P06 Death/Archive** | HIGH: owner_death_certificates table | HIGH: death pause uses lifecycle_svc | HIGH: pause modifies delegation.status | HIGH: death cancels in-flight approvals | LOW | — | MED: Flutter shows death state to admin | MED: notifications for death events | LOW | HIGH: admin verifies death cert |
| **P07 Flutter UI** | LOW | HIGH: X-Acting-As header injected here | HIGH: delegation screens call delegation API | HIGH: approval inbox calls approval API | HIGH: KYC screens | MED: heir flow screens | — | MED: FCM push received by Flutter | MED: commission report screen | LOW |
| **P08 Notifications** | LOW | MED: actor identity logged in notification | HIGH: delegation events trigger notifications | HIGH: approval events trigger notifications | MED: KYC events trigger notifications | HIGH: death events trigger notifications | HIGH: FCM push received by Flutter | — | LOW | LOW |
| **P09 Commission** | HIGH: invoices.platform_fee_pct column | MED: commission reads effective_owner_id | HIGH: commission snapshot uses active delegation | LOW | LOW | LOW | HIGH: Flutter displays commission report | LOW | — | LOW |
| **P10 Admin** | LOW | HIGH: admin bypasses actor_ctx (admin role) | HIGH: admin can modify delegation status | HIGH: admin can override/view approvals | HIGH: admin reviews KYC | HIGH: admin verifies death cert | LOW | LOW | LOW | — |

---

## High-Risk Interaction Details

### P02 ↔ P03 (Actor Context ↔ Delegation API)
**Risk:** HIGH — every delegation route depends on `resolve_actor_context()` dependency.

**Test coverage:**
- `tests/api/test_delegation_routes.py` — all endpoints exercise actor context
- `tests/services/test_actor_context.py` — unit tests for context building
- `tests/e2e/test_actor_context_isolation.py` — NFR-07 cross-tab isolation
- `tests/security/test_idor_matrix.py` (phase-11 add) — cross-owner IDOR

**Known interaction risk:** If `resolve_actor_context()` returns wrong `effective_owner_id`, ALL delegation endpoints serve wrong owner's data. This is the most critical surface.

---

### P03 ↔ P04 (Delegation Lifecycle ↔ Approval)
**Risk:** HIGH — approvals are created against delegations; delegation termination must cancel in-flight approvals.

**Test coverage:**
- `tests/services/approval/test_approval_service.py` — bulk cancel on terminate
- `tests/e2e/test_owner_operator_full_lifecycle.py` — approve → terminate → cancel sequence
- `tests/e2e/test_fraud_termination_flow.py` — fraud approve → immediate terminate

**Known interaction risk:** Race condition: operator submits approval at same millisecond as owner terminates delegation. Mitigation: `SELECT ... FOR UPDATE` in both services (NFR-01).

---

### P04 ↔ P06 (Approval ↔ Owner Death)
**Risk:** HIGH — death event must bulk-cancel all pending approvals (AC-58d).

**Test coverage:**
- `tests/services/owner_death/test_death_certificate.py` — death verify calls cancel_for_owner_death
- `tests/e2e/test_owner_death_heir_flow.py` — in-flight approval blocked after death

**Known interaction risk:** If `cancel_for_owner_death()` fails silently, in-flight approvals may be decided after owner is legally dead. This is the executor exception problem (O3).

---

### P02 ↔ P09 (Actor Context ↔ Commission)
**Risk:** MED — commission snapshot uses `effective_owner_id` to locate delegation.

**Test coverage:**
- `tests/services/commission/test_commission_snapshot.py` — commission with/without delegation
- `tests/regression/test_invoice_flow_with_commission_v1_freemium.py` — platform_fee_pct=0 regression

**Known interaction risk:** If `effective_owner_id` returns wrong owner, commission snapshot could link to wrong delegation (incorrect commission rate applied to invoice).

---

### P01 ↔ P06 (Data Model ↔ Death/Archive)
**Risk:** HIGH — `OwnerDeathCertificate` table introduces a new deletion/archive constraint that may conflict with FK cascade on `delegations`.

**Test coverage:**
- `tests/migrations/test_delegation_migrations.py` — migration reversibility
- `tests/e2e/test_owner_death_heir_flow.py` — delegation archived after death

**Known interaction risk:** If `owner_death_certificates.owner_user_id` FK has wrong cascade rule, deleting a user (e.g., PDPL erasure) may fail if death cert exists.

---

### P08 ↔ P04 (Notifications ↔ Approval)
**Risk:** HIGH — notifications triggered by approval events; if notification fails, approval still succeeds (fire-and-forget), but owner may not know to approve.

**Test coverage:**
- `tests/api/test_delegation_routes.py` — notifications mocked (not real delivery)
- Pre-launch gate: Vendor: SES + SMS must be CLOSED before ship

**Known interaction risk:** Email/SMS provider outage during approval creates silent failure. Mitigation: in-app push is primary; email/SMS are secondary channels.

---

## Phase-by-Phase Known Risks

| Phase | Self-Risk | Interaction Risk with Other Phase |
|-------|-----------|-----------------------------------|
| P01 | Migration rollback affects all phases | P06: FK cascade design; P09: invoices extension |
| P02 | Actor context wrong owner → IDOR | P03, P04, P09 (all consume actor_ctx) |
| P03 | Race condition on terminate + new invite | P04 (cancel in-flight), P06 (death pause) |
| P04 | Approval expired silently | P06 (death cancel), P08 (notification not delivered) |
| P05 | Operator KYC bypass | P02 (is_kyc_complete check in accept_invitation) |
| P06 | Executor exception flag OFF but code path enabled | P04 (in-flight approval), O3 gate |
| P07 | X-Acting-As header not injected consistently | P02 (all requests), P03, P04 |
| P08 | Vendor outage (SES/SMS) silent | P04 (approval notification), P03 (invitation email) |
| P09 | Incorrect commission rate at invoice creation | P01 (schema), P02 (effective_owner_id) |
| P10 | Admin bypasses actor_ctx IDOR guard | P02, P03, P04 (admin endpoints must not expose wrong owner data) |

---

## Test Coverage Gaps (flagged for Phase 11)

| Gap | Risk | Tests Added in Phase 11 |
|-----|------|------------------------|
| Full lifecycle E2E (all phases together) | HIGH | `tests/e2e/test_owner_operator_full_lifecycle.py` |
| KB04 6h SLA + escalation | MED | `tests/e2e/test_kb04_fast_track_flow.py` |
| Death → in-flight cancel + archive | HIGH | `tests/e2e/test_owner_death_heir_flow.py` |
| Fraud 24h SLA + auto-suspend | HIGH | `tests/e2e/test_fraud_termination_flow.py` |
| Cross-tab context isolation (NFR-07) | HIGH | `tests/e2e/test_actor_context_isolation.py` |
| IDOR across delegations | HIGH | `tests/security/test_idor_across_delegations.py` |
| Commission v1 freemium regression | MED | `tests/regression/test_invoice_flow_with_commission_v1_freemium.py` |
| ChangeLog dual-identity backward compat | MED | `tests/regression/test_changelog_dual_identity_does_not_break_existing_readers.py` |
| Actor context latency NFR-05 | MED | `tests/performance/test_actor_context_latency.py` |
| Approval concurrent throughput | MED | `tests/performance/test_approval_throughput.py` |
