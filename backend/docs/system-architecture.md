# System Architecture — ancu365 Backend

> Last updated: 2026-06-30  
> Version: 1.0 + Owner-Operator Delegation v1

## Overview

ancu365 backend is a FastAPI + SQLAlchemy + PostgreSQL system providing REST + WebSocket APIs for a real estate platform with planning lookup, house booking, reviews, and owner-operator delegation.

**Core layers:**
- API (FastAPI routes, auth, dependency injection)
- Services (business logic, domain workflows)
- Domain models (Pydantic schemas + SQLAlchemy ORM)
- Database (PostgreSQL + PostGIS)

---

## 1. Core Subsystems

### 1.1 Authentication & Authorization

**Location:** `app/auth.py`, `app/api/dependencies/actor.py`

**Flow:**
1. Login POST `/api/auth/login` returns JWT (HS256, expiry: 7 days)
2. Every request: Bearer token → decode JWT → `current_user` dependency
3. Role-based access (admin, host, guest)
4. Permissions enforced per-route via `require_user()`, `require_admin()`

**Key classes:**
- `TokenPayload` — JWT claims (user_id, role, exp)
- `CurrentUser` — per-request actor context

---

### 1.2 Actor Context (Dual-Identity Model)

**Location:** `app/services/actor_context.py`, `app/api/dependencies/actor.py`

**Purpose:** Resolve effective identity (owner vs. operator) on every request.

**Key concepts:**
- **Owner (host):** Primary account, can own properties + delegate rights
- **Operator:** Secondary account with limited rights, acts under a Delegation
- **ActorContext:** Per-request resolution, never cached in JWT

**Resolution logic:**
1. Decode JWT → extract `user_id` + optional `delegation_id`
2. If operator request + delegation active → build operator context (scoped permissions)
3. If owner request → build owner context (full rights for own properties)
4. Log both `actor_id` (effective user) + `on_behalf_of_user_id` (owner, if delegated)

**Key classes:**
- `ActorContext` — immutable per-request identity
- `build_owner_context()` — owner permissions
- `build_operator_context()` — scoped to delegation + preset permissions

---

### 1.3 Owner-Operator Delegation

**Location:** `app/domain/delegation.py`, `app/services/delegation/`, `app/api/routes/delegation.py`

**Overview:** A host (owner) delegates operational rights to another user (operator) via a notarized POA, with configurable scope, commission, and lockdown.

**Key entities:**

| Entity | Purpose |
|--------|---------|
| `Delegation` | Active grant: owner → operator, immutable core fields (owner_id, operator_id), with status (active, paused, terminated) |
| `DelegationInvitation` | Invite: owner → operator, expires_at, leads to KYC flow + POA generation + Delegation creation |
| `DelegationApproval` | Threshold approvals: operator requests action (e.g., invoice > threshold), requires owner approval with expires_at |
| `OwnerDeathCertificate` | Proof of owner death: heir claims ownership, pauses all delegations |
| `DelegationLockdown` | Post-termination lockdown: 30-day window blocks re-activation |

**Lifecycle:**

1. **Invite:** Owner invites operator → `DelegationInvitation` created
2. **KYC:** Operator completes KYC (identity verification)
3. **POA:** Dual-disclosure PDF generated (owner + operator copies)
4. **Activation:** Operator accepts → `Delegation` becomes active
5. **Active phase:** Operator acts within preset permissions + commission caps
6. **Termination:** Owner or operator initiates → status = terminated + lockdown starts
7. **Lockdown:** 30-day window where reactivation is blocked
8. **Archive:** After lockdown, move to archived state

**Key fields:**

- `owner_id`, `operator_id` — immutable
- `status` — active | paused | terminated | archived
- `preset` — permission set (e.g., "full_ops", "limited_approval")
- `commission_rate`, `commission_cap`, `platform_fee_pct` — financial terms
- `approval_threshold` — USD amount triggering threshold approvals
- `lockdown_ends_at` — computed from terminated_at + 30 days

**Dual-identity audit:**

Every action by operator is logged with:
- `actor_id` — operator's user_id
- `on_behalf_of_user_id` — owner's user_id
- `acted_via_delegation_id` — delegation_id reference

---

### 1.4 Delegation Services

**Location:** `app/services/delegation/`

#### Invitation Service
- **File:** `invitation_service.py`
- **Methods:**
  - `create_invitation()` — owner invites operator, sends SMS/email
  - `accept_invitation()` — operator KYC + accept
  - `reject_invitation()` — operator rejects (expires)

#### Lifecycle Service
- **File:** `lifecycle_service.py`
- **Methods:**
  - `activate_delegation()` — after KYC + POA, move to active
  - `pause_delegation()` — owner pauses (reversible)
  - `resume_delegation()` — owner resumes (post-pause)
  - `terminate_delegation()` — owner/operator terminate, start lockdown
  - `archive_delegation()` — after lockdown, move to archived
  - `promote_to_full_ops()` — owner upgrades operator to full access

#### Lockdown Service
- **File:** `lockdown_service.py`
- **Methods:**
  - `compute_lockdown_end()` — returns termination_at + 30 days
  - `is_locked_down()` — true if now < lockdown_ends_at
  - `suspend_operator_all_delegations()` — fraud: suspend across all active delegations

---

### 1.5 Commission & Invoice Management

**Location:** `app/services/commission/`

**Key concept:** Commission rate + platform fee locked at invoice `paid_at`, immutable thereafter.

**Key service:**
- `CommissionSnapshot` — compute_commission(invoice) → returns:
  - `commission_rate` (from delegation at time of payment)
  - `commission_amount` (calculated from total_amount * rate)
  - `platform_fee_pct` (from delegation)

**Immutability:** Once invoice marked paid, commission values cannot change.

---

### 1.6 Approvals (Threshold-Based)

**Location:** `app/services/approval/`

**Purpose:** Operator requests action (e.g., approve booking) above delegation threshold → owner must approve within expiry window.

**Key entity:** `DelegationApproval`
- `delegation_id`, `operator_id`, `owner_id` — actors
- `action_type` — e.g., "invoice_approval", "booking_approval"
- `amount_usd` — triggers threshold check
- `expires_at` — owner must approve/reject by this time
- `status` — pending | approved | rejected | auto_rejected (timeout)

**Auto-rejection:** If expires_at passes with no response → `auto_rejected`

---

### 1.7 Owner Death & Heir Flow

**Location:** `app/services/owner_death/`

**Entities:**
- `OwnerDeathCertificate` — proof of death (cert_number, issue_date)
- `OwnerDeathClaimant` — heir claim (relationship, identity proof)

**Workflow:**
1. Heir submits death cert + claim
2. Admin verifies
3. Upon approval: pause ALL delegations, transfer ownership
4. Heir can resume or terminate delegations

---

### 1.8 KB04 Fast-Track Workflow

**Location:** `app/services/kb04_workflow_service.py`

**Purpose:** District-flagged contracts can skip standard threshold approvals, move direct to escalation.

**Key methods:**
- `is_kb04_contract()` — check if contract has KB04 flag
- `apply_fast_track()` — skip approval queues
- `escalate_to_platform()` — route to platform review if needed

---

### 1.9 POA PDF Generation

**Location:** `app/services/contract_pdf_service.py`

**Purpose:** Generate dual-disclosure POA PDF for legal notarization.

**Key methods:**
- `generate_poa_pdf(delegation_id)` → bytes (PDF)
- Includes: owner name, operator name, scope, commission, signatures, dates

---

### 1.10 Marketplace Sync (Host Immutability)

**Location:** `app/services/marketplace_sync_service.py`

**Constraint:** Once a house/booking is linked to a host, `host_id` is immutable (no re-assignment to operators).

**Key methods:**
- `validate_host_immutability()` — block host_id changes
- `sync_with_marketplace_api()` — push changes to external API

---

### 1.11 MCP Endpoint (`/mcp`)

Code: `app/mcp/`, mounted by `main.py` inside `if ai_enabled_for_region(settings.region):` (AI is on when `registry.<region>.yaml` exists, see `app/ai_capabilities/loader.py`). Without that file `/mcp` is not mounted.

**Surface**
- `POST /mcp`: MCP over streamable HTTP, stateless, JSON responses (`stateless_http=True, json_response=True` in `app/mcp/sdk_server.py`). Exactly two tools, `get_system_skills` and `run_action`; new capabilities are registry actions, the tool list does not change. The registry is fetched on every call (hot reload).
- `GET /mcp/SKILL.md`: the fixed skill file as `text/markdown`, same text as the MCP `instructions` (front matter removed in `instructions`).
- Any other method on `/mcp` (GET, DELETE...): 405 with `Allow: POST`, no stream is opened.

**Request path** (`McpGuardASGI` in `app/mcp/mount.py`, then the SDK)
1. Method is not POST: 405.
2. Total limit exceeded (`mcp_rate_limit_total_per_min`): 429, body `{"error": {"code": "RATE_LIMITED", ...}}`. Counted before the Host/Origin check, so rejected hosts also use the budget.
3. SDK server not running (app not started or already shut down): 503 `MCP_UNAVAILABLE`.
4. SDK transport security: `Host` not in `mcp_allowed_hosts` gives 421; an `Origin` not in `mcp_allowed_origins` gives 403.
5. `tools/call` goes through `app/mcp/tool_bridge.py`: per-key limit first (`get_system_skills` or `run_action:<action>`; unknown or missing action shares `run_action:?`), then the fixed tool runs with `ActionContext(channel="mcp")`. Over the per-key limit returns a normal tool result with `isError` true and `{"error": "rate_limited", ...}`, not HTTP 429. Action errors and exceptions from the registry provider are also `isError` results (`upstream_error` for the latter), not HTTP errors.

**Lifecycle.** The SDK `Server` is built in the app `startup` event and closed in `shutdown` (`session_manager.run()` runs once per instance). The app must run its startup/shutdown events; before startup `/mcp` answers 503. In tests use `with TestClient(app)` as `tests/ai/test_mcp_endpoint.py` does. Rate counters live in process memory, reset on restart and are shared by all clients (not per IP).

Settings: see "MCP settings" in `codebase-summary.md`. Tests: `tests/ai/test_mcp_endpoint.py`, `test_mcp_rate_limit.py`, `test_mcp_tool_bridge.py`.

---

### 1.12 AI Chat Endpoint (`POST /api/ai/chat`)

Code: `app/api/routes/ai_chat.py` (thin router), `app/schemas/ai_chat.py`, `app/services/ai_chat/`. `main.py` includes the router inside the same `if ai_enabled_for_region(settings.region):` block as `/mcp`, so without `registry.<region>.yaml` the route does not exist. Stateless and not streamed: the client resends the history each turn. Login is optional (`optional_user`); a valid Bearer token becomes `ActionContext.user`, and the `Authorization` header is forwarded to actions only in that case.

**Request** (`AiChatRequest`)
- `messages`: 1 to 20 items `{role: "user" | "assistant", content}`. `content` is 1 to 2000 chars and not blank. The last item must have role `user`. Total `content` length is at most 8000 chars.
- `lang`: optional, pattern `^[a-z]{2}$`. Omitted: `registry.default_lang`.

**Response** (`AiChatResponse`): `reply` (at most 2000 chars), `listings`, `tool_rounds`, `tool_calls` (`[{name, arguments, is_error}]`), `model` (value of `ai_chat_model`).
- `listings` are neutral cards with the keys of `CARD_KEYS` in `app/services/ai_chat/listing_cards.py` (`listing_id`, `title`, `price`, `currency`, `area_m2`, `layout`, `bedrooms`, `station_name`, `walk_min`, `city`, `thumbnail_url`). Cards come only from items returned by `run_action` in the same turn. If the reply cites `[#<id>]`, only the cited ids that the tools returned are kept; with no citation, the result of the last `search_listings` is returned. A fallback or refusal reply carries no cards.

**Turn** (`run_chat_turn` in `app/services/ai_chat/chat_service.py`)
1. System blocks: fixed skill, JSON-encoded system skills (cache_control `ephemeral`), current local time (`local_tz()` from `app/ai_capabilities/fixed_tools.py`, i.e. `default_tz`). Tools: the two fixed tools, cache_control on the last one (`chat_tools.py`).
2. Call `client.messages.create`. While `stop_reason` is `tool_use`, each tool block runs through `call_fixed_tool`, the same function as MCP, with `ActionContext(channel="chat")`; results go back as `tool_result` blocks.
3. The loop stops when the model answers, or when rounds would exceed `ai_chat_max_tool_rounds`, or total tool calls would exceed `ai_chat_max_tool_calls`. Then the reply is a fixed fallback text (`ja`, `vi`, `en`; other languages use `en`). A `refusal` stop reason gives a fixed refusal text.
4. Chat text is not logged. One `ai_chat_tools` log event per turn carries `actions`, `registry_version`, `market`, `tool_rounds`, `model`, `lang`.

**Errors** (envelope `{"error": {"code", "message", ...}}` from `http_exception_handler`)

| Status | `code` | When |
|---|---|---|
| 503 | `AI_NOT_CONFIGURED` | `anthropic_api_key` empty. Raised before body validation (see note) |
| 504 | `AI_TIMEOUT` | Turn deadline `ai_chat_turn_deadline_s` or an Anthropic timeout |
| 502 | `AI_UPSTREAM_ERROR` | Other Anthropic `APIError` after client retries |
| 422 | (FastAPI validation) | Body violates the rules above |
| 429 | `RATE_LIMITED` | `ai_chat_rate_limit` exceeded; has `Retry-After` |

- 503 ordering: `get_anthropic_client` is a route dependency and raises 503 without a key; the handler body repeats the check because tests override that dependency. The code comment marks the check as running before anything else. `test_ai_chat_missing_api_key_returns_503` sends a valid body, so the ordering against an invalid body is stated by the code design, not covered by a test.
- 429 handler is app-wide: `rate_limit_exceeded_handler` (`app/middleware/error_handler.py`, registered in `main.py`) replaced the slowapi default for every slowapi-limited route. The body is the common envelope (message `Rate limit exceeded: <detail>`) and the response has a `Retry-After` header in seconds.
- Rate limit key: `user:<sub>` for a valid JWT, else client IP (`app/middleware/rate_limit.py`). Behind nginx the IP is the real client only when `FORWARDED_ALLOW_IPS` lists the proxy hops (comment in `deploy/jp/docker-compose.jp.yml`).

**Deploy (JP).** `deploy/jp/nginx.jp.conf` has `location = /api/ai/chat` with `proxy_read_timeout 75s` (the app deadline is 60 s), so a client gets the JSON 504 and not an nginx HTML page. `deploy/jp/env.jp.template` notes that the ALB idle timeout must be at least 75 s.

**Eval.** `scripts/eval_ai_chat_multilang.py --base-url <url> --out <file>` posts the cases in `scripts/data/ai_chat_eval_multilang.json` to a running backend and exits 1 below the thresholds in that file. It needs a real `ANTHROPIC_API_KEY` on the backend.

Settings: see "AI chat settings" in `codebase-summary.md`. Tests: `tests/ai/test_ai_chat_api.py`, `test_ai_chat_edge_cases.py`, `test_ai_chat_listing_cards.py`, `test_ai_chat_system_prompt.py` (fake client: `tests/ai/fake_anthropic.py`).

---

## 2. Data Model — Key Tables

| Table | Purpose | Owner | Operator |
|-------|---------|-------|----------|
| `users` | Auth, profile | Primary | Secondary |
| `houses` | Property listings | Creates | Can manage via delegation |
| `bookings` | Reservations | Approves | Can request/manage via delegation |
| `invoices` | Payments, commission tracking | Receives | Pays commission, fixed at paid_at |
| `delegations` | Active grants | Owner | Operator (scoped) |
| `delegation_invitations` | Invite workflow | Owner initiates | Operator accepts |
| `delegation_approvals` | Threshold approvals | Owner decides | Operator requests |
| `owner_death_certificates` | Proof of owner death | Heir submits | N/A |
| `delegation_lockdowns` | 30-day post-termination block | System enforced | N/A |

---

## 3. Request Flow — Operator Action with Dual Audit

Example: Operator creates invoice

```
1. POST /api/invoices
   Bearer token (operator JWT)
   Body: { amount, house_id }

2. ActorContext resolution:
   - Decode JWT → operator_id
   - Query delegation where operator_id + status=active
   - Load permission_set → check if "invoice.create" allowed
   - Build ActorContext: {
       actor_id: operator_id,
       on_behalf_of_user_id: owner_id,
       delegation_id: delegation_id,
       permissions: ["invoice.create", ...],
       commission_rate: 0.15,
       approval_threshold: 500
     }

3. Create invoice:
   - INSERT invoices:
     actor_id = operator_id
     on_behalf_of_user_id = owner_id
     acted_via_delegation_id = delegation_id

4. If amount > threshold → create DelegationApproval
   - requires owner approval within 24h

5. At payment (marked paid):
   - Lock commission_rate, commission_amount via CommissionSnapshot
   - Immutable thereafter
```

---

## 4. API Routes

### Delegation Routes
**File:** `app/api/routes/delegation.py`

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/delegations` | Owner creates invitation |
| GET | `/api/delegations` | List delegations (owner/operator view) |
| GET | `/api/delegations/{id}` | Delegation details + audit log |
| PATCH | `/api/delegations/{id}` | Pause/resume/terminate |
| POST | `/api/delegations/{id}/accept` | Operator accepts after KYC |
| POST | `/api/delegations/{id}/promote` | Owner upgrades preset |

### Approval Routes
**File:** `app/api/routes/approval.py`

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/approvals` | List pending approvals (owner view) |
| POST | `/api/approvals/{id}/approve` | Owner approves action |
| POST | `/api/approvals/{id}/reject` | Owner rejects action |

### Owner Death Routes
**File:** `app/api/routes/owner_death_*`

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/owner-death/claim` | Heir submits death cert + claim |
| GET | `/api/owner-death/claims` | Admin views claims (admin only) |
| POST | `/api/owner-death/claims/{id}/approve` | Admin approves heir claim |

### Admin Routes
**File:** `app/api/routes/admin_delegations.py`

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/admin/delegations` | Admin list all delegations |
| POST | `/api/admin/delegations/{id}/suspend` | Admin suspends operator across delegations (fraud) |

---

## 5. Permission Sets (Presets)

**Location:** `app/services/permission_set.py`

Preset → list of permission strings. Example:

```
preset "full_ops":
  - invoice.create
  - invoice.view
  - booking.approve
  - approval.decide
  - house.manage

preset "limited_approval":
  - invoice.view
  - booking.view (own)
  - approval.request (capped)
```

---

## 6. Migrations

**File:** `alembic/versions/`

Delegation schema added via migrations 0021–0036 (June 2026):
- 0021: `delegations`, `delegation_invitations`
- 0022: `delegation_approvals`
- 0023: `delegation_lockdowns`
- 0024: `owner_death_certificates`, `owner_death_claimants`
- 0025+: Indexes, audit columns

---

## 7. Security Model

### Owner → Operator Scope
- Operator permissions **scoped to preset** (cannot exceed)
- Operator **cannot see other owners' data**
- Operator **cannot create new delegations** (only owner initiates)

### Commission Immutability
- Commission locked at invoice `paid_at`
- Cannot be edited post-payment
- Prevents retroactive rate manipulation

### Dual Audit Trail
- Every operator action logs both `actor_id` + `on_behalf_of_user_id`
- Enables post-hoc compliance review
- Cannot be forged (enforced in service layer)

### Lockdown Anti-Replay
- Terminated delegation locked for 30 days
- Prevents rapid re-activation for fraud recovery
- Lockdown cleared only after full 30-day window

### Fraud Auto-Suspension
- Admin can suspend operator across ALL active delegations atomically
- Triggers reassessment of pending approvals

---

## 8. Testing Strategy

**Unit tests:** Services, permission logic, lockdown computation  
**Integration tests:** Delegation lifecycle (invite → activate → terminate → lockdown)  
**Smoke tests:** Full request flow (operator action with dual audit)  

---
