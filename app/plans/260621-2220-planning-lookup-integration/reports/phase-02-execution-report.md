# Phase 02 Execution Report

**Date:** 2026-06-21  
**Phase:** 02 — Docker Stack (PostGIS + Martin + Nominatim + Nginx) + Seed config  
**Executor:** fullstack-developer

---

## Files Created

| File | Size (est) | Notes |
|------|-----------|-------|
| `ancu365-backend/docker-compose.yml` | 80 lines | Full stack; profiles `full` for nominatim + nginx |
| `ancu365-backend/infra/postgres/init.sql` | 30 lines | PostGIS ext + planning schema + grants |
| `ancu365-backend/infra/martin/config.yaml` | 22 lines | auto_publish schema=planning, pool_size=10 |
| `ancu365-backend/infra/nginx/ancu365.dev.conf` | 45 lines | HTTP-only, /api/ + /tiles/ rewrite |
| `ancu365-backend/infra/nginx/ancu365.prod.conf` | 100 lines | HTTPS, rate limit 100r/s API / 1000r/s tiles, CORS locked to ancu365.vn |
| `ancu365-backend/.env.example` | 35 lines | Overwritten — merged old keys + new planning keys |
| `ancu365-backend/Makefile` | 50 lines | up, up-full, down, logs, ps, psql, migrate, seed, seed-test, restart-backend, health |
| `ancu365-backend/Dockerfile` | 22 lines | python:3.11-slim, libpq5 + libgeos + libproj, uvicorn |

## Files Modified

| File | Change |
|------|--------|
| `ancu365-backend/.gitignore` | Added: `.env.local`, `infra/certs/`, `infra/postgres-data/`, `infra/nominatim-data/`, `alembic/versions/__pycache__/` |
| `ancu365-backend/README.md` | Appended "Planning Lookup module" section (quickstart, full seed, troubleshooting) — old content intact |

---

## Validation

| Check | Result | Detail |
|-------|--------|--------|
| YAML syntax `docker-compose.yml` | **PASS** | `python3 -c "yaml.safe_load(...)"` — no exceptions |
| YAML syntax `infra/martin/config.yaml` | **PASS** | `yaml.safe_load(...)` — listen_addresses, pool_size, from_schemas validated |
| `docker compose config --quiet` | **PASS** | No errors. Warnings only: env vars not set (expected — no .env at validate time) |
| nginx configs syntax | **Manual check PASS** | HTTP-only dev + HTTPS prod — structure and directives verified by reading |
| SQL `init.sql` semantic | **Manual check PASS** | CREATE EXTENSION + SCHEMA + DO block GRANT — correct PostgreSQL 16 syntax |

---

## Deferred to User / Phase 09

- **Boot actual stack** — requires Docker Desktop running (`Cannot connect to Docker daemon`)
- **`alembic upgrade head`** — needs live postgis container
- **Seed HCMC** (`make seed-test`) — needs WFS STNMT reachable + daemon up
- **Smoke test Martin** — `curl /catalog`, tile endpoint — needs running stack
- **Full 24-district seed** — pending user confirm 2025 sáp nhập HC mapping (quan-1~12, binh-thanh, etc.)
- **TLS certs** (`infra/certs/`) — Phase 09 deploy; certbot/acme.sh

---

## Design Notes

1. **init.sql vs alembic:** `init.sql` only creates extensions + schema + grants (idempotent). Tables (`planning.parcels`, `planning.etl_runs`) are managed by alembic + `planning_models.py` (Phase 01). This avoids schema drift.

2. **Profile `full`:** Nominatim + nginx excluded from default compose to keep local dev lean (nominatim needs 3-4 GB RAM + 40 min import). `make up` = just postgis + martin + backend.

3. **Martin healthcheck:** Uses `wget` (available in alpine-based martin image) since `curl` may not be present in the `ghcr.io/maplibre/martin` image.

4. **`docker-compose.yml` backend `env_file` + `environment`:** env_file loads `.env`; the explicit `environment` block overrides `DATABASE_URL` to use the container hostname `postgis` (not localhost). This lets `.env` keep `DATABASE_URL=postgresql://...@postgis:...` consistently.

5. **nginx prod config:** Rate limit zones (`limit_req_zone`) defined at top of `ancu365.prod.conf`. If nginx `http {}` block doesn't include this file, they must be moved to a parent `nginx.conf`. Documented in comment.

---

## Open Questions / Blockers

1. **Port 3000 conflict:** Backend container listens on `127.0.0.1:3000`. The Martin R3 template uses `backend:8000` internally but this project uses `uvicorn --port 3000`. The compose file uses `3000:3000` — consistent with `main.py`. Confirm no port conflict with Martin's internal `3000` (Martin host port is `3001`). ✅ No conflict — Martin binds `127.0.0.1:3001:3000`; backend `127.0.0.1:3000:3000`.

2. **`IMPORT_STYLE=address` for Nominatim:** R3 uses default (full). The task spec says `IMPORT_STYLE=address` — this reduces import size but limits forward search. If full address search needed in P03, change to `IMPORT_STYLE=full` before first Nominatim start (volume must be empty).

3. **Sáp nhập HC 2025:** `make seed-test` uses `--districts "quan-1,quan-3,binh-thanh"` (slug format). Confirm slug format matches `app/services/planning_etl` district name resolution before running.
