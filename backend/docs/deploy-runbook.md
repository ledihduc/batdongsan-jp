# ancu365 Deploy Runbook

> Version: 1.0 | Last updated: 2026-06-21
> Audience: Ops / solo dev deploying ancu365 backend to VPS
> Stack: Ubuntu 22.04 + Docker Compose + Caddy + PostGIS + Martin + Nominatim + FastAPI

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [VPS First-Boot](#2-vps-first-boot)
3. [DNS Setup](#3-dns-setup)
4. [Initial Deploy](#4-initial-deploy)
5. [Migrations + Seed](#5-migrations--seed)
6. [TLS Verify](#6-tls-verify)
7. [Monitoring Setup](#7-monitoring-setup)
8. [Backup Verify](#8-backup-verify)
9. [Flutter Prod Build](#9-flutter-prod-build)
10. [48h Staging Soak Checklist](#10-48h-staging-soak-checklist)
11. [Cutover Procedure](#11-cutover-procedure)
12. [Disaster Recovery](#12-disaster-recovery)
13. [Cert Renewal](#13-cert-renewal)
14. [Rollback](#14-rollback)
15. [Troubleshooting Matrix](#15-troubleshooting-matrix)

---

## 1. Prerequisites

### Hardware (VPS)

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM      | 8 GB    | 16 GB (Nominatim needs ~4 GB during import) |
| CPU      | 4 vCPU  | 8 vCPU |
| Disk     | 160 GB SSD | 320 GB SSD (OSM data + PostgreSQL growth) |
| OS       | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |

**Recommended providers:**
- VPSServer Vietnam (lowest latency for HCMC users, ~$40/mo for 16 GB)
- Hetzner CCX23 Singapore (~$30/mo, good price/perf)

### Domain

- `ancu365.vn` registered and DNS control available
- A record must point to VPS IP (see §3)

### Backblaze B2

- Account at https://www.backblaze.com/
- Create bucket: `ancu365-backups`
- Create Application Key with read + write + deleteFiles on that bucket
- Note: `keyId` and `applicationKey`

### Software (local machine)

- SSH client + key pair
- `git`
- `flutter` SDK (for mobile build, §9)
- `k6` (for load test, optional)

---

## 2. VPS First-Boot

Run as `root` on a fresh Ubuntu 22.04 VPS. The `firstboot.sh` script is idempotent.

```bash
# Option A: pipe from GitHub (after pushing scripts/)
curl -fsSL https://raw.githubusercontent.com/YOUR_ORG/ancu365-backend/main/scripts/firstboot.sh | bash

# Option B: scp and run
scp scripts/firstboot.sh root@<vps-ip>:/tmp/
ssh root@<vps-ip> bash /tmp/firstboot.sh
```

What `firstboot.sh` does (each step is idempotent):
1. System update + install packages
2. Create `ancu365` user + add to `sudo` + `docker` groups
3. Copy SSH authorized_keys from root → ancu365; disable SSH password auth
4. UFW: allow 22, 80, 443 only
5. Create 4 GB swap file
6. Install Docker + Docker Compose plugin
7. Clone repo to `/opt/ancu365/ancu365-backend`
8. Configure logrotate for `/var/log/ancu365-backup.log`

After firstboot, verify:

```bash
ssh ancu365@<vps-ip>           # should work with key only
docker --version               # Docker 24+
docker compose version         # v2+
ufw status                     # shows 22, 80, 443
free -h                        # shows ~4 GB swap
```

---

## 3. DNS Setup

In your domain registrar's DNS panel:

| Type | Name       | Value       | TTL    |
|------|------------|-------------|--------|
| A    | ancu365.vn | `<vps-ip>`  | 300    |
| A    | www        | `<vps-ip>`  | 300    |

> Tip: Set TTL to 300 (5 min) during initial deploy. Lower to 60 before cutover (§11).

Verify propagation (may take up to 24h; usually < 5 min):

```bash
dig ancu365.vn +short           # should print VPS IP
dig www.ancu365.vn +short
# OR
nslookup ancu365.vn 8.8.8.8
```

Do NOT proceed to §4 until DNS resolves correctly — Caddy needs DNS to obtain TLS cert.

---

## 4. Initial Deploy

```bash
ssh ancu365@<vps-ip>
cd /opt/ancu365/ancu365-backend

# If repo not yet cloned by firstboot.sh (REPO_URL placeholder not set):
git clone https://github.com/YOUR_ORG/ancu365-backend.git .

# Configure environment
cp .env.example .env
nano .env   # Fill in all values; generate strong secrets:
#   openssl rand -hex 32   # for POSTGRES_PASSWORD, JWT_SECRET
#   openssl rand -hex 32   # for NOMINATIM_PASSWORD
chmod 600 .env

# Verify required prod vars are set
grep -E "ANCU_DOMAIN|B2_KEY_ID|B2_APPLICATION_KEY|POSTGRES_PASSWORD|JWT_SECRET" .env
```

Boot the full production stack:

```bash
# Full stack: postgis + martin + backend + nominatim + caddy (Nominatim import ~40 min)
make prod-up

# Watch all logs
make prod-logs

# Watch Nominatim specifically (takes 30-60 min first time)
docker compose logs -f nominatim
# When ready you'll see: "Nominatim is ready to accept connections"
```

Check container health:

```bash
docker compose ps
# All containers should show "healthy" or "running"
# Expected: postgis, martin, backend, nominatim, caddy, uptime-kuma
```

---

## 5. Migrations + Seed

After all containers are `healthy`:

```bash
# Apply database schema migrations
docker exec ancu365-backend alembic upgrade head

# Quick smoke test: seed 3 quận (~5 min, WFS endpoint must be reachable)
make seed-test

# Verify data in database
docker exec ancu365-postgis psql -U ancu365 -d ancu365 \
    -c "SELECT district_code, count(*) FROM planning.parcels GROUP BY 1 ORDER BY 1;"

# Full seed: all 24 HCMC quận (~30-60 min)
# Run in a screen/tmux session to survive SSH disconnect
make seed

# Check ETL run status
docker exec ancu365-postgis psql -U ancu365 -d ancu365 \
    -c "SELECT * FROM planning.etl_runs ORDER BY started_at DESC LIMIT 5;"
```

---

## 6. TLS Verify

Caddy auto-obtains Let's Encrypt cert when the domain resolves to the VPS.  
Wait ~1-2 min after first start for ACME challenge to complete.

```bash
# Basic health check over HTTPS
curl -I https://ancu365.vn/api/health
# Expected: HTTP/2 200

# Verify cert details
curl -sv https://ancu365.vn/api/health 2>&1 | grep -E "subject:|expire"

# Tiles endpoint
curl -s https://ancu365.vn/tiles/catalog | python3 -m json.tool | head -20

# Planning query
curl -s "https://ancu365.vn/api/planning/parcels?lat=10.7769&lng=106.7009" | python3 -m json.tool | head -30

# SSL Labs grade check (async — takes 1-2 min)
curl -s "https://api.ssllabs.com/api/v3/analyze?host=ancu365.vn&startNew=on" | python3 -m json.tool
# Re-poll (wait ~90s then run without startNew=on):
curl -s "https://api.ssllabs.com/api/v3/analyze?host=ancu365.vn" | python3 -m json.tool | grep grade
# Expected: grade "A" or "A+"
```

If TLS fails:
- Check DNS is resolving: `dig ancu365.vn +short`
- Check Caddy logs: `docker compose logs caddy | tail -50`
- Verify ports 80 + 443 are open in UFW: `ufw status`

---

## 7. Monitoring Setup

### Uptime-Kuma (SSH tunnel access)

From your local machine:

```bash
ssh -L 3010:127.0.0.1:3010 ancu365@<vps-ip> -N &
# Then open: http://localhost:3010
```

Initial setup in Uptime-Kuma:
1. Create admin account
2. Add 3 monitors:

| Name | Type | URL | Interval |
|------|------|-----|----------|
| Backend Health | HTTPS | `https://ancu365.vn/api/health` | 60s |
| Tiles Catalog  | HTTPS | `https://ancu365.vn/tiles/catalog` | 5 min |
| Planning Search | HTTPS | `https://ancu365.vn/api/planning/search?q=test` | 10 min |

3. Add ntfy notification:
   - Go to Settings → Notifications → Add ntfy
   - URL: `https://ntfy.sh` (or your self-hosted ntfy URL)
   - Topic: value of `NTFY_TOPIC` in your `.env`
   - Apply to all monitors

### Install backup cron

```bash
sudo cp /opt/ancu365/ancu365-backend/scripts/cron-backup /etc/cron.d/ancu365-backup
sudo chmod 644 /etc/cron.d/ancu365-backup
sudo chown root:root /etc/cron.d/ancu365-backup
# Verify:
cat /etc/cron.d/ancu365-backup
```

---

## 8. Backup Verify

### Manual trigger

```bash
cd /opt/ancu365/ancu365-backend
./scripts/backup.sh
# Expected output: "[backup] Done." with backup size
```

### Verify in B2

```bash
b2 authorize-account $B2_KEY_ID $B2_APPLICATION_KEY
b2 ls ancu365-backups
# Should list today's backup: ancu365-YYYYMMDD_HHmmss.sql.gz
```

### Restore drill (do this before 48h soak)

See §12 — Disaster Recovery.

---

## 9. Flutter Prod Build

With backend live at `https://ancu365.vn`, build the Flutter app:

```bash
# APK (Android)
flutter build apk --release \
    --dart-define=API_BASE_URL=https://ancu365.vn \
    --dart-define=MARTIN_TILE_URL=https://ancu365.vn/tiles/planning.parcels/{z}/{x}/{y}.pbf

# iOS (requires macOS + Xcode)
flutter build ios --release \
    --dart-define=API_BASE_URL=https://ancu365.vn \
    --dart-define=MARTIN_TILE_URL=https://ancu365.vn/tiles/planning.parcels/{z}/{x}/{y}.pbf

# AAB (Play Store)
flutter build appbundle --release \
    --dart-define=API_BASE_URL=https://ancu365.vn \
    --dart-define=MARTIN_TILE_URL=https://ancu365.vn/tiles/planning.parcels/{z}/{x}/{y}.pbf
```

Test with a real device pointed at the staging URL first.

---

## 10. 48h Staging Soak Checklist

Deploy to staging VPS first (same configuration, domain `staging.ancu365.vn`).  
Monitor for 48 consecutive hours before production cutover.

### Pre-soak setup
- [ ] Stack fully up: `docker compose ps` shows all 6 containers healthy
- [ ] TLS grade A confirmed (SSL Labs)
- [ ] All 3 uptime-kuma monitors added and showing green
- [ ] Backup cron installed: `cat /etc/cron.d/ancu365-backup`
- [ ] Manual backup ran successfully: `./scripts/backup.sh`
- [ ] Restore drill completed (see §12)
- [ ] Flutter app built with staging URL and tested on device

### During 48h window
- [ ] **Hour 0-2:** API + tile latency baseline — `make loadtest` passes p95 < 2s
- [ ] **Night 1 (3 AM):** Backup cron ran — check `/var/log/ancu365-backup.log`
- [ ] **Night 1 (2 AM):** ETL cron ran — `SELECT * FROM planning.etl_runs ORDER BY started_at DESC LIMIT 3;`
- [ ] **Night 2 (3 AM):** Backup cron ran again — 2 backups visible in B2
- [ ] **Night 2 (2 AM):** ETL cron ran second time — status = 'success'
- [ ] **Zero unscheduled restarts** in uptime-kuma (check incident log)
- [ ] **Disk usage:** `df -h` — stays below 70% at all times
- [ ] **Memory:** `free -h` — no OOM events in `dmesg | grep oom`

### Pass criteria (all must be true)
- [ ] 0 downtime incidents in uptime-kuma over 48h
- [ ] ETL ran 2 consecutive nights with `status = 'success'`
- [ ] Backup appeared in B2 both nights
- [ ] Restore drill succeeded (< 30 min total)
- [ ] Load test: 50 VUs × 5 min → p95 < 2s, 0 HTTP 5xx

---

## 11. Cutover Procedure

### 24h before cutover
1. Lower DNS TTL to 60s (so rollback is fast if needed)
2. Verify B2 backup from that day exists
3. Notify any beta users

### Cutover day
```bash
# 1. Take final backup before cutover
ssh ancu365@<staging-vps>
cd /opt/ancu365/ancu365-backend
./scripts/backup.sh
# Verify appears in B2

# 2. Deploy to prod VPS (same steps as §4, or use same VPS if staging == prod)
# If using separate prod VPS:
ssh ancu365@<prod-vps>
cd /opt/ancu365/ancu365-backend
git pull --ff-only
make prod-up

# 3. Apply migrations on prod
docker exec ancu365-backend alembic upgrade head

# 4. Seed data (if prod DB is fresh)
make seed

# 5. Verify health
curl -I https://ancu365.vn/api/health   # expect 200

# 6. Switch DNS A record to prod VPS IP
# (In your domain registrar — change ancu365.vn A record to prod IP)

# 7. Verify DNS switched
watch -n 10 "dig ancu365.vn +short"

# 8. Verify HTTPS on prod domain
curl -I https://ancu365.vn/api/health
```

### Post-cutover 24h monitoring
- Watch uptime-kuma every 2-4 hours
- Check `/var/log/ancu365-backup.log` next morning
- Keep staging VPS running (cold standby) for 48h post-cutover

---

## 12. Disaster Recovery

**RTO target: ≤ 30 minutes** (download + restore + verify)

### Restore from B2 to existing VPS

```bash
ssh ancu365@<vps-ip>
cd /opt/ancu365/ancu365-backend

# Interactive restore (lists available backups, prompts for confirmation)
./scripts/restore.sh

# Or specify backup directly:
./scripts/restore.sh ancu365-20260101_030000.sql.gz
```

### Full restore to new VPS (RTO ≤ 1h)

1. Provision new VPS (§2) — ~15 min
2. Set DNS A record to new VPS IP — propagation 5 min (with 60s TTL)
3. Clone repo + configure `.env` — ~5 min
4. Boot stack: `make prod-up` — ~2 min (Nominatim needs 40 min first-time import)
   > For RTO < 1h: skip Nominatim on initial restore, re-enable after data is up
5. Run restore: `./scripts/restore.sh <backup-name>` — ~5-10 min (depends on DB size)
6. Run migrations: `docker exec ancu365-backend alembic upgrade head`
7. Verify: `curl -I https://ancu365.vn/api/health`

Total (excluding Nominatim): ~30 min.  
With Nominatim: ~70-80 min (boot Nominatim in background after data is served).

### Backup file location

B2 bucket: `ancu365-backups`  
File pattern: `ancu365-YYYYMMDD_HHmmss.sql.gz`  
Retention: 30 days

List backups:
```bash
b2 authorize-account $B2_KEY_ID $B2_APPLICATION_KEY
b2 ls --long ancu365-backups
```

---

## 13. Cert Renewal

Caddy auto-renews Let's Encrypt certificates before expiry (typically 30 days before 90-day cert expires). No manual action normally needed.

### Force reload Caddy config

```bash
docker exec ancu365-caddy caddy reload --config /etc/caddy/Caddyfile
```

### Force cert renewal (if Caddy missed it)

```bash
docker exec ancu365-caddy caddy renew
```

### Check cert expiry

```bash
echo | openssl s_client -connect ancu365.vn:443 2>/dev/null \
    | openssl x509 -noout -dates
```

### If Caddy can't renew (port 80 blocked)

- Check UFW: `ufw status` → 80/tcp must be open
- Check no other process on port 80: `ss -tlnp | grep :80`
- Check Caddy logs: `docker compose logs caddy | grep -i "acme\|cert\|renew"`

---

## 14. Rollback

### Roll back backend to previous git tag

```bash
ssh ancu365@<vps-ip>
cd /opt/ancu365/ancu365-backend

# List available tags
git tag --sort=-creatordate | head -10

# Roll back (replace <prev-tag> with actual tag)
git checkout <prev-tag>

# Force recreate only backend (postgis/martin/caddy untouched)
docker compose -f docker-compose.yml -f docker-compose.prod.yml \
    up -d --force-recreate backend

# Verify
curl -I https://ancu365.vn/api/health
docker exec ancu365-backend python -c "from app import __version__; print(__version__)"
```

### Roll back database schema (alembic downgrade)

```bash
# View current head
docker exec ancu365-backend alembic current

# Downgrade one step
docker exec ancu365-backend alembic downgrade -1

# Downgrade to specific revision
docker exec ancu365-backend alembic downgrade <revision-id>
```

> Warning: downgrade may lose data if migration added columns/tables. Take backup first.

---

## 15. Troubleshooting Matrix

| Symptom | First check | Grep command | Fix |
|---------|-------------|--------------|-----|
| `502 Bad Gateway` from Caddy | Backend container health | `docker compose logs backend \| tail -50` | `docker compose restart backend` |
| Caddy won't start | Port 80/443 conflict | `ss -tlnp \| grep ':80\|:443'` | Stop conflicting service; check UFW |
| TLS cert not issuing | DNS not pointing to VPS | `dig ancu365.vn +short` | Fix A record; wait propagation |
| TLS cert not issuing | Port 80 blocked | `ufw status` | `ufw allow 80/tcp` |
| Nominatim health check failing | Import still running | `docker compose logs nominatim \| tail -20` | Wait; import takes 40-60 min first time |
| `500 Internal Server Error` on `/api/planning/*` | DB connection | `docker compose logs backend \| grep -i error` | Check `DATABASE_URL` in `.env`; `docker compose restart postgis` |
| Backup script fails | B2 keys invalid | `b2 authorize-account $B2_KEY_ID $B2_APPLICATION_KEY` | Regenerate B2 key |
| Backup script fails | Docker not running | `docker ps` | `systemctl start docker` |
| ETL cron not running | `CRON_ENABLED` not set | `docker exec ancu365-backend env \| grep CRON` | Set `CRON_ENABLED=1` in `.env`, `make prod-up` |
| ETL cron fails | WFS endpoint down | `curl -s "https://geodata-stnmt.tphcm.gov.vn/geoserver/ows?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetCapabilities" \| head -20` | Retry next day; seed from cache if available |
| High memory (OOM) | Nominatim using RAM | `docker stats` | Reduce Nominatim `shm_size` to `1g`; restart |
| Disk full | Postgis data growth | `df -h && docker system df` | `docker system prune -f` (safe, removes unused layers); check `nominatim-data` volume |
| High response latency | Missing DB indexes | `docker exec ancu365-postgis psql -U ancu365 -d ancu365 -c "EXPLAIN ANALYZE SELECT ..."` | Run `VACUUM ANALYZE planning.parcels;` |
| Uptime-kuma not accessible | SSH tunnel not open | `ssh -L 3010:127.0.0.1:3010 ancu365@<vps> -N` on local | Re-open SSH tunnel |
| Container keeps restarting | Check exit code | `docker inspect ancu365-backend --format='{{.State.ExitCode}}'` | `docker compose logs backend --tail=100` |
| `upstream connect error` on tiles | Martin not healthy | `docker compose logs martin \| tail -30` | Check `DATABASE_URL`; `docker compose restart martin` |

### Useful one-liners

```bash
# All container status + health
docker compose ps

# Live resource usage
docker stats

# Backend logs (last 100 lines)
docker compose logs backend --tail=100 -f

# Database connections count
docker exec ancu365-postgis psql -U ancu365 -d ancu365 \
    -c "SELECT count(*), state FROM pg_stat_activity GROUP BY state;"

# Disk usage by volume
docker system df -v | grep ancu365

# Check last ETL run
docker exec ancu365-postgis psql -U ancu365 -d ancu365 \
    -c "SELECT started_at, status, districts_processed, error_message FROM planning.etl_runs ORDER BY started_at DESC LIMIT 5;"

# Caddy access log (last errors)
docker exec ancu365-caddy tail -100 /var/log/caddy/access.log \
    | python3 -c "import sys,json; [print(json.dumps(json.loads(l), indent=2)) for l in sys.stdin if '\"status\":5' in l]"

# UFW log (blocked connections)
grep UFW /var/log/syslog | tail -20
```
