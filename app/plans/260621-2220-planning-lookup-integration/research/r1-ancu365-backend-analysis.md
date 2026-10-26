# Backend Architecture Analysis: ancu365-backend

**Date:** 2026-06-21  
**Scope:** Feasibility assessment for porting `planning_etl` from faceconst to ancu365  
**Status:** DONE

---

## 1. Auth Pattern

### Current Implementation
- **JWT Library:** `python-jose` (HS256) + `bcrypt` hashing
- **Token Payload:** `{sub: str(user_id), role: str, iat, exp}` — 168-hour TTL (7 days)
- **Dependency Injection:**
  ```python
  def optional_user(request: Request) -> Optional[dict]  # Extracts Bearer token
  def require_user(claims: Optional[dict] = Depends(optional_user)) -> dict  # Enforces auth
  ```

### Admin Protection Pattern
- **Current:** Endpoints check `claims["role"]` manually in handler bodies
- **Missing:** Dedicated `require_admin()` dependency (unlike faceconst's multi-tier auth)
- **Example** (houses.py): No admin endpoint exists; seed data hardcodes admin user with role="admin"

### Gaps vs. faceconst
1. **No centralized role enforcement:** faceconst uses dedicated dependencies (`require_contractor`, etc.); ancu365 relies on manual checks
2. **No audit logging** for admin actions
3. **Token algorithm fixed to HS256** — no RS256 option

**Migration Impact:** MEDIUM — Can reuse JWT pattern, but need to add admin route protection.

---

## 2. DB Session & Pattern

### Current Setup
```python
# database.py
engine = create_engine(
    settings.database_url,
    connect_args={"check_same_thread": False} if sqlite else {},
    pool_pre_ping=True
)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

### Key Properties
- **Sync-only:** No async support (SQLAlchemy ORM, not AsyncSession)
- **Schema Creation:** `Base.metadata.create_all(bind=engine)` on startup (no alembic)
- **Multi-schema Support:** ❌ **NOT SUPPORTED** — `create_all()` only creates public schema

### GeoAlchemy2 Compatibility
- **ancu365:** Uses SQLAlchemy 2.0.35 (ORM-only, not SQLModel)
- **faceconst:** Uses SQLModel (wrapper over SQLAlchemy) with GeoAlchemy2 for PostGIS types
- **Issue:** GeoAlchemy2 requires **Postgres-specific** Geometry types — SQLite cannot parse them at import time, even if columns are nullable

**Recommendation:** Separate `planning` models into isolated module (lazy import) to avoid import errors when targeting SQLite.

---

## 3. Router Pattern

### Pattern Convention
```python
# Example: app/routers/houses.py
router = APIRouter(prefix="/api/houses", tags=["houses"])

@router.get("")
def list_houses(
    query: str = "",
    categoryId: int = 0,  # Query params (not Pydantic schema)
    status: str = "",
    db: Session = Depends(get_db),
):
    # Manual query building with ORM
    q = db.query(models.House)
    if query:
        like = f"%{query.lower()}%"
        q = q.filter(or_(models.House.title.ilike(like), ...))
    return q.offset(offset).limit(limit).all()
```

### Observations
- **No request/response schemas:** Query params passed as primitives, not Pydantic models
- **No explicit response_model:** Marshallers (e.g., `helpers.user_to_dict()`) convert ORM to dicts
- **Error handling:** HTTPException with string details (no structured errors)
- **No pagination schema:** Implements offset-limit ad-hoc

### ancu365 vs. faceconst
| Aspect | ancu365 | faceconst |
|--------|---------|-----------|
| Request schemas | None (primitives) | Pydantic BaseModel |
| Response schemas | Implicit (no `response_model`) | Explicit `response_model` |
| Marshallers | helpers.user_to_dict() | Pydantic validators |
| Error responses | HTTPException detail strings | Structured error codes |

**Migration Impact:** LOW — ancu365 style is simpler; `planning_api` can follow same pattern, just add Pydantic schemas for consistency with faceconst.

---

## 4. CORS & Middleware

### Current Setup
```python
# main.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # ⚠️ WIDE OPEN
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.mount("/uploads", StaticFiles(...))
```

### Missing Safeguards
- ❌ No rate limiting
- ❌ No request timeout
- ❌ No request size limits
- ✅ WebSocket support exists (chat.py)

### Planning ETL Requirements
- **Public endpoint:** `/api/planning/parcels?...` should NOT require auth (read-only search)
- **Admin endpoint:** POST `/api/planning/etl-run` to trigger sync — **needs protection**

**Recommendation:** Add `require_admin()` middleware check before ETL endpoints.

---

## 5. Models & Schemas

### ORM Approach
- **Base:** SQLAlchemy DeclarativeBase (not SQLModel)
- **Columns:** Mapped[type] annotations with mapped_column()
- **Custom Types:** JSONList (TypeDecorator for list[str] ↔ JSON TEXT)
- **No relationships:** FK columns exist (host_id, category_id) but no relationship() — manual joins only

### Example: House
```python
class House(Base):
    __tablename__ = "houses"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    host_id: Mapped[int] = mapped_column(Integer, index=True)
    latitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    longitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    images: Mapped[list] = mapped_column(JSONList, default=list)  # Custom type
```

### Adding Planning Models
```python
# app/models.py — add these (NO GeoAlchemy2 at module level)
class PlanningParcel(Base):
    __tablename__ = "parcels"
    __table_args__ = {"schema": "planning"}  # ❌ Will fail if schema doesn't exist
    
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    parcel_id: Mapped[str] = mapped_column(String, unique=True)
    geometry: Mapped[?] = ???  # Can't use geoalchemy2.Geometry directly in SQLite
```

### Critical Blockers
1. **Multi-schema:** `__table_args__ = {"schema": "planning"}` requires Postgres + explicit schema creation
2. **GeoAlchemy2 import:** `from geoalchemy2 import Geometry` fails on SQLite environments
3. **No migration tool:** No alembic for `create_all()` to know which schemas to create

**Solution:**
- Lazy import planning models only when `DATABASE_URL` contains "postgres"
- Create separate factory function for planning Base (like faceconst PlanningBase)
- Manually execute `CREATE SCHEMA IF NOT EXISTS planning` before `create_all()`

---

## 6. SQLite → PostgreSQL Migration

### Current State
```python
# app/config.py
database_url: str = "sqlite:///./urbannest.db"

# app/database.py
is_sqlite = settings.database_url.startswith("sqlite")
connect_args = {"check_same_thread": False} if is_sqlite else {}
```

### Switching to Postgres
```python
# .env example
DATABASE_URL=postgresql://user:password@localhost:5432/ancu365

# database.py needs:
# 1. Install psycopg2-binary (or psycopg[binary])
# 2. Create schema:
#    CREATE SCHEMA IF NOT EXISTS planning;
# 3. Check for GeoAlchemy2 dependency (install geoalchemy2 + postgis in DB)
```

### Data Migration Path
**Current approach (non-blocking):**
1. New Postgres DB with public schema (existing tables from SQLite dump)
2. Manual `CREATE SCHEMA planning;` 
3. Run `Base.metadata.create_all()` for public tables
4. Run `PlanningBase.metadata.create_all()` for planning tables
5. Seed script continues to work (only targets public schema)

**Risk:** SQLite seed data NOT automatically migrated to Postgres. Need explicit dump+restore.

### Minimal Changes Required
- Add `psycopg2-binary` to requirements.txt
- Modify `database.py` to execute `CREATE SCHEMA planning;` after engine creation (if Postgres)
- Lazy-load `app.models.planning_*` only when using Postgres

---

## 7. Seed Data

### Current Seed
```python
# app/seed.py
def run(db: Session):
    if db.query(models.User).first():
        return  # Skip if already seeded
    
    # Hard-coded 3 users (admin, host, guest)
    # 5 categories + 6 amenities
    # 2 houses with lat/lon
```

### Impact of Planning Models
- ✅ **No conflict:** Seed only targets public schema (users, categories, houses, etc.)
- ✅ **Planning data:** Comes from ETL (external source), not seed
- ⚠️ **If switching to Postgres:** Seed still runs; planning.etl_runs/parcels remain empty until ETL executes

---

## 8. Comparison: ancu365 vs. faceconst Structure

| Aspect | ancu365 | faceconst | Port Complexity |
|--------|---------|-----------|-----------------|
| **ORM** | SQLAlchemy Base | SQLModel (wrapper) | LOW — Both support schema_name |
| **Auth** | JWT + bcrypt | JWT + bcrypt + roles | MEDIUM — Add role dependencies |
| **Models** | Single Base class | Multiple DeclarativeBase (planning) | MEDIUM — Create PlanningBase |
| **DB Driver** | sync (sessionmaker) | sync (session_factory) | LOW — Same pattern |
| **Schemas** | Public only | Public + planning | HIGH — Setup Postgres + schema |
| **GeoAlchemy2** | ❌ Not imported | ✅ PostGIS types | HIGH — Conditional import needed |
| **Migrations** | None (create_all) | None (create_all + SQL scripts) | MEDIUM — Add CREATE SCHEMA |
| **Services** | None (logic in routers) | planning_etl/ module | LOW — Copy entire module |
| **Routers** | Manual schemas | Pydantic BaseModel | LOW — ancu365 style acceptable |

---

## 9. Porting Checklist

### ✅ Direct Copy (No Changes)
- `faceconst/backend/planning_etl/` → `ancu365-backend/app/services/planning_etl/`
- `faceconst/backend/app/services/planning_etl/` → `ancu365-backend/app/services/planning_etl/`

### ⚠️ Adapt Required
1. **Models:**
   - Create `app/models/planning_base.py` (PlanningBase with schema="planning")
   - Add conditional import in `app/models/__init__.py` (only if Postgres)
   
2. **Database:**
   - Add to `app/database.py`:
     ```python
     if not is_sqlite:
         with engine.connect() as conn:
             conn.execute(text("CREATE SCHEMA IF NOT EXISTS planning"))
             conn.commit()
     ```
   - Update requirements: `psycopg2-binary>=2.9`
   
3. **Router:**
   - Create `app/routers/planning.py` for lookup endpoints
   - Add `require_admin()` dependency for ETL triggers
   - Import planning service
   
4. **Main:**
   - Conditionally load planning models:
     ```python
     if "postgres" in settings.database_url:
         from app.models.planning_parcel import PlanningBase
         PlanningBase.metadata.create_all(bind=engine)
     ```
   - Register planning router

### ❌ Blocked by Design
- ETL background job queueing (ancu365 has no RQ/Celery)
- PostGIS spatial queries (SQLite cannot handle)

---

## 10. Risk Assessment

### CRITICAL BLOCKERS
1. **SQLite incompatibility:** Planning models require Postgres — must migrate infrastructure
2. **GeoAlchemy2 imports:** Will crash on SQLite before schema validation
3. **No admin protection:** Current routes unprotected; need auth layer

### HIGH RISKS
1. **No alembic:** Schema drift possible if models change without manual SQL
2. **Single Base class:** Mixing public + planning in one Base makes cleanup harder
3. **No rate limiting:** ETL endpoint could be abused

### MEDIUM RISKS
1. **Seed data:** Not automatically migrated if switching DBs
2. **Response schemas:** ancu365 lacks Pydantic; planning_api should add for consistency
3. **Environment detection:** Conditional logic (is_sqlite) scattered; should centralize

---

## 11. Unresolved Questions

1. **ETL Triggering:** How will planning ETL be invoked? (cron job? webhook? manual API?)
2. **Auth for lookup:** Should `/api/planning/parcels` be public or require auth?
3. **Data freshness:** How often should ETL run? (daily? on-demand?)
4. **Postgres migration plan:** Will you migrate existing SQLite data or start fresh?
5. **Response format:** Should planning lookup return GeoJSON or custom schema?

---

## Summary

**ancu365-backend is ready for planning_etl port with MEDIUM effort:**

- **Auth pattern:** Reusable; just add `require_admin()` dependency
- **Router pattern:** Different (no Pydantic schemas), but acceptable
- **DB session:** Sync SQLAlchemy — compatible with planning services
- **Models:** CAN be added BUT requires Postgres migration + conditional imports
- **Critical gap:** Must switch from SQLite to Postgres; GeoAlchemy2 incompatible with SQLite

**Recommendation:**
1. Migrate to Postgres immediately (prerequisite)
2. Create PlanningBase + models (isolated module)
3. Add `require_admin()` auth dependency
4. Port planning_etl services (direct copy)
5. Add planning router with lookups + admin ETL trigger

**Timeline:** 3-4 weeks (most time spent on Postgres migration, not porting code).

---

**Status:** DONE  
**Summary:** ancu365-backend MEDIUM-complexity to port planning_etl — requires Postgres switch, conditional imports, admin protection. Porting code is LOW effort; infrastructure is HIGH effort.  
**Concerns:** No alembic tool for migration management; GeoAlchemy2 will crash on SQLite imports; seed data migration not automated.
