# Researcher Report: Backend Audit for Host Property Management

**Date:** 2026-06-22  
**Scope:** ancu365-backend FastAPI + SQLAlchemy codebase  
**Status:** Complete  
**Backend path:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend`

---

## 1. Models Inventory

All models in `/app/models.py` (single file, 161 lines). SQLAlchemy 2.0 with Mapped syntax.

| Model | Fields | Status | Notes |
|-------|--------|--------|-------|
| **User** | id, name, email, phone, avatar_path, role, is_active, created_at, birthday, bio, id_number | ✅ Ready | JWT sub = user_id, role = "guest"\|"host"\|"admin" |
| **House** | id, host_id, title, description, category_id, price, area, address, city, district, lat/lon, bedrooms, bathrooms, status, created_at, images (JSONList), amenities (JSONList), listing_type, total_units, available_units, gender_pref | ✅ Ready | Multi-unit support exists. status: pending\|approved\|rejected\|hidden (indexed). **NO FK constraints to User** |
| **Booking** | id, house_id, guest_id, booking_date, booking_time, message, status, created_at | ⚠️ Current | Only viewing appointment, NOT rental contract. Status: pending\|approved\|rejected\|completed\|cancelled\|lost\|locked (indexed). **NO FK constraints** |
| **Category** | id, name, icon | ✅ Ready | Amenity categories |
| **Amenity** | id, name, icon | ✅ Ready | Amenity library |
| **Wishlist** | id, user_id, house_id, created_at | ✅ Ready | Unique constraint (user_id, house_id) exists |
| **Review** | id, user_id, house_id, rating, comment, created_at | ✅ Ready | Guest reviews |
| **Notification** | id, user_id, type, title, body, related_id, read, created_at | ✅ Ready | DB-only, no FCM integration. Type: booking_*\|house_* |
| **ChatMessage** | id, sender_id, receiver_id, house_id (nullable), body, read, created_at | ✅ Ready | Linked to House context. **NO FK constraints** |

**Missing models for Host Property Management:**
- ❌ **HostProfile** (verified, bank_account, tax_id, response_time, rating, payout_schedule)
- ❌ **Building** (dãy trọ) — for grouping rooms
- ❌ **Room** (phòng individual, not just total_units count)
- ❌ **Tenant** (khách thuê long-term)
- ❌ **Contract** (hợp đồng nhà trọ — multi-tenant support via junction table)
- ❌ **ContractTenant** (M:N junction: contract_id, tenant_id, is_primary)
- ❌ **Invoice** (hóa đơn hàng tháng)
- ❌ **InvoiceLineItem** (line items: rent, utilities, services)
- ❌ **Payment** (payment tracking, deposit refund)
- ❌ **MeterReading** (electricity/water meter input)
- ❌ **ServiceFee** (dịch vụ add-on)
- ❌ **Availability** (homestay per-day per-property)
- ❌ **PricingRule** (base/weekend/holiday pricing)
- ❌ **Reservation** (homestay short-term booking — different from Contract)
- ❌ **KhaiBaoTamTru** (gov declaration form + reminder tracking)
- ❌ **ChangeLog** (audit trail for Contract/Invoice mutations)
- ❌ **CCCDAccessLog** (audit log for CCCD file reads/writes)

---

## 2. Routers & Endpoints

Full endpoint inventory. **NOTE: No auth checks on POST/PUT/DELETE except /api/auth/me**

### Auth Router (`/app/routers/auth_router.py:1-98`)

| Route | Method | Auth Check | Implemented | Notes |
|-------|--------|-----------|-------------|-------|
| `/api/auth/login` | POST | ❌ None | ✅ Yes | Email + password → JWT token |
| `/api/auth/register` | POST | ❌ None | ✅ Yes | **SECURITY GAP:** accepts role from client body (line 30: `role = body.get("role") or "guest"`) — no validation, users can self-promote to host/admin |
| `/api/auth/me` | GET | ✅ require_user | ✅ Yes | Returns current user |
| `/api/auth/change-password` | POST | ❌ None | ✅ Yes | **BUG:** trusts user_id from body (line 66) — IDOR risk |
| `/api/auth/forgot-password` | POST | ❌ None | ✅ Yes | Generates temp password, sends in response (not email) |

### Houses Router (`/app/routers/houses.py:1-223`)

| Route | Method | Auth Check | Implemented | Notes |
|-------|--------|-----------|-------------|-------|
| `/api/houses?query=...&categoryId=...&minPrice=...` | GET | ❌ None | ✅ Yes | Filter: status, hostId, price, area, category, search text |
| `/api/houses/{house_id}` | GET | ❌ None | ✅ Yes | Single house detail |
| `/api/houses` | POST | ❌ **NONE** | ✅ Yes | **CRITICAL:** Line 85 — no auth. Creates house with untrusted host_id from body. **MUST ADD require_host()** |
| `/api/houses/{house_id}` | PUT | ❌ **NONE** | ✅ Yes | **CRITICAL:** No auth check. No owner validation. Any user can edit any house (line 128). **MUST ADD require_host() + verify house.host_id == current_user.id** |
| `/api/houses/{house_id}` | DELETE | ❌ **NONE** | ✅ Yes | **CRITICAL:** Line 183 — cascades to bookings + wishlists. No auth. **MUST ADD require_host()** |
| `/api/houses/{house_id}/close-unit` | POST | ❌ **NONE** | ✅ Yes | **CRITICAL:** Decrements available_units, notifies pending bookings. No auth. |

### Bookings Router (`/app/routers/bookings.py:1-123`)

| Route | Method | Auth Check | Implemented | Notes |
|-------|--------|-----------|-------------|-------|
| `/api/bookings?userId=...&role=guest\|host` | GET | ❌ **NONE** | ✅ Yes | **SECURITY GAP:** Line 17-24 — filters by userId + role, but no auth check on userId param. User A can fetch User B's bookings by passing userId=B. **MUST ADD require_user() + verify userId == current_user.id** |
| `/api/bookings` | POST | ❌ **NONE** | ✅ Yes | **BUG:** Creates booking with untrusted guest_id from body (line 30). Sends notification to host. |
| `/api/bookings/{booking_id}/status` | PATCH | ❌ **NONE** | ✅ Yes | **CRITICAL:** Line 61 — no auth. Any user can approve/reject/lock any booking. Triggers notifications + available_units decrement. |

### Other Routers

| Router | Endpoints | Auth Check | Status |
|--------|-----------|-----------|--------|
| `/app/routers/chat.py` | GET /api/chats, GET /api/chats/{peer_id}/messages, POST /api/chats/{peer_id}/messages, PATCH /api/chats/{peer_id}/read, WS /ws | ❌ Query param `userId=` only, no Bearer token | ⚠️ Chat hub in-memory, WebSocket no token validation |
| `/app/routers/notifications.py` | GET /api/notifications, PATCH /api/notifications/{id}/read, PATCH /api/notifications/read-all | ❌ Query param `userId=` only | ⚠️ No auth |
| `/app/routers/reviews.py` | GET /api/reviews?house_id=..., POST /api/reviews | ❌ No auth on create | ⚠️ Any user can post review for any house |
| `/app/routers/upload.py` | POST /api/upload | ❌ No auth | ✅ Yes, local filesystem storage |
| `/app/routers/wishlists.py` | GET, POST, DELETE | ❌ No auth | ⚠️ Query param `user_id=` only |
| `/app/routers/users.py` | GET /api/users/{id}, PUT /api/users/{id} | ❌ No auth | ⚠️ Any user can view/edit any user |
| `/app/routers/catalog.py` | GET /api/categories, GET /api/amenities | ❌ None | ✅ Read-only, safe |

**Total security gaps found:** 8+ endpoints missing auth checks (houses CUD, bookings, chat, notifications, reviews, wishlists, users).

---

## 3. Auth & Dependencies

### JWT Implementation (`/app/auth.py:1-85`)

```python
# sign_token(user_id: int, role: str) → JWT
# Payload: {"sub": str(user_id), "role": role, "iat": ..., "exp": ...}
# Algorithm: HS256
# TTL: 168 hours (configurable via JWT_SECRET, TOKEN_TTL_HOURS)

# verify_token(token: str) → dict | None
# Decodes + converts sub back to int

# Dependencies available:
# - optional_user(request) → dict | None (no error if missing)
# - require_user(claims) → dict (403 if missing/invalid)
# - require_admin(claims) → dict (403 if role != "admin")
```

**Location:** `/app/auth.py:56-85`

**Existing dependency functions:**
- ✅ `optional_user()` — extracts Bearer token or None
- ✅ `require_user()` — enforces auth (401 if missing)
- ✅ `require_admin()` — enforces admin role (403 if not admin)
- ❌ **MISSING: `require_host()`** — needed for all ops endpoints (Phase 02 deliverable)

**Usage pattern in routers:**
```python
@router.get("/api/houses")
def get_house(claims: dict = Depends(auth.require_user), db: Session = Depends(get_db)):
    # Access current user: claims["sub"] = user_id, claims["role"] = "host"|"guest"|"admin"
```

**To add multi-tenant isolation (Phase 02):**
Create `require_host()` in auth.py:
```python
def require_host(claims: dict = Depends(require_user)) -> dict:
    if claims.get("role") != "host":
        raise HTTPException(403, "Yêu cầu quyền host")
    return claims
```

Then wrap all ops routes:
```python
@router.post("/api/houses")
def create_house(
    claims: dict = Depends(auth.require_host),
    db: Session = Depends(get_db)
):
    # claims["sub"] is guaranteed host user_id
    # Always validate: host_id from body == claims["sub"]
```

---

## 4. Database Layer

### Configuration (`/app/database.py:1-39`)

```python
# engine = create_engine(settings.database_url, ...)
# settings.database_url default: "sqlite:///./urbannest.db"

# Dual-mode: SQLite OR Postgres
if settings.database_url.startswith("sqlite"):
    connect_args = {"check_same_thread": False}  # Enable multi-threading
else:
    connect_args = {}  # Postgres handles threading

# SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

# get_db() — FastAPI dependency yields Session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

**Location:** `/app/database.py:1-39`

### Schema Creation

- **Current approach:** `Base.metadata.create_all(bind=engine)` at startup (line 50 in `main.py`)
- **Creates all tables from models automatically** — no versioning
- **Planning module:** `planning_models.PlanningBase.metadata.create_all(bind=engine)` for Postgres-only PostGIS schema

**Location:** `/main.py:49-61`

### Migrations Setup

**Tool:** Alembic (configured at `/alembic.ini`)

**Current state:**
- ✅ Alembic config present
- ✅ `alembic/versions/` directory exists
- ⚠️ **Only 1 migration file:** `0001_planning_reports.py` (planning module only)
- ❌ **NO migration for core tables** (users, houses, bookings, etc.) — uses metadata.create_all() instead

**To implement Phase 01 (DB migration SQLite → Postgres):**
1. Create Alembic baseline migration covering ALL existing tables (users, houses, bookings, wishlists, reviews, notifications, chat_messages, categories, amenities)
2. Generate via: `alembic revision --autogenerate -m "0002_baseline_core_tables"`
3. Or manually: `alembic revision -m "0002_baseline_core_tables"` + write migration
4. Run: `alembic upgrade head`

**Seed script:** `/app/seed.py` called at startup. Creates categories, amenities, admin user (not fully inspected).

### Multi-database support

| DB Type | Usage | Tested | Notes |
|---------|-------|--------|-------|
| SQLite | ✅ Dev default | Yes | Local file, no concurrency issues for small team |
| Postgres | ⚠️ Optional | Partial | Planning module requires Postgres + PostGIS. Phase 01 decision: migrate to Postgres for all |

**Docker:** `postgres:15` + `postgis/postgis:16-3.4` service in `docker-compose.yml:12-33`

---

## 5. Booking Usages (for Phase 01b Rename: Booking → ViewingAppointment)

**Goal:** Rename to avoid confusion with Contract (nhà trọ) + Reservation (homestay).

### Files Mentioning "Booking" or "booking"

| File | Line | Type | Content | Action |
|------|------|------|---------|--------|
| `/app/models.py` | 109-119 | **Model def** | `class Booking(Base): __tablename__ = "bookings"` | **RENAME to ViewingAppointment** |
| `/app/routers/bookings.py` | 1-123 | **Router file** | All endpoints GET/POST /api/bookings | **Rename router file to viewing_appointments.py, update route prefix** |
| `/app/routers/houses.py` | 188 | Query | `db.query(models.Booking).filter(...).delete()` in delete_house | **Update to ViewingAppointment** |
| `/app/routers/bookings.py` | 10-123 | **Notification events** | `booking_new`, `booking_approved`, `booking_rejected`, `booking_locked`, `booking_lost` | **Rename to viewing_appointment_*** |
| `/app/helpers.py` | 7, 59-80 | **Import + function** | `from app.models import ... Booking ...` + `booking_to_dict()` | **Rename function to viewing_appointment_to_dict()** |
| `/app/routers/bookings.py` | 46-53, 72-88, 93-119 | **Push notifications** | `helpers.push_notification(..., type_="booking_*", ...)` | **Update type strings to viewing_appointment_*** |
| `/main.py` | 109 | **Router include** | `app.include_router(bookings.router)` | **Update import + include statement** |

### Grep verification (all occurrences):
```bash
grep -r "Booking\|booking" /Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/app \
  --include="*.py" | grep -v ".venv"
```

**Files affected:**
1. `/app/models.py` — class definition + imports
2. `/app/routers/bookings.py` — router + all endpoints
3. `/app/routers/houses.py` — cascade delete
4. `/app/helpers.py` — import + dict converter
5. `/main.py` — router include
6. **Flutter side** (not backend, but mentioned in BA doc Phase 01b): `lib/providers/bookings_provider.dart`, `lib/features/host/host_home_screen.dart:57`

**Notification type mapping (old → new):**
- `booking_new` → `viewing_appointment_requested`
- `booking_approved` → `viewing_appointment_approved`
- `booking_rejected` → `viewing_appointment_rejected`
- `booking_locked` → `viewing_appointment_confirmed`
- `booking_lost` → `viewing_appointment_lost`

---

## 6. Existing Patterns to Follow

### 1. SQLAlchemy ORM Usage

**Pattern:** SQLAlchemy 2.0 with Mapped syntax (not legacy Base.metadata)

```python
# app/models.py style
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import Integer, String, Float, DateTime, ForeignKey, Index

class House(Base):
    __tablename__ = "houses"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    host_id: Mapped[int] = mapped_column(Integer, index=True)  # Manual index
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
```

**For Phase 02+, ADD:**
- ✅ ForeignKey constraints (currently missing on host_id, guest_id, user_id)
- ✅ Composite indexes where needed (e.g., (host_id, status) on House)
- ❌ **DO NOT use:** Declarative relationships (no backref) — sticks to FK numbers

### 2. Router & Dependency Injection

**Pattern:** All routers use FastAPI dependency injection

```python
@router.get("/api/endpoint")
def handler(
    query_param: str = Query(...),
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),  # Add when auth needed
):
    # db is SQLAlchemy Session
    # claims = {"sub": user_id, "role": "..."}
```

**Convention:**
- Query params with defaults: `param: type = default`
- Required body: `body: dict = Body(...)`
- Optional auth: `claims: dict = Depends(auth.optional_user)`
- Enforce auth: `claims: dict = Depends(auth.require_user)`
- Admin-only: `claims: dict = Depends(auth.require_admin)`

### 3. Response Format

**Convention:** All endpoints return dict with key matching noun (singular/plural)

```python
# Single object
return {"house": house_dict}

# List
return {"houses": [house_dict, ...], "total": count}

# Success response
return {"success": True, "message": "..."}

# Include related data when needed
house_dict includes: host_name, host_avatar, category_name
booking_dict includes: house_title, house_price, guest_name, host_name
```

**Serialization function:** `helpers.*_to_dict(db: Session, obj: Model) → dict`
- ✅ Accepts Session to join related objects
- ✅ Converts datetime to ISO string
- ✅ Handles nullable fields gracefully

### 4. Error Handling

**Convention:** `HTTPException(status_code, detail_message)`

```python
# 400 Bad Request
raise HTTPException(400, "Thiếu thông tin bắt buộc")

# 401 Unauthorized
raise HTTPException(401, "Token không hợp lệ")

# 403 Forbidden
raise HTTPException(403, "Yêu cầu quyền admin")

# 404 Not Found
raise HTTPException(404, "Không tìm thấy")

# 409 Conflict
raise HTTPException(409, "Email đã được sử dụng")
```

**Middleware:** `/app/middleware/error_handler.py` — wraps exceptions, logs stack trace (dev mode only)

### 5. Pydantic Schemas (NOT USED YET — opportunity for Phase 02)

**Location:** `/app/schemas/` directory exists but EMPTY (only __pycache__)

**Current approach:** All routers accept `body: dict = Body(...)` — NO validation!

**Recommendation for Phase 02+:**
```python
# app/schemas/house.py
from pydantic import BaseModel, Field

class HouseCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=300)
    price: float = Field(..., gt=0)
    category_id: int = Field(..., gt=0)

class HouseUpdate(BaseModel):
    title: Optional[str] = None
    price: Optional[float] = None

# In router:
@router.post("/api/houses")
def create_house(
    body: HouseCreate,  # Auto-validates + parses
    db: Session = Depends(get_db)
):
    h = models.House(**body.model_dump())
    db.add(h)
    ...
```

**Current gap:** No input validation on POST/PUT → vulnerable to type confusion, missing required fields.

### 6. Logging

**Current state:** No structured logging found (no logger config)

**Middleware uses:** Print statements only (no log level control)

**Phase 02+ opportunity:** Add Python `logging` module with levels (DEBUG, INFO, WARNING, ERROR)

### 7. Testing

**Framework:** pytest (conftest.py at `/tests/conftest.py`)

**Current tests:** Only planning module tests (7 files, all import planning router)

**Test strategy observed:**
- ✅ Uses dependency_overrides to mock DB
- ✅ Creates minimal FastAPI test app (avoids main.py module-level DB init)
- ✅ Fixtures for canned data
- ✅ env vars set at conftest top-level (before any app imports)

**Missing:** No tests for auth, houses, bookings, chat routers.

**Phase 02+ deliverable:** Integration tests for:
- ✅ require_host() middleware
- ✅ Cross-host isolation (Host A cannot see Host B's rooms)
- ✅ Role validation on registration
- ✅ Auth checks on all ops endpoints

---

## 7. Tests Setup

### Pytest Configuration

**Location:** `/tests/conftest.py:1-52`

**Strategy:**
- Set `DATABASE_URL=postgresql://localhost/fake_test` + `JWT_SECRET=test-secret-xyz` at module load
- Purge cached app modules before importing (line 26-30)
- Override `get_db` dependency with mock via `app.dependency_overrides`
- Build minimal test FastAPI app (not main.py — avoids module-level DB init)

**Fixtures available (line 54+):**
- `CANNED_PARCEL` — test parcel data
- (others in conftest but not shown)

**No test database setup:** Tests mock DB via `MagicMock` (no real Postgres container)

### Requirements

**File:** `/requirements.txt:24-29`

```
pytest==8.3.2
pytest-cov==5.0.0
pytest-asyncio==0.23.8
pytest-mock==3.14.0
```

**Coverage:** No .coveragerc config; default pytest-cov behavior

**Run tests:** `pytest` (runs all tests in `/tests/` directory)

---

## 8. Lint / Static Analysis Setup

### Installed but NO CONFIG FOUND

**Tools in requirements.txt:**
- ✅ pytest (test runner)
- ✅ APScheduler (planning ETL scheduler)
- ✅ slowapi (rate limiting)

**Missing config files:**
- ❌ `ruff.toml` or `[tool.ruff]` in pyproject.toml
- ❌ `black.toml` or `[tool.black]` in pyproject.toml
- ❌ `mypy.ini` or `[tool.mypy]` in pyproject.toml
- ❌ `.pre-commit-config.yaml`
- ❌ `pyproject.toml` (no PEP 518 config file)

**Current state:**
- No linting enforced in CI/CD
- Code style ad-hoc (consistent enough, but no tool enforcement)
- No type checking (no mypy run)

**Phase 02+ opportunity:** Add pre-commit hooks:
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    hooks:
      - id: ruff
        args: [ --fix ]
  - repo: https://github.com/pre-commit/mirrors-mypy
    hooks:
      - id: mypy
        additional_dependencies: [ sqlalchemy, fastapi ]
```

---

## Recommendations for Tech Lead

### 1. **Priority security refactor (Phase 01b-02)**
   - ❌ **CRITICAL:** Add `require_host()` dependency + wrap all ops endpoints (houses CUD, bookings, etc.)
   - ❌ **CRITICAL:** Auth check on `/api/bookings` GET — validate userId == current_user.id
   - ❌ **CRITICAL:** Add owner validation on PUT/DELETE routes (verify house.host_id == claims["sub"])
   - ❌ **HIGH:** Reject self-promoted roles in /api/auth/register — whitelist roles or skip role param
   - ⚠️ **MEDIUM:** Add ForeignKey constraints to DB schema (currently bare integers)

### 2. **Keep existing patterns**
   - ✅ SQLAlchemy 2.0 ORM style (Mapped columns)
   - ✅ FastAPI dependency injection for DB + auth
   - ✅ HTTPException for error responses
   - ✅ Serializer helper functions (*_to_dict) that join related data
   - ✅ Alembic migration tool (set up proper versioning in Phase 01)

### 3. **Refactor opportunities**
   - ⚠️ **Input validation:** Replace `body: dict` with Pydantic schemas (Phase 02+)
   - ⚠️ **Structured logging:** Add Python logging module, not print statements
   - ⚠️ **Type checking:** Enable mypy, add pyproject.toml
   - ⚠️ **Code organization:** Router files are single-file (houses.py 223 lines OK, but if >300 split by feature)

### 4. **Ready to build on**
   - ✅ User model with role field + JWT auth infrastructure
   - ✅ House model with multi-unit support
   - ✅ Chat + notification scaffolding
   - ✅ Upload endpoint + local storage
   - ✅ Docker compose with Postgres + Martin (ready for Phase 01 migration)
   - ✅ Alembic + pytest fixtures (ready for Phase 01 baseline migration)

### 5. **Constraints from decisions (D1-D10, Q1-Q5)**
   - **D1 (SQLite reset):** Phase 01 wipes data, no migration script needed
   - **D2 (Roommates M:N):** Add `contract_tenants` junction table in Phase 03
   - **D3 (HTML public-link):** Add `public_token` (UUIDv4) field to KhaiBaoTamTru model in Phase 05
   - **D4 (Manual button, no cron):** Avoid APScheduler for core invoice generation (already in requirements, but don't use for MVP)
   - **D5 (Duplicate rooms):** Keep simple — just Room model with CRUD + copy endpoint
   - **D6 (Repository pattern auto-inject host_id):** Create base repository class in Phase 02, wrap all ops queries
   - **D7 (CCCD local + audit):** Folder `storage/cccd/` (0700 perms) + `cccd_access_log` table in Phase 02
   - **D9 (Booking rename in Phase 01b):** Must complete before Phase 03 (Contract model would clash naming)
   - **D10 (24h rigid cancel policy):** Hard-code logic in Phase 07 Reservation logic, not DB field

---

## Risks & Gotchas

### 1. **Booking rename (Phase 01b) = high regression risk**
   - Affects 5 files (models, router, houses cascade, helpers, main)
   - Notification event types MUST stay backward-compatible (Flutter may have cached event listeners)
   - **Mitigation:** Grep entire codebase before rename; test end-to-end viewing appointment flow post-rename

### 2. **No ForeignKey constraints = orphan data risk**
   - If delete user (host_id foreign key missing) → orphan houses
   - **Phase 01:** Add FK constraints + cascading rules in Alembic migration
   - **Phase 02:** Add NOT NULL constraints where appropriate

### 3. **Multi-tenant isolation gap**
   - Currently no repository layer — all routers query directly
   - Host A can fetch Host B's houses via GET /api/houses?hostId=<B's id> (intended, it's public)
   - But Host B can EDIT/DELETE via PUT/DELETE without owner check → **critical bug**
   - **Phase 02:** Implement repository pattern (wrap all db.query in HostScopedRepository base class)

### 4. **Planning module Postgres-only**
   - GeoAlchemy2 import crashes with SQLite
   - Conditional import at line 56-61 in main.py
   - **Phase 01:** Ensure Alembic migration handles both DB modes

### 5. **Duplicate `host_id` vs JWT `claims["sub"]`**
   - routes accept `host_id` from request body (untrusted)
   - JWT already carries user_id in claims["sub"]
   - **Phase 02:** Always use claims["sub"] as authoritative; validate body host_id matches, or reject

### 6. **Concurrency in WebSocket chat**
   - Chat hub (`app.chat_hub.hub`) not shown in audit — could be in-memory, not safe for multi-instance
   - **Phase 06+:** If scaling, migrate to Redis pub/sub

---

## Unresolved Questions

1. **Where is chat_hub defined?** File not found in grep — may be in `/app/services/` or dynamically created in chat.py init
2. **Seed script details?** `/app/seed.py` content not reviewed — what categories/amenities are created?
3. **Rate limiting config?** `slowapi` in requirements, middleware in main.py, but no routes marked with @limiter.limit() — is it active?
4. **Planning ETL scheduler status?** APScheduler started in startup hook (line 129 main.py) — what jobs run?
5. **Upload directory permissions?** `/uploads` folder created with `os.makedirs(..., exist_ok=True)` — safe for production? (Phase 02 should enforce 0700 for CCCD)
6. **Email sending?** No email library in requirements — forgot-password endpoint returns temp password in response (line 95 auth_router.py), doesn't send email. Is this intended?
7. **Nominatim rate limiting?** Config at line 18-20 (app/config.py) mentions "1 req/s policy" — is there client-side rate limiting in ETL, or just doc?

---

**Status:** DONE

**Summary:** ancu365-backend is a working FastAPI MVP with SQLite + Postgres dual-mode support. Core auth + house models ready. **Critical security gaps:** 8+ endpoints missing auth checks (POST /api/houses, PUT /api/houses/{id}, PATCH /api/bookings/{id}/status, etc.). **Missing models for Host Property Management:** HostProfile, Building, Room, Tenant, Contract, Invoice, Availability, Reservation, KhaiBaoTamTru — must be added Phase 02+. **Booking rename (Phase 01b) well-scoped:** 5 files, 1-day effort. **Multi-tenant isolation strategy decided:** Repository pattern auto-inject host_id, test cross-host IDOR in Phase 02.
