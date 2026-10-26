#!/usr/bin/env bash
# deploy_backend.sh — build + recreate backend container với AUTO-ROLLBACK.
#
# Chiến lược blue/green-lite:
#   1. Trích cấu hình runtime (ports/networks/binds/restart) từ container đang chạy.
#   2. Build image mới từ code đã vá.
#   3. Đổi tên container cũ → *_old (giữ để rollback), tạo container mới cùng cấu hình.
#   4. Health-check. PASS → xoá *_old. FAIL → xoá container mới, phục hồi *_old.
#
# KHÔNG đụng DB (deploy chỉ swap process; /health là liveness thuần).
# Exit: 0 = deployed OK | 1 = rolled back | 2 = lỗi tiền đề.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/selfheal.config.sh"

log(){ echo "[deploy $(date -u +%H:%M:%S)] $*"; }

C="$BACKEND_CONTAINER"
OLD="${C}_old"

if ! docker inspect "$C" >/dev/null 2>&1; then
  log "Container $C không tồn tại — abort (deploy tự động chỉ dành cho container đang chạy)."
  exit 2
fi

# ── 1. Trích cấu hình runtime hiện tại ───────────────────────────────────────
PORTS="$(docker inspect "$C" --format '{{range $p, $conf := .HostConfig.PortBindings}}{{range $conf}}-p {{if .HostIp}}{{.HostIp}}:{{end}}{{.HostPort}}:{{$p}} {{end}}{{end}}' | sed 's#/tcp##g')"
BINDS="$(docker inspect "$C" --format '{{range .HostConfig.Binds}}-v {{.}} {{end}}')"
RESTART="$(docker inspect "$C" --format '{{.HostConfig.RestartPolicy.Name}}')"
NETWORKS="$(docker inspect "$C" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}')"
PRIMARY_NET="$(echo "$NETWORKS" | awk '{print $1}')"
RESTART_ARG=""; [ -n "$RESTART" ] && [ "$RESTART" != "no" ] && RESTART_ARG="--restart $RESTART"

ENV_SNAPSHOT="$(mktemp)"
docker inspect "$C" --format '{{range .Config.Env}}{{println .}}{{end}}' > "$ENV_SNAPSHOT"
ENV_ARGS="--env-file $ENV_SNAPSHOT"
if [ -f "$REPO_ROOT/.env" ]; then
  ENV_ARGS="$ENV_ARGS --env-file $REPO_ROOT/.env"
fi

# Bảo đảm log của container chảy ra host để pipeline (chạy trên host) đọc được.
# Bind $REPO_ROOT/storage/logs → /app/storage/logs + set LOG_DIR trong container.
mkdir -p "$REPO_ROOT/storage/logs"
LOG_MOUNT="-v $REPO_ROOT/storage/logs:/app/storage/logs -e LOG_DIR=/app/storage/logs"
# Tránh mount trùng nếu BINDS đã có (idempotent qua các lần deploy).
if echo "$BINDS" | grep -q "/app/storage/logs"; then LOG_MOUNT="-e LOG_DIR=/app/storage/logs"; fi

SECRET_MOUNT=""
if [ -d "$REPO_ROOT/../secrets" ] && ! echo "$BINDS" | grep -q "/run/secrets"; then
  SECRET_MOUNT="-v $REPO_ROOT/../secrets:/run/secrets:ro"
fi

cleanup(){ rm -f "$ENV_SNAPSHOT"; }
trap cleanup EXIT

log "ports=$PORTS | net=$NETWORKS | restart=$RESTART | env=preserve+.env | logmount=on | secrets=$([ -n "$SECRET_MOUNT" ] && echo on || echo off)"

# ── 2. Build image mới (giữ image cũ làm rollback) ───────────────────────────
log "Tag rollback image ← image hiện tại"
docker tag "$BACKEND_IMAGE" "$ROLLBACK_IMAGE"
log "Building $BACKEND_IMAGE từ $REPO_ROOT …"
docker build -t "$BACKEND_IMAGE" "$REPO_ROOT" >/dev/null

# ── 3. Swap: đổi tên cũ, tạo mới ─────────────────────────────────────────────
docker rm -f "$OLD" >/dev/null 2>&1 || true
log "Rename $C → $OLD (stop)"
docker stop "$C" >/dev/null
docker rename "$C" "$OLD"

log "Tạo container mới $C"
# shellcheck disable=SC2086
docker run -d --name "$C" $RESTART_ARG $PORTS $BINDS $LOG_MOUNT $SECRET_MOUNT $ENV_ARGS --network "$PRIMARY_NET" "$BACKEND_IMAGE" >/dev/null
# Kết nối các network còn lại (nếu >1)
for net in $NETWORKS; do
  [ "$net" = "$PRIMARY_NET" ] && continue
  docker network connect "$net" "$C" >/dev/null 2>&1 || true
done

# ── 4. Health-check + rollback ───────────────────────────────────────────────
ok=0
for i in $(seq 1 "$HEALTH_RETRIES"); do
  sleep "$HEALTH_INTERVAL_S"
  if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then ok=1; log "health OK (thử $i)"; break; fi
  log "health chưa sẵn sàng (thử $i/$HEALTH_RETRIES)"
done

if [ "$ok" = "1" ]; then
  log "DEPLOY OK — xoá container cũ."
  docker rm -f "$OLD" >/dev/null 2>&1 || true
  exit 0
fi

# ROLLBACK
log "HEALTH FAIL — ROLLBACK về container cũ."
docker rm -f "$C" >/dev/null 2>&1 || true
docker tag "$ROLLBACK_IMAGE" "$BACKEND_IMAGE" || true
docker rename "$OLD" "$C" >/dev/null
docker start "$C" >/dev/null
log "Đã phục hồi $C từ rollback."
exit 1
