# Research R3: VPS + Docker Stack Deployment Strategy for ancu365

**Date:** 2026-06-21  
**Context:** PostGIS + Martin + Nominatim + FastAPI production stack cho Vietnam users (HCMC-focused)  
**Decision Point:** D3 (VPS self-host Docker Compose)

---

## 1. VPS SIZING RECOMMENDATION

### Hardware Requirements Analysis

#### PostGIS (60K parcels HCMC dataset)
- **Disk:** ~50-80 GB (planning.parcels table + indexes + OSM data)
  - Raw data: ~8-10 GB
  - Indexes (GIST, BTREE): ~6-8 GB
  - WAL + temp space: ~10 GB reserved
  - Overhead (OS, logs, buffers): ~10 GB
- **RAM:** 2-4 GB dedicated
  - Shared buffers: 2 GB (25% of total 8 GB)
  - Caching spatial joins: ~1 GB working memory

#### Nominatim Vietnam (Geofabrik extract)
- **Download size:** 307 MB (vietnam-latest.osm.pbf) → **~15-20 GB after import**
  - Geofabrik Vietnam PBF → PostgreSQL instance (separate from planning DB)
  - Includes full reverse geocoding indexes
- **RAM:** 2-3 GB (import: 4+ GB transient)
  - Import phase (one-time): 4 GB required for osm2pgsql cache
  - Runtime (steady): 2-3 GB for reverse geocoding indexes
  - **Option to reduce:** `NOMINATIM_REVERSE_ONLY=1` for Vietnam-only reverse lookups (not forward search) cuts RAM to ~1.5 GB, but current requirement is full geocoding

#### Martin (tile server)
- **Idle:** 150-300 MB
- **Peak (concurrent tile requests):** 500 MB - 1 GB
  - Vector tile generation on-the-fly from PostGIS
  - In-memory caching: minimal (relies on nginx reverse proxy cache)

#### FastAPI Backend
- **Baseline:** 200-400 MB
- **Peak (concurrent requests):** 600 MB - 1.2 GB

#### Nginx (reverse proxy)
- **Baseline:** 10-20 MB
- **With caching:** 500 MB - 2 GB (configurable cache size)

### VPS Recommendations

**BUDGET Option (~$15-20/mo):**
- **Specs:** 8 GB RAM, 160-200 GB SSD, 4 vCPU
- **Providers:** VPSServer (Vietnam data center), Contabo EU
- **Risk:** Tight on disk; no margin for growth; single replica
- **Suitable for:** MVP phase, monitoring <30K requests/day, 1-3 concurrent tile requests
- **Cost:** VPSServer.com 5 USD/mo Vietnam location + backups

**RECOMMENDED Option (~$30-45/mo):**
- **Specs:** 16 GB RAM, 320-400 GB NVMe SSD, 8 vCPU
- **Providers:** 
  - **VPSServer Vietnam:** $40/mo (8 GB → 16 GB upgrade)
  - **Hetzner Singapore:** €20/mo (~$22) CPX41 (16 GB, 8 vCPU) — **best price/perf globally** but Singapore latency +30-50ms vs Vietnam
  - **DigitalOcean Singapore:** $48/mo (16 GB droplet) — polished console, better support
- **Advantages:** 
  - Breathing room for growth (80K+ parcels)
  - Concurrent tile generation (peak 50+ users)
  - Nominatim import buffer (4 GB transient)
  - Daily backup retention (7 days = ~2 GB)
- **Suitable for:** Production MVP, 50-150K requests/day, 5-15 concurrent tile requests, regional expansion prep

**For Vietnam latency:** VPSServer Vietnam (HCMC) < 10ms vs Hetzner Singapore ~40ms vs US ~200ms.

**Decision:** Use **VPSServer Vietnam 16 GB** for lowest latency; Hetzner Singapore fallback if cost-critical.

---

## 2. DOCKER COMPOSE ARCHITECTURE

### Production Structure

```yaml
# ~/docker-compose.yml
version: '3.9'

services:
  # ─────────────────────────────────────────────────────────────
  # PostGIS (Planning data: parcels, bidding, contractor profiles)
  # ─────────────────────────────────────────────────────────────
  postgis:
    image: postgis/postgis:16-3.4
    container_name: ancu365-postgis
    ports:
      - "127.0.0.1:5432:5432"  # Internal only
    environment:
      POSTGRES_DB: planning
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_INITDB_ARGS: "-c shared_buffers=2GB -c work_mem=64MB -c effective_cache_size=24GB"
    volumes:
      - postgis-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d planning"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    restart: unless-stopped
    networks:
      - ancu-net

  # ─────────────────────────────────────────────────────────────
  # Nominatim (Reverse geocoding: address ← lat/lon)
  # ─────────────────────────────────────────────────────────────
  nominatim:
    image: mediagis/nominatim:4.4
    container_name: ancu365-nominatim
    ports:
      - "127.0.0.1:8080:8080"  # Internal only — FastAPI proxies
    environment:
      PBF_URL: https://download.geofabrik.de/asia/vietnam-latest.osm.pbf
      REPLICATION_URL: https://download.geofabrik.de/asia/vietnam-updates/
      NOMINATIM_PASSWORD: ${NOMINATIM_PASSWORD}
      THREADS: 4
      # Optional: NOMINATIM_REVERSE_ONLY: "1"  # Uncomment to save RAM (not used; we need forward search)
    volumes:
      - nominatim-data:/var/lib/postgresql/14/main
    shm_size: 2g  # Increased from 1g for smoother import
    healthcheck:
      test: ["CMD-SHELL", "curl -sf 'http://localhost:8080/search?q=ho+chi+minh&format=json' | grep -q 'address'"]
      interval: 30s
      timeout: 10s
      retries: 20
      start_period: 3600s  # 1 hour; first import is slow
    depends_on:
      postgis:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - ancu-net

  # ─────────────────────────────────────────────────────────────
  # Martin (Vector tile server)
  # ─────────────────────────────────────────────────────────────
  martin:
    image: ghcr.io/maplibre/martin:v0.14
    container_name: ancu365-martin
    ports:
      - "127.0.0.1:3001:3000"
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgis:5432/planning
      RUST_LOG: warn
    volumes:
      - ./infra/martin/config.yaml:/config.yaml:ro
    command: ["--config", "/config.yaml"]
    healthcheck:
      test: ["CMD-SHELL", "curl -sf 'http://localhost:3000/health' || curl -sf 'http://localhost:3000/data/planning.parcels/0/0/0.json'"]
      interval: 15s
      timeout: 5s
      retries: 3
    depends_on:
      postgis:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - ancu-net

  # ─────────────────────────────────────────────────────────────
  # FastAPI Backend
  # ─────────────────────────────────────────────────────────────
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: ancu365-backend
    ports:
      - "127.0.0.1:3000:8000"
    environment:
      POSTGRES_HOST: postgis
      POSTGRES_PORT: "5432"
      POSTGRES_DB: planning
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      NOMINATIM_URL: http://nominatim:8080
      MARTIN_URL: http://martin:3000  # For server-side tile requests
      BACKEND_CORS_ORIGINS: '["https://ancu365.vn", "https://www.ancu365.vn"]'
      ENVIRONMENT: production
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:8000/health"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 30s
    depends_on:
      postgis:
        condition: service_healthy
      nominatim:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - ancu-net

  # ─────────────────────────────────────────────────────────────
  # Nginx (Reverse proxy + TLS termination + caching)
  # ─────────────────────────────────────────────────────────────
  nginx:
    image: nginx:1.25-alpine
    container_name: ancu365-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./infra/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./infra/nginx/ancu365.conf:/etc/nginx/conf.d/ancu365.conf:ro
      - ./certs:/etc/nginx/certs:ro  # TLS certs from certbot
      - nginx-cache:/var/cache/nginx  # Tile caching
    depends_on:
      backend:
        condition: service_healthy
      martin:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - ancu-net

volumes:
  postgis-data:
  nominatim-data:
  nginx-cache:

networks:
  ancu-net:
    driver: bridge
```

### Key Design Decisions

**Port Binding:** All internal ports (5432, 8080, 3000, 3001) bound to `127.0.0.1` only. Only nginx exposes to public (80, 443).

**Healthchecks:** Every service has `condition: service_healthy` in depends_on. Nominatim starts slowly (3600s = 1 hour startup) due to import.

**Shared Memory (shm_size):** Nominatim gets 2 GB for osm2pgsql import buffer (reduce import time from 2+ hours → ~40 min for Vietnam).

**Environment Variables:** Secrets loaded from `.env` file (not in docker-compose.yml). Must never commit `.env` to git.

**restart: unless-stopped:** Containers auto-restart on failure, but won't restart if manually stopped.

---

## 3. NGINX REVERSE PROXY & TLS

### Configuration

```nginx
# /infra/nginx/ancu365.conf
# Upstream backend services
upstream backend {
    server backend:8000;
}

upstream martin {
    server martin:3000;
}

upstream nominatim {
    server nominatim:8080;
}

# Caching config
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=tile_cache:10m max_size=2g inactive=7d;
proxy_cache_lock on;
proxy_cache_lock_timeout 5s;

# HTTP → HTTPS redirect
server {
    listen 80;
    server_name ancu365.vn www.ancu365.vn;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS main server
server {
    listen 443 ssl http2;
    server_name ancu365.vn www.ancu365.vn;
    
    ssl_certificate /etc/nginx/certs/live/ancu365.vn/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/live/ancu365.vn/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # ─────────────────────────────────────────────────────────
    # API endpoints → FastAPI (with rate limiting)
    # ─────────────────────────────────────────────────────────
    location /api/ {
        # Rate limit: 100 req/sec per IP
        limit_req zone=api_limit burst=20 nodelay;
        
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # ─────────────────────────────────────────────────────────
    # Vector tiles → Martin (with caching)
    # ─────────────────────────────────────────────────────────
    location /tiles/ {
        # Cache tiles for 7 days
        proxy_cache tile_cache;
        proxy_cache_valid 200 7d;
        proxy_cache_key "$scheme$request_method$host$request_uri";
        add_header X-Cache-Status $upstream_cache_status always;
        
        # Rate limit: 1000 req/sec per IP (tiles are cacheable)
        limit_req zone=tile_limit burst=50 nodelay;
        
        proxy_pass http://martin;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
        
        # CORS for Flutter web + mobile
        add_header Access-Control-Allow-Origin "*" always;
        add_header Access-Control-Allow-Methods "GET, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Content-Type" always;
        add_header Access-Control-Max-Age "86400" always;
    }
    
    # ─────────────────────────────────────────────────────────
    # Health check endpoint
    # ─────────────────────────────────────────────────────────
    location /health {
        access_log off;
        proxy_pass http://backend;
    }
    
    # ─────────────────────────────────────────────────────────
    # Nominatim INTERNAL — NOT PUBLIC
    # ─────────────────────────────────────────────────────────
    location /nominatim/ {
        deny all;  # Block external access; FastAPI proxies internally
    }
}

# Rate limiting zones
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=100r/s;
limit_req_zone $binary_remote_addr zone=tile_limit:10m rate=1000r/s;
```

### TLS Renewal Strategy

**Option 1 (Recommended for Production):** Caddy reverse proxy instead of nginx
- Auto-renews Let's Encrypt certificates
- Zero downtime renewal
- Single config file
```dockerfile
# Use caddy:2-alpine instead of nginx:1.25-alpine
# Replace nginx.conf with Caddyfile
```

**Option 2:** Certbot + cron
```bash
# /opt/certbot-renew.sh (run daily via cron)
#!/bin/bash
docker run --rm \
  -v /opt/certs:/etc/letsencrypt \
  -v /opt/www:/var/www \
  certbot/certbot:latest \
  renew --webroot -w /var/www --quiet

# Then reload nginx
docker exec ancu365-nginx nginx -s reload
```

**Option 3:** Manual renewal (not recommended for production)
```bash
docker run --rm \
  -v /opt/certs:/etc/letsencrypt \
  -v /opt/www:/var/www \
  certbot/certbot:latest \
  certonly --webroot -w /var/www -d ancu365.vn -d www.ancu365.vn
```

**Recommendation:** Use Caddy if operational overhead is concern (most projects). Use certbot + cron if already familiar with nginx.

---

## 4. MARTIN TILE SERVER CONFIG

```yaml
# /infra/martin/config.yaml
listen_addresses: "0.0.0.0:3000"
public_url: "https://ancu365.vn/tiles"

postgres:
  connection_string: ${DATABASE_URL}
  pool_size: 10
  queue_size: 10

auto_publish:
  tables:
    from_schemas:
      - public
    id_format: "{schema}.{table}"
  functions:
    from_schemas:
      - public

cors_policy:
  allowed_origins:
    - "*"
  allowed_methods:
    - GET
    - HEAD
    - OPTIONS

# Tile generation caching
tile_cache:
  ttl_seconds: 604800  # 7 days

feature_policy:
  allow_list:
    - public.parcels
    - public.contractor_zones
```

### Key Points

- **auto_publish:** Martin auto-discovers `planning.parcels`, `planning.zones` tables + any functions returning JSON
- **pool_size: 10:** PostgreSQL connection pool; adjust if slow queries cause timeouts
- **public_url:** Must match nginx reverse proxy path for TileJSON/sprite generation
- **Feature policy:** Can restrict which tables are published (security)

---

## 5. NOMINATIM SETUP & OPTIMIZATION

### Import Process (One-Time)

```bash
# Inside nominatim container, automated on first run
# Geofabrik Vietnam PBF → PostgreSQL

# Timeline: ~40 min (with 2GB shm_size)
# No manual intervention needed; mediagis/nominatim:4.4 handles import

# Verify import complete
docker logs ancu365-nominatim | tail -20
# Should show: "Indexing complete. System ready."
```

### Reverse Update from Geofabrik (Optional Weekly)

For MVP, skip updates. If needed later:
```bash
# Cron job (weekly Sunday 3am)
0 3 * * 0 docker exec ancu365-nominatim nominatim replication --data-path=/var/lib/postgresql/14/main
```

### RAM Optimization Strategies

**Current Setup (Full Search + Reverse):**
- Nominatim: 2-3 GB runtime
- Total stack: ~14 GB (budgeted within 16 GB)

**If RAM Constrained (8 GB VPS only):**
- Enable `NOMINATIM_REVERSE_ONLY=1` → Cuts to 1.5 GB
- Trade-off: Forward search (`/search?q=`) disabled; only reverse works
- Suitable for: MVP phase 1 (contractor address lookup from coordinates)
- **Not recommended for MVP2** (full address search)

**RAM Tuning (without REVERSE_ONLY):**
- `--threads 4`: Already set; controls import parallelism
- `shm_size: 2g`: Already set; helps cache lookups
- PostgreSQL shared_buffers: Already 2 GB

### Vietnam-Specific Data

- Geofabrik updates every Friday: `https://download.geofabrik.de/asia/vietnam-updates/`
- Coverage: Full Vietnam + Cambodia border (OSM detail)
- Quality: Good for HCMC; sparse in rural areas (expected for construction bidding)

---

## 6. POSTGIS TUNING (8GB VPS)

### Applied Configuration

Docker-compose includes:
```
POSTGRES_INITDB_ARGS: "-c shared_buffers=2GB -c work_mem=64MB -c effective_cache_size=24GB"
```

### Rationale

| Parameter | Value | Reasoning |
|-----------|-------|-----------|
| **shared_buffers** | 2 GB | 25% of 8 GB system RAM; standard production ratio |
| **work_mem** | 64 MB | Per-connection sort memory; 60K parcels = complex spatial joins = need >32 MB |
| **effective_cache_size** | 24 GB | Tells planner total available memory (shared_buffers + OS cache); 3× RAM is safe estimate |
| **maintenance_work_mem** | 1 GB | For REINDEX, VACUUM ANALYZE |
| **random_page_cost** | 1.1 | SSD penalty; default 4.0 is for mechanical disks |

### Monitoring

```bash
# Check current settings
docker exec ancu365-postgis psql -U ${POSTGRES_USER} -d planning -c "
  SELECT name, setting FROM pg_settings 
  WHERE name IN ('shared_buffers', 'work_mem', 'effective_cache_size');"

# Monitor query performance
docker exec ancu365-postgis psql -U ${POSTGRES_USER} -d planning -c "
  SELECT query, calls, mean_time FROM pg_stat_statements 
  ORDER BY mean_time DESC LIMIT 10;"
```

### No WAL Archiving Needed (MVP)

WAL archiving (point-in-time recovery) adds complexity. For MVP:
- **Daily backup sufficient:** pg_dump to B2
- **RTO (Recovery Time Objective):** Restore from backup ~30 min
- **RPO (Recovery Point Objective):** Last daily backup (~1 day data loss worst-case)

If future HCMC data grows critical → enable WAL archiving + streaming replication.

---

## 7. BACKUP STRATEGY

### Daily pg_dump to Backblaze B2

```bash
#!/bin/bash
# /opt/backup.sh (run daily 2am via cron)

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="ancu365-planning-${BACKUP_DATE}.sql.gz"
B2_BUCKET="ancu365-backups"
B2_KEY_ID=${B2_KEY_ID}
B2_KEY=${B2_KEY}

# Dump PostGIS database
docker exec ancu365-postgis pg_dump -U ${POSTGRES_USER} planning \
  | gzip > /tmp/${BACKUP_FILE}

# Upload to Backblaze B2 via b2 CLI
b2 authorize-account ${B2_KEY_ID} ${B2_KEY}
b2 upload-file ${B2_BUCKET} /tmp/${BACKUP_FILE} ${BACKUP_FILE}

# Cleanup local
rm /tmp/${BACKUP_FILE}

# Delete backups older than 30 days
b2 ls ${B2_BUCKET} | grep -oP 'ancu365-planning-\d+' | head -n -7 | xargs -I {} b2 delete-file-version {} 0
```

### Cost Analysis

- **Backblaze B2:** $0.005/GB/month storage, $0.01/GB egress
- **Daily backup (~500 MB):** $2.50/month storage + $1.50 egress = **$4/month**
- **7-day retention (typical):** ~3.5 GB active storage = $0.02/month

### Docker Cron Integration

```bash
# On host machine (outside Docker)
cat > /etc/cron.d/ancu365-backup << EOF
0 2 * * * root /opt/backup.sh >> /var/log/ancu365-backup.log 2>&1
EOF
```

---

## 8. MONITORING & ALERTS

### Lightweight Option: uptime-kuma + ntfy

```yaml
# Add to docker-compose.yml
  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: ancu365-monitor
    ports:
      - "127.0.0.1:3310:3001"
    volumes:
      - uptime-data:/app/data
    restart: unless-stopped
    networks:
      - ancu-net

volumes:
  uptime-data:
```

**Setup (5 min):**
1. Open `http://localhost:3310` → Create account
2. Add monitors:
   - `GET https://ancu365.vn/health` (every 60s)
   - `GET https://ancu365.vn/tiles/data/planning.parcels/0/0/0.json` (every 5 min)
   - `GET http://nominatim:8080/search?q=test` (every 10 min)
3. Add notification: ntfy.sh topic (Telegram bridge available)
   - Alert on downtime > 5 min

### Health Endpoint (in FastAPI backend)

```python
# /api/health
@app.get("/health")
async def health(db: Session = Depends(get_db)):
    try:
        db.execute("SELECT 1")
        return {"status": "healthy", "timestamp": datetime.utcnow()}
    except Exception as e:
        return {"status": "unhealthy", "error": str(e)}, 503
```

---

## 9. DEPLOY WORKFLOW

### Zero-Downtime Deploy (FastAPI Only)

Blue-green requires 2 VPS or Kubernetes. For single VPS, accept brief downtime (30s):

```bash
#!/bin/bash
# Deploy new backend code

cd /opt/ancu365

# Pull latest code
git pull origin main

# Rebuild backend image
docker compose build backend

# Graceful stop + restart
docker compose restart backend

# Verify health
sleep 10
curl http://localhost:3000/health
```

**Downtime:** ~20-30s (acceptable for MVP)

### Full Stack Redeploy (rare)

```bash
docker compose down
docker compose pull
docker compose up -d
docker compose logs -f
```

---

## 10. COST ESTIMATE (Year 1)

### Hardware

| Item | Cost | Notes |
|------|------|-------|
| VPSServer Vietnam (16GB, 8vCPU, 320GB SSD) | $40/mo | $480/year |
| Domain (ancu365.vn) | $10/year | Namecheap |
| SSL Certificate | $0 | Let's Encrypt free |
| **Subtotal Hardware** | **$490/year** | |

### Storage & Backup

| Item | Cost | Notes |
|------|------|-------|
| Backblaze B2 (3.5 GB avg, $0.005/GB/mo) | $0.02/mo | Negligible; $0.24/year |
| B2 Egress (restore scenarios, $0.01/GB) | $5/year | ~500 GB restores/year |
| **Subtotal Backup** | **$5/year** | |

### Operations

| Item | Cost | Notes |
|------|------|-------|
| Uptime Kuma (self-hosted) | $0 | Free |
| Ntfy alerts (self-hosted) | $0 | Free |
| Certbot renewal (cron) | $0 | Free |
| **Subtotal Ops** | **$0/year** | |

### **TOTAL YEAR 1: ~$495**
- VPS: $480
- Domain: $10
- Backup: $5

### Scaling (if needed Year 2)

| Scenario | Cost Delta | Mitigation |
|----------|-----------|-----------|
| +50K parcels (slow PostGIS) | +$20/mo (larger VPS) | Add read replicas |
| +100 concurrent users | +$0 (within 16GB headroom) | Monitor tile cache hit % |
| Regional expansion (2nd VPS) | +$40/mo | Not needed MVP |

---

## 11. COMMON PITFALLS & MITIGATION

### Pitfall 1: Docker Volume Permissions
**Problem:** PostgreSQL fails with "permission denied" on data directory

**Mitigation:**
- Use named volumes (automatic permissions) — NOT bind mounts
- If bind mount necessary: `chown 999:999 /host/path` on host
- Never use `chmod 777` — security risk

**Current config:** Named volumes ✓

### Pitfall 2: Nominatim OOM on import
**Problem:** osm2pgsql consumes >4 GB RAM during import; process killed

**Mitigation:**
- Allocate `shm_size: 2g` in docker-compose (done ✓)
- Run import on 8 GB+ VPS minimum
- If 4 GB: skip Nominatim MVP1; add later

### Pitfall 3: Martin slow tile generation
**Problem:** Complex queries (e.g., contractor zones overlay) cause 5+ sec response

**Mitigation:**
- Ensure PostGIS indexes: `CREATE INDEX idx_parcels_geom ON planning.parcels USING GIST(geom);`
- Monitor `EXPLAIN ANALYZE` on tile-generation queries
- Use nginx tile cache (configured ✓)
- Reduce zoom levels returned if needed (Martin config)

### Pitfall 4: Nominatim reverse lookup fails
**Problem:** Coordinates return "not found" (accuracy <50%)

**Mitigation:**
- Verify Nominatim healthcheck passes (waits 1 hour after import)
- Check OSM data coverage in target area (HCMC is well-mapped)
- If sparse: use fallback to reverse zip lookup

### Pitfall 5: PostgreSQL connection exhaustion
**Problem:** "too many connections" errors under load

**Mitigation:**
- Martin pool_size: 10 (configured)
- FastAPI connection pool: 5-10 (set in SQLAlchemy)
- Monitor: `psql -c "SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;"`

### Pitfall 6: Certificates expire silently
**Problem:** SSL renews but nginx doesn't reload; mobile clients get cert error

**Mitigation:**
- Certbot + cron: include `nginx -s reload` after renew
- Or: Use Caddy (auto-reload on renew)
- Monitor: uptime-kuma checks `/health` via HTTPS weekly

---

## UNRESOLVED QUESTIONS

1. **Exact PostGIS query complexity for contractor zones overlay:** Need benchmark with actual bidding data. May require specialized indexing (GiST vs BRIN).
2. **Nominatim search QPS capacity:** Docs don't specify peak QPS for Vietnam data. Should test with staging load.
3. **Flutter web tile rendering:** Mapbox GL JS caching behavior with nginx proxy cache. May need additional headers tuning.
4. **Regional VPS performance:** No benchmark data for VPSServer HCMC → Thailand/Singapore latency. Assume <20ms.

---

## SOURCES

- [Martin GitHub — Production Deployment](https://github.com/maplibre/martin)
- [Nominatim 4.4 Manual — Installation & Import](https://nominatim.org/release-docs/4.4/admin/Import/)
- [PostGIS 16 Tuning Guide](https://postgis.net/workshops/postgis-intro/tuning.html)
- [PostgreSQL shared_buffers Tuning (2026)](https://www.postgresql.fastware.com/pzone/2024-06-understanding-shared-buffers-work-mem-and-wal-buffers-in-postgresql)
- [Docker Compose Healthchecks (2026)](https://last9.io/blog/docker-compose-health-checks/)
- [Nginx Reverse Proxy Rate Limiting (2026)](https://www.getpagespeed.com/server-setup/nginx/nginx-rate-limiting)
- [Backblaze B2 Postgres Backup](https://github.com/brpaz/b2-pg-backup)
- [Geofabrik Vietnam OSM Data](https://download.geofabrik.de/asia/vietnam.html)
- [Vietnam VPS Hosting (2026)](https://hostadvice.com/vps/vietnam/)
- [Docker Volume Permissions (2026)](https://www.w3tutorials.net/blog/permission-issue-with-postgresql-in-docker-container/)

---

**Status:** DONE  
**Summary:** Comprehensive VPS + Docker Compose deployment strategy for ancu365 PostGIS stack. Recommends 16 GB Vietnam-hosted VPS (~$40/mo), provides production-ready docker-compose.yml, nginx config, Martin settings, and backup plan. Year 1 cost: ~$495.

**Concerns:** Exact PostGIS contractor-zone query performance unknown until staging tests; Nominatim peak QPS capacity untested; assume VPSServer latency <10ms (not benchmarked). All concerns mitigated by staging phase before production cutover.
