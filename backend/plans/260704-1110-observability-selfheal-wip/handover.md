# Observability + Self-Heal Pipeline — WIP Handover

**Date:** 2026-07-04
**Author:** Claude (session on VPS via SSH)
**Status:** Feature code COMPLETE + DEPLOYED to prod container, **but never git-committed** until now.
**Scope:** Both `ancu365-backend` and `ancu365-app` repos.

---

## TL;DR — Where we are

- Structured JSON logging with PII redaction (backend) — DONE
- Request-context middleware (request-id, user-hash, latency) — DONE
- Error fingerprint + `/api/client-logs` endpoint for Flutter crashes — DONE
- Self-heal orchestration scripts (`collect_errors -> guardrail -> verify -> deploy -> rollback`) — DONE
- Backend container `ancu365-backend` is ALREADY RUNNING this code (rebuilt Jul 4 ~07:10 UTC) — DONE
- Web container `ancu365-web` bundle contains reference to `/api/client-logs` (built with error_reporter) — LIKELY DONE, verify locally
- Cron for self-heal — NOT installed (pipeline dormant, no periodic sweep)
- Autofix / autodeploy flags — NOT enabled (intentional — safe-by-default)
- CI / pytest coverage for new observability code — NOT written yet

---

## Architecture on VPS (as observed 2026-07-04)

```
  Internet
     |
     v
  Nginx Proxy Manager (proxy-proxymanager-1, :80/:443)
     |  server_name digilab.ddns.net + 192.168.112.101
     |  Config: /home/sysadmin/deploy/ancu365/npm-digilab.conf
     |
     +---> /            -> ancu365-web:80        (Flutter web SPA)
     +---> /api/*       -> ancu365-backend:3000  (FastAPI)
     +---> /martin/*    -> ancu365-martin:3000   (MVT tiles)
     +---> /docs, /health, /uploads/, /planning-tiles/  -> ancu365-backend
```

**Note:** Repo's `docker-compose.prod.yml` + `infra/Caddyfile` reference **Caddy** — but prod actually uses **NPM**. The Caddyfile is NOT used. Do not "fix" NPM config to match Caddyfile.

---

## What was committed just now

### Backend (`ancu365-backend`)

Modified:
- `main.py` — call `setup_logging()` before other imports; add `RequestContextMiddleware` after CORS; include `client_logs` router.
- `app/config.py` — add `log_dir`, `log_level`, `log_hash_salt`, `client_logs_enabled` settings.
- `app/middleware/error_handler.py` — emit structured `unhandled_exception` log with redacted traceback + fingerprint.
- `.env.example` — document new LOG_* + CLIENT_LOGS_ENABLED vars.
- `.gitignore` — exclude `storage/logs/`, `ENABLE_AUTOFIX`, `ENABLE_AUTODEPLOY`, `KILLSWITCH` flag files.

New:
- `app/observability/{__init__,context,redaction,fingerprint,logging_config,middleware}.py`
- `app/routers/client_logs.py`
- `scripts/observability/{collect_errors.py, guardrail_check.py, selfheal.sh, selfheal.config.sh, deploy_backend.sh, install_cron.sh, AUTOFIX_POLICY.md, README.md}`

### Frontend (`ancu365-app`)

Modified:
- `lib/main.dart` — wire `ErrorReporter.report(...)` into `FlutterError.onError` + `PlatformDispatcher.onError`.

New:
- `lib/core/telemetry/error_reporter.dart` — POST crash to `/api/client-logs`, throttle 50/session, dedupe by signature, stack <=6KB.

---

## What still needs to be done (in priority order)

### 1. Prod `.env` — add observability vars
Currently prod `.env` on VPS (`/home/sysadmin/deploy/ancu365/ancu365-backend/.env`) has NO `LOG_HASH_SALT` set. Backend falls back to default `"ancu365-log-salt"` from `config.py`. Not a security hole (salt only affects user-correlation across log entries), but should be rotated per environment.

```bash
# On VPS
cd ~/deploy/ancu365/ancu365-backend
cat >> .env <<EOF

# Observability
LOG_DIR=/app/storage/logs
LOG_LEVEL=INFO
LOG_HASH_SALT=$(openssl rand -hex 32)
CLIENT_LOGS_ENABLED=true
EOF
docker restart ancu365-backend
```

### 2. Verify JSON log actually flows
Container has `storage/logs/app.jsonl` if `deploy_backend.sh` was used. Verify:
```bash
docker exec ancu365-backend ls -la /app/storage/logs/
docker exec ancu365-backend tail -5 /app/storage/logs/app.jsonl
```
If missing -> run `bash scripts/observability/deploy_backend.sh` to re-deploy with log volume mount.

### 3. Smoke-test `/api/client-logs`
```bash
curl -X POST https://digilab.ddns.net/api/client-logs \
  -H "Content-Type: application/json" \
  -d '{"level":"error","message":"WIP smoke test","error_type":"TestError","stack":"at foo()","route":"/test","platform":"web"}' -k
# Expect: 204 No Content
# Verify: log line appears in app.jsonl with event=client_error
```

### 4. Install cron (safe — report-only until flags flipped)
```bash
bash scripts/observability/install_cron.sh
# Verify: crontab -l | grep ancu365-selfheal
# Log will accumulate at storage/logs/selfheal_cron.log every 15min.
```

### 5. Write tests for observability code
No pytest coverage yet for:
- `redaction.redact_text/redact_obj` (patterns: email/JWT/bearer/phone/longnum + sensitive keys)
- `fingerprint.compute_fingerprint` (stable across UUIDs/numbers)
- `RequestContextMiddleware` (X-Request-ID passthrough, user_hash derivation)
- `client_logs` endpoint (204, rate limit, disabled flag)

Suggested files: `tests/observability/test_redaction.py`, `test_fingerprint.py`, `test_client_logs.py`.

### 6. Rebuild `ancu365-web` when Flutter app changes are pulled locally
Web container was built Jul 2 — before `error_reporter.dart` existed. Yet grep on `main.dart.js` finds `client-logs` string — meaning either (a) some other web build happened after, or (b) coincidence in Flutter tree-shaking. Verify locally:
```bash
cd ancu365-app
flutter build web --release \
  --dart-define=API_BASE_URL=https://digilab.ddns.net
# Copy build/web/ into whatever mechanism produces the ancu365-web docker image
# (look for a Dockerfile or scripts/build_web.sh in the repo — did not find on VPS).
```

### 7. Custom domain `ancu365.digi-lab.vn` (original task)
DNS already trỏ vào VPS (per user confirmation). Steps:
1. Log into Nginx Proxy Manager UI (find internal admin port — check `docker port proxy-proxymanager-1`).
2. Add a new proxy host for `ancu365.digi-lab.vn` mirroring `npm-digilab.conf` routes.
3. Request Let's Encrypt SSL through NPM UI (needs port 80 reachable from Internet + DNS propagated).
4. Update backend `.env` on VPS: `BACKEND_CORS_ORIGINS=["https://ancu365.digi-lab.vn","https://digilab.ddns.net"]`.
5. `docker restart ancu365-backend`.
6. Rebuild web with `--dart-define=API_BASE_URL=https://ancu365.digi-lab.vn`.

**Local repo already prepped:** `ancu365-backend/.env.example` on Mac already updated with `ANCU_DOMAIN=ancu365.digi-lab.vn` (uncommitted on Mac).

---

## Container inventory (2026-07-04 ~09:20 UTC)

| Container | Image | Ports | Uptime | Notes |
|-----------|-------|-------|--------|-------|
| ancu365-backend | (built locally) | 127.0.0.1:3010->3000 | 2h (healthy) | Has observability code |
| ancu365-web | nginx:alpine | 127.0.0.1:3030->80 | 36h | Static Flutter build |
| ancu365-martin | martin | 127.0.0.1:3021->3000 | 37h | MVT tiles |
| ancu365-8443 | ? | 0.0.0.0:8443->8443 | 36h | Stream proxy — purpose unclear |
| proxy-proxymanager-1 | NPM | 80/81/443 | 42h | Public entrypoint |

Other containers on VPS (faceconst-*, moneyprinter-*, n8n, hbbs/hbbr) are unrelated projects sharing the box.

---

## Files to be aware of when working locally

- Backend prod compose: `docker-compose.yml` + `docker-compose.override.yml` (VPS uses these, NOT `docker-compose.prod.yml`).
- NPM config (deployed manually): `/home/sysadmin/deploy/ancu365/npm-digilab.conf` — copy to `<NPM data volume>/nginx/proxy_host/N.conf` on VPS if regenerating.
- Prod `.env` — **NEVER commit** — lives only at `/home/sysadmin/deploy/ancu365/ancu365-backend/.env` on VPS.
- Repo `infra/Caddyfile` + `infra/nginx/*.conf` are DEAD CODE for now (NPM handles proxy). Consider removing or explicitly marking deprecated.

---

## Open questions

1. Where is `ancu365-web` docker image built from? No Dockerfile found in `ancu365-app/` — likely built ad-hoc with `nginx:alpine` + copied `build/web/`. Needs a proper Dockerfile committed.
2. Is `ancu365-8443` still needed? It just streams 8443 -> NPM 443 (see `stream-8443.conf`). Maybe leftover from a router NAT setup.
3. Should the repo's `infra/Caddyfile` be removed given prod uses NPM?
4. What's the plan for backup/rotation of `storage/logs/app.jsonl`? Rotate handler set to 25MB x 10 = 250MB max, but no offsite backup wired.

---

## COMPLETION 2026-07-11 (session hoàn thiện A+C+P3)

**Observability (mục "còn phải làm"):**
1. ✅ Prod `.env`: thêm `LOG_HASH_SALT` (64 hex ngẫu nhiên) + `LOG_DIR/LOG_LEVEL/CLIENT_LOGS_ENABLED`. Backup `.env.bak-*` giữ tại VPS.
2. ✅ JSON log verified đang chảy (`app.jsonl`), cron self-heal đã cài (crontab */15).
3. ✅ Smoke-test `/api/client-logs` → 204, log có fingerprint.
4. ✅ Siết CORS `["*"]` → `["https://digilab.ddns.net","https://ancu365.digi-lab.vn"]` (origin lạ bị chặn; web same-origin không ảnh hưởng). `allow_credentials=False`.
5. ✅ Pytest observability: 37 test (redaction/fingerprint/middleware/client-logs) pass. Fix bug key `set-cookie`→`set_cookie` (lookup chuẩn hoá dash→_). Commit `27b1a37`.
7. ⏸️ Domain `ancu365.digi-lab.vn`: DNS đã trỏ đúng IP; **hoãn theo quyết định user** (cần đăng nhập NPM UI cổng 81 cấp SSL). CORS đã sẵn origin cho domain.

**Marketplace P3 (mới, ngoài handover này):**
- migration 0046 (houses.industrial_attrs JSON + index) ĐÃ APPLY lên DB prod (backup `backups/ancu365-preP3-*.sql`). alembic head=0046.
- Backend: tin `product_type=industrial` + thuộc tính KCN (gated `INDUSTRIAL_RE_ENABLED=true`); xếp hạng directory promote→pro→verified→rating. Commit backend `af30ade`.
- FE: badge Nổi bật/Pro + thẻ thông số CN. Commit app `2e807fe`.
- Verified end-to-end trên prod (tạo/list tin CN rồi xoá sạch).

**LƯU Ý QUAN TRỌNG:** code mới đã `docker cp` vào container đang chạy (writable layer) + commit git, container healthy. Để BỀN VỮNG nên **rebuild image backend từ git** (nếu recreate container mà chưa rebuild sẽ revert về image cũ). Chưa push git remote.
