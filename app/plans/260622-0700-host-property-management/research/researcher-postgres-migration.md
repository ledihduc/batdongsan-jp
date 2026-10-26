# Researcher Report: Postgres Migration + Alembic Baseline Strategy

**Date:** 2026-06-22  
**Phase:** Phase 01 — DB migration (SQLite → Postgres) + Alembic baseline  
**Status:** Complete research; ready for Phase 3 Tech Lead Planning  
**Sources:** Codebase audit + 7 research sources (2025-2026)

---

## Part 1: Current State Inventory

### 1.1 Database Configuration

**File:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/app/config.py:1-44`

```python
# Current config supports both SQLite (dev) and Postgres (prod)
database_url: str = "sqlite:///./urbannest.db"  # Default: SQLite
# Supports Postgres via env var: postgresql://user:pass@host:5432/dbname
```

**Database setup:** `app/database.py:1-39`
```python
connect_args = {"check_same_thread": False} if settings.database_url.startswith("sqlite") else {}
engine = create_engine(settings.database_url, connect_args=connect_args)
```

**Key observation:** Config already supports dual-mode (SQLite/Postgres via `DATABASE_URL` env var). **No code changes needed** for database URL switching.

---

### 1.2 Alembic State

**Alembic configured:** ✅ Yes — `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/alembic.ini`

**Migration history:**
- Only 1 migration file: `alembic/versions/0001_planning_reports.py` (planning module only)
- **Core tables (users, houses, bookings, categories, amenities, wishlists, chats, notifications) use `metadata.create_all()`** — NO migration files exist
- **Planning schema uses separate `PlanningBase.metadata`** (conditional Postgres-only)

**Alembic env.py state:** `alembic/env.py:1-92`
```python
# Line 28-35: target_metadata = None (commented out)
# Migration currently disabled for core schema
# Phase 01 task: uncomment + wire Base.metadata + PlanningBase.metadata
```

---

### 1.3 Docker-compose State

**File:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/docker-compose.yml:1-80+`

**Postgres service already exists:** ✅ Yes

```yaml
postgis:
  image: postgis/postgis:16-3.4
  container_name: ancu365-postgis
  ports:
    - "127.0.0.1:5432:5432"
  environment:
    POSTGRES_USER: ${POSTGRES_USER}
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    POSTGRES_DB: ${POSTGRES_DB}
  volumes:
    - postgis-data:/var/lib/postgresql/data
    - ./infra/postgres/init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
    interval: 10s
    timeout: 5s
    retries: 5
    start_period: 30s
  restart: unless-stopped
  networks:
    - ancu-net
```

**Assessment:**
- ✅ Healthcheck already present (uses `pg_isready`)
- ✅ Persistent volume `postgis-data` mapped
- ✅ PostGIS 16 (includes geographic support for planning module)
- ✅ Network isolation (`ancu-net`)
- **Upgrade needed:** Add `start_period: 60s` for safer large DB startup (currently 30s)

---

### 1.4 metadata.create_all() Usages

**File:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/main.py:50-61`

```python
# Line 50: Core tables auto-created
Base.metadata.create_all(bind=engine)

# Line 51-52: Seed data
with SessionLocal() as db:
    seed_run(db)

# Line 56-61: Planning schema (Postgres-only)
if _planning_enabled:
    from app.database import _ensure_planning_schema
    from app import planning_models
    _ensure_planning_schema()
    planning_models.PlaningBase.metadata.create_all(bind=engine)
```

**Impact:** `metadata.create_all()` called at app startup:
- **Line 50:** Creates users, houses, bookings, categories, amenities, wishlists, chats, notifications, reviews
- **Line 61:** Creates planning tables (parcels, etl_runs, etc.)

---

### 1.5 Seed Scripts

**File:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/app/seed.py`

**Current state:** ✅ Seed script exists (not inspected in detail)
- Called from `main.py:52` at startup
- Likely creates categories, amenities, admin user

**Phase 01 task:** Create `scripts/seed_dev.py` that runs against Postgres (identical logic, tested with Postgres container).

---

### 1.6 Current Models Overview

**Core models in `app/models.py`:**
```
User (users table)
├── Field: role (string: 'guest'|'host'|'admin')
├── Field: email, phone, password_hash
└── FK relationships: House.host_id, Booking.guest_id, etc.

House (houses table)
├── FK: host_id → User.id
├── Fields: title, description, price, area
├── JSON fields: images (TextList), amenities (TextList)
├── Status: pending|approved|rejected|hidden
└── Multi-unit: listing_type, total_units, available_units

Booking (bookings table)
├── FK: house_id → House.id
├── FK: guest_id → User.id
├── Status: pending|approved|rejected|completed|cancelled|locked
└── Fields: booking_date, booking_time, message

ChatMessage
├── FK: sender_id, receiver_id → User.id
├── FK: house_id → House.id (context)

Notification
├── FK: user_id → User.id
├── Type: booking_*, notification_*

Category, Amenity, Wishlist, Review, etc.
```

**Data types analysis:**
- ✅ All use SQLAlchemy generic types (String, Integer, DateTime, Boolean, JSON)
- ✅ **Boolean used for fields** (will auto-convert to BOOLEAN in Postgres, INTEGER in SQLite)
- ✅ **DateTime used (naive, no timezone)** — important for migration

---

## Part 2: Best Practice Research (2025-2026)

### 2.1 SQLite → Postgres Migration Approach

**Recommended Pattern:** Environment-driven database URL (no code changes)

**Citation:** FastAPI + SQLAlchemy guide (2025-2026, official FastAPI, Alembic docs)

**Step-by-step approach:**

1. **Update `.env`** to point to Postgres:
   ```bash
   DATABASE_URL=postgresql://ancu365:password@postgis:5432/ancu365
   ```

2. **No model changes needed** — SQLAlchemy's type system is database-agnostic
   - `String` → VARCHAR in both
   - `Integer` → INT in both
   - `Boolean` → BOOLEAN (Postgres) vs INTEGER (SQLite)
   - `DateTime` → TIMESTAMP in both (see timezone note below)

3. **Trade-off decision (D1 sealed):** Reset data (no migration script needed)
   - BA sealed: app hasn't launched → data reset is safe
   - Saves 2-3 days migration script development
   - **Implementation:** `docker-compose down -v && docker-compose up` (wipe `postgis-data` volume)

4. **Verification steps:**
   - Run Alembic migrations (baseline + any new ones)
   - Run seed script against Postgres
   - Smoke test app via API

---

### 2.2 Alembic Baseline from Existing Models

**Citation:** Alembic 1.18.4 official docs + Medium 2025 guides (megablazikenabhishek, iamjeremie)

**Phase 01 concrete steps:**

#### Step 1: Enable autogenerate in `alembic/env.py`
```python
# Line 28-35: Uncomment and update
from app.database import Base
from app import planning_models  # noqa: F401
from app.planning_models import PlanningBase

target_metadata = [Base.metadata, PlanningBase.metadata]
```

#### Step 2: Generate baseline migration
```bash
# From /ancu365-backend directory
alembic revision --autogenerate -m "initial: all tables"
```

**What this generates:**
- File: `alembic/versions/0002_initial_all_tables.py`
- Contains: CREATE TABLE for all models in Base + PlanningBase metadata
- Compares **model definitions** vs **existing Postgres schema** (empty on first run)

#### Step 3: Review + fix migration
**Alembic limitation:** Autogenerate is NOT perfect. Common fixes:
- Remove `op.drop_table()` calls if they appear (shouldn't on fresh DB)
- Verify all columns/types match models
- Add explicit constraints (FK, unique, check)

#### Step 4: Apply migration
```bash
alembic upgrade head
```

**Result:** Alembic marks current revision as applied in `alembic_version` table.

---

### 2.3 Common Pitfalls & Mitigation

**Pitfall 1: Metadata mismatch**
- **Problem:** If `env.py` doesn't import all model modules, Alembic autogenerate thinks tables were deleted
- **Mitigation:** Ensure `from app.database import Base` + `from app import planning_models` + all model files are imported
- **Test:** Run `alembic current` before/after — should show correct revision

**Pitfall 2: DateTime timezone handling**
- **Problem:** SQLite stores naive DateTime; Postgres can use timezone-aware
- **Mitigation Phase 01:** Use `DateTime(timezone=False)` in migration for compatibility (no change to models)
- **Future:** Phase 02 can add `timezone=True` to new columns; old columns remain naive

**Pitfall 3: Type detection failures**
- **Problem:** Autogenerate may miss custom types or JSON columns
- **Mitigation:** Review generated migration + manually edit if needed
- **In this codebase:** JSON fields (images, amenities) should be `sa.JSON` type — verify in migration

**Pitfall 4: Foreign key ordering**
- **Problem:** Alembic creates FKs in arbitrary order; may fail if dependent tables not created first
- **Mitigation:** Manual reorder in migration if needed (rare with autogenerate)

---

### 2.4 Docker-compose Postgres 15/16 Best Practices

**Citation:** Docker Compose health checks + persistent data guides (2025-2026)

**Current `docker-compose.yml` is nearly optimal.** Recommendations:

```yaml
postgis:
  image: postgis/postgis:16-3.4
  container_name: ancu365-postgis
  ports:
    - "127.0.0.1:5432:5432"
  environment:
    POSTGRES_USER: ${POSTGRES_USER}
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    POSTGRES_DB: ${POSTGRES_DB}
    # Optional: Buffer tuning (adjust per host RAM)
    POSTGRES_INITDB_ARGS: "-c shared_buffers=2GB -c work_mem=64MB -c effective_cache_size=6GB"
  volumes:
    - postgis-data:/var/lib/postgresql/data  # Named volume (persistent)
    - ./infra/postgres/init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
    interval: 10s
    timeout: 5s
    retries: 5
    start_period: 60s  # ← Upgrade: was 30s, use 60s for safety
  restart: unless-stopped
  networks:
    - ancu-net

volumes:
  postgis-data:  # ← Named volume declaration (persist on host)
    driver: local
```

**Key points:**
- ✅ Named volume `postgis-data` persists data across container restarts
- ✅ Healthcheck waits 60s before checking (safe for large DB startup)
- ✅ Network isolation via `ancu-net`
- ✅ PostGIS 16 includes geographic support

---

### 2.5 CI Testing Pattern: GitHub Actions + Postgres

**Citation:** GitHub Docs official (2025-2026) + FastAPI template examples

**Minimal GitHub Actions workflow for Postgres testing:**

```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v4
        with:
          python-version: '3.12'

      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install pytest pytest-cov

      - name: Run migrations
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test_db
        run: alembic upgrade head

      - name: Run tests
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test_db
        run: pytest --cov=app tests/
```

**Key points:**
- ✅ Service container `postgres:16` auto-started
- ✅ Healthcheck waits for readiness
- ✅ Environment variables pass DB URL to tests
- ✅ `alembic upgrade head` applies migrations before tests

---

### 2.6 Pytest Fixtures: pytest-postgresql vs testcontainers-python

**Citation:** 2025-2026 FastAPI testing guides + PyPI + GitHub examples

**Comparison:**

| Approach | Pros | Cons | Recommendation |
|----------|------|------|-----------------|
| **pytest-postgresql (pytest plugin)** | Simple fixture API, fast setup, auto-cleanup | Requires local Postgres binary or Docker daemon, manages single shared instance | ✅ **Recommended for Phase 01** (local dev + CI) |
| **testcontainers-python** | Pure Docker, no local binary needed, isolated per test | Slower (container per test), more complex, overkill for MVP | ❌ Defer to Phase 02 if needed |
| **SQLite in-memory** | Fast, no infra | Doesn't test Postgres-specific logic, type differences | ❌ Not suitable (defeats migration purpose) |

**Phase 01 recommended setup: `pytest-postgresql`**

```bash
pip install pytest-postgresql
```

Example test fixture:
```python
# tests/conftest.py
import pytest
from sqlalchemy import create_engine
from app.database import Base, SessionLocal

@pytest.fixture(scope="session")
def db_engine(postgresql):
    """Postgres container fixture provided by pytest-postgresql."""
    url = f"postgresql://postgres:postgres@{postgresql.host}:{postgresql.port}/test_db"
    engine = create_engine(url)
    Base.metadata.create_all(bind=engine)
    yield engine
    engine.dispose()

@pytest.fixture
def db_session(db_engine):
    """Fresh session per test."""
    connection = db_engine.connect()
    transaction = connection.begin()
    session = SessionLocal(bind=connection)
    yield session
    session.close()
    transaction.rollback()
    connection.close()
```

**Usage:**
```python
def test_user_creation(db_session):
    user = User(name="Test", email="test@example.com")
    db_session.add(user)
    db_session.commit()
    assert user.id is not None
```

---

## Part 3: Concrete Phase 01 Plan

### 3.1 Sizing Validation

**Duration:** 2–3 days realistic (dev + QA per BA Leader v2 recommendation)

**Breakdown:**
- **Day 1a:** Alembic baseline migration (1-2 hours)
  - Enable autogenerate in env.py
  - Generate migration via `alembic revision --autogenerate`
  - Review + fix (mostly auto-correct)
  - Apply to Postgres
  
- **Day 1b:** Docker-compose + .env setup (2-3 hours)
  - Update `docker-compose.yml` (add `start_period: 60s`)
  - Create `.env` with Postgres URL
  - Test `docker compose up` → app startup → no errors
  
- **Day 2:** Seed script + test setup (full day, 6 hours)
  - Create `scripts/seed_dev.py` (copy from `app/seed.py` logic)
  - Test seed runs on Postgres
  - Setup `pytest-postgresql` fixture
  - Write smoke tests (CRUD on users, houses, bookings)
  
- **Day 2b–3:** CI + regression (1-2 days, 4-6 hours)
  - Update GitHub Actions workflow to use Postgres container
  - Run full test suite against Postgres
  - Fix any type/schema issues discovered
  - Smoke test: reset DB → app starts → seed runs → API calls work

**Confidence:** 80% — assumes no hidden schema conflicts (unlikely given code review found none).

---

### 3.2 File-Level Tasks (Detailed)

#### **Task 1: Enable Alembic autogenerate**
- **File:** `/ancu365-backend/alembic/env.py`
- **Changes:**
  - Uncomment lines 31-34 (import Base, PlanningBase, set target_metadata)
  - Verify `get_url()` function reads DATABASE_URL env var ✅ (already correct)
- **Testing:** Run `alembic current` → should report revision (empty initially)
- **Effort:** 10 min

#### **Task 2: Generate initial migration**
- **Command:** `cd /ancu365-backend && alembic revision --autogenerate -m "initial_baseline_all_tables"`
- **Output:** `alembic/versions/0002_initial_baseline_all_tables.py`
- **Manual review:**
  - Check all User, House, Booking, Category, Amenity, Wishlist, Chat, Notification tables present
  - Verify ForeignKey constraints
  - Verify indexes (host_id, status, created_at on House; house_id, guest_id on Booking)
  - Check JSON columns (images, amenities) → should be `sa.JSON()` type
  - Fix any `op.drop_table()` (shouldn't exist on fresh DB, but check)
- **Testing:** Run `alembic upgrade head` → tables created in Postgres
- **Effort:** 1-2 hours

#### **Task 3: Update docker-compose.yml**
- **File:** `/ancu365-backend/docker-compose.yml:25-30`
- **Change:** `start_period: 30s` → `start_period: 60s`
- **Rationale:** Safer for large DB initialization
- **Testing:** `docker compose up postgis` → wait 60s → `pg_isready` passes
- **Effort:** 5 min

#### **Task 4: Create .env for Postgres (dev)**
- **File:** `/ancu365-backend/.env` (from `.env.example`)
- **Key values:**
  ```
  DATABASE_URL=postgresql://ancu365:change_me_strong_64_chars@postgis:5432/ancu365
  POSTGRES_USER=ancu365
  POSTGRES_PASSWORD=change_me_strong_64_chars
  POSTGRES_DB=ancu365
  ```
- **Note:** `.env` already gitignored; safe to commit example only
- **Testing:** `DATABASE_URL=...postgres... python -c "from app.database import engine; engine.connect()"`
- **Effort:** 5 min

#### **Task 5: Create seed_dev.py script**
- **File:** `/ancu365-backend/scripts/seed_dev.py` (NEW)
- **Content:** Extract from `app/seed.py:run()` function
  - Create categories (homestay, room, etc.)
  - Create amenities (WiFi, AC, etc.)
  - Create admin user
  - Idempotent (check existence before insert)
- **Usage:** `cd /ancu365-backend && python scripts/seed_dev.py` (run against current DATABASE_URL)
- **Testing:** Run on Postgres → check `SELECT COUNT(*) FROM categories;` → expect 5+ rows
- **Effort:** 1-2 hours (includes testing)

#### **Task 6: Setup pytest-postgresql fixture**
- **File:** `/ancu365-backend/tests/conftest.py` (NEW or update if exists)
- **Install:** `pip install pytest-postgresql`
- **Content:**
  ```python
  import pytest
  from sqlalchemy import create_engine
  from app.database import Base
  from app.seed import run as seed_run
  
  @pytest.fixture(scope="session")
  def db_engine(postgresql):
      url = f"postgresql://postgres:postgres@{postgresql.host}:{postgresql.port}/test_db"
      engine = create_engine(url)
      Base.metadata.create_all(bind=engine)
      yield engine
      engine.dispose()
  
  @pytest.fixture
  def db_session(db_engine):
      from app.database import SessionLocal
      # ... (as shown in Part 2.6)
  ```
- **Testing:** `pytest tests/ -v` → fixtures load, no errors
- **Effort:** 1 hour

#### **Task 7: Write smoke tests**
- **Files:** `/ancu365-backend/tests/test_smoke_postgres.py` (NEW)
- **Tests:**
  - ✅ User create/read/delete
  - ✅ House create/read/update/delete (with host_id validation)
  - ✅ Booking create/read/status transitions
  - ✅ Category + Amenity CRUD
  - ✅ Cross-host isolation (Host A can't see Host B's houses)
- **Coverage:** ~10-15 simple test cases
- **Effort:** 2-3 hours

#### **Task 8: Update GitHub Actions workflow**
- **File:** `/.github/workflows/tests.yml` (NEW or update)
- **Add Postgres service container** (as shown in Part 2.5)
- **Steps:**
  1. Checkout
  2. Setup Python
  3. Install dependencies
  4. Run `alembic upgrade head`
  5. Run pytest
- **Testing:** Push branch → GH Actions runs → all tests pass
- **Effort:** 1-2 hours

#### **Task 9: Update README.md**
- **File:** `/ancu365-backend/README.md`
- **Sections to add/update:**
  - **Setup (Postgres mode):**
    ```bash
    cp .env.example .env
    # Edit .env: set DATABASE_URL=postgresql://...
    docker compose up -d postgis
    alembic upgrade head
    python scripts/seed_dev.py
    uvicorn main:app --reload
    ```
  - **Migrations:** Quick guide on running `alembic revision --autogenerate`
  - **Testing:** How to run pytest against Postgres
- **Effort:** 1 hour

#### **Task 10: Smoke test end-to-end**
- **Manual checklist:**
  - [ ] `docker compose up` → all services healthy (postgis, backend)
  - [ ] App startup: `curl http://localhost:3000/docs` → Swagger UI loads
  - [ ] Create user: `curl -X POST http://localhost:3000/api/auth/register` → success
  - [ ] Create house: `curl -X POST http://localhost:3000/api/houses` → success (with auth)
  - [ ] List houses: `curl http://localhost:3000/api/houses` → returns data
  - [ ] Booking flow: create booking → approve → check notification
  - [ ] Database integrity: `psql ancu365 -c "SELECT COUNT(*) FROM users, houses, bookings;"`
  - [ ] Seed idempotency: restart app → no duplicate data errors
- **Effort:** 1-2 hours (includes debugging if needed)

---

### 3.3 Risks Specific to This Codebase

#### **Risk 1: JSON column type detection (Medium severity)**
- **Issue:** Alembic autogenerate may not correctly identify `images` and `amenities` as JSON type
- **Symptom:** Migration creates them as VARCHAR/TEXT instead of JSON
- **Mitigation:** 
  - Review generated migration file manually
  - Change `sa.Text()` → `sa.JSON()` if needed
  - Test with sample data: `UPDATE house SET images = '["url1", "url2"]'::json;`
- **Testing phase:** Day 2 (during migration review)

#### **Risk 2: Booking status transition state machine (Low severity)**
- **Issue:** Booking has complex state flow: `pending→approved/rejected→completed/lost→locked`
- **Symptom:** Incomplete status checks in migration
- **Mitigation:** Verify migration includes status enum/check constraint
- **Testing phase:** Smoke tests (Task 7) validate transitions

#### **Risk 3: Foreign key cascade rules missing (Medium severity)**
- **Issue:** House.host_id, Booking.house_id, ChatMessage.house_id have no CASCADE DELETE in models
- **Symptom:** Deleting a user/house leaves orphaned records
- **Mitigation:** 
  - Review migration ForeignKey definitions
  - Add `ondelete="CASCADE"` to models if needed (Phase 02 refactor)
  - For Phase 01 baseline: document as known limitation
- **Testing phase:** Day 3 (security review of cross-host queries)

#### **Risk 4: DateTime timezone handling (Low severity)**
- **Issue:** Current models use naive DateTime (no timezone); Postgres can store timezone-aware
- **Symptom:** Migration may add `TIMESTAMP WITH TIME ZONE` which breaks existing logic
- **Mitigation:** 
  - Use `DateTime(timezone=False)` in migration for compatibility
  - Future phases can migrate to timezone-aware gradually
- **Testing phase:** Day 2 (review generated migration)

#### **Risk 5: Multi-unit field type (Low severity)**
- **Issue:** `total_units`, `available_units` are Integer; should validate > 0
- **Symptom:** Business logic bugs (allow -1 units)
- **Mitigation:** Add CHECK constraint in migration: `CHECK(total_units > 0)`
- **Testing phase:** Task 7 (smoke tests validate valid data)

---

### 3.4 Test Plan for Phase 01 Verification

#### **Smoke Test Suite (Day 2b–3)**

**Test environment:** Postgres container + pytest-postgresql

**Pass criteria:**
- ✅ 100% of smoke tests pass (Tasks 7)
- ✅ No schema conflicts (migration runs clean)
- ✅ Seed data loads without errors
- ✅ End-to-end flow works (register → create listing → book)
- ✅ Cross-host isolation enforced (Host A cannot query Host B's data)
- ✅ CI/CD pipeline passes (GitHub Actions runs successfully)

**Rollback criteria (if anything fails):**
- [ ] Drop Postgres volume: `docker compose down -v`
- [ ] Revert .env to SQLite path
- [ ] Revert Alembic env.py changes
- [ ] Restart on SQLite (should work as before)

**Confidence level:** 80% (assumes no hidden schema issues)

---

## Part 4: Risks & Mitigation Matrix

| Risk | Severity | Probability | Mitigation | Owner | Timeline |
|------|----------|-------------|-----------|-------|----------|
| JSON type auto-detect fails | MEDIUM | 30% | Manual review + fix in migration | Dev | Day 2 |
| DateTime timezone incompatibility | LOW | 20% | Use `DateTime(timezone=False)` | Dev | Day 2 |
| Missing CASCADE DELETE | MEDIUM | 40% | Document as Phase 02 refactor | Dev + Tech Lead | Day 3 review |
| Booking state machine broken | LOW | 15% | Smoke tests validate transitions | Tester | Day 3 |
| Git history conflict | LOW | 10% | Feature branch + PR review | Dev | Day 1–3 |
| Seed script idempotency fail | MEDIUM | 25% | Test with app restart | QA | Day 2 |

---

## Part 5: Recommendations Summary

1. **Postgres migration is safe & viable with data reset (D1 sealed):**
   - Codebase already supports dual-mode DB URLs
   - SQLAlchemy's type system is database-agnostic
   - No model code changes needed

2. **Alembic baseline via autogenerate is recommended:**
   - Tools mature (v1.18.4+, 2025-2026 usage widespread)
   - Only gotcha: manual review required after generation
   - Phase 01 plan includes 1–2 hour review buffer

3. **Docker-compose Postgres is production-ready:**
   - Healthcheck + persistent volume already present
   - Minor upgrade: `start_period: 30s → 60s` for safety
   - No breaking changes

4. **CI/CD via GitHub Actions + pytest-postgresql is lightweight & proven:**
   - Official GitHub Docs support (2025-2026)
   - pytest-postgresql plugin is mature + maintained
   - ~1–2 hours to integrate into workflow

5. **2–3 day Phase 01 is realistic + achievable:**
   - Day 1: Alembic setup + Docker (3–4 hours)
   - Day 2: Seed script + pytest fixtures (6 hours)
   - Day 2b–3: CI/CD + smoke tests + regression (6–8 hours)
   - Buffer for debugging (2–4 hours)

6. **Type compatibility is well-handled:**
   - ✅ Boolean: auto-converts (BOOLEAN in Postgres, INTEGER in SQLite)
   - ✅ DateTime: naive by default (safe); timezone-aware deferred to Phase 02
   - ✅ JSON: verify in autogenerated migration; manual fix if needed
   - ✅ String/Integer/UUID: fully portable across DB engines

---

## Part 6: Unresolved Questions

1. **Nominatim + Martin services**: Will they stay on Postgres backend, or switch to separate DB?
   - Answer required from Tech Lead (Phase 3)
   - Assumption: Use same Postgres instance (simplest)

2. **Backup strategy for postgis-data volume**: Should Phase 01 include daily backup setup?
   - Answer required from Ops/Tech Lead
   - Assumption: Defer to Phase post-launch (not MVP)

3. **Test data isolation between test runs**: Should tests use transactional rollback or full table truncate?
   - Answer required from QA/Testing lead
   - Assumption: Transactional rollback (faster, safer)

4. **Search indexing** (if planning module uses FTS): Does Alembic baseline handle tsvector indexes?
   - Answer required from search specialist (not critical for Phase 01)
   - Assumption: Planning module deferred to Phase 02+

5. **Schema versioning strategy**: Should schema version sync with app version tag?
   - Answer required from DevOps/Tech Lead
   - Assumption: Alembic version independent; tracked separately

---

## Conclusion

**Phase 01 SQLite→Postgres migration is GREEN-LIGHT feasible:**

- Codebase is well-architected for dual-DB support
- Alembic baseline strategy is proven (2025-2026 industry standard)
- Docker-compose already production-ready
- 2–3d timeline is realistic with buffer
- No architectural blockers identified

**Next steps:** Await Phase 3 Tech Lead to finalize detailed phase-01.md with concrete subtasks + resource allocation.

---

**Report status:** ✅ READY FOR TECH LEAD PLANNING (Phase 3)

---

## Sources

- [FastAPI SQL Databases Tutorial](https://fastapi.tiangolo.com/tutorial/sql-databases/)
- [No-Fail Guide: FastAPI × SQLAlchemy × Alembic (2025)](https://blog.greeden.me/en/2025/08/12/no-fail-guide-getting-started-with-database-migrations-fastapi-x-sqlalchemy-x-alembic/)
- [Alembic 1.18.4 Official Documentation - Autogenerate](https://alembic.sqlalchemy.org/en/latest/autogenerate.html)
- [Initialize Alembic on Existing Database (Medium, 2025)](https://medium.com/@megablazikenabhishek/initialize-alembic-migrations-on-existing-database-for-auto-generated-migrations-zero-state-31ee93632ed1)
- [Docker Compose Health Checks Guide (2025-2026)](https://last9.io/blog/docker-compose-health-checks/)
- [Docker Volumes Persistent Data (2026)](https://oneuptime.com/blog/post/2026-02-02-docker-volumes-persistent-data/view)
- [Getting Started with Testcontainers for Python](https://testcontainers.com/guides/getting-started-with-testcontainers-for-python/)
- [Testcontainers with FastAPI and asyncpg](https://lealre.github.io/fastapi-testcontainer-asyncpg/)
- [Pytest API Testing with FastAPI, SQLAlchemy, Postgres](https://pytest-with-eric.com/api-testing/pytest-api-testing-1/)
- [GitHub Actions PostgreSQL Service Containers](https://docs.github.com/en/actions/using-containerized-services/creating-postgresql-service-containers)
- [SQLAlchemy Boolean Type Documentation](https://docs.sqlalchemy.org/en/20/core/type_basics.html)
- [Handling DateTime Across Time Zones with Postgres + SQLAlchemy (2025)](https://vivianyzhang.com/lessons-learned-handling-datetime-across-time-zones-in-postgres-with-sqlalchemy-and-alembic/)
