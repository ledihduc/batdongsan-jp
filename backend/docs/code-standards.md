# Code Standards — ancu365 Backend

**Last updated:** 2026-06-30  
**Language:** Python 3.12  
**Framework:** FastAPI + SQLAlchemy 2.0

---

## 1. Project Structure

```
app/
├── config.py               # Load env, settings
├── database.py             # SQLAlchemy engine + session
├── auth.py                 # JWT + bcrypt + dependencies
├── models.py               # ORM models (User, House, Delegation, etc.)
├── chat_hub.py             # WebSocket async manager
├── helpers.py              # Logging, notifications, rich helpers
├── domain/                 # Domain models (business entities)
│   └── delegation.py       # Delegation domain logic
├── schemas/                # Pydantic request/response schemas
│   ├── user.py
│   ├── delegation.py
│   └── ...
├── services/               # Business logic layer
│   ├── actor_context.py    # ActorContext resolution
│   ├── permission_set.py   # Permission presets
│   ├── delegation/         # Delegation services
│   ├── approval/           # Approval services
│   ├── owner_death/        # Owner death services
│   ├── commission/         # Commission services
│   ├── admin/              # Admin actions
│   ├── notification/       # Notifications
│   └── ...
├── api/
│   ├── dependencies/       # Route-level dependency injection
│   │   └── actor.py        # ActorContext per-request
│   └── routes/             # API route handlers
│       ├── auth.py
│       ├── delegation.py
│       ├── approval.py
│       └── ...
└── tests/
    ├── test_smoke_postgres.py
    ├── test_*_unit.py
    └── conftest.py
```

---

## 2. Naming Conventions

| Element | Pattern | Example |
|---------|---------|---------|
| Files | snake_case + descriptive | `delegation_lifecycle_service.py`, `actor_context.py` |
| Classes | PascalCase | `DelegationService`, `ActorContext`, `TokenPayload` |
| Functions | snake_case | `build_actor_context()`, `compute_commission()` |
| Constants | UPPER_SNAKE_CASE | `JWT_EXPIRY_DAYS`, `LOCKDOWN_DAYS` |
| DB columns | snake_case | `created_at`, `on_behalf_of_user_id` |
| Enums | PascalCase class + UPPER values | `class DelegationStatus(str, Enum): ACTIVE = "active"` |

---

## 3. Typing & Type Hints

**Rule:** All exported functions and class methods must have explicit parameter + return types.

```python
# ✅ GOOD
async def activate_delegation(delegation_id: str) -> Delegation:
    """Activate a pending delegation after KYC + POA."""
    ...

# ❌ BAD
async def activate_delegation(delegation_id):
    ...

# ✅ GOOD — Pydantic types
def create_delegation(data: DelegationCreate) -> DelegationResponse:
    ...

# ✅ GOOD — Collections
def get_all_delegations(owner_id: str) -> list[Delegation]:
    ...

# ✅ GOOD — Optional
def get_delegation(delegation_id: str) -> Delegation | None:
    ...

# ✅ GOOD — Union (use literal for status)
type DelegationStatus = Literal["active", "paused", "terminated", "archived"]
```

---

## 4. Imports & Organization

**Order:**
1. Standard library (os, datetime, asyncio)
2. Third-party (fastapi, sqlalchemy, pydantic)
3. Local (app.models, app.services, app.schemas)

```python
# ✅ GOOD
import os
from datetime import datetime, timedelta
from typing import Literal

from fastapi import APIRouter, Depends
from sqlalchemy import select
from pydantic import BaseModel, Field

from app.models import Delegation, User
from app.services.delegation.lifecycle_service import DelegationLifecycleService
from app.schemas.delegation import DelegationResponse
```

---

## 5. Database Models (SQLAlchemy ORM)

**Rules:**
- All models inherit from `Base` (sqlalchemy.orm.DeclarativeBase)
- Primary key: always `id` (UUID or integer)
- Timestamps: `created_at`, `updated_at` (default=func.now(), onupdate=func.now())
- Soft deletes: `deleted_at` (nullable datetime) — query with `WHERE deleted_at IS NULL`
- Audit columns: `actor_id`, `on_behalf_of_user_id` (for operator actions)

```python
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from datetime import datetime
from uuid import UUID, uuid4

class Base(DeclarativeBase):
    pass

class Delegation(Base):
    __tablename__ = "delegations"

    id: Mapped[str] = mapped_column(primary_key=True, default=lambda: str(uuid4()))
    owner_id: Mapped[str] = mapped_column(nullable=False, index=True)
    operator_id: Mapped[str] = mapped_column(nullable=False, index=True)
    preset: Mapped[str] = mapped_column(nullable=False)  # full_ops, limited_approval, etc.
    commission_rate: Mapped[float] = mapped_column(nullable=False)
    status: Mapped[str] = mapped_column(nullable=False, default="pending")  # active | paused | terminated | archived
    created_at: Mapped[datetime] = mapped_column(nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(nullable=False, server_default=func.now(), onupdate=func.now())
    terminated_at: Mapped[datetime | None] = mapped_column(nullable=True)
    lockdown_ends_at: Mapped[datetime | None] = mapped_column(nullable=True)
```

---

## 6. Pydantic Schemas (Request/Response)

**Rule:** Every request + response has a Pydantic schema. Use separate request (In) + response (Out) models.

```python
from pydantic import BaseModel, Field

class DelegationCreate(BaseModel):
    """Request body for creating a delegation invitation."""
    operator_email: str = Field(..., min_length=1)
    preset: Literal["full_ops", "limited_approval"] = Field(default="full_ops")
    commission_rate: float = Field(ge=0.0, le=1.0)

class DelegationResponse(BaseModel):
    """Response schema for delegation."""
    id: str
    owner_id: str
    operator_id: str
    preset: str
    status: str
    commission_rate: float
    created_at: datetime

    class Config:
        from_attributes = True  # Enable ORM mode (read from SQLAlchemy models)
```

---

## 7. Service Layer (Business Logic)

**Rule:** Keep models + schemas thin. Put business logic in services.

**Pattern:**
- Services are classes or modules with async methods
- Depend on database session, logger, external services
- Return domain models or Pydantic schemas
- Raise domain-specific exceptions (custom subclass of Exception)

```python
# ✅ GOOD
class DelegationLifecycleService:
    def __init__(self, db_session: AsyncSession, logger: Logger):
        self.db = db_session
        self.logger = logger

    async def activate_delegation(self, delegation_id: str) -> Delegation:
        """Activate pending delegation after KYC + POA."""
        delegation = await self.db.get(Delegation, delegation_id)
        if not delegation:
            raise DelegationNotFound(f"Delegation {delegation_id} not found")
        
        if delegation.status != "pending":
            raise InvalidDelegationStatus(f"Cannot activate {delegation.status} delegation")
        
        delegation.status = "active"
        self.db.add(delegation)
        await self.db.commit()
        
        self.logger.info(f"Activated delegation {delegation_id}")
        return delegation
```

---

## 8. API Routes (FastAPI)

**Rule:** Routes are thin. Delegate to services.

```python
from fastapi import APIRouter, Depends, HTTPException
from app.services.delegation.lifecycle_service import DelegationLifecycleService
from app.schemas.delegation import DelegationResponse
from app.api.dependencies.actor import ActorContext, get_actor_context

router = APIRouter(prefix="/api/delegations", tags=["delegations"])

@router.post("/", response_model=DelegationResponse)
async def create_delegation(
    data: DelegationCreate,
    actor: ActorContext = Depends(get_actor_context),
    service: DelegationLifecycleService = Depends(),
) -> DelegationResponse:
    """Owner creates a delegation invitation."""
    if actor.actor_role != "owner":
        raise HTTPException(status_code=403, detail="Only owners can create delegations")
    
    delegation = await service.create_delegation(actor.actor_id, data)
    return DelegationResponse.model_validate(delegation)
```

---

## 9. Dependency Injection

**FastAPI Depends:**
- Use for auth (current_user, ActorContext)
- Use for services (DatabaseSession, Logger)
- Use for rate limiting, CORS headers

```python
# ✅ GOOD — Custom dependency
async def get_actor_context(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db_session),
) -> ActorContext:
    """Resolve actor context (owner vs. operator) per request."""
    user = await decode_jwt(token)
    return await build_actor_context(user.id, db)

# ✅ GOOD — Service dependency
async def get_delegation_service(
    db: AsyncSession = Depends(get_db_session),
) -> DelegationLifecycleService:
    """Provide service with session."""
    return DelegationLifecycleService(db, logger)
```

---

## 10. Error Handling

**Rule:** Custom exception hierarchy. Catch at route level, convert to HTTPException.

```python
# ✅ GOOD — Custom exceptions
class DelegationError(Exception):
    """Base delegation error."""
    pass

class DelegationNotFound(DelegationError):
    pass

class InvalidDelegationStatus(DelegationError):
    pass

class CommissionLocked(DelegationError):
    pass

# ✅ GOOD — Route-level handler
@router.post("/activate")
async def activate(delegation_id: str, service: DelegationLifecycleService):
    try:
        return await service.activate_delegation(delegation_id)
    except DelegationNotFound as e:
        raise HTTPException(status_code=404, detail=str(e))
    except InvalidDelegationStatus as e:
        raise HTTPException(status_code=400, detail=str(e))
```

---

## 11. Async/Await

**Rule:** All I/O must be async (database, HTTP, file, etc.). Use async services throughout.

```python
# ✅ GOOD
async def get_delegation(delegation_id: str, db: AsyncSession) -> Delegation:
    stmt = select(Delegation).where(Delegation.id == delegation_id)
    result = await db.execute(stmt)
    return result.scalar_one_or_none()

# ❌ BAD — Sync I/O in async function
async def get_delegation(delegation_id: str, db: Session) -> Delegation:
    return db.query(Delegation).filter(Delegation.id == delegation_id).first()
```

---

## 12. Logging

**Rule:** Use standard logger, no print statements in production code.

```python
import logging

logger = logging.getLogger(__name__)

async def activate_delegation(delegation_id: str):
    logger.info(f"Activating delegation {delegation_id}", extra={"delegation_id": delegation_id})
    try:
        result = await service.activate(delegation_id)
        logger.info(f"Successfully activated delegation {delegation_id}")
        return result
    except Exception as e:
        logger.error(f"Failed to activate delegation {delegation_id}: {e}", exc_info=True)
        raise
```

---

## 13. Dual-Identity Audit

**Rule:** Every operator action logs both `actor_id` + `on_behalf_of_user_id`.

```python
# ✅ GOOD
async def create_invoice(
    actor: ActorContext,
    data: InvoiceCreate,
    db: AsyncSession,
) -> Invoice:
    """Operator creates invoice (dual-identity audit)."""
    invoice = Invoice(
        amount=data.amount,
        actor_id=actor.actor_id,                    # Operator
        on_behalf_of_user_id=actor.on_behalf_of_user_id,  # Owner
        acted_via_delegation_id=actor.delegation_id,
    )
    db.add(invoice)
    await db.commit()
    return invoice
```

---

## 14. Permission Checking

**Rule:** ActorContext has permissions. Check before action.

```python
# ✅ GOOD
async def approve_booking(
    booking_id: str,
    actor: ActorContext,
    service: ApprovalService,
):
    """Operator approves booking (if permitted)."""
    if "booking.approve" not in actor.permissions:
        raise HTTPException(status_code=403, detail="Permission denied")
    
    return await service.approve_booking(booking_id, actor.actor_id)
```

---

## 15. Testing

**Rules:**
- Unit tests for services (mock DB)
- Integration tests for routes (live DB, conftest fixtures)
- Use pytest + pytest-asyncio for async tests
- Aim for ≥ 90% coverage on services

```python
# ✅ GOOD — Unit test
@pytest.mark.asyncio
async def test_activate_delegation_success(db_session, delegation_service):
    """Test successful delegation activation."""
    delegation = await create_test_delegation(db_session, status="pending")
    
    result = await delegation_service.activate_delegation(delegation.id)
    
    assert result.status == "active"
    assert result.updated_at > delegation.created_at

# ✅ GOOD — Integration test
@pytest.mark.asyncio
async def test_create_delegation_route(client, owner_token):
    """Test POST /api/delegations route."""
    response = client.post(
        "/api/delegations",
        json={"operator_email": "op@example.com", "preset": "full_ops"},
        headers={"Authorization": f"Bearer {owner_token}"}
    )
    assert response.status_code == 201
    assert response.json()["status"] == "pending"
```

---

## 16. Migrations (Alembic)

**Rule:** One logical change per migration. Auto-generate, then review.

```bash
# Create migration
alembic revision --autogenerate -m "add_delegation_lockdown_field"

# Review alembic/versions/xxxx_add_delegation_lockdown_field.py
# Then apply
alembic upgrade head

# Rollback if needed
alembic downgrade -1
```

**Naming:** `{timestamp}_{short_description}.py`

---

## 17. Configuration & Secrets

**Rule:** Use environment variables. Never hardcode secrets.

```python
# ✅ GOOD — app/config.py
import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
JWT_SECRET = os.getenv("JWT_SECRET")
JWT_EXPIRY_DAYS = int(os.getenv("JWT_EXPIRY_DAYS", "7"))
LOCKDOWN_DAYS = int(os.getenv("LOCKDOWN_DAYS", "30"))

if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL not configured")
if not JWT_SECRET:
    raise RuntimeError("JWT_SECRET not configured")

# ❌ BAD
DATABASE_URL = "postgresql://user:pass@localhost/db"
JWT_SECRET = "secret123"
```

---

## 18. Code Quality Checklist

Before commit:
- [ ] All functions have type hints (parameters + return)
- [ ] No `print()` statements (use logger)
- [ ] No hardcoded secrets
- [ ] Tests pass (pytest)
- [ ] Linting passes (flake8 or ruff)
- [ ] Type checking passes (mypy)
- [ ] Database migrations reviewed
- [ ] Error handling covers edge cases
- [ ] Async/await used for all I/O
- [ ] Audit columns (actor_id, on_behalf_of_user_id) included for operator actions

---

## 19. Security Practices

**Authentication:**
- JWT HS256, expiry 7 days
- Password: bcrypt with salt (min 12 rounds)
- No plaintext passwords in logs

**Authorization:**
- ActorContext resolved per-request (never cached in JWT)
- Permissions checked before action
- Operator scoped to delegation preset (cannot exceed)
- Dual audit (actor_id + on_behalf_of_user_id)

**Immutability:**
- Commission locked at invoice paid_at
- Host_id immutable once assigned
- Delegation core fields (owner_id, operator_id) immutable

**Rate Limiting:**
- slowapi: 100/h per user (JWT) or IP (anonymous)

**Input Validation:**
- Pydantic schemas validate all incoming data
- Whitelist allowed values (enums, literals)

---

## 20. Performance Guidelines

**Database:**
- Index on frequently queried columns (owner_id, operator_id, status)
- Avoid N+1 queries (use joinedload for related objects)
- Batch operations when possible

**API:**
- Paginate large result sets (limit=100, offset)
- Use select() for specific columns (not SELECT *)
- Cache delegation metadata (commission_rate, preset) in ActorContext

**Async:**
- Never use sync DB drivers (psycopg3, not psycopg2)
- Never block event loop (no time.sleep, use asyncio.sleep)

---
