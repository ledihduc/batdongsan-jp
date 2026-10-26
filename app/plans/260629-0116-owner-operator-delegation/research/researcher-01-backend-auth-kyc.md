# Researcher 01 — Backend Auth/Users/KYC/Notifications/Audit

**Date:** 2026-06-29  
**Scope:** ancu365-backend FastAPI codebase analysis for delegation feature requirements (BA v4)  
**Baseline:** Migrations 0001–0020, models.py (884 lines), auth.py, routers (20+ endpoints)

---

## A. User/Role Model

### Current State
- **User model** (`app/models.py:49–65`): Single role field `role: str` (default="guest")
  - Supported roles: `guest`, `host`, `admin`
  - No enum; string-based (flexible for future, but risk of typos)
  - No "owner" vs "operator" distinction — system treats `host_id` in all tables as the single owner/operator
  - `is_active` flag exists for soft-delete compliance

- **Auth flow** (`app/auth.py:30–52`):
  - `sign_token(user_id, role)` → JWT with `sub` (user_id) + `role` claim
  - `require_user` → checks token exists
  - `require_admin` → checks role == "admin"
  - `require_host` → checks role in ("host", "admin")
  - No scope/context per request yet (no delegation context)

- **IDOR checks** (`app/auth.py:98–109`):
  - `_ensure_owner_or_admin(claims, owner_id)` — compares JWT `sub` vs record owner
  - Used in notifications, user resources; NOT enforced universally (property access still via `host_id` only)

- **Login/register** (`app/routers/auth_router.py:18–61`):
  - Register forces role → "guest" (whitelist enforcement)
  - Login → returns token + user dict
  - No operator-specific onboarding path yet

### Implications for Delegation (BA v4)
- **No operator user type yet** — BA v4 §US-P2 calls for operator_id registration path
- **Existing role column sufficient for v1** — can extend to "operator" role OR use `user_type` table later; BA v4 proposes 4 preset roles (owner-view / operator-full / accountant / viewer) suggest need for **role + scope intersection**, not just flat role
- **`host_id` in all tables = owner_id in v1** — constraint: renaming would break circuit; instead, create `OperatorDelegation(owner_id → host_id, operator_id → users.id, property_id, role_preset, ...)` bridge
- **Actor context NOT request-scoped** — JWT only has `sub` (user_id) + `role`; delegation context (acting-as-operator-for-owner-X) must be passed per-request (header or body), not stored in JWT to avoid stale state across tab switches (§BA v4 §2.5 persona-switcher design)

---

## B. KYC / Onboarding

### Current State
- **HostProfile model** (`app/models.py:179–205`):
  - 1:1 with User (user_id unique, FK cascade delete)
  - CCCD fields: `cccd_front_path`, `cccd_back_path`, `cccd_number_hash` (bcrypt)
  - Bank: `bank_account_number`, `bank_name`, `bank_account_holder`
  - Tax: `tax_id` (nullable)
  - `verified` boolean (default=False) — probably admin-set, no state machine
  - `payout_schedule` (default="monthly")
  - `monthly_revenue_goal` (nullable, Phase 04 analytics — not needed v1)

- **CCCDAccessLog** (`app/models.py:264–277`, migration 0004):
  - Tracks every CCCD file read/write; PDPL compliance
  - Columns: `user_id` (actor), `file_path`, `action` ('upload'|'read'|'delete'), `accessed_at`, `ip_address`
  - FK to users (ondelete=SET NULL — allows audit of deleted users)

- **No GPKD / eKYC vendor integration** — Grep confirms:
  - NO columns for business name, registration number, representative
  - NO enum for "person" vs "business" operator type
  - NO API integration with vendor (Veriff, Trueffect, AML service)
  - **Implication:** v1 operator KYC **NOT YET IMPLEMENTED** — operator-doanh-nghiệp path is greenfield

- **Onboarding flow** (referenced in BA v4 §2.4):
  - Flutter side: 3 steps (step1_info, step2_cccd, step3_bank)
  - Backend: POST endpoints to save HostProfile fields
  - No enum for "verification_status" — just `verified` boolean
  - No public API for admin dashboard to approve/reject KYC

### Implications for Delegation (BA v4)
- **Operator cá nhân** (AC-13, AC-14): reuse HostProfile + existing CCCD flow ✓
- **Operator doanh nghiệp** (AC-50b, AC-65, AC-66): **greenfield**
  - Need new schema (OperatorBusiness? — or column extension to HostProfile like `business_name`, `business_registration_number`, `business_type`, `business_representative_name`, `business_representative_cccd`, `business_representative_phone`)
  - Need verification state machine with admin approval SLA (D2 Expert Rec: 24h SLA for manual upload)
  - No eKYC vendor integrated yet — decide v1.1 or later
- **KB04 (residence registration)** — **NOT YET IMPLEMENTED**
  - KhaiBaoTamTru model exists (contract auto-create, tenant declaration via public link)
  - No operator-submitted CT01 form yet
  - No pre-file workflow (BA v4 D1 = 6h SLA + pre-file option)
  - **Must implement** for delegation feature (AC-55, AC-55b, AC-55c, AC-55d involve KB04)

---

## C. Notification Infrastructure

### Current State
- **Notification model** (`app/models.py:153–163`):
  - Simple per-user inbox: `user_id`, `type`, `title`, `body`, `related_id`, `read`, `created_at`
  - No channels (in-app only for v1)
  - No email/SMS/Zalo ZNS columns
  - No retry/failure tracking

- **Notification router** (`app/routers/notifications.py`):
  - GET list (per-user, JWT `sub` extracted)
  - PATCH mark-read (per-notif + IDOR check)
  - PATCH mark-all-read
  - No creation endpoint exposed — must be internal service call

- **Zalo integration exists** (`app/utils/zalo.py`):
  - `build_zalo_share_link(phone, message)` — generates `zalo.me/{phone}?body=...` deep-link
  - 3 message templates: invoice_reminder, contract_expiring, khai_bao_reminder
  - **Does NOT send ZNS** (Official Zalo Notification Service) — just builds shareable links for now

- **No email/SMS provider configured** — grep finds no SES/Sendgrid/Twilio references

- **Expert Recommendation D8** (Strategy §Q2):
  - v1: in-app + email only
  - v1.1 (Q4 2026): Zalo ZNS + SMS fallback

### Implications for Delegation (BA v4)
- **Notification escalation ladder** (AC-30b v1):
  - Owner threshold-triggered notifications → push + email
  - v1 schema ready for email channel (add `email_notification` table?)
  - v1.1 adds Zalo ZNS + SMS columns
  - **Decision needed:** Does Notification table need `channel` column (in-app, email, sms, zalo) in v1 schema, or defer to v1.1? Expert rec suggests email exists v1 but code shows in-app only → **clarify with planner**
  
- **Notification scoping:**
  - Delegation invitation → sent to operator (new user)
  - KB04 workflow update → sent to owner + operator
  - Owner approval/rejection → sent to operator
  - **Current model supports user_id recipient ✓**

- **No Zalo Business Solutions account yet** — Expert Rec O5: setup Sep 2026; check v1.1 readiness

---

## D. Audit Log

### Current State (Two separate audit mechanisms)

#### 1. ChangeLog (`app/models.py:244–262`, migration 0004)
- Per-entity mutation trail: `entity_type`, `entity_id`, `actor_id`, `action`, `before_json`, `after_json`, `created_at`
- **No delegation context** — no column for `on_behalf_of`, `delegation_id`, or `scope`
- Indexed: `(entity_type, entity_id, created_at)` — good for "what happened to contract X"
- **Not used in current code** — grep finds no writes to change_logs; probably created for future Phase 03+ (see model comment)

#### 2. AuditLog (`app/models.py:830–855`, migration 0019)
- Simpler, action-focused: `host_id`, `action` (e.g., 'export_tt200'), `period`, `success`, `ip`, `user_agent`, `extra` (JSON), `created_at`
- Currently tracks export operations only
- **No actor_id** — implies action is always by owner (host_id)
- Indexed: `(host_id, action, created_at)`

#### 3. CCCDAccessLog (`app/models.py:264–277`, migration 0004)
- Compliance trail: `user_id` (actor), `file_path`, `action`, `accessed_at`, `ip_address`
- Specific to CCCD file operations

### Implications for Delegation (BA v4)
- **ChangeLog needs extension for AC-32**:
  - Add `actor_id` (already exists ✓) — but ensure every write includes this
  - Add `on_behalf_of` column? (owner_id when operator acts for owner)
  - OR use `extra: JSON { "on_behalf_of": owner_id }` to avoid new migration
  - Expert rec D9: 4-tier retention (hot 90d / warm 2y / cold 5y / legal hold) — **not yet implemented**; cron job needed

- **AuditLog extension for delegation approval workflow (AC-34 to AC-40)**:
  - Add `actor_id` column (who performed the action)
  - Add `delegation_id` FK (which delegation triggered the action)
  - Example: action="delegation_approved", delegation_id=123, actor_id=5 (owner), created_at=...

- **Current state assessment:**
  - ChangeLog ready for operator writes (if code starts using it)
  - AuditLog assumes owner-only; needs refactor to support delegation context
  - No retention policy implemented → plan Phase 1 or later based on compliance urgency

---

## E. Permission/Authorization

### Current State
- **Role-based only (no scope/property-level)**:
  - `require_host` checks role in ("host", "admin")
  - `_ensure_owner_or_admin` checks JWT sub vs owner_id of resource (per-user resources only)
  - **No property-level access control** — host_id check implicit in queries (`WHERE host_id = claims["sub"]`)

- **Admin bypass**:
  - require_host treats admin as super-host (can access any host endpoint for support)
  - No admin-as-actor scoping (admin action logged, but not as "acting on behalf of host X")

### Implications for Delegation (BA v4)
- **Operator permission checks:**
  - Operator must have delegation record + valid role_preset (owner-view / operator-full / accountant / viewer)
  - Each endpoint needs: `@require_host_or_operator_on_behalf(operation_type, property_id)`
  - **Pattern not yet in codebase** — greenfield
  
- **Recommended decorator shape** (for planner):
  ```python
  def require_operator_on_behalf(
      required_permission: str,  # 'read_property' | 'write_contract' | 'approve_kb04' | etc.
      property_id_param: str = "property_id"  # Extract from path/query
  ) -> dict:
      """Verify actor is either owner OR has delegation with permission."""
      # JWT sub + claims["delegation_context"] (request header or body)
      # Lookup OperatorDelegation record
      # Check role_preset against required_permission
  ```

---

## F. KB04 / CT01 (Residence Registration) — Existing Code

### Current KB04 Implementation (KhaiBaoTamTru)
- **Model** (`app/models.py:613–669`, migration 0007):
  - `host_id`, `tenant_id`, `contract_id`, `reservation_id`, `check_in_at`
  - Status: pending | declared | overdue | skipped (computed in service, persisted for perf)
  - `declared_at` (when host marks "declared")
  - `public_token` (UUIDv4 string) → host prints/screenshots public link, submits at police portal
  - `public_token_expires_at` (default 30 days)

- **Service** (`app/services/khai_bao_service.py` — referenced in router, not read):
  - `compute_status_now(record)` — recomputes from check_in_at + 12h deadline
  - `mark_declared(db, record_id, host_id, declared_at)` — owner confirms submission
  - `mark_skipped(db, record_id, host_id, reason)`
  - `dashboard_counts(db, host_id)` — summary of pending/declared/overdue

- **Router** (`app/routers/host_khai_bao.py`):
  - GET list, detail, dashboard-summary
  - PATCH declared, skipped
  - NO operator-initiated submission yet
  - NO admin approval flow

### What's MISSING for BA v4
- **Pre-file workflow (AC-55, AC-55b)**:
  - Operator submits CT01 form (within 6h of tenant check-in)
  - No manual operator-to-police; system should support auto-filing (greenfield)
  - BA v4 D1: "6h SLA + pre-file option" — architecture change needed

- **Admin verification**:
  - No admin panel to approve/reject KB04 from tenant/operator report
  - AC-31 "owner escalates to admin" → missing endpoint

- **Tenant notification**:
  - Current template (zalo.py:62–67) sends public_link to tenant
  - No channel for tenant response (callback or webhook from police portal?)

### Implications
- **KB04 is ~60% implemented** for owner self-service
- **Operator workflow 0% implemented** — new routers + schema extension needed
- **Admin approval 0% implemented** — new router + approval state machine needed

---

## G. Database Migrations

### Current State
- **Migration history**: 0001 (planning) → 0020 (tt200_exports), 21 files total
- **Latest version**: 0020_create_tt200_exports (2026-06-28)
- **Down revision chain**: 0020 ← 0019 ← 0018 ← ... ← 0001
- **All migrations reversible** (upgrade/downgrade implemented)

### Key Existing Migrations (Schema precedents)
- **0004** (host_profile + audit): sets pattern for complex feature (multi-table, unique constraints, FKs, indexes)
- **0005** (nha_tro_core): building/room/tenant/contract — large migration (8.6K)
- **0007** (khai_bao_tam_tru): shows pattern for complex status enum + unique constraints
- **0012** (revenue_sources): shows pattern for scoped data (host_id + name unique constraint)

### Naming/Convention
- `NNNN_snake_case_description.py` (e.g., 0021_create_operator_delegations.py)
- Alembic auto-upgrade: `alembic upgrade head`
- SQLite dev: create_all() + schema drift check (main.py:80–122)

### Implications for Delegation
- **New migrations needed (Phase 01):**
  - 0021: operator_delegations table (main feature)
  - 0022: delegation_invitations table
  - 0023: delegation_approvals table (optional, or store in extra JSON)
  - Possibly 0024: operator_businesses table (if GPKD required for business ops v1)
  - Possibly 0025: operator_kb04_submissions table (if pre-file workflow included v1)

- **ChangeLog + AuditLog extension:**
  - Drop/recreate with new columns? Or ALTER existing tables?
  - Preferred: ALTER migrations (non-breaking)

---

## H. RBAC / Scope Checking

### Current Maturity
- **Role layer (coarse):** ✓ implemented
  - `require_host`, `require_admin`, `optional_user`
- **Owner check (IDOR prevention):** ✓ for per-user resources
  - `_ensure_owner_or_admin` on notifications, user resources
- **Property-level access control:** ✗ NOT implemented
  - No decorator for "user can only view properties they own"
  - Implicit via `WHERE host_id = claims["sub"]` in repo queries
  - **Risk:** if JWT sub is not verified in place, SQL injection or logic error could leak data

### Summary for Planner
- **v1 RBAC readiness: 30%**
  - Role-based routing exists
  - IDOR checks spot-applied
  - No permission matrix, no scope decorators
  - No delegation role_preset system (4 roles: owner-view / operator-full / accountant / viewer per BA v4)

---

## Implications for Delegation Feature (BA v4)

### Schema Readiness
| BA v4 Component | Existing Support | Status |
|---|---|---|
| Operator user type (US-P2, AC-01) | `role` field can extend to "operator" | Ready to extend |
| Delegation entity (AC-01..AC-22) | NOT in schema | NEW table required |
| Audit on_behalf_of (AC-32) | ChangeLog exists, needs `on_behalf_of` column | Partial; needs extension |
| KB04 workflow (AC-55, AC-55b, AC-55c, AC-55d) | KhaiBaoTamTru ~60% (owner), 0% (operator) | Partial; needs operator + admin routes |
| Approval workflow (AC-34..AC-40) | No approval state machine | NEW table + service |
| Permission escalation (AC-30b) | In-app notifications exist | Ready; add email v1.1 |
| PMC onboarding (AC-50b, AC-65, AC-66) | HostProfile only (no business fields) | Greenfield |
| PDPL audit retention (D9) | AuditLog table exists, no cron | Needs implementation |
| Scope-aware schema (NFR-13) | Flat (host_id only), no scope_id | Not ready; suggest defer behavior to v2 per D6, but schema v1-ready per expert |

### Major Gaps
1. **No operator delegation table** — PRIMARY blocker for AC-01..AC-22
2. **No operator user type registration** — secondary (extend `role` column)
3. **No KB04 operator workflow** — blocks AC-55+ (expert rec D1 calls for 6h SLA operator pre-file)
4. **No permission escalation beyond owner** — AC-30b owner approval ladder (implement request-scoped delegation context)
5. **No business operator support** — AC-50b (defer to v2 Org model per expert D7, or greenfield in v1 with caveat)

### Recommended Tech Lead Discussion Points
1. **Delegation context per-request (header vs body vs session)?**
   - BA v4 §2.5 mentions persona-switcher (Airbnb pattern) to avoid stale cross-tab state
   - Suggest `X-Delegation-Context: <operator_id>:<owner_id>` header OR body + request-scoped, NOT JWT claim

2. **Operator role field: enum or separate table?**
   - Current: `role IN ('guest', 'host', 'admin')`
   - v1: extend to 'operator', OR create `user_type` table (person/business)
   - Impact: all current queries `WHERE role = 'host'` need adjustment

3. **ChangeLog vs AuditLog: consolidate or extend separately?**
   - ChangeLog is per-entity (before/after JSON); AuditLog is per-action
   - Delegation feature may need both with `on_behalf_of` + `delegation_id`
   - Decision: migration strategy?

4. **KB04 pre-file workflow: synchronous or queue-based?**
   - Expert rec D1: 6h SLA for owner approval of operator's pre-file submission
   - Suggest async job (Celery/RabbitMQ) for police portal integration (v1.1)?
   - v1 scope: operator submits CT01 JSON, system stores in DB, owner reviews UI

5. **Business operator KYC: v1 or v2?**
   - Expert D7 recommends defer RBAC to v2 (shared login OK for small PMC)
   - But schema design impact: add `business_*` columns to HostProfile v1 (D6 recommendation)?
   - Or separate `OperatorBusiness` table (cleaner)?

---

## Known Risks / Gotchas

### Pre-existing Tech Debt
1. **User.role is string, not enum** — typo-prone; consider migration to Python enum later
2. **No migration for schema drift on SQLite** — `create_all()` only adds tables, doesn't ALTER (main.py comment)
3. **Admin bypass in require_host** — admin can access any host endpoint; audit trail unclear if action is "admin support" vs "admin fraud"

### Migration Concerns
1. **Existing queries assume host_id = owner** — adding operator + acting-as relationship requires audit of all routers (50+ endpoints?) to add delegation context check
2. **Cascade deletes on FK** — OperatorDelegation(owner_id → users.id) with CASCADE would delete all delegations if owner deleted; use SET NULL or custom trigger instead

### Performance
1. **ChangeLog before_json/after_json** — TEXT columns can bloat; index on (entity_type, entity_id) only; no full-text search
2. **No partitioning strategy for audit logs** — if 4-tier retention planned (D9), need archival strategy (cold storage table or separate DB)

### Compliance
1. **CCCD file paths stored as text** — no encryption at rest; PDPL Decree 13/2023 may require encryption (verify with legal)
2. **Audit log IP/UA in plain text** — PII if IP = user's home; PDPL minimal data principle applies

---

## Recommended Tech Lead Discussion Points

1. **Delegation context scoping:** Per-request header vs JWT claim vs session state?
2. **Role extension:** String "operator" vs separate `user_type` table for person/business split?
3. **ChangeLog adoption:** Start using for contract/invoice/host_profile mutations in Phase 02, or defer to Phase 05?
4. **KB04 workflow timing:** Owner approval SLA enforcement (advisory vs strict)? Pre-file queue mechanism?
5. **Business operator v1 scope:** Schema-ready (add columns) vs full v2 deferral?
6. **Audit retention automation:** Cron job for 4-tier archival (D9)? When to implement?
7. **Permission matrix:** 4 preset roles (owner-view / operator-full / accountant / viewer) as table or hardcoded?

---

## Summary Table: Codebase Readiness

| Area | Status | Notes |
|---|---|---|
| **A. User/Role Model** | 30% | role field extendable; JWT structure solid; no delegation context yet |
| **B. KYC / Onboarding** | 40% | CCCD done for individuals; business GPKD greenfield; KB04 ~60% (owner only) |
| **C. Notifications** | 20% | In-app model exists; email/SMS/Zalo ZNS not wired; no escalation workflow |
| **D. Audit Logs** | 50% | 2 separate mechanisms (ChangeLog + AuditLog); no on_behalf_of; no retention cron |
| **E. Permission/Authorization** | 30% | Role-based routing OK; IDOR checks partial; no scope-aware decorators |
| **F. KB04 / CT01** | 60% | Owner declaration flow done; operator pre-file greenfield; admin approval greenfield |
| **G. Migrations** | 90% | All reversible; naming convention set; schema drift checks in place; ready for new tables |
| **H. RBAC / Scope Checking** | 30% | Role layer exists; property-level access implicit; no permission matrix |

**Overall Backend Readiness for Delegation v1: ~40% (foundation exists, core feature greenfield)**

---

**Prepared by:** Researcher 1 (Claude Haiku, technical analysis)  
**Status:** DONE  
**Report:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-app/plans/260629-0116-owner-operator-delegation/research/researcher-01-backend-auth-kyc.md`
