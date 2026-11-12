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

Code: `app/mcp/`, mounted by `main.py` inside `if ai_enabled_for_region(settings.region):` (AI is on when `registry.<region>.yaml` exists, see `app/ai_capabilities/loader.py`). Without that file `/mcp` is not mounted. The packaged registry directory has `registry.jp.yaml` and `registry.vn.yaml`, so both markets mount `/mcp` (the vn actions are in 1.14).

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

Registry actions with `mode: write` do not write through this path: `run_action` returns `status: confirmation_required` with a `confirm_url` (see 1.13).

Settings: see "MCP settings" in `codebase-summary.md`. Tests: `tests/ai/test_mcp_endpoint.py`, `test_mcp_rate_limit.py`, `test_mcp_tool_bridge.py`.

---

### 1.12 AI Chat Endpoint (`POST /api/ai/chat`)

Code: `app/api/routes/ai_chat.py` (thin router), `app/schemas/ai_chat.py`, `app/services/ai_chat/`. `main.py` includes the router inside the same `if ai_enabled_for_region(settings.region):` block as `/mcp`, so without `registry.<region>.yaml` the route does not exist. Stateless and not streamed: the client resends the history each turn. Login is optional (`optional_user`); a valid Bearer token becomes `ActionContext.user`, and the `Authorization` header is forwarded to actions only in that case.

**Request** (`AiChatRequest`)
- `messages`: 1 to 20 items `{role: "user" | "assistant", content}`. `content` is 1 to 2000 chars and not blank. The last item must have role `user`. Total `content` length is at most 8000 chars.
- `lang`: optional, pattern `^[a-z]{2}$`. Omitted: `registry.default_lang`.

**Response** (`AiChatResponse`): `reply` (at most 2000 chars), `listings`, `tool_rounds`, `tool_calls` (`[{name, arguments, is_error}]`), `model` (value of `ai_chat_model`), `pending_actions` (default `[]`), `login_required` (default `false`).
- `pending_actions` are confirmation cards `{token, action, title, params, expires_at}` for write actions the model asked for in this turn (see 1.13). `login_required` is `true` when a write action was called without a logged-in user; the response is still 200.
- `listings` are neutral cards with the keys of `CARD_KEYS` in `app/services/ai_chat/listing_cards.py` (`listing_id`, `title`, `price`, `currency`, `area_m2`, `layout`, `bedrooms`, `station_name`, `walk_min`, `city`, `thumbnail_url`). Cards come only from items returned by `run_action` in the same turn. If the reply cites `[#<id>]`, only the cited ids that the tools returned are kept; with no citation, the result of the last `search_listings` is returned. A fallback or refusal reply carries no cards.

**Turn** (`run_chat_turn` in `app/services/ai_chat/chat_service.py`)
1. System blocks: fixed skill, JSON-encoded system skills (cache_control `ephemeral`), current local time (`local_tz()` from `app/ai_capabilities/fixed_tools.py`, i.e. `default_tz`). Tools: the two fixed tools, cache_control on the last one (`chat_tools.py`).
2. Call `client.messages.create`. While `stop_reason` is `tool_use`, each tool block runs through `call_fixed_tool`, the same function as MCP, with `ActionContext(channel="chat")`; results go back as `tool_result` blocks. A `run_action` payload passes through `PendingCards.take` (`app/services/ai_chat/pending_cards.py`) first: the `pending_token` is removed from what the model sees and a fixed note (`CARD_SHOWN_NOTE`) is added.
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

### 1.13 AI Write Actions with Pending Confirm

Code: `app/ai_capabilities/action_runner.py`, `app/services/ai_actions/`, `app/services/jp_search/ai_write_tools.py`, `app/services/vn_search/ai_write_tools.py`, `app/api/routes/ai_actions.py`, `app/schemas/ai_actions.py`, `app/domain/ai_pending_action.py` (table `ai_pending_actions`, migration `0168_ai_pending_actions`). `main.py` includes the router in the same `if ai_enabled_for_region(settings.region):` block as `/mcp` and `/api/ai/chat`.

An action with `mode: write` never writes when the AI calls it. The user confirms first, then the write runs under the identity of the user who confirmed. The jp registry has two (`app/ai_capabilities/registry/registry.jp.yaml`): `save_favorite` (`listing_id`) and `request_viewing` (`listing_id`, `slots` 1-3, optional `note`). Both are `requires_login: true` and use python handlers. The vn registry (`registry.vn.yaml`) has one write action, `save_favorite`, also `requires_login: true`; it has no `request_viewing`.

**Create pending** (`_create_pending` in `action_runner.py`)
1. Params are validated against the action schema.
2. Channel `chat` without a user: `ActionError` `login_required` (surfaces as `login_required` in the chat response). Channel `mcp` has no user, so a pending is still created; login is enforced at confirm time.
3. Handler runs with `ActionContext(dry_run=True)`: it only checks (listing exists, slots valid) and writes nothing. A rejection reaches the AI as a normal action error and no row is created.
4. `create_pending` (`pending_store.py`) inserts a `pending` row and commits. Token is `secrets.token_urlsafe(32)` (43 chars); only its SHA-256 is stored. Expiry is `ai_pending_ttl_min` after creation. Pending rows expired for more than 1 day are deleted on each create.
5. Result: `{status: "confirmation_required", action, params, expires_at}` plus, for `chat`, `pending_token` (stripped before the model, returned as a card) or, for `mcp`, `confirm_url` = `<AI_CONFIRM_BASE_URL>/ai-confirm/<token>`. `ai-confirm` is a client page; the backend has no route for it. Only python handlers can be pending (rest handler: `upstream_error`).

Chat pendings store `owner_user_id` (the creator). MCP pendings store `NULL`, so any logged-in user holding the link can confirm.

**Routes** (`app/api/routes/ai_actions.py`, prefix `/api/ai/actions`, both rate-limited by `ai_confirm_rate_limit`)

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/ai/actions/{token}` | none | Preview: `action`, localized `title` and `description`, `params`, `listing` brief (jp and vn; `listing_brief` in `app/services/ai_actions/listing_brief.py` returns `None` for other regions), `status`, `expires_at` (UTC offset), `owner_bound`. Optional `lang` query. Writes nothing |
| POST | `/api/ai/actions/{token}/confirm` | Bearer (`require_user`) | Execute once. Body is not read. Returns `{status: "executed", action, result}` |

A token that does not match `^[A-Za-z0-9_-]{43}$` is answered 404 before any DB access.

**Confirm order** (`confirm_pending` in `confirm_service.py`): lookup, owner check, status, expiry, registry check, re-validate params against the current registry, claim, run handler.
1. Claim = `UPDATE ... SET status='executed' WHERE id=:id AND status='pending' AND expires_at > now`. `rowcount != 1` means 409 `used`.
2. Handler runs with `ActionContext(channel="confirm", user=<claims>)` in the same transaction; success commits claim, written rows and `result` together.
3. Handler `ActionError`: rollback, mark `failed` in a new transaction with `error_code`, answer 422 with the handler's code. Any other exception: same, answer 502 `upstream_error`.

**Errors** (envelope `{"error": {"code", "message"}}`, plus `request_id` when the request has one)

| Status | `code` | When |
|---|---|---|
| 404 | `not_found` | Unknown token or malformed token |
| 403 | `forbidden` | Pending has an owner and the confirming user is another user (confirm only) |
| 409 | `used` | Status is not `pending` (executed, failed, undone) or the claim lost a race |
| 410 | `expired` | `expires_at <= now` |
| 410 | `action_unavailable` | Action removed, no longer `write`, or no longer python in the current registry |
| 422 | handler code (e.g. `invalid_arguments`, `not_found`) | Handler or param validation rejected; row becomes `failed` |
| 502 | `upstream_error` | Handler raised an unexpected exception; row becomes `failed` |
| 401 | `HTTP_401` (generic envelope) | Confirm only: no valid Bearer, or the password was changed after the token was issued (`require_user` in `app/auth.py`) |
| 403 | `HTTP_403` (generic envelope) | Confirm only: account locked or disabled (`require_user`). Not the same as `forbidden` above |
| 429 | `RATE_LIMITED` | `ai_confirm_rate_limit` exceeded |

Preview applies the same 404/409/410 checks but not 403 (no user).

**Do not make the confirm route or `confirm_pending` async.** The claim `UPDATE` holds a row lock until commit. On the event loop, a second request for the same token would wait on that lock and block the loop, so the first request could never commit. Both routes are plain `def` (run in the threadpool by FastAPI); `tests/ai/test_ai_pending_actions_hardening.py` has a test for this.

**Write handlers** (`ai_write_tools.py`). They write through models/services because there is no `/api/wishlists` route and `POST /api/jp/viewings` always returns 403 (module docstring). They never commit; `confirm_pending` does.
- `save_favorite`: `save_wishlist` (`wishlist_writer.py`) get-or-create on `Wishlist`; result `{saved, created, wishlist_id}`. `created=false` when the listing was already a favorite.
- vn `save_favorite` (`app/services/vn_search/ai_write_tools.py`): same `save_wishlist` and result. It first calls `get_vn_listing_detail`; a JP, unpublished or missing listing raises `LookupError`, so no pending row is created. With `dry_run` it returns `{preview: {listing_id, title}}` and writes nothing.
- `request_viewing`: `validate_slots` runs at pending creation and again at confirm (time may have passed), then `create_viewing_request`; notes are prefixed `[AI]`. Result `{viewing_id, status: "requested", created: true}`.

**Secrecy of the token.** It is never logged: `app/observability/middleware.py` replaces it with `{token}` in the request log path, and `deploy/jp/nginx.jp.conf` does the same in the access log (`map $request_uri $jp_log_uri`, field `uri`). The chat token goes to the app only, never to the model.

**Rollback / undo.** `scripts/ai_actions_undo.py` (`undo_service.py`) deletes the rows that executed AI actions created: `wishlists` for `save_favorite` with `created=true`, `jp_viewings` for `request_viewing`; every executed row is then marked `undone`. Dry run by default.
```
python scripts/ai_actions_undo.py --all|--since <ISO> [--yes]
```
`--since` filters on `executed_at`; an offset-aware time is converted to naive UTC. The script docstring shows the `docker compose exec -T -e PYTHONPATH=/app backend ...` form (untested here).

Settings: see "AI write action settings" in `codebase-summary.md`. Tests: `tests/ai/test_ai_write_tools.py`, `test_ai_pending_actions_api.py`, `test_ai_pending_actions_hardening.py`, `test_ai_chat_write_actions.py`, `test_ai_actions_undo.py` (helpers: `write_test_utils.py`).

---

### 1.14 VN Market AI Search (`REGION=vn`)

Code: `app/ai_capabilities/registry/registry.vn.yaml`, `app/services/vn_search/` (`listing_search_service.py`, `vn_location_normalizer.py`, `ai_tools.py`, `ai_write_tools.py`). The vn market uses the same `/mcp`, `/api/ai/chat` and `/api/ai/actions/*` code as jp (1.11-1.13); only the registry file and its handlers differ. `registry.vn.yaml` has `version: 2`, `market: vn`, `default_lang: vi`, a `guide` in `ja`, `vi`, `en`, and three actions.

| Action | Mode | Handler | Params (all `additionalProperties: false`) |
|---|---|---|---|
| `search_listings` | read | `app.services.vn_search.ai_tools:tool_search_listings` | `location` (1-60 chars), `category` (enum of 12 VN property types), `transaction_type` (`rent` or `sale`), `min_price_vnd`, `max_price_vnd`, `min_area_m2`, `max_area_m2`, `min_bedrooms` (0-20), `limit` (1-20, default 10) |
| `get_listing` | read | `app.services.vn_search.ai_tools:tool_get_listing` | `listing_id` (integer >= 1, required) |
| `save_favorite` | write, `requires_login: true` | `app.services.vn_search.ai_write_tools:tool_save_favorite` | `listing_id` (integer >= 1, required) |

**Search** (`search_vn_listings`). It reads the `houses` table directly, not `/api/houses`, because `house_to_dict` returns `host_phone` and `GET /api/houses/{id}` increments `view_count`.
- Scope: `status = 'published'` and `scope_houses(q, "vn")` (no `jp_rental_terms` row), applied always, independent of `DEMO_MARKET_SCOPE`. A JP listing is never returned at vn, and `get_listing` / `save_favorite` on a JP listing raise `LookupError`.
- `location`: `normalize_location` splits on `,` and every part must match. A part matches when `lower(district)` equals it, or `city` contains it (case-insensitive, `%` `_` `\` escaped). It strips `TP.` / `Thành phố` / `Tỉnh` prefixes and a `City` / `Province` suffix, and maps `Q1` / `District 1` / `Quận 1` to `Quận 1`, and `HCM`, `HCMC`, `TP.HCM`, `Sài Gòn`, `Ho Chi Minh` to `Hồ Chí Minh`, `Hanoi` to `Hà Nội`. District is compared for equality, so `Quận 1` does not match `Quận 10`.
- Other filters: `category` by exact `Category.name`, `transaction_type`, price (VND), area, bedrooms. Order: `price`, then `id`. `total` counts matches before `limit`.
- Item = the `CARD_KEYS` of 1.12 with `currency: "VND"`, `layout`, `station_name`, `walk_min` set to `None`, `price` as integer. `get_listing` adds `description` (cut at 1500 chars), `category`, `transaction_type`, `bathrooms`, `district`. Neither returns `address`, `host_phone` or email. The description is passed as stored; phone numbers or emails typed into it are not filtered.
- `detail_to_item` (`app/services/ai_chat/listing_cards.py`) keeps a flat payload that already has `currency`, so the vn `get_listing` card shows VND.

**Demo data.** `scripts/seed_vn_demo.py` runs `seed_vn_demo` from `app/services/vn_demo_seed.py`: 20 listings from `scripts/data/vn_listings_demo.json` (HCM and Hà Nội) under the host `vn-demo-host@example.invalid`, upserted by (`host_id`, `title`). It uses existing categories by name and raises `ValueError` for an unknown one. `--undo` deletes wishlists pointing at the demo listings, the listings and the host. The script exits 2 when `settings.region != "vn"`.

**Market switch (demo).** One image serves both markets; `REGION` and `DEFAULT_TZ` pick the market. The local demo compose file reads them from `DEMO_REGION` and `DEMO_TZ`. Commands, Flutter pairing and checks: `docs/how-to-run-demo-vn-market.md`.

**Eval.** `scripts/data/ai_chat_eval_vn.json` (6 cases) runs with `scripts/eval_ai_chat_multilang.py --data`. `_value_ok` matches expected strings on digit/Latin/Vietnamese word boundaries (`Quận 10` does not satisfy `Quận 1`) and not on CJK.

Tests: `tests/vn/test_vn_demo_seed.py`, `tests/vn/test_vn_listing_search.py` (fixture `tests/vn/vn_fixtures.py`), `tests/ai/test_ai_registry_vn.py`, `tests/ai/test_ai_vn_market.py`, `tests/scripts/test_eval_ai_chat_value_ok.py`.

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
| `ai_pending_actions` | AI write actions awaiting user confirm (token SHA-256, status, result ids) | N/A | N/A |

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
- 0168 `ai_pending_actions`: AI write actions pending confirm (revises `0167_jp_listing_link_columns`; additive, idempotent, has `downgrade()`)

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
