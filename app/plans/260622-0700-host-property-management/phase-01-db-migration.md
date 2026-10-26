---
title: "Phase 01 — DB Migration SQLite → Postgres + Alembic baseline"
description: "Migrate dev DB to Postgres 16, create Alembic baseline for ALL core tables, pytest-postgresql + CI setup"
status: pending
priority: P1
effort: 2-3d
branch: TBD
tags: [backend, infrastructure, migration, alembic, postgres]
created: 2026-06-22
---

# Phase 01 — DB Migration SQLite → Postgres

**Sized:** 2–3d
**Status:** ⏸ Pending (Ready)
**Blocks:** 01b, 02, 03, 04, 05, 06, 07, 08 (all subsequent phases)
**Blocked by:** None (foundation phase)

## Context links
- BA doc §9 (D1 reset OK, Q4 chưa launch), §9b row 01, §9c Migration constraints
- Research: `research/researcher-postgres-migration.md` (concrete 10-step plan §3.2), `research/researcher-backend-audit.md` §4 (DB config)
- Code files affected: `main.py`, `alembic/env.py`, `docker-compose.yml`, `app/seed.py`, `tests/conftest.py`

## Overview
Migrate khỏi SQLite về Postgres 16 (PostGIS, dùng chung instance với planning module). Tạo Alembic baseline cho TẤT CẢ core tables (users, houses, bookings, ...), remove `metadata.create_all()` ở app startup. Setup pytest-postgresql fixture + GitHub Actions Postgres service.

## Key insights from research
- Codebase đã hỗ trợ dual-mode DB qua `DATABASE_URL` env var → KHÔNG cần code changes ở models
- D1 sealed: reset data OK (chưa có production user) → tiết kiệm 2-3d migration script
- Postgres 16 + PostGIS đã có sẵn trong `docker-compose.yml` (planning module dùng) — chỉ cần upgrade `start_period 30s→60s`
- Alembic autogenerate sẽ generate baseline; cần review JSON column type (images, amenities) — autogen có thể nhận nhầm thành TEXT
- `target_metadata = None` đang comment trong `alembic/env.py:28-35` → cần enable

## Requirements

### Functional
- App start được trên Postgres không error
- `alembic upgrade head` apply clean migration
- Seed script chạy idempotent
- Pytest tests pass trên Postgres container

### Non-functional
- CI workflow chạy <5 phút
- Docker postgis healthcheck pass <60s
- Migration safe: documented rollback procedure

## Architecture

### Backend
**Models:** Không thay đổi (database-agnostic SQLAlchemy types).

**Migrations:**
- `alembic/versions/0002_initial_baseline_all_tables.py` — CREATE TABLE cho users, houses, bookings, categories, amenities, wishlists, reviews, notifications, chat_messages
- Existing `0001_planning_reports.py` giữ nguyên (planning module riêng)

**Files modified:**
- `alembic/env.py` — enable `target_metadata = [Base.metadata, PlanningBase.metadata]`
- `main.py` — REMOVE `Base.metadata.create_all(bind=engine)` ở line 50 (vẫn giữ planning conditional ở line 61 hoặc chuyển sang alembic)
- `docker-compose.yml` — `start_period: 30s → 60s` cho postgis service
- `.env.example` — update `DATABASE_URL=postgresql://...` default sample
- `requirements.txt` — add `pytest-postgresql==6.0.0`

### Flutter
**Không thay đổi.** Flutter dùng REST API, không kết nối trực tiếp DB. Backend URL không đổi.

### Data flow
```
Dev local: docker compose up postgis → alembic upgrade head → python scripts/seed_dev.py → uvicorn main:app
CI: postgres service container → install deps → alembic upgrade head → pytest
```

## Related code files

### Backend new files
- `backend/scripts/seed_dev.py` — wrap `app.seed.run()` with CLI entry
- `backend/alembic/versions/0002_initial_baseline_all_tables.py`
- `backend/tests/conftest.py` (rewrite or add postgres fixture)
- `backend/tests/test_smoke_postgres.py`
- `backend/.github/workflows/tests.yml` (nếu chưa có) hoặc update existing

### Backend modified files
- `backend/alembic/env.py` — uncomment `target_metadata`, import Base + PlanningBase
- `backend/main.py` — remove line 50 `Base.metadata.create_all(bind=engine)`
- `backend/docker-compose.yml` — bump `start_period: 60s`
- `backend/.env.example` — change default to Postgres URL
- `backend/requirements.txt` — add pytest-postgresql
- `backend/README.md` — update setup section

## Implementation steps

1. **Backend (env):** Update `alembic/env.py` line 28-35: import `from app.database import Base` + `from app.planning_models import PlanningBase`. Set `target_metadata = [Base.metadata, PlanningBase.metadata]`.
2. **Backend (docker):** Edit `docker-compose.yml` line ~30 (postgis healthcheck): `start_period: 60s`.
3. **Backend (env):** Cập nhật `.env.example`: `DATABASE_URL=postgresql://ancu365:change_me@localhost:5432/ancu365` + POSTGRES_USER/PASSWORD/DB.
4. **Backend (cleanup):** Remove `Base.metadata.create_all(bind=engine)` ở `main.py:50`. Giữ planning conditional ở line 56-61 cho tới khi planning move sang alembic.
5. **Backend (migration):** `docker compose up -d postgis` → wait healthy → `alembic revision --autogenerate -m "initial_baseline_all_tables"` → review file, verify JSON columns dùng `sa.JSON()`, FK constraints có mặt, indexes (host_id, status, created_at) include.
6. **Backend (verify):** `alembic upgrade head` → connect psql → `\dt` → verify 9 tables tạo OK.
7. **Backend (seed):** Tạo `scripts/seed_dev.py`:
   ```python
   from app.database import SessionLocal
   from app.seed import run
   if __name__ == "__main__":
       with SessionLocal() as db:
           run(db)
       print("Seed completed")
   ```
8. **Backend (deps):** `pip install pytest-postgresql==6.0.0` → add vào `requirements.txt`.
9. **Backend (tests):** Update `tests/conftest.py` với pytest-postgresql fixture (xem research §2.6):
   ```python
   @pytest.fixture(scope="session")
   def db_engine(postgresql):
       url = f"postgresql://{postgresql.info.user}@{postgresql.info.host}:{postgresql.info.port}/{postgresql.info.dbname}"
       engine = create_engine(url)
       Base.metadata.create_all(bind=engine)
       yield engine
       engine.dispose()
   ```
10. **Backend (smoke tests):** Create `tests/test_smoke_postgres.py` — 5-10 cases: User CRUD, House CRUD with FK, Booking status transitions, Category seed, cross-host query (Host A queries → no rows of Host B).
11. **Backend (CI):** Create/update `.github/workflows/tests.yml` với postgres:16 service container (xem research §2.5). Steps: checkout → setup-python → install → `alembic upgrade head` → `pytest`.
12. **Backend (docs):** Update `README.md` Setup section: docker compose + alembic + seed_dev + uvicorn instructions.
13. **Smoke E2E:** `docker compose down -v && docker compose up -d` → app starts → `curl /docs` → register user → create house → list houses. All pass.

## Todo list
- [ ] Update `alembic/env.py` target_metadata
- [ ] Bump postgis healthcheck `start_period: 60s`
- [ ] Update `.env.example` Postgres defaults
- [ ] Remove `Base.metadata.create_all()` from `main.py`
- [ ] Generate Alembic baseline migration
- [ ] Review migration: JSON cols, FK, indexes
- [ ] Apply migration to clean Postgres
- [ ] Create `scripts/seed_dev.py`
- [ ] Add `pytest-postgresql` dependency
- [ ] Rewrite `tests/conftest.py` Postgres fixture
- [ ] Write `tests/test_smoke_postgres.py`
- [ ] Setup GitHub Actions Postgres service workflow
- [ ] Update `README.md` setup instructions
- [ ] Smoke E2E test: docker → migration → seed → register → CRUD

## Success criteria (testable)
- AC1: `docker compose up` + `alembic upgrade head` succeed lần đầu không error
- AC2: `pytest` chạy clean trên Postgres (no SQLite anywhere)
- AC3: `scripts/seed_dev.py` idempotent (chạy 2 lần không duplicate)
- AC4: GitHub Actions CI workflow green
- AC5: API smoke: register → login → create house → list — all 200 OK
- AC6: `psql -c "\dt"` shows 9+ core tables created from alembic, not metadata.create_all
- Demo: reset volume → docker up → alembic upgrade → seed → uvicorn → curl /docs renders Swagger

## Risk assessment
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| JSON cols autogen mislabel as TEXT | 30% | MED | Manual review migration; force `sa.JSON()` |
| DateTime timezone mismatch | 20% | LOW | Keep `timezone=False` cho consistency |
| FK CASCADE missing | 40% | MED | Document Phase 02 refactor; accept Phase 01 baseline |
| Booking state machine constraint missing | 15% | LOW | Smoke tests validate transitions |
| Postgres connection from host vs container | 25% | LOW | Use `postgis` service hostname inside container, `localhost:5432` from host |

## Security considerations
- `.env` MUST be gitignored (verify); only commit `.env.example`
- Postgres password strong (64 chars random) ngay từ dev
- Port binding `127.0.0.1:5432` only (not `0.0.0.0`) — đã đúng trong current `docker-compose.yml`
- CI uses ephemeral service container, no persistent secrets

## Next steps
- Unblocks Phase 01b (Booking rename can now run on stable DB)
- Unblocks Phase 02+ (foundation phases assume Postgres)
- Dependencies for next: 01b chỉ rename + smoke test, không touch schema
