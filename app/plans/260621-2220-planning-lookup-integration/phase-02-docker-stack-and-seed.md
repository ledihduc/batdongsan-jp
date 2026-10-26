# Phase 02 — Docker Stack (PostGIS+Martin+Nominatim+nginx) + Seed HCMC 24 Quận

## Context Links
- BA: `phase-00-ba-requirements.md` § Locked Decisions D3, D5, AC-01/03, NFR
- Reports: `research/r3-vps-docker-stack.md` (docker-compose template production-ready), `r2` § 2 (Martin endpoint pattern)
- Reference code:
  - `faceconst/backend/app/services/planning_etl/hcmc_fetcher.py` (district list HCMC)
  - `faceconst/backend/app/services/planning_etl/cli.py` (`seed-all` command)
  - `faceconst/backend/docker-compose.yml`, `faceconst/postgres/init.sql`

## Overview
- Priority: **P0**
- Status: Pending
- Estimate: 1 ngày
- Description: Dựng full stack Docker (PostGIS + Martin + Nominatim + backend + nginx local) cho dev/staging; chạy seed ETL lấy 24 quận HCMC; verify Martin tile endpoint.

## Key Insights
- R3 đã có sẵn `docker-compose.yml` production-ready — copy nguyên xi, chỉ chỉnh hostname `ancu365` (vs `tagroup`).
- Nominatim import Vietnam OSM (~307MB PBF) mất ~40 phút lần đầu (start_period 3600s).
- Martin auto-publish bảng từ schema `planning` → endpoint `/planning.parcels/{z}/{x}/{y}.pbf` ready sau khi P01 schema OK + có ≥ 1 row.
- HCMC có 24 quận theo dataset hiện hữu; lưu ý sáp nhập 2025 (BA flagged) → seed thử 3-5 quận trước, full sau khi user confirm dataset mapping.
- Local dev: chỉ cần `postgis + martin` (skip nominatim vì tốn 3GB+ RAM); nominatim chỉ chạy staging/prod.

## Requirements
### Functional
- `docker compose up -d postgis martin` → backend connect được, Martin trả tile ở port 3001.
- `docker compose --profile full up -d` → thêm nominatim + backend container.
- `python -m app.services.planning_etl seed-all` (chạy trong backend container) → seed ≥ 3 quận (Quận 1, Quận 3, Bình Thạnh) lần đầu, sau đó full 24 quận.
- `curl http://localhost:3001/planning.parcels/13/6688/3892.pbf` → trả MVT (binary), HTTP 200.
- `INSERT INTO planning.etl_runs (...)` đầy đủ sau khi seed (verify timestamp + count).

### Non-functional
- Postgres `shared_buffers=2GB`, `work_mem=64MB` (per R3) — set trong `POSTGRES_INITDB_ARGS`.
- Martin `pool_size=10` trong `martin/config.yaml`.
- Tất cả container có `healthcheck` + `restart: unless-stopped`.

## Architecture
```
Host VPS (dev/staging)
  Docker network: ancu-net
  ┌────────────────────────────────────────────────────────┐
  │ postgis :5432 (127.0.0.1) ── volume: postgis-data     │
  │   ├ public schema (existing ancu365)                  │
  │   └ planning schema (parcels, etl_runs)               │
  │                                                        │
  │ martin :3001 (127.0.0.1) → connects postgis:5432       │
  │   auto_publish: planning.*                            │
  │                                                        │
  │ nominatim :8080 (127.0.0.1) [profile: full]           │
  │   PBF: vietnam-latest.osm.pbf (~307MB → 15GB import)  │
  │                                                        │
  │ backend :3000 (127.0.0.1) ── builds from ./backend     │
  │   depends_on: postgis (healthy), nominatim (healthy)  │
  │                                                        │
  │ nginx :80,:443 (public) [profile: full]               │
  │   → /api/ → backend, /tiles/ → martin                 │
  └────────────────────────────────────────────────────────┘
```

## Related Code Files

### To create
- `ancu365-backend/docker-compose.yml` (full stack — copy từ R3 §2)
- `ancu365-backend/infra/martin/config.yaml` (R3 §4)
- `ancu365-backend/infra/postgres/init.sql` (CREATE SCHEMA planning + GRANT)
- `ancu365-backend/infra/nginx/ancu365.dev.conf` (HTTP-only dev variant)
- `ancu365-backend/infra/nginx/ancu365.prod.conf` (R3 §3 HTTPS, dùng ở P09)
- `ancu365-backend/.env.example` (POSTGRES_USER/PASSWORD, NOMINATIM_PASSWORD, JWT_SECRET, ...)
- `ancu365-backend/Makefile` (shortcut: `make up`, `make seed`, `make logs`, `make psql`)

### To modify
- `ancu365-backend/.gitignore` → add `.env`, `infra/certs/`, volume dirs
- `ancu365-backend/Dockerfile` (từ P01) — verify multi-stage build, slim image

### To delete
- (none)

## Implementation Steps

1. **Copy `docker-compose.yml`** từ R3 §2, sửa:
   - Container names `ancu365-postgis`, `ancu365-martin`, `ancu365-nominatim`, `ancu365-backend`, `ancu365-nginx`
   - `BACKEND_CORS_ORIGINS` để `["*"]` dev, `["https://ancu365.vn"]` prod (override `.env`)
   - Profile `full` cho `nominatim` + `nginx` (dev không cần):
     ```yaml
     nominatim:
       profiles: ["full"]
     nginx:
       profiles: ["full"]
     ```

2. **Tạo `infra/postgres/init.sql`:**
   ```sql
   CREATE EXTENSION IF NOT EXISTS postgis;
   CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
   CREATE SCHEMA IF NOT EXISTS planning;
   GRANT USAGE ON SCHEMA planning TO PUBLIC;
   ```
   Mount vào `postgis` service:
   ```yaml
   volumes:
     - ./infra/postgres/init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro
   ```

3. **Tạo `infra/martin/config.yaml`** (theo R3 §4, sửa `from_schemas: [planning]`):
   ```yaml
   listen_addresses: "0.0.0.0:3000"
   postgres:
     connection_string: ${DATABASE_URL}
     pool_size: 10
   auto_publish:
     tables:
       from_schemas: [planning]
       id_format: "{schema}.{table}"
   cors_policy:
     allowed_origins: ["*"]
     allowed_methods: [GET, HEAD, OPTIONS]
   ```

4. **Tạo `.env.example`:**
   ```env
   # Database
   POSTGRES_USER=ancu365
   POSTGRES_PASSWORD=change_me_strong
   POSTGRES_DB=ancu365
   DATABASE_URL=postgresql://ancu365:change_me_strong@postgis:5432/ancu365

   # Nominatim
   NOMINATIM_PASSWORD=change_me
   NOMINATIM_URL=http://nominatim:8080

   # Martin
   MARTIN_URL=http://martin:3000
   MARTIN_PUBLIC_URL=http://localhost:3001  # dev

   # Backend
   JWT_SECRET=please_rotate_in_prod
   BACKEND_CORS_ORIGINS=["*"]
   ```

5. **Tạo `Makefile`:**
   ```makefile
   .PHONY: up down logs seed psql
   up:
   	docker compose up -d postgis martin
   up-full:
   	docker compose --profile full up -d
   down:
   	docker compose down
   logs:
   	docker compose logs -f
   psql:
   	docker exec -it ancu365-postgis psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)
   seed:
   	docker exec ancu365-backend python -m app.services.planning_etl seed-all
   seed-test:
   	docker exec ancu365-backend python -m app.services.planning_etl seed --districts "Quận 1,Quận 3,Bình Thạnh"
   ```

6. **Boot stack lần đầu:**
   ```bash
   cp .env.example .env  # sửa password
   make up                      # postgis + martin only (dev)
   docker compose logs postgis | grep "database system is ready"
   docker compose logs martin | grep "Listening"
   alembic upgrade head         # tạo bảng (P01)
   make seed-test               # seed 3 quận test
   ```

7. **Verify Martin endpoint:**
   ```bash
   curl -i http://localhost:3001/catalog
   # expect JSON liệt kê "planning.parcels"
   curl -o /tmp/tile.pbf http://localhost:3001/planning.parcels/13/6688/3892.pbf
   file /tmp/tile.pbf  # expect "data" (binary MVT, ~5-30KB)
   ```

8. **Verify ETL run record:**
   ```sql
   SELECT id, district, status, parcels_total, finished_at
   FROM planning.etl_runs ORDER BY id DESC LIMIT 3;
   -- expect status='success' cho 3 quận
   SELECT COUNT(*) FROM planning.parcels;
   -- expect > 1000 (Quận 1+3+BT)
   ```

9. **Full seed 24 quận** (sau khi user confirm sáp nhập HC mapping):
   ```bash
   make seed  # ~30-60 phút
   ```

10. **Document trong `ancu365-backend/README.md`:**
    - Quickstart: `cp .env.example .env && make up && alembic upgrade head && make seed-test`
    - Troubleshooting: postgis perm, Martin connect fail, nominatim slow import

## Todo List
- [ ] Copy `docker-compose.yml` từ R3, profile `full` cho nominatim+nginx
- [ ] Tạo `infra/postgres/init.sql` (PostGIS + schema)
- [ ] Tạo `infra/martin/config.yaml` (planning schema only)
- [ ] Tạo `.env.example` (rotate trước commit)
- [ ] Tạo `Makefile` shortcuts
- [ ] Boot stack dev: postgis + martin healthy
- [ ] `alembic upgrade head` thành công
- [ ] `make seed-test` → ≥3 quận, etl_runs status=success
- [ ] `curl /catalog` show planning.parcels
- [ ] `curl /planning.parcels/13/x/y.pbf` trả binary
- [ ] Full seed 24 quận sau user confirm sáp nhập HC
- [ ] README quickstart + troubleshooting

## Success Criteria
- `docker compose ps` show postgis (healthy), martin (healthy) — both <1 phút start
- `planning.parcels` có ≥ 5000 rows sau full seed (24 quận HCMC ~60K parcels)
- `planning.etl_runs` có 24 success rows (1 per district)
- Martin tile endpoint trả MVT binary cho zoom 13-16 ở bbox HCMC
- `EXPLAIN ANALYZE SELECT * FROM planning.parcels WHERE ST_Contains(geom, ST_SetSRID(ST_Point(106.69, 10.77), 4326))` < 50ms (GIST index hit)

## Risk Assessment
| Risk | Mức | Mitigation |
|------|-----|-----------|
| Nominatim import OOM (cần 4GB shm) | Cao | `shm_size: 2g` đã trong R3; dev skip nominatim (profile full); prod kiểm tra RAM trước import |
| WFS TNMT down → seed fail | Trung | Retry 3 lần (`hcmc_fetcher.py` có); skip district fail, log vào `etl_runs.status='failed'` |
| Sáp nhập đơn vị HC 2025 chưa map | Trung | Seed 3 quận test trước (Q1, Q3, BT — tên không đổi); chờ user confirm mapping cho 21 quận còn lại |
| Postgres password yếu rò rỉ | Cao | `.env` gitignored; password sinh `openssl rand -hex 32` ở prod |
| Martin connect refused (postgis chưa ready) | Trung | `depends_on: condition: service_healthy` đã có |
| Disk full khi nominatim import (15GB) | Trung | VPS ≥ 80GB SSD per R3; cảnh báo `df -h` trong P09 deploy checklist |

## Security Considerations
- ✅ All ports bind `127.0.0.1` (per R3) — chỉ nginx expose public.
- [ ] `.env` permission 600, owner non-root.
- [ ] PostGIS `postgres` superuser KHÔNG dùng cho app — tạo role `ancu365` GRANT minimal (CONNECT, USAGE, SELECT/INSERT/UPDATE on schemas).
- [ ] Martin CORS dev `*` OK; prod khóa `https://ancu365.vn` (override ở P09 nginx).
- [ ] Nominatim KHÔNG expose port 8080 ra public ngay cả prod — FastAPI proxy (P03).
- [ ] WFS request KHÔNG có credential — public WFS, không log full response body.

## Next Steps
- ✅ Phase 03 (FastAPI routes) start sau khi `planning.parcels` có ≥ 1 row + Martin trả tile.
- ⚠️ Full 24-quận seed có thể defer sau Phase 03 nếu user chưa confirm sáp nhập HC mapping.
