# ancu365 backend — Makefile shortcuts
# Prerequisites: Docker + .env file (cp .env.example .env)
# Usage: make <target>

.PHONY: up up-full down logs ps psql migrate seed seed-test restart-backend health \
        prod-up prod-logs backup loadtest

# ── Stack management ──────────────────────────────────────────────────────────

## Start dev stack (postgis + martin + backend only)
up:
	docker compose up -d postgis martin backend

## Start full stack (+ nominatim + nginx); first run takes ~40 min for Nominatim import
up-full:
	docker compose --profile full up -d

## Stop all containers (keeps volumes)
down:
	docker compose down

## Tail all service logs
logs:
	docker compose logs -f

## Show container status
ps:
	docker compose ps

# ── Database ──────────────────────────────────────────────────────────────────

## Open psql shell in postgis container
psql:
	docker exec -it ancu365-postgis psql -U $${POSTGRES_USER} -d $${POSTGRES_DB}

## Run alembic migrations inside backend container
migrate:
	docker exec ancu365-backend alembic upgrade head

# ── ETL seed ──────────────────────────────────────────────────────────────────

## Quick test seed: Q1, Q3, Bình Thạnh (~5 min, WFS reachable required)
seed-test:
	docker exec ancu365-backend python -m app.services.planning_etl seed --districts "quan-1,quan-3,binh-thanh"

## Full seed: all 24 HCMC districts (~30-60 min); confirm sáp nhập HC mapping first
seed:
	docker exec ancu365-backend python -m app.services.planning_etl seed-all

# ── Ops ───────────────────────────────────────────────────────────────────────

## Restart backend without touching postgis/martin
restart-backend:
	docker compose restart backend

## Quick health check for backend + Martin
health:
	@echo "=== Backend ===" && \
	  curl -sf http://localhost:3000/api/health && echo "" || echo "Backend not up"
	@echo "=== Martin catalog ===" && \
	  curl -sf http://localhost:3001/catalog | python3 -m json.tool | head -30 || echo "Martin not up"

# ── Production ────────────────────────────────────────────────────────────────

## Boot production stack (base + prod override; requires ANCU_DOMAIN in .env)
prod-up:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml --profile full up -d

## Tail backend + caddy logs (Ctrl-C to stop)
prod-logs:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml logs -f backend caddy

## Run manual database backup (uploads to B2; requires B2_* vars in .env)
backup:
	./scripts/backup.sh

## Run k6 load test against ANCU_DOMAIN (requires k6 installed and ANCU_DOMAIN in .env)
loadtest:
	@if ! command -v k6 &>/dev/null; then \
	  echo "k6 not found. Install: brew install k6  OR  https://k6.io/docs/getting-started/installation/"; \
	  exit 1; \
	fi
	@if [ -z "$${ANCU_DOMAIN}" ]; then \
	  echo "ANCU_DOMAIN not set. Run: export ANCU_DOMAIN=ancu365.vn  or set in .env"; \
	  exit 1; \
	fi
	k6 run --env TARGET_HOST=https://$${ANCU_DOMAIN} docs/loadtest/loadtest.js
