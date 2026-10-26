# Phase 01 Execution Report

**Date:** 2026-06-21
**Executor:** fullstack-developer

## Decision Deviation from Phase File

Phase file spec (`phase-01-backend-port-planning-module.md`) mô tả tách `models.py` → `models/core.py` + `models/__init__.py`. Tuy nhiên prompt instruction (từ orchestrator) override sang **quyết định đơn giản hơn**:
- Giữ nguyên `app/models.py` (KHÔNG rename, KHÔNG tách package)
- Tạo MỚI `app/planning_models.py` riêng biệt
- Conditional import trong `main.py` thay vì trong `models/__init__.py`

Lý do: tránh phá pattern `from app import models` ở tất cả routers hiện hữu.

## Files Created

| File | Mô tả |
|------|-------|
| `ancu365-backend/app/planning_models.py` | PlanningBase + PlanningParcel + PlanningEtlRun (SQLAlchemy 2.0 ORM, adapted từ faceconst SQLModel) |
| `ancu365-backend/app/services/__init__.py` | Empty package marker |
| `ancu365-backend/app/services/planning_etl/__init__.py` | Copied + giữ nguyên |
| `ancu365-backend/app/services/planning_etl/__main__.py` | Copied + giữ nguyên |
| `ancu365-backend/app/services/planning_etl/config.py` | Rewritten: `DATABASE_URL` từ raise-at-import → `get_database_url()` lazy function; env fallback `ETL_CONTACT_EMAIL` đổi sang `ops@ancu365.vn` |
| `ancu365-backend/app/services/planning_etl/wfs_client.py` | Copied + đổi User-Agent "FaceConst" → "Ancu365" |
| `ancu365-backend/app/services/planning_etl/hcmc_fetcher.py` | Copied nguyên xi |
| `ancu365-backend/app/services/planning_etl/postgis_loader.py` | Sửa `from .config import DATABASE_URL` → `get_database_url()` (lazy engine init) |
| `ancu365-backend/app/services/planning_etl/geometry_utils.py` | Copied nguyên xi |
| `ancu365-backend/app/services/planning_etl/scheduler.py` | Sửa `DATABASE_URL` → `get_database_url()` |
| `ancu365-backend/app/services/planning_etl/cli.py` | Sửa entry point doc + "FaceConst" → "Ancu365" |
| `ancu365-backend/alembic.ini` | Skeleton alembic config, sqlalchemy.url không hardcode |
| `ancu365-backend/alembic/env.py` | env.py khung (target_metadata=None), inject DATABASE_URL từ env |
| `ancu365-backend/alembic/versions/.gitkeep` | Empty placeholder |

## Files Modified

| File | Thay đổi |
|------|---------|
| `ancu365-backend/app/database.py` | Thêm `_ensure_planning_schema()` — CREATE SCHEMA IF NOT EXISTS planning, chỉ chạy khi Postgres |
| `ancu365-backend/app/auth.py` | Thêm `require_admin()` FastAPI dependency — check `claims["role"] == "admin"`, 403 nếu không |
| `ancu365-backend/app/config.py` | Thêm 6 planning fields: `nominatim_url`, `martin_url`, `wfs_base_url`, `wfs_request_delay_s`, `etl_contact_email`, `planning_database_url` |
| `ancu365-backend/main.py` | Thêm imports `datetime/text/Session/get_db`; conditional planning block (postgres-only); endpoint `/api/health` |
| `ancu365-backend/requirements.txt` | Append 10 deps mới (psycopg2-binary, geoalchemy2, shapely, pyproj, httpx, APScheduler, slowapi, alembic, requests, click) |
| `ancu365-backend/.env.example` | Thêm planning keys: PLANNING_DATABASE_URL, NOMINATIM_URL, MARTIN_URL, WFS_BASE_URL, ETL_CONTACT_EMAIL |
| `ancu365-backend/.gitignore` | Thêm `alembic/versions/__pycache__/` |

## Smoke Test Results

| Test | Result |
|------|--------|
| SQLite mode import (`DATABASE_URL=sqlite:///...` từ `main import app`) | **PASS** |
| Syntax check `app/planning_models.py` | **PASS** |
| Syntax check toàn bộ `app/services/planning_etl/*.py` | **PASS** (11 files) |
| Syntax check `alembic/env.py` | **PASS** |
| Syntax check modified files (`database.py`, `auth.py`, `config.py`, `main.py`) | **PASS** |
| Existing routes count | 39 routes (bao gồm `/api/health` mới) |
| `/api/health` endpoint present | **PASS** |
| `/health` endpoint vẫn tồn tại (backward compat) | **PASS** |

Note: Postgres smoke test (actual schema creation) deferred sang Phase 02 khi có Docker Postgres.

## Key Technical Decisions

1. **Lazy `get_database_url()`**: faceconst gốc dùng `DATABASE_URL: str = _raw_db_url` ở module level — sẽ raise ValueError khi import nếu env không set. Đổi sang function `get_database_url()` chỉ gọi khi cần → tránh crash SQLite mode.

2. **`planning_models.py` top-level `from geoalchemy2 import`**: GeoAlchemy2 vẫn ở top-level của file, nhưng file này chỉ được `main.py` import khi `DATABASE_URL.startswith("postgresql")` → an toàn.

3. **`alembic/env.py` — `target_metadata = None`**: Phase 01 chỉ chuẩn bị skeleton. Phase 02+ sẽ uncomment và wire `Base.metadata + PlanningBase.metadata`.

## Deferred Work (chuyển sang Phase 02)

- Docker Compose file cho PostGIS local dev (Phase 01 spec có đề cập, nhưng không cần cho smoke test SQLite)
- Alembic `revision --autogenerate` (cần Postgres running)
- Thực thi `alembic upgrade head` (cần Postgres running)
- Cài `psycopg2-binary` + `geoalchemy2` vào venv (cần system libs)
- Postgres smoke test: `CREATE SCHEMA planning` + `planning.parcels` + `planning.etl_runs`

## Concerns

- `app/services/planning_etl/__pycache__` từ faceconst đã được copy vào (từ `cp -r`). Không gây hại nhưng nên thêm `app/services/planning_etl/__pycache__/` vào `.gitignore` — đã có `__pycache__/` pattern catch-all nên không cần thêm riêng.
- `click` package được dùng bởi `cli.py` nhưng không có trong requirements gốc → đã thêm `click==8.1.7`. Verify version compat với FastAPI ecosystem (click 8.x tương thích).
- `requirements.txt` hiện chứa cả `python-dotenv==1.0.1` và `pydantic-settings` — có thể dư (pydantic-settings đọc `.env` nội tại). Không remove để tránh breaking change.
