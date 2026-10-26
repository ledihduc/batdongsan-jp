# Phase 01 — Backend: Port Planning Module + Switch SQLite→PostgreSQL+PostGIS

## Context Links
- BA: `phase-00-ba-requirements.md` § Locked Decisions D1, Assumptions, AC-18/19
- Reports: `research/r1-ancu365-backend-analysis.md` (BLOCKER: SQLite→Postgres + conditional GeoAlchemy2)
- Reference code:
  - `faceconst/backend/app/services/planning_etl/{wfs_client,hcmc_fetcher,postgis_loader,geometry_utils,scheduler,cli,config}.py`
  - `faceconst/backend/app/models/planning_parcel.py`, `planning_etl_run.py`
  - `ancu365-backend/app/{database,models,config,main}.py`

## Overview
- Priority: **P0** (blocker cho mọi phase sau)
- Status: Pending
- Estimate: 2 ngày
- Description: Port nguyên `planning_etl` module + 2 model từ faceconst sang ancu365-backend; switch DB sang Postgres+PostGIS; alembic init; lazy GeoAlchemy2 import; reuse `auth.py` JWT.

## Key Insights
- ancu365-backend dùng SQLAlchemy 2.0 **ORM thuần** (KHÔNG SQLModel) → tạo `PlanningBase` riêng, KHÔNG nhập chung `Base` để cô lập schema `planning`.
- GeoAlchemy2 sẽ crash khi `from geoalchemy2 import Geometry` chạy với SQLite → bọc conditional `if "postgres" in DATABASE_URL`.
- ancu365 dùng pattern `helpers.user_to_dict()` (no Pydantic schema) — planning router sẽ thêm Pydantic schema rõ ràng vì payload phức tạp (GeoJSON).
- ancu365 chưa có alembic — phase này init lần đầu, manage cả public + planning schema.
- Reuse JWT `auth.py` hiện hữu (HS256+bcrypt), thêm `require_admin` dependency (gap nêu trong R1 §1).

## Requirements
### Functional
- Đặt được `DATABASE_URL=postgresql://...` → app start, tạo schema `planning` + tất cả bảng `planning.parcels`, `planning.etl_runs`.
- ETL CLI chạy được: `python -m app.services.planning_etl seed-all` lấy data WFS HCMC vào DB (sẽ dùng ở P02).
- `auth.require_admin()` dependency mới — verify `claims["role"] == "admin"`.
- Endpoint `/api/health` mới — check DB connectivity (cho uptime-kuma ở P09).

### Non-functional
- Backward compat: nếu `DATABASE_URL` bắt đầu `sqlite://`, app KHÔNG load planning models → existing tests SQLite vẫn pass.
- Alembic `upgrade head` hoàn tất ≤ 5s (chỉ create_all equivalents).

## Architecture
```
ancu365-backend/app/
├── models/                           ← NEW package (split khỏi models.py)
│   ├── __init__.py                   ← re-export House, User, ...; conditional planning_*
│   ├── core.py                       ← move existing models.py → core.py
│   ├── planning_base.py              ← NEW: PlanningBase = declarative_base(schema='planning')
│   ├── planning_parcel.py            ← PORT từ faceconst
│   └── planning_etl_run.py           ← PORT từ faceconst
├── services/                          ← NEW package
│   └── planning_etl/                 ← COPY toàn bộ folder từ faceconst
├── auth.py                           ← add require_admin()
├── database.py                       ← add CREATE SCHEMA + Postgres detect
├── config.py                         ← add planning_* settings
└── main.py                           ← conditional import planning models
```

Flow startup:
```
main.py startup
 └─ engine = create_engine(DATABASE_URL)
 └─ if Postgres:
      ├─ CREATE SCHEMA IF NOT EXISTS planning
      ├─ from app.models import planning_parcel, planning_etl_run  ← lazy
      └─ PlanningBase.metadata.create_all(bind=engine)
 └─ Base.metadata.create_all(bind=engine)  ← public schema (existing)
```

## Related Code Files

### To create
- `ancu365-backend/app/models/__init__.py`
- `ancu365-backend/app/models/planning_base.py`
- `ancu365-backend/app/models/planning_parcel.py` (adapt từ faceconst)
- `ancu365-backend/app/models/planning_etl_run.py` (adapt từ faceconst)
- `ancu365-backend/app/services/__init__.py`
- `ancu365-backend/app/services/planning_etl/{__init__,__main__,cli,config,wfs_client,hcmc_fetcher,postgis_loader,geometry_utils,scheduler}.py` (copy)
- `ancu365-backend/alembic.ini` + `ancu365-backend/alembic/env.py` + `versions/0001_initial.py`
- `ancu365-backend/.env.example` (DATABASE_URL postgres example, NOMINATIM_URL, MARTIN_URL)
- `ancu365-backend/docker-compose.dev.yml` (chỉ postgis cho local dev — full stack ở P02)

### To modify
- `ancu365-backend/app/models.py` → rename → `app/models/core.py` (giữ nguyên nội dung)
- `ancu365-backend/app/database.py` → add CREATE SCHEMA logic + conditional asyncpg removal
- `ancu365-backend/app/config.py` → add `postgres_planning_url` fallback, `nominatim_url`, `martin_url`, `wfs_timeout`
- `ancu365-backend/app/auth.py` → add `require_admin(claims = Depends(require_user))`
- `ancu365-backend/app/main.py` → conditional planning import + add `/api/health`
- `ancu365-backend/requirements.txt` → add `psycopg2-binary==2.9.9`, `geoalchemy2==0.15.2`, `shapely==2.0.4`, `pyproj==3.6.1`, `httpx==0.27.0`, `APScheduler==3.10.4`, `slowapi==0.1.9`, `alembic==1.13.2`

### To delete
- (none — backward compat)

## Implementation Steps

1. **Rename `models.py` → `models/core.py`**, tạo `models/__init__.py` re-export:
   ```python
   # app/models/__init__.py
   from app.models.core import User, House, Category, Amenity, Booking, Review, Wishlist, ChatMessage, Notification
   import os
   if "postgres" in os.getenv("DATABASE_URL", ""):
       from app.models.planning_parcel import PlanningParcel
       from app.models.planning_etl_run import PlanningEtlRun
       from app.models.planning_base import PlanningBase
   ```
   → update mọi `from app.models import X` ở routers/seed (search-replace, không đổi import path).

2. **Tạo `app/models/planning_base.py`:**
   ```python
   from sqlalchemy.orm import DeclarativeBase
   class PlanningBase(DeclarativeBase):
       pass  # bind metadata schema khi declare bảng
   ```

3. **Copy `planning_parcel.py` + `planning_etl_run.py`** từ faceconst, sửa import:
   - `from app.core.config` → `from app.config`
   - `from sqlmodel import SQLModel, Field` → SQLAlchemy 2.0 ORM (`Mapped, mapped_column, BigInteger, String, Float, DateTime`)
   - `from geoalchemy2 import Geometry` giữ nguyên (đã conditional ở `__init__.py`)
   - `__table_args__ = {"schema": "planning"}` giữ nguyên

4. **Copy folder `services/planning_etl/`** nguyên xi:
   ```bash
   cp -r /Users/ducld/.../faceconst/backend/app/services/planning_etl \
         /Users/ducld/.../ancu365-backend/app/services/
   ```
   Sửa imports trong từng file:
   - `from app.core.config import settings` → `from app.config import settings`
   - `from app.models.planning_parcel` → `from app.models.planning_parcel` (path giống nhau OK)

5. **Update `app/database.py`:**
   ```python
   from sqlalchemy import text
   is_postgres = settings.database_url.startswith("postgresql")
   engine = create_engine(settings.database_url, pool_pre_ping=True,
       connect_args={"check_same_thread": False} if not is_postgres else {})
   if is_postgres:
       with engine.connect() as conn:
           conn.execute(text("CREATE SCHEMA IF NOT EXISTS planning"))
           conn.commit()
   ```

6. **Update `app/main.py` startup hook:**
   ```python
   from app.database import engine
   from app.models.core import Base  # existing
   Base.metadata.create_all(bind=engine)
   if "postgres" in settings.database_url:
       from app.models.planning_base import PlanningBase
       from app.models import planning_parcel, planning_etl_run  # noqa
       PlanningBase.metadata.create_all(bind=engine)
   ```
   Add `/api/health` endpoint:
   ```python
   @app.get("/api/health")
   def health(db: Session = Depends(get_db)):
       db.execute(text("SELECT 1"))
       return {"status": "healthy", "ts": datetime.utcnow().isoformat()}
   ```

7. **Update `app/auth.py`** thêm:
   ```python
   def require_admin(claims: dict = Depends(require_user)) -> dict:
       if claims.get("role") != "admin":
           raise HTTPException(403, "Admin role required")
       return claims
   ```

8. **Init alembic:**
   ```bash
   cd ancu365-backend
   alembic init alembic
   # edit alembic/env.py: target_metadata = [Base.metadata, PlanningBase.metadata]
   alembic revision --autogenerate -m "initial schema with planning"
   alembic upgrade head
   ```

9. **Dockerfile** (dev only, prod ở P09):
   ```dockerfile
   FROM python:3.11-slim
   RUN apt-get update && apt-get install -y libpq5 libgeos-dev
   COPY requirements.txt . && pip install -r requirements.txt
   COPY app/ /app/app/
   CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
   ```

10. **Smoke test local:**
    ```bash
    docker run -d -p 5432:5432 -e POSTGRES_PASSWORD=dev postgis/postgis:16-3.4
    export DATABASE_URL=postgresql://postgres:dev@localhost:5432/postgres
    uvicorn app.main:app --reload
    curl http://localhost:8000/api/health  # expect {status:healthy}
    psql $DATABASE_URL -c "\dn"  # expect schema 'planning' exists
    psql $DATABASE_URL -c "\dt planning.*"  # expect parcels + etl_runs
    ```

## Todo List
- [ ] Rename `models.py` → `models/core.py`, tạo `__init__.py` re-export
- [ ] Tạo `models/planning_base.py`
- [ ] Port `planning_parcel.py` + `planning_etl_run.py` (sửa imports)
- [ ] Copy `services/planning_etl/` + fix imports
- [ ] Update `database.py` (CREATE SCHEMA Postgres-only)
- [ ] Update `main.py` (conditional planning load + `/api/health`)
- [ ] Add `require_admin()` vào `auth.py`
- [ ] Update `requirements.txt` (7 deps mới)
- [ ] Init alembic + revision đầu
- [ ] Dockerfile dev cho backend
- [ ] Smoke test: app start với postgres, schema/tables tồn tại
- [ ] Smoke test: SQLite mode vẫn start (no planning loaded)

## Success Criteria
- `uvicorn app.main:app` start không lỗi với `DATABASE_URL=postgresql://...`
- `psql -c "\dt planning.*"` show `planning.parcels`, `planning.etl_runs`
- `curl /api/health` trả `{status: healthy}`
- `DATABASE_URL=sqlite:///dev.db uvicorn ...` vẫn start (no planning)
- `python -m app.services.planning_etl --help` show CLI options (preparation cho P02)
- Existing endpoints (`/api/houses`, `/api/auth/...`) hoạt động bình thường (smoke test 3 calls)

## Risk Assessment
| Risk | Mức | Mitigation |
|------|-----|-----------|
| GeoAlchemy2 import crash SQLite env | Cao | Conditional `if "postgres" in DATABASE_URL` ở `models/__init__.py` |
| Existing SQLite data mất khi switch | Trung | Document migration: `sqlite3 dump → psql restore`; ghi rõ trong README backend |
| Alembic autogenerate detect sai (dual metadata) | Trung | `target_metadata = [Base.metadata, PlanningBase.metadata]`; verify revision file trước upgrade |
| faceconst code dùng `app.core.config` path khác | Thấp | Search-replace import; chạy `python -c "import app.services.planning_etl"` verify |
| Pool exhaustion khi ETL chạy đồng thời FastAPI | Trung | `pool_size=10` ở engine; ETL dùng separate session |

## Security Considerations
- ✅ Reuse `auth.py` JWT HS256 (existing); thêm `require_admin` cho ETL endpoints (preempt P03).
- [ ] Secrets: `DATABASE_URL`, `POSTGRES_PASSWORD` chỉ ở `.env` — KHÔNG commit (`.gitignore` check).
- [ ] `CREATE SCHEMA` chỉ chạy bởi superuser ở dev; prod cần grant role riêng (đề cập ở P09).
- [ ] WFS client (`wfs_client.py`) timeout `httpx.AsyncClient(timeout=30)` — đã có ở faceconst, giữ nguyên.
- [ ] Log policy: KHÔNG log full WFS response body (có thể chứa coordinates) → chỉ log count/status.

## Next Steps
- ✅ Phase 02 có thể start sau khi `psql \dt planning.*` show schema OK.
- ⚠️ Phase 04 (Flutter data layer) cần endpoint contract → block tới hết P03, nhưng types có thể được nháp song song.
