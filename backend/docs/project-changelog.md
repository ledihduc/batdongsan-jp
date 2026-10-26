# Project Changelog — ancu365 Backend

All notable changes documented. Format: date (YYYY-MM-DD), version tag, scope, summary.

---

## [1.0.0] — 2026-06-30

### ✅ SHIPPED: Owner-Operator Delegation v1

**Scope:** Operators can now manage properties on behalf of owners with notarized POA + dual-identity audit.

**Features Added:**

- **Delegation Model**
  - Owner → operator authorization with preset permissions + commission
  - Immutable core fields (owner_id, operator_id)
  - Status lifecycle: active | paused | terminated | archived
  - 30-day lockdown post-termination blocks re-activation

- **ActorContext (Per-Request Identity)**
  - Resolves effective identity (owner vs. operator) on every request
  - Never cached in JWT (fresh per request)
  - Dual audit: `actor_id` + `on_behalf_of_user_id`

- **Invitation Workflow**
  - Owner invites operator via email/SMS
  - Operator completes KYC (identity verification)
  - Dual-disclosure POA PDF generated
  - Operator accepts → Delegation becomes active

- **Permission Sets (Presets)**
  - Operator scoped to delegation preset (cannot exceed)
  - Presets: full_ops, limited_approval, kb04_fast_track
  - Permission strings: invoice.create, booking.approve, approval.decide, etc.

- **Commission Immutability**
  - Commission rate + amount locked at invoice `paid_at`
  - Immutable thereafter (no retroactive edits)
  - CommissionSnapshot service locks values

- **Threshold Approvals**
  - Actions above delegation threshold require owner approval
  - 24-hour expiry window
  - Auto-rejection if not approved in time

- **Lockdown Enforcement**
  - 30-day window after termination
  - Blocks re-activation during lockdown
  - After lockdown expires, delegation archived

- **Owner Death + Heir Flow**
  - Heir submits death certificate + claim
  - Admin verification
  - Upon approval: pause ALL delegations, transfer ownership
  - Heir can resume or terminate delegations

- **KB04 Fast-Track Workflow**
  - District-flagged contracts skip standard approval queues
  - Fast-track to escalation
  - Reduces friction for high-priority deals

- **Fraud Auto-Suspension**
  - Admin can suspend operator across ALL active delegations atomically
  - Triggers reassessment of pending approvals
  - Prevents fraud recovery via re-delegation

- **Marketplace Sync (Host Immutability)**
  - Once house/booking linked to host, `host_id` immutable
  - Prevents re-assignment to operators
  - Enforced in marketplace_sync_service

**Files Added:**

- `app/domain/delegation.py` — Domain models
- `app/services/actor_context.py` — ActorContext resolution
- `app/services/permission_set.py` — Permission presets
- `app/services/commission/commission_snapshot.py` — Immutable commission lock
- `app/services/delegation/invitation_service.py` — Invite workflow
- `app/services/delegation/lifecycle_service.py` — Delegation state machine
- `app/services/delegation/lockdown_service.py` — Lockdown logic
- `app/services/approval/approval_service.py` — Threshold approvals
- `app/services/owner_death/death_cert_service.py` — Death cert verification
- `app/services/owner_death/heir_flow_service.py` — Heir transition
- `app/services/kb04_workflow_service.py` — KB04 fast-track
- `app/services/contract_pdf_service.py` — POA PDF generation
- `app/services/marketplace_sync_service.py` — Host immutability
- `app/services/admin/admin_delegation_actions.py` — Admin fraud handling
- `app/api/routes/delegation.py` — Delegation endpoints
- `app/api/routes/approval.py` — Approval endpoints
- `app/api/routes/owner_death_*.py` — Owner death endpoints
- `app/api/routes/admin_delegations.py` — Admin endpoints
- `app/schemas/delegation.py` — Request/response schemas
- `app/api/dependencies/actor.py` — ActorContext injection

**Migrations 0021–0036:**
- 0021: delegations + delegation_invitations
- 0022: delegation_approvals
- 0023: operator_business_profiles
- 0024: owner_death_certificates
- 0025: tenant_authority_flags
- 0026: bank_account_reveal_logs
- 0027: extend users (is_operator_capable, sole_ownership_attested_at, business_operator_profile_id)
- 0028: extend host_profiles (KYC expiry)
- 0029: extend buildings (district pre-file)
- 0030: extend contracts (KB04 form data)
- 0031: contract_tenants joined datetime
- 0032: extend change_logs (on_behalf_of_user_id, acted_via_delegation_id, retention_tier, scope_snapshot_json)
- 0033: extend audit_logs (dual-identity)
- 0034: extend invoices (platform_fee_pct, platform_fee_amount, commission_rate, commission_amount)
- 0035: extend notifications (channels)
- 0036: CHECK constraint enforcing commission_pct fraction convention (0 < x ≤ 1) — with pre-flight data validation

**Test suite (full repo):** 1218 passed, 0 failed, 114 skipped. Areas covered:
- Delegation invite → accept → activate → terminate → lockdown → archive
- Commission lock at paid_at + AC-37 partial-payment proportional commission
- Threshold approval auto-rejection (24h timeout)
- Owner death claim + heir transition
- KB04 fast-track + escalation
- Operator permission scoping + scope guards
- Fraud auto-suspension across delegations
- Marketplace host_id immutability (AC-51)
- Contract dual-disclosure PDF (AC-54)
- JWT not cached after delegation pause (NFR-02, NFR-07)
- IDOR guards across delegations

**Breaking Changes:** None (backward-compatible feature addition)

**Dependencies Added:**
- weasyprint>=60.0 (POA PDF generation with Vietnamese UTF-8 support)

---

## [0.9.0] — 2026-06-22

### Planning Lookup Module

**Features:**
- 9 REST endpoints for HCMC land-use planning data
- PostGIS spatial queries (ST_Contains)
- Nightly ETL from TNMT WFS
- Martin tile server integration
- Rate limiting by user_id / IP

**Files Added:**
- `app/services/planning_etl.py`
- `app/api/routes/planning.py`

---

## [0.8.0] — 2026-05-15

### Core House Booking Platform

**Features:**
- User authentication (JWT HS256 + bcrypt)
- House CRUD + filtering
- Booking lifecycle
- Reviews + ratings
- Wishlists
- Notifications
- Chat (REST + WebSocket)
- Image upload

**Files:**
- `app/models.py` (8 core models)
- `app/routers/` (auth, users, houses, bookings, reviews, wishlists, notifications, chat, upload)
- `app/auth.py` (JWT + password hashing)
- `app/chat_hub.py` (WebSocket manager)

---
