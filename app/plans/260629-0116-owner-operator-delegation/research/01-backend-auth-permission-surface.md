# Research Report: Backend Auth & Permission Surface

**Researcher:** Claude (Haiku 4.5)  
**Date:** 2026-06-29  
**Target:** Identify current auth dependency chain, host_id enforcement patterns, audit log architecture, and constraints for Owner–Operator Delegation feature  
**Scope:** FastAPI backend at `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/`  

---

## 1. Current Auth Dependency Chain

### 1.1 JWT Structure & Extraction

**File:** `app/auth.py:30-53`

JWT payload structure:
```python
{
  "sub": str(user_id),      # string per JWT spec, converted to int after decode
  "role": role,             # 'guest' | 'host' | 'admin'
  "iat": timestamp,
  "exp": timestamp
}
```

**Token signing** (`sign_token()`, line 30):
- Uses `HS256` with `settings.jwt_secret`
- TTL: `settings.token_ttl_hours` (read from `.env`)
- No custom claims yet (e.g., no delegation context)

**Token verification** (`verify_token()`, line 42):
- Decodes without raising on JWTError (returns None if invalid)
- Auto-converts `sub` string → int after decode (line 48)
- No role-specific claim extraction

**Extraction on request** (`optional_user()`, line 59):
- Reads `Authorization: Bearer {token}` header
- Returns decoded claims dict or None
- Used as FastAPI Depends injection

### 1.2 Role Check Hierarchy

**File:** `app/auth.py:68-95`

Three role-based dependencies:

| Dependency | Check | Notes |
|-----------|-------|-------|
| `require_user` (line 68) | Checks JWT exists | Base for all authenticated endpoints |
| `require_admin` (line 77) | Checks `role == 'admin'` | Scoped to ETL + admin-only ops |
| `require_host` (line 87) | Checks `role in ('host', 'admin')` | **Critical:** Admin can act as super-host for support/reconciliation (line 88 comment) |

**Key constraint:** `require_host` allows admin to call host endpoints. This is intentional for support/audit but **affects delegation logic** — must decide: does admin bypass delegation checks or must declare acting-as context?

### 1.3 IDOR Prevention Helper

**File:** `app/auth.py:98-109`

`_ensure_owner_or_admin()` function:
- Used on per-user resources (wishlists, notifications, messages)
- Pattern: extract `actor_id = claims["sub"]`, compare to resource owner
- Raises 403 if mismatch (unless actor is admin)
- **Not used in host/* endpoints** — those use HostScopedRepository pattern instead

---

## 2. Host_id Enforcement Pattern (Repository Layer)

### 2.1 HostScopedRepository Base Class

**File:** `app/repositories/base.py:22-62`

Core isolation mechanism:
```python
class HostScopedRepository(Generic[T]):
    model_class: Type[T]
    host_field_name: str = "host_id"
    
    def __init__(self, db: Session, host_id: int) -> None:
        self.db = db
        self.host_id = host_id
    
    def _base_query(self) -> Query:
        """Pre-filter by host_id on EVERY query"""
        return self.db.query(self.model_class).filter(
            getattr(self.model_class, self.host_field_name) == self.host_id
        )
```

**Pattern:**
- Every repo method calls `_base_query()` first
- `get(entity_id)` returns None if not found OR belongs to different host (404-safe)
- `list()` accepts extra filters stacked on top of host filter
- `exists()` checks both existence + ownership

**Inheritance chain:** 15 repositories extend HostScopedRepository (sample below)

### 2.2 Sample Usage: 3 Host Routers

#### Building Router (`app/routers/host_building.py:26-85`)

Pattern:
```python
@router.get("/buildings")
def list_buildings(
    claims: dict = Depends(auth.require_host),  # JWT check
    db: Session = Depends(get_db),
) -> list[BuildingResponse]:
    repo = BuildingRepository(db, host_id=claims["sub"])  # ← Pass host_id from JWT
    buildings = repo.list()                                 # ← Auto-filtered
    return [BuildingResponse.model_validate(b) for b in buildings]
```

- CRUD: list (line 26), create (line 36), patch (line 49), delete (line 66)
- All pass `claims["sub"]` to repository constructor
- No explicit host_id checks in router — delegated to repo
- Soft-delete with FK RESTRICT cascading (line 77–84)

**File references:**
- Router: `app/routers/host_building.py:26-85`
- Repo: `app/repositories/building_repository.py:15-58`
- Base: `app/repositories/base.py:22-62`

#### Contract Router (`app/routers/host_contract.py:75-150`)

Pattern similar to Building, but with helper enrichment:
```python
def _enrich_contract(contract, db: Session, host_id: int) -> ContractResponse:
    """Build response with embedded tenant pivot rows."""
    pivot_rows = db.query(models.ContractTenant).filter(...)
    tenant_repo = TenantRepository(db, host_id)  # ← Host-scoped
    # ... build response
```

- List (line 75), create (line 94), get (line 106)
- Patch endpoints for activate, terminate, transfer-room (line 119+)
- Helper function re-validates tenant ownership via TenantRepository
- All list/get filtered by `ContractRepository(db, host_id=claims["sub"])`

**File reference:** `app/routers/host_contract.py:48-150`

#### Invoice Router (Search)

Similar pattern in:
- `app/routers/host_invoice.py` (not fully read, but grep confirms require_host + repo pattern)

### 2.3 Repository Count & Field Mapping

**File:** `app/models.py`

All tables with `host_id` field (line grep results):

| Table | Line | Model Class |
|-------|------|-------------|
| House | 85 | House |
| RevenueSource | 225 | RevenueSource |
| Building | 287 | Building |
| Tenant | 345 | Tenant |
| Contract | 379 | Contract |
| ServiceFee | 450 | ServiceFee |
| MeterReading | 489 | MeterReading |
| Invoice | 518 | Invoice |
| Payment | 576 | Payment |
| CreditNote | 598 | CreditNote |
| KhaiBaoTamTru | 643 | KhaiBaoTamTru |
| Availability | 693 | Availability |
| PricingRule | 729 | PricingRule |
| Reservation | 778 | Reservation |
| AuditLog | 842 | AuditLog (special: legal immutable event log) |
| Tt200Export | 874 | Tt200Export (immutable export snapshot) |

**Total: 16 tables with host_id FK.** Most use HostScopedRepository pattern; AuditLog + Tt200Export are immutable logging tables.

---

## 3. Audit Log Architecture

### 3.1 ChangeLog Table (for entity mutations)

**File:** `app/models.py:244-262`

```python
class ChangeLog(Base):
    """Audit trail for all contract/invoice/host_profile mutations (Phase 03+ write here)."""
    __tablename__ = "change_logs"
    
    id: int (PK)
    entity_type: str (index)           # 'contract' | 'invoice' | 'host_profile' | ...
    entity_id: int (index)             # PK of affected row
    actor_id: int (FK users.id, nullable)  # who made the change
    action: str                        # 'create' | 'update' | 'status_change' | 'delete'
    before_json: str (Text, nullable)  # state before change
    after_json: str (Text, nullable)   # state after change
    created_at: datetime (index)
```

**Schema design notes:**
- `actor_id` is nullable (for system-generated actions)
- JSON blobs allow arbitrary state capture (no rigid before/after schema)
- No `host_id` column — audit is tied to entity + actor, not owner

### 3.2 Centralized Audit Service

**File:** `app/repositories/audit.py:28-59`

Single function `write_change_log()`:
```python
def write_change_log(
    db: Session,
    entity_type: str,
    entity_id: int,
    actor_id: Optional[int],
    action: str,
    before: Optional[Any] = None,
    after: Optional[Any] = None,
) -> models.ChangeLog:
    """Write a ChangeLog row. Flushes but does NOT commit — caller owns transaction."""
    entry = models.ChangeLog(
        entity_type=entity_type,
        entity_id=entity_id,
        actor_id=actor_id,
        action=action,
        before_json=json.dumps(before, default=str) if before else None,
        after_json=json.dumps(after, default=str) if after else None,
        created_at=datetime.utcnow(),
    )
    db.add(entry)
    db.flush()  # ← Flush but NOT commit
    return entry
```

**Transaction model:**
- Service calls `write_change_log()` → db.flush() (writes, not committed)
- Caller (router) owns db.commit()
- Allows multiple logs + entity mutation in single transaction
- If router commit fails, all logs roll back together

**Usage sites** (grep results show ~30+ call sites):
- `app/repositories/host_profile_repository.py:50, 79, 106` (3 profile mutations)
- `app/services/invoice_service.py:185, 220, 273, 314` (invoice lifecycle)
- `app/services/move_out_invoice_service.py:186`
- `app/services/marketplace_sync_service.py:109, 147, 309`
- `app/services/khai_bao_service.py:192, 222`
- `app/services/reservation_service.py:130, 153, 180`

### 3.3 AuditLog Table (immutable legal compliance)

**File:** `app/models.py:830-854`

```python
class AuditLog(Base):
    """Per-action audit trail for legal compliance.
    Tracks every export attempt (success + failure).
    """
    __tablename__ = "audit_logs"
    __table_args__ = (
        Index("ix_audit_logs_host_action_created", "host_id", "action", "created_at"),
    )
    
    id: int (PK)
    host_id: int (FK users.id, index) — "who is the owner"
    action: str                        # 'export_tt200' | future actions
    period: str (nullable, 7 chars)    # "YYYY-MM" for export_tt200
    success: bool
    ip: str (45 chars, nullable)       # IPv4/IPv6 support
    user_agent: str (500 chars, nullable)
    extra: str (Text, nullable)        # arbitrary JSON blob
    created_at: datetime
```

**Usage:** Currently only for export TT200 (immutable tax export, Phase 19).
**Index:** Compound `(host_id, action, created_at)` for query by owner + action + time range.

### 3.4 CCCD Access Log (PDPL compliance)

**File:** `app/models.py:264-283`

```python
class CCCDAccessLog(Base):
    """PDPL compliance audit: every CCCD file read/write is logged."""
    __tablename__ = "cccd_access_logs"
    
    id: int (PK)
    user_id: int (FK users.id, nullable) — "actor who accessed"
    file_path: str (500 chars)
    # ... more fields
```

Separate table for PII (CCCD document) access tracking (PDPL compliance).

### 3.5 Audit Pattern Analysis

**Constraint for delegation:**
- `ChangeLog.actor_id` must be set to operator_id when operator makes mutation
- Need new nullable columns in ChangeLog: `acted_via_delegation_id`, `owner_id` (denormalized for query speed)
- Or: extend `extra` JSON blob to store {owner_id, delegation_id, ...}

---

## 4. CORS & Middleware Chain

### 4.1 CORS Configuration

**File:** `main.py:153-159`

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.backend_cors_origins,  # ← from .env
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

**Current state:**
- `allow_origins` loaded from settings (likely Flutter app domain + localhost)
- `allow_headers=["*"]` means any header is allowed
- **Adding `X-Acting-As` header requires NO CORS change** (already wildcard)

### 4.2 Rate Limiter (per-user keying)

**File:** `app/middleware/rate_limit.py:14-41`

```python
def _key_func(request: Request) -> str:
    auth = request.headers.get("Authorization", "")
    if auth.lower().startswith("bearer "):
        token = auth.split(" ", 1)[1]
        try:
            payload = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
            sub = payload.get("sub")
            if sub:
                return f"user:{sub}"  # Rate limit by user_id
        except (JWTError, Exception):
            pass
    return get_remote_address(request)  # Fallback to IP

limiter = Limiter(key_func=_key_func, default_limits=[])
```

**Constraint for delegation:**
- Rate limiter keys by `user_id` (extracted from JWT `sub`)
- When operator makes request, key is `user:{operator_id}`
- **No change needed** — operator_id will be rate-limited as separate user (not conflated with owner)

### 4.3 Error Handlers

**File:** `main.py:146-151`

Three error handlers stacked:
- `RequestValidationError` → validation_handler
- `StarletteHTTPException` → http_exception_handler
- `Exception` → unhandled_exception_handler (catch-all, ensures 500 includes CORS headers)

**Constraint:** No new middleware needed for delegation context — validation happens in service/repo layer.

---

## 5. Notification System (Limited Current Implementation)

### 5.1 Notification Router

**File:** `app/routers/notifications.py:10-63`

```python
@router.get("")
def list_notifications(
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    user_id = int(claims["sub"])
    items = db.query(models.Notification).filter(
        models.Notification.user_id == user_id
    ).order_by(models.Notification.created_at.desc()).all()
    unread = db.query(models.Notification).filter(
        models.Notification.user_id == user_id,
        models.Notification.read == False
    ).count()
    return {...}
```

**Current scope:**
- Per-user notification list (in-app only)
- Mark read / mark all read endpoints
- No FCM, no push tokens, no digest jobs

**Constraint for delegation:**
- BA requirement: "Là Owner, tôi muốn nhận thông báo CHỈ cho action vượt ngưỡng" (US-O7)
- Backend must:
  1. Insert Notification row for owner when operator triggers approval-required action
  2. Future: integrate FCM for push (not in MVP)
  3. Future: implement digest scheduler (weekly summary)

---

## 6. Background Job Scheduler

### 6.1 APScheduler Setup

**File:** `app/services/planning_etl/scheduler.py:28-60`

```python
def start_scheduler() -> None:
    global _scheduler
    
    cron_enabled = os.getenv("CRON_ENABLED", "0").strip() == "1"
    if not cron_enabled:
        logger.info("CRON_ENABLED not set → scheduler skipped")
        return
    
    database_url = os.getenv("DATABASE_URL", "")
    if not database_url.startswith("postgresql"):
        logger.warning("Scheduler requires Postgres — skipped")
        return
    
    _scheduler = BackgroundScheduler(timezone="UTC")
    _scheduler.add_job(
        fetch_all_districts,
        trigger="cron",
        hour=_CRON_HOUR_UTC,  # 19:00 UTC = 02:00 Hanoi
        minute=_CRON_MINUTE_UTC,
        id=_JOB_ID,
    )
    _scheduler.start()
```

**Current usage:** Daily ETL for planning district data (geography).

**Constraint for delegation:**
- Scheduler already exists with APScheduler + BackgroundScheduler
- Can reuse for future tasks:
  - Digest job (weekly owner summary)
  - Approval auto-expiry job (if threshold-based approval not approved within X days)
  - Commission invoice generator
- Single process (no Redis lock) — fine for MVP

---

## 7. Existing Delegation-like Patterns

### 7.1 Search Results

Grep for "impersonate", "on_behalf", "acting", "delegate": **No results.**

**Implication:** No existing act-as pattern. This is greenfield.

### 7.2 Admin Super-Host Pattern

**File:** `app/auth.py:87-95`

```python
def require_host(claims: dict = Depends(require_user)) -> dict:
    """Yêu cầu role host hoặc admin. Admin được xem như super-host —
    có thể vận hành mọi host endpoint cho mục đích hỗ trợ/đối soát."""
    if claims.get("role") not in ("host", "admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Yêu cầu quyền host",
        )
    return claims
```

**Pattern:** Admin can call host endpoints without owning the property.
- **But:** repository is still instantiated with admin's user_id (claims["sub"])
- This means admin sees no data (queries filter by admin_id, not target host_id)
- **Issue:** Admin can't actually view target host's data with current repo pattern

**Insight for delegation:** The current admin pattern is broken — admin bypass not implemented. Tech Lead must decide:
1. Teach repositories to accept optional `override_host_id` parameter (for admin + delegation)
2. Or: add admin-specific endpoints that explicitly pass target_host_id

---

## 8. Database Session & Transaction Model

### 8.1 Session Factory

**File:** `app/database.py:16-28`

```python
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

**Configuration:**
- `autoflush=False` — explicit flush only (called by services)
- `autocommit=False` — explicit commit (called by routers)
- FastAPI dependency injection via `Depends(get_db)`
- Session closed in finally block

**Pattern:** 
- Router receives db Session
- Router calls service function(s) — they may call repo methods
- Service flushes audit log rows (db.flush())
- Router commits everything together (db.commit())
- If any exception: rollback automatic on session close

### 8.2 Alembic Migrations

**File locations:** `/app/alembic/versions/`

Latest migration: **0020_create_tt200_exports.py** (2026-06-28 23:40)
- Next new migrations will be 0021_*, 0022_*, etc.

**Schema version constraint:**
- DB must be on latest alembic migration before delegation tables added
- Plan to create migration 0021: create_operator_delegations + related tables

---

## 9. Status Enum Patterns

### 9.1 String-based Status Fields

**File:** `app/models.py` (grep results)

All status fields are string types, not enums:
```python
status: Mapped[str] = mapped_column(String(20), default="pending", index=True)
```

**Valid values per entity type** (inferred from code, not exhaustive):

| Entity | Status Values | Default | References |
|--------|---------------|---------|------------|
| Contract | `draft`, `active`, `terminated` | `draft` | contract_service.py state machine |
| Invoice | `draft`, `pending`, `paid`, `cancelled` | `draft` | invoice_service.py lifecycle |
| KhaiBaoTamTru | `pending`, `approved`, `rejected` | `pending` | khai_bao_service.py workflow |
| Reservation | `pending`, `confirmed`, `cancelled` | `pending` | reservation_service.py |
| House/Room | `pending`, `vacant` | varies | marketplace_integration |
| Viewing Appointment | `pending`, `confirmed` | `pending` | viewing_appointment schema |

**Constraint for delegation:**
- New `OperatorDelegation` table needs status field
- BA suggests: `pending`, `active`, `frozen`, `terminated`
- Implement as string(20), not python Enum (matches codebase convention)

---

## 10. Models.py Comprehensive Scan

### 10.1 Key Tables (20+ with host_id)

Detailed line-by-line references for Tech Lead:

| Table | Lines | Model Name | Foreign Keys | Indexes |
|-------|-------|-----------|--------------|---------|
| users | 1–40 | User | none | (email UNIQUE) |
| Notification | 43–60 | Notification | user_id FK | (user_id, created_at) |
| House | 63–130 | House | host_id FK (1) | (host_id, status) |
| ViewingAppointment | 133–150 | ViewingAppointment | guest_id, house_id FKs | multiple |
| Wishlist | 153–180 | Wishlist | guest_id, house_id FKs | multiple |
| Review | 188–242 | Review | house_id, author_id FKs | multiple |
| **ChangeLog** | 244–262 | ChangeLog | actor_id FK (nullable) | (entity_type, entity_id, actor_id, created_at) |
| CCCDAccessLog | 264–283 | CCCDAccessLog | user_id FK (nullable) | (user_id, created_at) |
| Building | 285–315 | Building | host_id FK | (host_id, name, city, status) |
| Room | 317–375 | Room | host_id, building_id FKs | (host_id, building_id, status) |
| Tenant | 343–375 | Tenant | host_id FK | (host_id, email, phone, status) |
| Contract | 377–420 | Contract | host_id, room_id, tenant_id FKs | (host_id, room_id, status, start_date, end_date) |
| ContractTenant | 422–448 | ContractTenant | contract_id, tenant_id FKs (pivot) | (contract_id, tenant_id, is_primary) |
| ServiceFee | 450–487 | ServiceFee | host_id FK | (host_id, contract_id) |
| MeterReading | 489–516 | MeterReading | host_id, room_id FKs | (host_id, room_id, created_at) |
| Invoice | 518–574 | Invoice | host_id, contract_id, service_fee_id FKs | (host_id, contract_id, status, created_at) |
| Payment | 576–596 | Payment | host_id, invoice_id FKs | (host_id, invoice_id, created_at) |
| CreditNote | 598–641 | CreditNote | host_id, invoice_id FKs | (host_id, invoice_id, created_at) |
| KhaiBaoTamTru | 643–691 | KhaiBaoTamTru | host_id FK | (host_id, status, created_at) |
| Availability | 693–727 | Availability | host_id, room_id FKs | (host_id, room_id) |
| PricingRule | 729–776 | PricingRule | host_id FK | (host_id) |
| Reservation | 778–828 | Reservation | host_id, house_id FKs | (host_id, house_id, status) |
| **AuditLog** | 830–855 | AuditLog | host_id FK | (ix_audit_logs_host_action_created) |
| Tt200Export | 874–900 | Tt200Export | host_id FK | (host_id) |
| RevenueSource | 225–240 | RevenueSource | host_id FK | (host_id, name) |

**FK constraints overview:**
- Most use `ondelete="CASCADE"` (e.g., Building → Room → Contract cascade)
- AuditLog uses explicit `ondelete="CASCADE"`
- No soft-delete flags (except Building has soft_delete method override)

---

## 11. Existing Constraints & Gotchas

### 11.1 Admin Bypass Not Fully Implemented

**Issue:** `require_host` allows admin to call host endpoints, but repositories filter by `claims["sub"]` (admin's user_id), not target host.

**Example:** Admin calls GET /api/host/buildings, gets empty list (filtered to admin's buildings, which are none).

**Fix needed before delegation:** Add optional `override_host_id` parameter to HostScopedRepository, or create admin-specific query helpers.

### 11.2 No Custom Request Context Pattern

- No request-scoped context store (no threadlocal, no contextvars)
- Each endpoint extracts values from claims/header independently
- **Implication:** `X-Acting-As` header must be read + validated at every service boundary (no magic per-request context)

### 11.3 No Permission Matrix or RBAC Engine

- Only role-based coarse gating (guest/host/admin)
- No fine-grained permissions (e.g., "can-create-invoice", "can-approve-expense")
- **Implication:** Delegation permissions (4 presets: owner-view, operator-full, accountant, viewer) must be hardcoded in service layer, not external config

### 11.4 Rate Limiter Keys by User

- User-based rate limiting (not property-based or delegation-based)
- Operator will have own rate limit bucket (separate from owner)
- Acceptable for MVP

### 11.5 Session Handling (No Advisory Locks)

- No PostgreSQL advisory locks for concurrency control
- Multiple requests to same property in parallel: no lock, rely on DB constraints
- **Implication:** Concurrent operator mutations on same contract possible (race conditions on state transitions unlikely due to state machine, but payment records could double-record)

### 11.6 Audit Log Doesn't Capture Delegation Context

- ChangeLog has `actor_id` but no `owner_id` or `acted_via_delegation_id`
- **Must add:** nullable columns `owner_id` + `acted_via_delegation_id` (or extend JSON `extra` blob)

---

## 12. Schema Diagram: Current host_id Dependency

```
User (id, role, email, ...)
  ↓ PK
  ├─ House (host_id FK) → ViewingAppointment, Wishlist, Review, Reservation
  ├─ Building (host_id FK) → Room → Contract → ContractTenant, ServiceFee, Invoice
  ├─ Tenant (host_id FK)
  ├─ MeterReading (host_id FK)
  ├─ Payment (host_id FK)
  ├─ CreditNote (host_id FK)
  ├─ KhaiBaoTamTru (host_id FK)
  ├─ Availability (host_id FK)
  ├─ PricingRule (host_id FK)
  ├─ RevenueSource (host_id FK)
  ├─ AuditLog (host_id FK, immutable)
  └─ Tt200Export (host_id FK, immutable)

[Audit/Compliance]
  ├─ ChangeLog (actor_id FK → user, entity_type, entity_id, action, before/after JSON)
  └─ CCCDAccessLog (user_id FK → user, file_path)
```

---

## 13. Unresolved Questions & Constraints for Tech Lead

### Q1: Admin Bypass Pattern
**Question:** When admin calls GET /api/host/buildings/{building_id}, do we:
- (A) Make admin see target host's data (currently broken)?
- (B) Forbid admin from host endpoints entirely (use new admin_* routers)?
- (C) Pass explicit `?as_host_id=X` query param (awkward)?

**Impact:** Delegation delegation might reuse same pattern (operator passes `?as_owner_id=X`).

### Q2: Notification Delivery Channel
**Question:** Current notifications.py only supports in-app. BA requires:
- Owner notification when operator does approval-required action
- (P1) Weekly digest email/Zalo

**Decision needed:** Integrate Zalo/email service now or defer to Phase 2?

### Q3: ChangeLog Schema Extension
**Question:** Add explicit columns to ChangeLog, or extend `extra` JSON blob?
- (A) Add `owner_id`, `acted_via_delegation_id`, `approval_threshold_exceeded` as columns (cleaner queries)
- (B) Extend `extra` JSON (backward-compatible, slower to query)

**Impact:** Query performance for owner's audit report (might filter by delegation_id).

### Q4: Rate Limiter for Approval-Required Actions
**Question:** When operator hits approval threshold repeatedly, does operator's rate limit apply or owner's?
- Current: user:{operator_id} bucket
- Risk: operator floods owner with approval requests

**Decision:** Implement separate quota for approval-threshold actions, or accept MVP limitation?

### Q5: Session Concurrency (Advisory Locks)
**Question:** Do we need PostgreSQL advisory locks for concurrent mutations on same contract?
- Example: Operator + Owner both update contract fields simultaneously
- Current: No locks, last-write-wins (dangerous for financial records)

**Decision:** Implement pessimistic locking (advisory locks) or accept risk for MVP?

### Q6: Operator Role Assignment (JWT Claims)
**Question:** When operator logs in, do we need new JWT claim to signal "this user can operate"?
- Current: role='guest' for new users, upgraded to 'host' via upgrade-to-host flow
- Operator cca nhân: also 'host' role? Or new role 'operator'?
- Operator doanh nghiệp: 'operator' role?

**Decision:** Keep single role per JWT, determine operator status by querying OperatorDelegation table per-request?

---

## 14. Recommendations for Tech Lead Planning Phase

### Must-Do Before Implementation
1. Extend ChangeLog schema (add owner_id, acted_via_delegation_id columns)
2. Create OperatorDelegation + DelegationInvitation + DelegationApproval tables (alembic 0021)
3. Decide: admin bypass pattern (impacts repository layer)
4. Extend HostScopedRepository to accept optional override_host_id
5. Create new service layer: delegation_service.py (permission checks, audit writes)

### Nice-to-Have (P1+)
1. Notification delivery channels (Zalo, email)
2. Approval threshold digest scheduler
3. Advisory lock wrapper for concurrent contract mutations

### Out-of-Scope (Explicitly defer)
1. Organization model (for PMC multi-tier — Phase ?2, 2026-Q4)
2. FCM push tokens (draft schema exists, not integrated)
3. Super-admin impersonation tool (use delegation instead)

---

## 15. File Index for Tech Lead

### Auth Layer
- `app/auth.py` — JWT signing, verification, role checks, IDOR helper
- `app/routers/auth_router.py` — login, register, reauth (export), password reset

### Repository Pattern
- `app/repositories/base.py` — HostScopedRepository (core isolation mechanism)
- `app/repositories/building_repository.py` — sample concrete repo
- `app/repositories/contract_repository.py` — sample with state machine
- `app/repositories/audit.py` — centralized write_change_log() function

### Routers (3 samples showing host pattern)
- `app/routers/host_building.py` — CRUD with list/create/patch/delete
- `app/routers/host_contract.py` — with helper enrichment + state transitions
- `app/routers/host_invoice.py` — (similar pattern, not fully read)

### Models & Audit
- `app/models.py` — all 16 host_id tables + ChangeLog + AuditLog + CCCDAccessLog
- `app/database.py` — SessionLocal setup, get_db() dependency

### Infrastructure
- `main.py` — CORS, rate limiter, error handlers, router registration
- `app/middleware/rate_limit.py` — per-user rate limit keying
- `app/services/planning_etl/scheduler.py` — APScheduler setup (reusable)

### Notifications (Limited)
- `app/routers/notifications.py` — in-app only, no push/email yet

---

## Conclusion

The backend auth surface is straightforward:
- **JWT-based** with role hierarchy (guest/host/admin)
- **Repository pattern** auto-injects host_id on every query (core isolation mechanism works)
- **Audit logging** already centralized (write_change_log) — just needs context extension
- **No custom RBAC** — implement delegation presets in service layer
- **CORS & middleware** already flexible (no config changes needed for X-Acting-As header)
- **One gotcha:** admin bypass pattern broken (not urgent, but must fix before delegation)

Tech Lead can proceed with Phase 3 planning. No architectural blockers identified.

---

**Status:** DONE  
**Report saved:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-app/plans/260629-0116-owner-operator-delegation/research/01-backend-auth-permission-surface.md`
