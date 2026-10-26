# Phase 09 — VPS Production Deploy (Docker Compose + nginx + TLS + Backup + Monitoring)

## Context Links
- BA: `phase-00-ba-requirements.md` § Locked D3 (VPS self-host), AC-18 (rate limit), Risk (legal/IP)
- Reports: `research/r3-vps-docker-stack.md` (toàn bộ — production-ready)
- Reference code: P02 docker-compose.yml, infra/martin/config.yaml, infra/nginx/

## Overview
- Priority: **P0** (release gate)
- Status: Pending
- Estimate: 1 ngày + 48h staging soak
- Description: Provision VPS, deploy full Docker stack với HTTPS TLS, daily backup, uptime monitoring. Reuse infra files từ P02. Staging soak ≥ 48h trước cutover prod.

## Key Insights
- R3 đã có sẵn `docker-compose.yml` + `nginx.conf` production-ready — chỉ cần render `.env` thật + DNS + TLS cert.
- VPS recommendation: VPSServer Vietnam 16GB/8vCPU/320GB SSD (~$40/mo) cho latency thấp nhất, hoặc Hetzner CCX23 Singapore (~$30/mo) tiết kiệm.
- **Nominatim import lần đầu MẤT ~40 phút + 4GB RAM peak** — phải provision VPS xong rồi đợi tới khi healthcheck pass mới go-live.
- Caddy reverse proxy thay nginx → auto-renew TLS, ÍT phải chỉnh hơn (R3 §3 Option 1) — recommend cho MVP solo dev.
- Daily backup pg_dump → Backblaze B2 (~$4/mo), retention 30 ngày.
- uptime-kuma + ntfy alerts (self-hosted, free) — đủ cho MVP.

## Requirements
### Functional
- Domain `ancu365.vn` (hoặc `api.ancu365.vn`) point tới VPS IP.
- HTTPS active với valid cert (Let's Encrypt).
- 5 service containers up + healthy: postgis, martin, nominatim, backend, caddy (hoặc nginx).
- ETL daily cron 2AM ICT chạy auto (APScheduler trong backend hoặc cron job host).
- Backup daily 2AM (sau ETL) → B2.
- uptime-kuma monitor 3 endpoint: `/api/health`, `/tiles/catalog`, `/api/planning/search?q=test`.

### Non-functional
- Cold start full stack (postgis + martin + backend) < 2 phút (Nominatim ngoại lệ — 1h lần đầu).
- TLS A grade (ssl-labs check).
- 48h staging soak: 0 unscheduled restart, ETL pass 2 ngày liên tiếp.
- RPO ≤ 24h (daily backup); RTO ≤ 30 phút (restore từ B2).

## Architecture
```
Internet → DNS ancu365.vn (A record) → VPS public IP
                                        ↓
                                       :80, :443 (Caddy)
                                        ├─ /api/* → backend:8000
                                        ├─ /tiles/* → martin:3000
                                        └─ rest 404
                                        
VPS internal Docker network "ancu-net":
  postgis :5432 (127.0.0.1)
  nominatim :8080 (127.0.0.1, internal proxy only)
  martin :3000 (127.0.0.1)
  backend :8000 (127.0.0.1)
  uptime-kuma :3001 (127.0.0.1 + SSH tunnel admin)
  
Host cron:
  0 2 * * * /opt/ancu365/backup.sh    # Daily backup
  0 3 * * 0 /opt/ancu365/cert-renew.sh  # Weekly cert renew (if not Caddy)
```

## Related Code Files

### To create (on VPS, outside repo)
- `/opt/ancu365/.env` (real secrets, permission 600)
- `/opt/ancu365/backup.sh` (R3 §7)
- `/opt/ancu365/Caddyfile` (replace nginx; simpler)
- `/etc/cron.d/ancu365-backup`
- `/opt/ancu365/scripts/restore.sh` (DR runbook)

### To modify (in repo)
- `ancu365-backend/infra/Caddyfile` (NEW — alternative to nginx.conf)
- `ancu365-backend/docker-compose.prod.yml` (override với caddy + uptime-kuma)
- `ancu365-backend/docs/deploy-runbook.md` (NEW)
- `ancu365-backend/.env.example` → comment cho prod (FQDN, B2 keys)

### To delete
- (none)

## Implementation Steps

1. **VPS provision** (1h):
   - Order VPSServer Vietnam 16GB or Hetzner CCX23 Singapore.
   - OS: Ubuntu 22.04 LTS.
   - Initial setup:
     ```bash
     ssh root@<ip>
     adduser ancu365 --disabled-password
     usermod -aG sudo,docker ancu365
     # SSH key only:
     mkdir -p /home/ancu365/.ssh && cp ~/.ssh/authorized_keys /home/ancu365/.ssh/
     sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
     systemctl restart sshd
     ufw allow 22,80,443/tcp && ufw enable
     ```

2. **Install Docker + Docker Compose:**
   ```bash
   curl -fsSL https://get.docker.com | sh
   apt install docker-compose-plugin
   docker --version && docker compose version
   ```

3. **DNS setup:**
   - Add A record: `ancu365.vn` → VPS IP.
   - Verify: `dig ancu365.vn +short`.

4. **Deploy code:**
   ```bash
   su - ancu365
   mkdir -p /opt/ancu365 && cd /opt/ancu365
   git clone <repo> ancu365-backend
   cd ancu365-backend
   cp .env.example .env
   # Edit .env: generate strong passwords
   openssl rand -hex 32  # for POSTGRES_PASSWORD, JWT_SECRET, NOMINATIM_PASSWORD
   chmod 600 .env
   ```

5. **Caddyfile** (replace nginx, simpler TLS):
   ```caddy
   ancu365.vn {
       # Auto TLS via Let's Encrypt
       encode gzip zstd
       
       @api path /api/*
       handle @api {
           rate_limit {
               zone api_zone {
                   key {client_ip}
                   events 100
                   window 1m
               }
           }
           reverse_proxy backend:8000
       }
       
       @tiles path /tiles/*
       handle @tiles {
           reverse_proxy martin:3000 {
               header_up X-Forwarded-Proto https
           }
           header Cache-Control "public, max-age=604800"
           header Access-Control-Allow-Origin "*"
       }
       
       handle {
           respond "Not Found" 404
       }
       
       log {
           output file /var/log/caddy/access.log
           format json
       }
   }
   ```

6. **docker-compose.prod.yml** (override P02):
   ```yaml
   services:
     postgis:
       env_file: [.env]
       restart: unless-stopped
     nominatim:
       env_file: [.env]
       restart: unless-stopped
     martin:
       env_file: [.env]
       restart: unless-stopped
     backend:
       env_file: [.env]
       restart: unless-stopped
       environment:
         ENVIRONMENT: production
         BACKEND_CORS_ORIGINS: '["https://ancu365.vn"]'
         CRON_ENABLED: "1"  # APScheduler ETL daily 2AM ICT
     caddy:
       image: caddy:2-alpine
       container_name: ancu365-caddy
       ports: ["80:80", "443:443"]
       volumes:
         - ./infra/Caddyfile:/etc/caddy/Caddyfile:ro
         - caddy-data:/data
         - caddy-config:/config
       depends_on:
         backend: { condition: service_healthy }
         martin: { condition: service_healthy }
       restart: unless-stopped
       networks: [ancu-net]
     uptime-kuma:
       image: louislam/uptime-kuma:1
       container_name: ancu365-monitor
       ports: ["127.0.0.1:3010:3001"]
       volumes: [uptime-data:/app/data]
       restart: unless-stopped
       networks: [ancu-net]
   volumes:
     caddy-data:
     caddy-config:
     uptime-data:
   ```

7. **Boot full stack:**
   ```bash
   docker compose -f docker-compose.yml -f docker-compose.prod.yml --profile full up -d
   docker compose ps  # all healthy
   docker compose logs -f nominatim  # đợi ~40 phút first import
   ```

8. **Apply migrations + seed:**
   ```bash
   docker exec ancu365-backend alembic upgrade head
   docker exec ancu365-backend python -m app.services.planning_etl seed-all
   # ~60 phút for 24 quận HCMC
   ```

9. **Verify TLS + endpoints:**
   ```bash
   curl -I https://ancu365.vn/api/health  # expect 200 + valid cert
   curl https://ancu365.vn/tiles/catalog | jq
   curl "https://ancu365.vn/api/planning/parcels?lat=10.77&lng=106.69" | jq
   # SSL Labs scan:
   curl -s "https://api.ssllabs.com/api/v3/analyze?host=ancu365.vn"
   # expect grade A
   ```

10. **Backup script** `/opt/ancu365/backup.sh` (per R3 §7):
    ```bash
    #!/bin/bash
    set -euo pipefail
    DATE=$(date +%Y%m%d_%H%M%S)
    FILE="ancu365-${DATE}.sql.gz"
    docker exec ancu365-postgis pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip > /tmp/$FILE
    b2 authorize-account $B2_KEY_ID $B2_KEY
    b2 upload-file ancu365-backups /tmp/$FILE $FILE
    rm /tmp/$FILE
    # Keep last 30 days
    b2 ls ancu365-backups | tail -n +31 | xargs -I {} b2 delete-file-version {}
    ```
    ```bash
    chmod 700 /opt/ancu365/backup.sh
    echo "0 3 * * * ancu365 /opt/ancu365/backup.sh >> /var/log/ancu365-backup.log 2>&1" \
        | sudo tee /etc/cron.d/ancu365-backup
    ```

11. **Setup uptime-kuma:**
    - SSH tunnel: `ssh -L 3010:127.0.0.1:3010 ancu365@<ip>`
    - Open `http://localhost:3010` → create admin.
    - Add 3 monitors:
      - HTTPS `https://ancu365.vn/api/health` every 60s
      - HTTPS `https://ancu365.vn/tiles/catalog` every 5min
      - HTTPS `https://ancu365.vn/api/planning/search?q=test` every 10min
    - Notification: ntfy.sh topic + Telegram bridge.

12. **Update Flutter app** prod config:
    ```bash
    flutter build apk --release \
      --dart-define=API_BASE_URL=https://ancu365.vn \
      --dart-define=MARTIN_TILE_URL=https://ancu365.vn/tiles/planning.parcels/{z}/{x}/{y}.pbf
    ```

13. **48h staging soak** (BEFORE prod cutover):
    - Deploy lên staging VPS (cùng config, domain `staging.ancu365.vn`).
    - Monitor uptime-kuma 48h: 0 unscheduled restart, ETL cron pass 2 đêm liên tiếp.
    - Verify backup chạy + restore test (R3 DR).
    - Test 50 concurrent users (loadtest with k6 or wrk):
      ```bash
      k6 run --vus 50 --duration 5m loadtest.js
      ```

14. **Cutover** (production):
    - Final backup pre-cutover.
    - Deploy cuối to prod VPS.
    - DNS cutover.
    - Monitor 24h closely.

15. **DR runbook** `docs/deploy-runbook.md`:
    - Restore from B2: download + `gunzip | docker exec postgis psql`.
    - Cert renewal: `docker exec ancu365-caddy caddy reload`.
    - Roll back: `git checkout <prev-tag> && docker compose up -d --force-recreate backend`.

## Todo List
- [ ] Provision VPS Ubuntu 22.04 + Docker
- [ ] DNS A record + verify
- [ ] Clone repo + `.env` strong secrets
- [ ] `Caddyfile` thay nginx (auto TLS)
- [ ] `docker-compose.prod.yml` override
- [ ] Boot stack + wait Nominatim import (~40 phút)
- [ ] `alembic upgrade head` + seed 24 quận
- [ ] Verify TLS A grade + 3 endpoints
- [ ] Backup script + cron daily 3AM
- [ ] uptime-kuma 3 monitors + ntfy alert
- [ ] Flutter build APK với prod URL
- [ ] 48h staging soak (0 restart, ETL pass 2 đêm)
- [ ] Loadtest 50 vus 5 phút (no 5xx)
- [ ] Cutover prod + DNS final
- [ ] DR runbook `deploy-runbook.md`
- [ ] Final security check (SSL Labs, no port leak)

## Success Criteria
- `https://ancu365.vn/api/health` trả 200 với cert valid (Let's Encrypt).
- SSL Labs grade ≥ A.
- 5 service containers healthy `docker compose ps`.
- 48h soak: 0 unscheduled restart in uptime-kuma.
- ETL daily cron 2AM ICT chạy 2 đêm liên tiếp, `planning.etl_runs.status='success'`.
- Backup daily xuất hiện trong B2; restore test 1 lần thành công.
- Loadtest 50 concurrent users 5 phút: 0 lỗi 5xx, p95 < 2s.
- DR runbook reviewed, runnable.

## Risk Assessment
| Risk | Mức | Mitigation |
|------|-----|-----------|
| Nominatim import OOM (need 4GB shm) | Cao | `shm_size: 2g` đã set; VPS ≥ 8GB; nếu 16GB → khả năng OK |
| TLS cert renewal fail silent | Cao | Caddy auto-renew + uptime-kuma weekly check via HTTPS |
| Backup script fail silent | Trung | Cron log → `/var/log/ancu365-backup.log`; uptime-kuma monitor latest backup timestamp endpoint |
| ETL cron miss daily run | Trung | APScheduler in-process; `/api/planning/admin/etl-runs` monitor; alert nếu > 36h |
| Disk full (80GB SSD) | Cao | uptime-kuma check disk %; cleanup nginx-cache nếu > 50GB; alert > 80% |
| WFS TNMT down 2 ngày liên tiếp | Trung | Retry logic in ETL; alert sau 2 fail liên tiếp; manual seed từ cached parcels |
| DDOS / scraping | Trung | Caddy rate_limit + cloudflare proxy (free tier optional) |
| VPS provider downtime | Trung | DR runbook restore B2 → new VPS ≤ 1h |
| Cutover DNS propagation delay | Thấp | Lower TTL trước cutover 24h |

## Security Considerations
- ✅ All ports bind 127.0.0.1 trừ Caddy 80/443.
- ✅ Auto TLS Let's Encrypt qua Caddy.
- ✅ HSTS header + security headers từ Caddy default.
- [ ] SSH key only, password disabled.
- [ ] UFW: chỉ 22, 80, 443 mở.
- [ ] PostgreSQL role `ancu365`: minimal grants, KHÔNG superuser.
- [ ] Secrets `.env` permission 600, chỉ owner read.
- [ ] B2 keys rotate quarterly.
- [ ] No nominatim public exposure (deny in Caddy).
- [ ] Backup files encrypted-at-rest qua B2 (server-side encryption).
- [ ] Privacy: GPS logs purge cron 30 ngày (Nghị định 13) — verify in P03 implementation.
- [ ] Reviewed Tor/abuse IP block — Caddy can add `@bad_ip` matcher if needed.

## Next Steps
- ✅ Sau cutover: monitor 7 ngày, capture metrics baseline.
- ⚠️ Phase 2: scale-out (read replica Postgres) nếu QPS > 100.
- ⚠️ Future: Move uptime-kuma + ntfy ra VPS thứ 2 cho independence.
