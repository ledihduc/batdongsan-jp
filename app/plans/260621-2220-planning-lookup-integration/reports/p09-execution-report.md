# P09 Execution Report — VPS Deploy Artifacts

**Date:** 2026-06-21  
**Phase:** phase-09-vps-deploy  
**Work context:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/`  
**Status:** DONE_WITH_CONCERNS (see Concerns section)

---

## Artifacts Delivered

| File | Lines | Status | Notes |
|------|-------|--------|-------|
| `infra/Caddyfile` | 107 | Created | Domain via `{$ANCU_DOMAIN}` env var |
| `docker-compose.prod.yml` | 113 | Created | Caddy + uptime-kuma; nginx disabled |
| `.env.example` | 65 | Updated | Added `# ============ Production ============` section |
| `scripts/backup.sh` | 127 | Created | Executable; B2 upload + 30-day rotation + ntfy alert |
| `scripts/restore.sh` | 140 | Created | Executable; interactive; `yes` confirmation guard |
| `scripts/cron-backup` | 28 | Created | `/etc/cron.d` drop-in; 03:00 daily |
| `scripts/firstboot.sh` | 233 | Created | Executable; idempotent 8-step VPS setup |
| `docs/deploy-runbook.md` | 562 | Created | 15 sections (prerequisites → troubleshooting) |
| `docs/loadtest/loadtest.js` | 208 | Created | k6; 50 VUs 5 min; 70/20/10 mix; p95<2s |
| `Makefile` | 87 | Updated | Added `prod-up`, `prod-logs`, `backup`, `loadtest` |

---

## Validation Results

### Shell script syntax (`bash -n`)

```
backup.sh:    OK
restore.sh:   OK
firstboot.sh: OK
```

### YAML validity (`python3 yaml.safe_load`)

```
docker-compose.prod.yml: VALID
```

### Service cross-check (base vs prod)

| Layer | Services |
|-------|---------|
| Base `docker-compose.yml` | postgis, martin, backend, nominatim, nginx |
| Prod override adds | caddy, uptime-kuma |
| Prod override disables | nginx (ports: []) |
| All internal ports | 127.0.0.1 bound |

### Caddyfile syntax

- Docker daemon is DOWN locally — live `caddy validate` skipped.
- Static review: syntax conforms to Caddy 2 Caddyfile spec (site address block, matchers, handle, reverse_proxy, log, header, encode directives).
- Port corrected: backend → `backend:3000` (container port per Dockerfile EXPOSE 3000).

### Security checks

- [x] Nominatim: Caddyfile explicitly returns 404 on `/nominatim/*` (line 98-100)
- [x] All internal services bind `127.0.0.1` in `docker-compose.prod.yml`
- [x] Caddy only publishes `:80` and `:443` to all interfaces
- [x] `backup.sh` validates `B2_KEY_ID`, `B2_APPLICATION_KEY`, `POSTGRES_USER`, `POSTGRES_DB` before running; fails fast
- [x] `restore.sh` requires explicit `yes` typed confirmation
- [x] `firstboot.sh`: `PasswordAuthentication no` + `PermitRootLogin prohibit-password` set
- [x] `firstboot.sh`: UFW allows only 22, 80, 443
- [x] `.env.example` contains only placeholders — no real secrets

---

## What You Must Do Next (User Checklist)

### Phase A: Provision VPS (~1h)

```bash
# 1. Order VPS — Ubuntu 22.04 LTS, 16 GB RAM, 320 GB SSD
#    VPSServer Vietnam: https://vpsserver.com
#    OR Hetzner Singapore: https://hetzner.com/cloud

# 2. SSH in as root and run firstboot.sh
#    (edit REPO_URL= inside firstboot.sh first, or set as env var)
export REPO_URL=https://github.com/YOUR_ORG/ancu365-backend.git
curl -fsSL https://raw.githubusercontent.com/YOUR_ORG/ancu365-backend/main/scripts/firstboot.sh | bash
```

### Phase B: DNS (~5 min setup, up to 24h propagation)

```bash
# Add A record in your domain registrar:
# ancu365.vn → <vps-ip>
# www.ancu365.vn → <vps-ip>
# TTL: 300 (lower to 60 before cutover)

# Verify:
dig ancu365.vn +short  # must return VPS IP before proceeding
```

### Phase C: Configure .env and boot stack (~30 min + 40 min Nominatim import)

```bash
ssh ancu365@<vps-ip>
cd /opt/ancu365/ancu365-backend
cp .env.example .env

# Generate strong secrets:
openssl rand -hex 32   # use for POSTGRES_PASSWORD
openssl rand -hex 32   # use for JWT_SECRET
openssl rand -hex 32   # use for NOMINATIM_PASSWORD

nano .env              # Fill: ANCU_DOMAIN, all passwords, B2_KEY_ID, B2_APPLICATION_KEY
chmod 600 .env

# Boot (Nominatim first-time import ~40-60 min):
make prod-up
docker compose logs -f nominatim  # wait for "ready to accept connections"
```

### Phase D: Migrations + seed (~5-60 min)

```bash
docker exec ancu365-backend alembic upgrade head

# Smoke test (3 quận, ~5 min):
make seed-test

# Full seed (24 quận, ~60 min — run in screen/tmux):
screen -S seed
make seed
# Ctrl-A D to detach; screen -r seed to reattach
```

### Phase E: Verify TLS + endpoints

```bash
curl -I https://ancu365.vn/api/health           # expect HTTP/2 200
curl -s https://ancu365.vn/tiles/catalog | head  # expect JSON
# SSL Labs (wait ~90s for results):
curl -s "https://api.ssllabs.com/api/v3/analyze?host=ancu365.vn&startNew=on"
# Then poll: curl -s "https://api.ssllabs.com/api/v3/analyze?host=ancu365.vn" | python3 -m json.tool | grep grade
```

### Phase F: Monitoring + backup cron

```bash
# Install backup cron
sudo cp scripts/cron-backup /etc/cron.d/ancu365-backup
sudo chmod 644 /etc/cron.d/ancu365-backup

# Manual backup test
./scripts/backup.sh

# Uptime-Kuma (SSH tunnel from local machine):
ssh -L 3010:127.0.0.1:3010 ancu365@<vps-ip> -N &
# Open http://localhost:3010 → create admin → add 3 monitors (see runbook §7)
```

### Phase G: 48h staging soak

Follow checklist in `docs/deploy-runbook.md` §10.

### Phase H: Flutter prod build

```bash
flutter build apk --release \
    --dart-define=API_BASE_URL=https://ancu365.vn \
    --dart-define=MARTIN_TILE_URL=https://ancu365.vn/tiles/planning.parcels/{z}/{x}/{y}.pbf
```

### Phase I: Load test

```bash
export ANCU_DOMAIN=ancu365.vn
make loadtest
# Thresholds: p95 < 2000ms, error rate < 1%
```

### Phase J: Cutover (after 48h soak passes all checks)

Follow `docs/deploy-runbook.md` §11.

---

## Concerns

1. **Rate limiting not active** — Caddy 2 standard Alpine image does not include `caddy-rate-limit` plugin. The Caddyfile has detailed TODO comments explaining how to build Caddy with the plugin (`xcaddy`). For MVP: rely on UFW conntrack + optional Cloudflare free proxy. MEDIUM risk.

2. **Caddyfile syntax not live-validated** — Docker daemon was DOWN during execution. Syntax validated by static review only. Must run `docker exec ancu365-caddy caddy validate --config /etc/caddy/Caddyfile` after first boot.

3. **`firstboot.sh` REPO_URL placeholder** — Script contains `YOUR_ORG` placeholder. User must either set `REPO_URL` env var or edit the script before running. Logged as a clear warning in the script.

4. **`docker-compose.prod.yml` network declaration** — The override file redeclares `ancu-net` network. With `docker compose -f base -f override`, Compose merges network declarations correctly. If the override is used standalone (without base), it will attempt to create the network fresh — this is the intended fallback. The comment in the file explains this.

5. **`make loadtest` reads `ANCU_DOMAIN` from shell env**, not `.env` (Make doesn't auto-source `.env`). User must `export ANCU_DOMAIN=ancu365.vn` or run `set -a && source .env && set +a && make loadtest`.

6. **B2 rotation logic** — The `b2 ls --long` format differs between b2 CLI v2 and v3. Script uses `awk '{print $NF}'` to get filename which is safe across both. But `b2 delete-file-version` in v3 requires both fileId and fileName. For v3, consider `b2 delete-file-version <bucket> <fileName>` or use `b2 rm`. The script uses the v3-compatible form. If b2 CLI version is v2, replace with `b2 delete-file-version <fileId> <fileName>`.

---

**Status:** DONE_WITH_CONCERNS  
**Summary:** All 10 artifact files created/updated. Bash syntax clean. YAML valid. Security checks pass. Caddy syntax not live-validated (Docker down). Rate limiting requires plugin build (documented in Caddyfile). No live VPS ops performed — all deferred to user per task spec.  
**Concerns:** Rate limit plugin, Caddyfile live validation skipped, REPO_URL placeholder, b2 CLI version sensitivity.
