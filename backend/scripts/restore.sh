#!/usr/bin/env bash
# restore.sh — Restore PostgreSQL database from Backblaze B2 backup
#
# Usage:   ./scripts/restore.sh [backup-filename]
#   e.g.:  ./scripts/restore.sh ancu365-20260101_030000.sql.gz
#   (If no argument given, the script lists available backups and prompts)
#
# WARNING: This DROPS and RECREATES the target database. Data loss is permanent.
#
# Required env vars (set in .env or exported):
#   POSTGRES_USER, POSTGRES_DB, B2_KEY_ID, B2_APPLICATION_KEY, B2_BUCKET
#
# Dependencies: docker, b2 CLI, gunzip

set -euo pipefail

# ── Load .env ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ -f "${REPO_ROOT}/.env" ]]; then
    # shellcheck disable=SC1091
    set -a
    source "${REPO_ROOT}/.env"
    set +a
fi

# ── Validate required env vars ────────────────────────────────────────────────
_require_env() {
    local var="$1"
    if [[ -z "${!var:-}" ]]; then
        echo "[restore] FATAL: Required env var '$var' is not set. Aborting." >&2
        exit 1
    fi
}

_require_env POSTGRES_USER
_require_env POSTGRES_DB
_require_env B2_KEY_ID
_require_env B2_APPLICATION_KEY
_require_env B2_BUCKET

# ── Authorize B2 ──────────────────────────────────────────────────────────────
echo "[restore] Authorizing B2..."
b2 authorize-account "${B2_KEY_ID}" "${B2_APPLICATION_KEY}" > /dev/null

# ── Determine backup file ─────────────────────────────────────────────────────
BACKUP_NAME="${1:-}"

if [[ -z "$BACKUP_NAME" ]]; then
    echo ""
    echo "[restore] Available backups in B2 bucket '${B2_BUCKET}':"
    echo "────────────────────────────────────────────────────────"
    b2 ls "${B2_BUCKET}" | grep -E '\.sql\.gz$' | sort -r | head -20
    echo "────────────────────────────────────────────────────────"
    echo ""
    read -rp "Enter backup filename to restore (or Ctrl-C to abort): " BACKUP_NAME
fi

if [[ -z "$BACKUP_NAME" ]]; then
    echo "[restore] No backup selected. Aborting." >&2
    exit 1
fi

# ── Big confirmation prompt ───────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    !! DESTRUCTIVE OPERATION !!               ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  This will DROP and RECREATE the PostgreSQL database:        ║"
echo "║                                                              ║"
echo "║  Database : ${POSTGRES_DB}"
echo "║  User     : ${POSTGRES_USER}"
echo "║  Backup   : ${BACKUP_NAME}"
echo "║                                                              ║"
echo "║  ALL EXISTING DATA WILL BE PERMANENTLY DELETED.             ║"
echo "║  Ensure you have a current backup before proceeding.         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
read -rp "Type 'yes' to confirm restore (anything else aborts): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "[restore] Aborted by user."
    exit 0
fi

# ── Download from B2 ──────────────────────────────────────────────────────────
DOWNLOAD_PATH="/tmp/${BACKUP_NAME}"
echo ""
echo "[restore] Downloading ${BACKUP_NAME} from B2..."
b2 download-file-by-name "${B2_BUCKET}" "${BACKUP_NAME}" "${DOWNLOAD_PATH}"
echo "[restore] Download complete. Size: $(du -sh "${DOWNLOAD_PATH}" | cut -f1)"

# ── Drop and recreate target database ────────────────────────────────────────
echo "[restore] Dropping database '${POSTGRES_DB}' (terminating connections)..."
docker exec ancu365-postgis psql \
    -U "${POSTGRES_USER}" \
    -d postgres \
    -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${POSTGRES_DB}';" \
    > /dev/null

docker exec ancu365-postgis psql \
    -U "${POSTGRES_USER}" \
    -d postgres \
    -c "DROP DATABASE IF EXISTS ${POSTGRES_DB};" \
    > /dev/null

docker exec ancu365-postgis psql \
    -U "${POSTGRES_USER}" \
    -d postgres \
    -c "CREATE DATABASE ${POSTGRES_DB} OWNER ${POSTGRES_USER};" \
    > /dev/null

echo "[restore] Database recreated."

# ── Restore ───────────────────────────────────────────────────────────────────
echo "[restore] Restoring from ${DOWNLOAD_PATH}..."
gunzip -c "${DOWNLOAD_PATH}" \
    | docker exec -i ancu365-postgis \
        psql \
        --no-password \
        -U "${POSTGRES_USER}" \
        -d "${POSTGRES_DB}" \
        -v ON_ERROR_STOP=1 \
        -q

echo "[restore] Restore complete."

# ── Re-run migrations to apply any schema changes not in dump ─────────────────
echo "[restore] Running alembic upgrade head (to apply any missing migrations)..."
docker exec ancu365-backend alembic upgrade head || {
    echo "[restore] WARNING: alembic upgrade returned non-zero. Check manually." >&2
}

# ── Cleanup ───────────────────────────────────────────────────────────────────
rm -f "${DOWNLOAD_PATH}"
echo "[restore] Temp file removed."
echo ""
echo "[restore] Restore finished successfully at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "[restore] Restart backend if needed: docker compose restart backend"
