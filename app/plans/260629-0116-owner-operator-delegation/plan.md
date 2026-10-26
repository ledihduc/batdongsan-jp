---
title: "Owner-Operator Delegation (Model A, v1)"
description: "Owner ủy thác Operator vận hành BĐS với threshold approval, dual-identity audit, KB04 fast-track, request-scoped actor context. Schema-ready cho v2 scope nesting + commission."
status: pending
priority: P1
effort: 14-18 weeks (3 BE + 2 FE + 1 admin/QA, parallelized)
branch: main
tags: [delegation, multi-tenant, auth, rbac, audit, kyc, kb04, fastapi, flutter, postgres]
created: 2026-06-29
---

# Plan — Owner-Operator Delegation v1

**BA spec:** `phase-00-ba-requirements.md` (v4 — 66 ACs, 15 NFRs, 32+ user stories, §13 D1-D9+Q1 unified decisions)
**Research:** `research/researcher-01-backend-auth-kyc.md`, `research/researcher-02-backend-money-flows.md`, `research/researcher-03-flutter-app.md`
**Expert basis:** `reports/expert-consolidated-recommendations.md` (10 decisions matrix)

---

## Goal

Cho phép Owner ủy thác toàn bộ vận hành BĐS cho Operator (cá nhân hoặc 1 pháp nhân doanh nghiệp) — minh bạch, có audit dual-identity, có threshold approval, KHÔNG refactor `host_id` trên 20+ bảng nghiệp vụ.

## Scope summary

**In-scope (v1):** Delegation lifecycle (invite → accept → active → pause → revoke + 30d lockdown), 4 preset roles (`owner_view` / `operator_full` / `accountant` / `viewer`), per-delegation threshold-based approval workflow, KB04 fast-track 6h SLA + pre-file pathway, dual-disclosure tenant contract PDF, commission tracking (no auto-transfer), owner death/heir flow, GPKD revocation auto-pause, PDPL 4-tier retention, in-app + email + SMS escalation ladder, request-scoped actor context.

**Out-of-scope (v1, deferred to v2 Q4 2026 per BA §7 + D6/D7):** Multi-tier delegation (sub-operator), sub-property/room-level scope nesting (UI), PMC multi-user RBAC, auto-transfer commission (NHNN license), e-sign chữ ký số, co-ownership (refused via AC-64 self-attestation), Zalo ZNS channel (deferred to v1.1 per D8), custom permission matrix, audit hash chain, multi-currency.

## Architecture summary

- **Backend (FastAPI/SQLAlchemy):** 5 new tables (`delegations`, `delegation_invitations`, `delegation_approvals`, `operator_business_profiles`, `owner_death_certificates`) + extensions to `users` (operator capable flag), `host_profiles`, `buildings` (sole-ownership attestation, district pre-file flag), `change_logs` + `audit_logs` (dual-identity columns), `invoices` (`platform_fee_pct` forward-compat per NFR-15), `contracts` (`kb04_form_data` JSON, move-in datetime precision).
- **Actor context layer:** new FastAPI dependency `resolve_actor_context()` → `ActorContext(actor_user, on_behalf_of_user, delegation, scope, permission_set)`; replaces flat `require_host`. JWT stays user-identity only; delegation context per-request via `X-Acting-As` header.
- **Background scheduler (APScheduler — already wired):** new jobs for 72h approval expiry, 6h KB04 fast-track, 24h fraud-termination SLA, 30d termination lockdown, 7d owner-death pause, 4-tier PDPL retention transitions.
- **Notifications:** extend existing in-app + add SES email + add SMS vendor (eSMS/FPT.AI) wired into ladder; Zalo ZNS hooks placeholder for v1.1.
- **Flutter:** new `ActorContextProvider` (request-scoped, NOT persisted) + `OperatorPortfolioScreen`, `ApprovalInboxScreen`, `DelegationInviteScreen`, `DelegationDetailScreen`, `ActivityFeedScreen`. Reuses Editorial Cockpit `Ds*` widgets + `HD.*` design tokens. Persona-switcher pattern (`guest_shell.dart`) extended for "acting-as" overlay (warm orange tint).
- **Admin:** minimal backend admin endpoints + scripts for KYC review, death-cert verification, GPKD verification, POA upload review, dispute escalation. Full admin web UI deferred to v2.

## Phases

| # | Phase | Owner | Effort | Type | Status | Depends on |
|---|-------|-------|--------|------|--------|------------|
| 01 | [Data model & migrations](phase-01-data-model-and-migrations.md) | BE | 5d | backend | Pending | — |
| 02 | [Permission & actor context layer](phase-02-permission-and-actor-context.md) | BE | 5d | backend + FE plumbing | Pending | 01 |
| 03 | [Delegation lifecycle API](phase-03-delegation-lifecycle-api.md) | BE | 7d | backend | Pending | 01, 02 |
| 04 | [Approval workflow + KB04 carve-out](phase-04-approval-workflow.md) | BE | 7d | backend | Pending | 01, 02, 03 |
| 05 | [Onboarding & KYC extensions](phase-05-onboarding-and-kyc-extensions.md) | BE + FE | 6d | full-stack | Pending | 01, 02 |
| 06 | [Owner death, archive & retention](phase-06-owner-death-and-archive-retention.md) | BE | 5d | backend + admin | Pending | 01, 03 |
| 07 | [Frontend delegation UI](phase-07-frontend-delegation-ui.md) | FE | 10d | frontend | Pending | 02, 03 |
| 08 | [Notification, email & SMS](phase-08-notification-and-email-and-sms.md) | BE | 5d | backend + ops | Pending | 01 |
| 09 | [Pricing & commission tracking](phase-09-pricing-and-commission-tracking.md) | BE + FE | 5d | full-stack | Pending | 01, 03 |
| 10 | [Admin & runbooks](phase-10-admin-and-runbooks.md) | BE + admin | 4d | backend + ops | Pending | 03, 04, 05, 06 |
| 11 | [Testing & pre-launch validations](phase-11-testing-and-pre-launch-validations.md) | QA + BE + FE | 8d | cross-cutting | Pending | all impl |

**Estimated total dev effort:** ~67 dev-days = ~14 calendar weeks with 2 BE + 2 FE + 1 admin/QA running parallel where possible. Reduce to ~11 weeks if 3 BE devs available.

## Critical dependencies

```
01 ──┬─► 02 ─┬─► 03 ─┬─► 04 ─┬─► 06 ─┐
     │      │       │       │       │
     │      │       │       │       └─► 10
     │      │       └─► 05 ─────────────► 07 ─┐
     │      └─► 07 (actor wiring) ────────────│
     ├─► 08 (independent — wire into 04) ─────│
     ├─► 09 (independent — schema only) ──────│
     └────────────────────────────────────────┴─► 11 (testing)
```

**Parallelization:**
- After 01 ships: 02 + 08 + 09 can run in parallel (different files, no shared APIs).
- After 02 ships: 03 + 05 + 07-skeleton can run parallel.
- After 03 + 04 ship: 06 + 07 (full UI) + 10 can run parallel.
- 11 (testing) is rolling — unit + integration tests written WITHIN each phase; E2E + regression at end.

## Critical Tech Lead decisions (rationale documented in linked phase)

| # | Decision | Choice | Rationale | Phase |
|---|----------|--------|-----------|-------|
| TL-1 | NFR-13 scope-aware schema mechanism | `scope_type` enum + `scope_target_ids` JSON array column on `delegations` table (NOT separate Scope table, NOT polymorphic) | KISS — v1 only needs `all` or building-list (non-nested per D6). JSON array is forward-compat for v2 nesting (just add new enum values + validation). Separate Scope table = +1 join on every permission check (NFR-05 latency penalty). Polymorphic = over-abstraction for v1. Migration to scope-table v2 if needed = mechanical. | 01 |
| TL-2 | NFR-15 `platform_fee_pct` column placement | `invoices.platform_fee_pct` (denormalized snapshot at invoice generation, locked at `paid_at`) — same pattern as existing `commission_rate` / `commission_amount` | Mirrors existing immutability convention (researcher-02 §C). v1 default = 0; v2 inserts non-zero values without breaking. Avoids new Payout table for v1 (YAGNI). | 09 |
| TL-3 | Design system reuse | Reuse Editorial Cockpit `HD.*` tokens + `Ds*` widget barrel (`lib/core/widgets/ds.dart`). New "acting-as" overlay = `HD.warning` (warm orange) tint on existing `DsAppBar`. No new design system. | researcher-03 §F confirms full coverage. | 07 |
| TL-4 | Background scheduler | APScheduler (already wired in `app/services/planning_etl/scheduler.py`). No Celery for v1. | researcher-02 §G confirms single-instance v1 is OK; Redis lock needed only for multi-instance scale-out (v2+). | 03, 04, 06, 08 |
| TL-5 | Email vendor | **AWS SES** (primary candidate; alternative Sendgrid). Decide at phase-08 kickoff based on existing AWS account + cost (SES ~$0.10/1K emails). | Cheap, SPF/DKIM/DMARC easy, IAM-managed. Both candidates support read-receipt tracking for NFR-14. | 08 |
| TL-6 | SMS vendor | **eSMS.vn** (primary candidate; alternative FPT.AI). Decide at phase-08 kickoff based on contract terms + delivery rate. | Both VN local, ~600 VND/msg per BA §10.9, OTP-tier reliability. | 08 |
| TL-7 | Digital signature vendor (AC-55d, AS-14) | **FastCA** (primary) with VinaCA fallback. Vendor contract MUST be signed before phase-05 mid-point (acceptance flow uses signature); if not signed by then → ship phase-05 with notarized-PDF-only path + add digital flow as patch v1.0.1. | FastCA has lower per-signature cost (~50K VND) per AS-14 budget. Sales contact required = pre-launch validation gate. | 05 |
| TL-8 | Actor context propagation mechanism | **Per-request HTTP header `X-Acting-As-Delegation-Id`** (UUID). Backend `resolve_actor_context()` dependency reads it, looks up delegation, validates active status + scope + permission, populates `request.state.actor_ctx`. JWT remains user-identity only — NEVER caches delegation state (NFR-02, NFR-07). | researcher-01 §A confirms current JWT structure (`sub` + `role` only). Header (not JWT, not session) gives request-scoped semantics + cross-tab safety (AC-15b). Flutter side: `ActorContextProvider` injects header on every API call via `ApiClient` interceptor. | 02 |
| TL-9 | Phase ordering / parallelization | Phase 01 is strict blocker. After 01: phases 02, 08, 09 run parallel. Phase 03 blocks 04. Phase 11 (testing) runs rolling. See "Critical dependencies" graph above. | Maximize parallelism without ownership conflicts. | — |

## Pre-launch validation gates (BA v4 §9 — block ship if unresolved)

| Gate | Description | Blocks | Owner | Due |
|------|-------------|--------|-------|-----|
| **O1** | Police pre-file CT01 acceptance — confirm ≥1 phường in HCMC and ≥1 in Hà Nội accept CT01 submission BEFORE tenant move-in | AC-55b (KB04 pre-file pathway), phase-04 freeze | Legal + ops | Before phase-04 mid-point |
| **O2** | Police digital POA acceptance — confirm which districts accept FastCA/VinaCA digital signature for KB04 | AC-55d (POA format default), phase-05 freeze | Legal | Before phase-05 freeze |
| **O3** | Legal counsel sign-off on AC-58d executor exception (in-flight approvals by executor within 7-day pause) | AC-58d, phase-06 freeze | Legal counsel | Before phase-06 freeze |
| **O4** | NHNN intermediary license scope confirmation | v2 auto-commission (NOT v1 blocker) | Corporate counsel | Before v2 (Q4 2026) |
| **Q-DD5** | Sponsor acceptance of cumulative ~30-40% Segment C TAM defer (D4 + D6 + D7 combined) | Phase 3 kickoff (NOT phase-by-phase) | Product sponsor | BEFORE Phase 4 starts |
| **AS-14 contract** | FastCA OR VinaCA vendor contract signed | Phase-05 digital POA path | Procurement | Mid phase-05 |
| **Vendor contracts (SES + SMS)** | AWS SES production access + eSMS/FPT.AI account active | Phase-08 launch | Ops | Before phase-08 launch |

## KPI gates (BA v4 §11, §13 Q1)

- **v1 → v1.5 (Freemium):** ≥ **50 delegations** active + **NPS ≥ 55** + churn ≤ 10%/mo + ≥ 85% approvals approved (vs rejected).
- **v1.5 → v2 (commission):** 100+ delegations + churn ≤ 5%/mo. Requires NHNN clarification (O4).
- **v2 → v3 (SaaS subscription):** 150+ delegations + churn ≤ 10%/mo.
- **Hard-fail review trigger:** < 50 delegations in 6 months → evaluate whether D4/D6/D7 defers caused TAM gap (per Q-DD5).

## AC / NFR / US coverage matrix (assigned to phases)

**ACs (66 total — all assigned):** AC-01..AC-10b → 03; AC-11..AC-18 → 02+07; AC-19..AC-23 → 02; AC-24..AC-31b → 04; AC-32..AC-37 → 09; AC-38..AC-41 → 07+08; AC-42..AC-46 → 03+06; AC-47..AC-52 → 02+03 (regression); AC-53 → 02; AC-54 → 09; AC-55..AC-55d → 04; AC-56 → 02; AC-57..AC-58-OOO → 03; AC-58..AC-58d (heir) → 06; AC-59 → 06; AC-60..AC-63 → 07+10; AC-64..AC-66 → 05.

**NFRs (15 total — all assigned):** NFR-01..NFR-07 → 02+03 (atomicity + revocation propagation + scope check); NFR-08..NFR-12 → 07 (mobile-first + i18n); NFR-13 → 01 (scope-aware schema); NFR-14 → 08 (email deliverability); NFR-15 → 09 (platform_fee_pct).

**User Stories:** US-O1..O14 → 03+07; US-O15..O16 → 02; US-O17 → out-of-scope (v2); US-O18..O19 → 06+05; US-P1..P13 → 03+05+07; US-P14..P16 → 05; US-S1..S2 → 02 (regression); US-T1..T2 → 07+09; US-A1..A7 → 10.

**Orphans:** NONE. All 66 ACs, 15 NFRs, 32+ user stories assigned to a phase.

## Open items (NOT blockers for plan, but flagged)

- **Q1b** legal — KB04 revocation during 12h pre-file window (lawyer follow-up)
- **Q2a** legal (= O3) — owner death + in-flight approval scope (lawyer follow-up)
- **Q2.1/2.2/2.3** — operator pre-verification / curated list / dispute mediation (product decision)
- **Q3.2** — marketplace booking routing AC-51 user-confirm
- **Q5.1, Q5.3, Q5.4** — auto-transfer commission, cash-advance reimbursement, TNCN/VAT withholding model (tax counsel)
- **Q6.1, Q6.3, Q6.4, Q6.5** — delegation contract template + GPKD ngành dịch vụ + dual-disclosure tenant signing + KB04 notarized POA (legal counsel)
- **Q7.1, Q7.3** — pilot first / geographic launch order (product decision)
- **Q8.1** — operator fraud liability TOS position (insurance/legal)
- **Q-DD2** — red book OCR for high-value properties (v2 product decision)
- **Q-DD4** — email deliverability liability for absentee owners (risk acceptance)
- **Q-DD8** — admin team scaling threshold (ops budget)

## Docs impact (post-launch)

- `docs/system-architecture.md` — add delegation context section + request lifecycle diagram
- `docs/code-standards.md` — add `X-Acting-As-Delegation-Id` header contract, ChangeLog dual-identity convention
- `docs/development-roadmap.md` — mark Owner-Operator Delegation v1 milestone complete
- `docs/project-changelog.md` — populate at launch
