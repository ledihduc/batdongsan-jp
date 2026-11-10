# Codebase Summary — ancu365 Backend

> Last updated: 2026-06-30  
> Stack: FastAPI 0.104+, SQLAlchemy 2.0, PostgreSQL 16 + PostGIS, Alembic

## Directory Structure

```
backend/
├── main.py                      # FastAPI app entry, router wiring
├── requirements.txt             # Python dependencies
├── .env.example                 # Config template
├── alembic.ini                  # Migration config
├── alembic/versions/            # Migration files (0001–0036+)
├── scripts/
│   ├── seed_dev.py              # Idempotent dev seed
│   ├── eval_ai_chat_multilang.py  # AI chat eval (stdlib, needs a running backend); data: scripts/data/ai_chat_eval_multilang.json
├── uploads/                     # User-uploaded images (git-ignored)
└── app/
    ├── config.py                # Load .env, settings
    ├── database.py              # SQLAlchemy engine, session factory
    ├── models.py                # ORM models (User, House, Booking, Delegation, etc.)
    ├── auth.py                  # JWT HS256, bcrypt, current_user dependency
    ├── chat_hub.py              # WebSocket manager (async)
    ├── seed.py                  # Seed logic (imported by scripts/seed_dev.py)
    ├── helpers.py               # Logging, notifications, rich text helpers
    ├── ai_capabilities/         # AI action registry, 2 fixed tools (get_system_skills, run_action), fixed skill
    ├── mcp/                     # MCP server at /mcp (mounted only when the region has a registry file)
    │   ├── mount.py             # mount_mcp(app): /mcp + /mcp/SKILL.md, startup/shutdown handlers, 405/429/503 guard
    │   ├── sdk_server.py        # mcp SDK low-level Server, stateless + JSON, Host/Origin allowlists
    │   ├── tool_bridge.py       # SDK <-> ai_capabilities fixed tools, per-action rate key, error mapping
    │   └── rate_limit.py        # In-memory fixed 60 s window limiter (total + per key)
    ├── domain/
    │   ├── delegation.py        # Domain models: Delegation, DelegationInvitation, DelegationApproval, OwnerDeathCertificate
    │   └── ...
    ├── schemas/                 # Pydantic request/response schemas
    │   ├── ai_chat.py           # AiChatRequest / AiChatResponse for POST /api/ai/chat
    │   ├── user.py
    │   ├── house.py
    │   ├── booking.py
    │   ├── delegation.py        # DelegationCreate, DelegationResponse, etc.
    │   └── ...
    ├── services/
    │   ├── actor_context.py     # ActorContext resolution (owner vs. operator)
    │   ├── permission_set.py    # Preset → permission strings
    │   ├── ai_chat/             # AI chat turn (POST /api/ai/chat)
    │   │   ├── anthropic_client.py  # get_anthropic_client(): cached AsyncAnthropic, 503 AI_NOT_CONFIGURED without key
    │   │   ├── chat_service.py      # run_chat_turn(): manual tool loop against the two fixed tools
    │   │   ├── chat_tools.py        # Anthropic tool list + system blocks (fixed skill, system skills, current time)
    │   │   └── listing_cards.py     # Neutral listing cards (CARD_KEYS) from tool results
    │   ├── commission/
    │   │   └── commission_snapshot.py  # Immutable commission lock at paid_at
    │   ├── delegation/
    │   │   ├── invitation_service.py   # Invite → KYC → accept workflow
    │   │   ├── lifecycle_service.py    # Activate, pause, resume, terminate, archive
    │   │   └── lockdown_service.py     # 30-day post-termination lockdown
    │   ├── approval/
    │   │   └── approval_service.py     # Threshold approvals, auto-rejection
    │   ├── owner_death/
    │   │   ├── death_cert_service.py   # Death cert + claim verification
    │   │   └── heir_flow_service.py    # Heir transition + delegation pause
    │   ├── kb04_workflow_service.py    # District fast-track for contracts
    │   ├── contract_pdf_service.py     # POA PDF generation (dual-disclosure)
    │   ├── marketplace_sync_service.py # Host immutability enforcement
    │   ├── planning_etl.py             # Planning lookup ETL (nightly)
    │   ├── notification/
    │   │   ├── notification_service.py
    │   │   └── templates/              # SMS/email templates (Jinja2)
    │   ├── admin/
    │   │   └── admin_delegation_actions.py  # Admin suspension, fraud handling
    │   └── ...
    ├── api/
    │   ├── dependencies/
    │   │   ├── actor.py               # ActorContext per-request injection
    │   │   └── ...
    │   └── routes/
    │       ├── auth.py                # Login, register, forgot-password
    │       ├── users.py               # User profile CRUD
    │       ├── houses.py              # House CRUD, filtering, close-unit
    │       ├── bookings.py            # Booking CRUD, status transitions
    │       ├── reviews.py             # Review CRUD
    │       ├── wishlists.py           # Wishlist CRUD
    │       ├── notifications.py       # Notification list + mark-read
    │       ├── chat.py                # Chat REST endpoints
    │       ├── upload.py              # Image upload (base64)
    │       ├── delegation.py          # Delegation invite, list, accept, pause, terminate
    │       ├── approval.py            # Approval list, approve, reject
    │       ├── owner_death_*.py       # Heir claim, admin verification
    │       ├── admin_delegations.py   # Admin delegation suspension
    │       ├── planning.py            # Planning lookup (9 endpoints)
    │       ├── health.py              # /health endpoint
    │       ├── ai_chat.py             # POST /api/ai/chat (mounted only when the region has a registry file)
    │       └── ...
    └── tests/
        ├── test_smoke_postgres.py     # Integration tests (needs DB)
        ├── test_*_unit.py             # Unit tests
        └── ...
```

---

## Core Models (app/models.py)

| Model | Purpose | Key fields |
|-------|---------|-----------|
| `User` | Auth, profile | id, email, password_hash, role, kyc_verified_at |
| `House` | Property | id, owner_id, title, location, amenities |
| `Booking` | Reservation | id, house_id, guest_id, check_in, check_out, status |
| `Invoice` | Payment + commission | id, booking_id, total_amount, commission_amount, paid_at, actor_id, on_behalf_of_user_id, acted_via_delegation_id |
| `Delegation` | Owner → operator grant | id, owner_id, operator_id, preset, commission_rate, approval_threshold, status, locked_down_ends_at |
| `DelegationInvitation` | Invite workflow | id, owner_id, operator_email, expires_at, status |
| `DelegationApproval` | Threshold approval | id, delegation_id, operator_id, owner_id, action_type, amount_usd, expires_at, status |
| `OwnerDeathCertificate` | Proof of death | id, owner_id, heir_user_id, cert_number, status |
| `Review` | Property feedback | id, booking_id, reviewer_id, rating, comment |
| `Notification` | In-app alerts | id, user_id, type, is_read |

---

## Authentication & Authorization

**File:** `app/auth.py`

```python
# Token payload
class TokenPayload(BaseModel):
    sub: str              # user_id
    exp: int              # expiry (7 days)
    role: str             # admin | host | guest

# Current user dependency
async def get_current_user(token: str) -> CurrentUser:
    payload = jwt.decode(token, JWT_SECRET)
    return CurrentUser(user_id=payload['sub'], role=payload['role'])
```

**Routes:**
- POST `/api/auth/login` → JWT
- POST `/api/auth/register` → User + JWT
- POST `/api/auth/forgot-password` → Reset email
- POST `/api/auth/change-password` → Hash + update
- GET `/api/auth/me` → Current user profile

---

## Key Services

### ActorContext Resolution
**File:** `app/services/actor_context.py`

```python
class ActorContext:
    actor_id: str           # effective user
    actor_role: str         # owner | operator | admin
    on_behalf_of_user_id: str | None  # owner, if delegated
    delegation_id: str | None
    permissions: set[str]   # ["invoice.create", ...]
    commission_rate: float  # 0.0–1.0

def build_owner_context(user_id: str) -> ActorContext:
    # Full permissions for own data
    return ActorContext(actor_id=user_id, permissions=ALL_OWNER_PERMS)

def build_operator_context(delegation: Delegation) -> ActorContext:
    # Scoped to preset
    permissions = PERMISSION_SETS[delegation.preset]
    return ActorContext(actor_id=delegation.operator_id, on_behalf_of_user_id=delegation.owner_id, permissions=permissions, ...)
```

### Delegation Lifecycle
**File:** `app/services/delegation/lifecycle_service.py`

```python
class DelegationLifecycleService:
    async def activate_delegation(delegation_id: str) -> Delegation:
        # Mark as active after KYC + POA

    async def pause_delegation(delegation_id: str) -> Delegation:
        # Reversible pause (owner only)

    async def terminate_delegation(delegation_id: str, reason: str) -> Delegation:
        # Set status = terminated, start 30-day lockdown

    async def archive_delegation(delegation_id: str) -> Delegation:
        # Move to archived (after lockdown expires)
```

### Commission Immutability
**File:** `app/services/commission/commission_snapshot.py`

```python
def compute_commission(invoice: Invoice) -> CommissionSnapshot:
    """Lock commission at payment time; subsequent reads return locked values."""
    if invoice.paid_at is None:
        delegation = get_delegation(invoice.acted_via_delegation_id)
        return CommissionSnapshot(
            rate=delegation.commission_rate,
            amount=invoice.total_amount * delegation.commission_rate,
            platform_fee_pct=delegation.platform_fee_pct
        )
    else:
        # Paid: return locked snapshot (immutable)
        return CommissionSnapshot.from_invoice_locked_values(invoice)
```

### Lockdown Enforcement
**File:** `app/services/delegation/lockdown_service.py`

```python
class DelegationLockdownService:
    def compute_lockdown_end(terminated_at: datetime) -> datetime:
        return terminated_at + timedelta(days=30)

    def is_locked_down(delegation: Delegation) -> bool:
        return delegation.status == "terminated" and now() < delegation.lockdown_ends_at

    async def suspend_operator_all_delegations(operator_id: str):
        # Admin action: suspend operator across ALL active delegations
```

### Threshold Approvals
**File:** `app/services/approval/approval_service.py`

```python
class ApprovalService:
    async def request_approval(delegation_id: str, action: str, amount_usd: float) -> DelegationApproval:
        # Operator requests; creates pending approval if amount > threshold

    async def approve(approval_id: str, owner_id: str) -> DelegationApproval:
        # Owner approves, action proceeds

    async def auto_reject_expired():
        # Batch job: mark expired approvals as auto_rejected (24h default)
```

---

## API Routes

### Delegation Routes
**File:** `app/api/routes/delegation.py`

```python
POST   /api/delegations                    # Owner invites operator
GET    /api/delegations                    # List (owner/operator view)
GET    /api/delegations/{id}               # Details + audit log
PATCH  /api/delegations/{id}               # Pause/resume/terminate
POST   /api/delegations/{id}/accept        # Operator KYC + accept
POST   /api/delegations/{id}/promote       # Owner upgrades preset
```

### Approval Routes
**File:** `app/api/routes/approval.py`

```python
GET    /api/approvals                      # List pending (owner view)
POST   /api/approvals/{id}/approve         # Owner approves
POST   /api/approvals/{id}/reject          # Owner rejects
```

### Owner Death Routes
**File:** `app/api/routes/owner_death_*.py`

```python
POST   /api/owner-death/claim              # Heir submits death cert
GET    /api/owner-death/claims             # Admin list
POST   /api/owner-death/claims/{id}/approve  # Admin approves
```

### Admin Routes
**File:** `app/api/routes/admin_delegations.py`

```python
GET    /api/admin/delegations              # List all
POST   /api/admin/delegations/{id}/suspend # Suspend operator (fraud)
```

### Planning Routes
**File:** `app/api/routes/planning.py`

```python
GET    /api/planning/districts             # List 24 HCMC districts
GET    /api/planning/layers                # Available layers + Martin URL
GET    /api/planning/parcels/search        # Spatial search (ST_Contains)
GET    /api/planning/parcels/{id}          # Parcel details
GET    /api/planning/addresses/search      # Nominatim reverse search
POST   /api/planning/contracts/kb04-flag   # Flag contract for fast-track
```

---

## Permissions Model

**File:** `app/services/permission_set.py`

```python
PERMISSION_SETS = {
    "full_ops": {
        "invoice.create",
        "invoice.view",
        "booking.approve",
        "approval.decide",
        "house.manage"
    },
    "limited_approval": {
        "invoice.view",
        "booking.view",
        "approval.request"
    },
    "kb04_fast_track": {
        "invoice.create",
        "approval.skip",  # Skip threshold queue for KB04 contracts
    }
}
```

---

## Migrations

**File:** `alembic/versions/`

| Migration | Added |
|-----------|-------|
| 0001–0020 | Core tables (users, houses, bookings, planning.*, etc.) |
| 0021 | delegations, delegation_invitations |
| 0022 | delegation_approvals |
| 0023 | delegation_lockdowns |
| 0024 | owner_death_certificates, owner_death_claimants |
| 0025–0036 | Indexes, audit columns, constraints |

---

## Testing

**Files:**
- `tests/test_smoke_postgres.py` — Integration tests (requires live DB)
- `tests/test_*_unit.py` — Unit tests (mocked DB)

**Coverage:**
- Delegation invite → KYC → accept → activate → terminate → lockdown → archive
- Commission immutability at paid_at
- Threshold approval auto-rejection
- Owner death claim + heir transition
- KB04 fast-track dispatch
- Operator permission scoping

---

## Key Dependencies

```
fastapi==0.104.1
sqlalchemy==2.0.23
alembic==1.13.1
psycopg2-binary==2.9.9          # PostgreSQL driver
geoalchemy2==0.14.5             # PostGIS ORM
pydantic==2.14.1
uvicorn[standard]==0.54.0
mcp==2.3.0                       # imported by app/mcp/sdk_server.py (low-level Server, streamable HTTP)
anthropic==2.3.0                 # imported by app/services/ai_chat/anthropic_client.py (AsyncAnthropic) and app/api/routes/ai_chat.py
jsonschema==4.26.0
PyYAML==6.0.3
python-jose==3.3.0               # JWT
passlib==1.7.4                  # bcrypt
aiofiles==23.2.1
slowapi==0.1.9                  # Rate limiting
jinja2==3.1.2                   # Email/SMS templates
reportlab==4.0.7                # POA PDF generation
httpx==0.25.0                   # Async HTTP for external APIs
apscheduler==3.10.4             # Planning ETL scheduler
```

---

## Configuration

**File:** `app/config.py`

```python
DATABASE_URL = os.getenv("DATABASE_URL")  # postgresql://...
JWT_SECRET = os.getenv("JWT_SECRET")
JWT_EXPIRY_DAYS = 7
COMMISSION_LOCK_AT_PAID_AT = True
LOCKDOWN_DAYS = 30
APPROVAL_EXPIRY_HOURS = 24
```

### MCP settings (`app/config.py`)

Read from env (case-insensitive field names, e.g. `MCP_ALLOWED_HOSTS`). Defaults are in `app/config.py`.

| Setting | Default | Meaning |
|---|---|---|
| `mcp_allowed_hosts` | `["localhost:*", "127.0.0.1:*"]` | `Host` header allowlist. Other host: 421 |
| `mcp_allowed_origins` | `[]` | `Origin` allowlist. Request with an `Origin` not in the list: 403. No `Origin` header is accepted |
| `mcp_rate_limit_total_per_min` | `120` | POST `/mcp` requests per 60 s window. Over: HTTP 429 |
| `mcp_rate_limit_per_action_per_min` | `60` | `tools/call` per key per 60 s window. Over: tool result with `isError` |

- `MCP_ALLOWED_HOSTS` and `MCP_ALLOWED_ORIGINS` must be JSON lists, e.g. `["localhost:*","127.0.0.1:*","mcp.example.com"]`. When adding a tunnel or nginx host, keep the localhost entries (comment in `app/config.py`).
- The lists are read at app startup, not at import. Changing them needs a restart.
- Related: `ai_registry_dir` (`AI_REGISTRY_DIR`) decides where `registry.<region>.yaml` is looked up; no file for `settings.region` means `/mcp` is not mounted.

### AI chat settings (`app/config.py`)

Read from env (case-insensitive field names, e.g. `ANTHROPIC_API_KEY`). Defaults are in `app/config.py`. Used by `POST /api/ai/chat` (see `system-architecture.md`, section 1.12).

| Setting | Default | Meaning |
|---|---|---|
| `anthropic_api_key` | empty | Anthropic API key. Empty: the endpoint answers 503 `AI_NOT_CONFIGURED` |
| `ai_chat_model` | `claude-haiku-5-5` | Model id sent to the Messages API; echoed in the response `model` field |
| `ai_chat_call_timeout_s` | `30.0` | Timeout of one Anthropic call (client built with `max_retries=2`) |
| `ai_chat_turn_deadline_s` | `60.0` | Deadline of the whole turn. Over: 504 `AI_TIMEOUT` |
| `ai_chat_max_tool_rounds` | `6` | Max tool rounds per turn |
| `ai_chat_max_tool_calls` | `8` | Max `tool_use` blocks run per turn (one round can ask for several) |
| `ai_chat_max_tokens` | `1024` | `max_tokens` per Anthropic call |
| `ai_chat_rate_limit` | `30/hour` | slowapi limit string for the endpoint; key = `user:<sub>` for a valid JWT, else client IP |

- JP deploy passes `ANTHROPIC_API_KEY`, `AI_CHAT_MODEL`, `AI_CHAT_RATE_LIMIT` and `FORWARDED_ALLOW_IPS` through `deploy/jp/docker-compose.jp.yml`; `deploy/jp/env.jp.template` lists them. The other five `ai_chat_*` settings (timeouts, tool limits, `max_tokens`) are not passed by that compose file, so they keep the defaults there.
- The route is mounted only when the region has a registry file, the same condition as `/mcp`.

---
