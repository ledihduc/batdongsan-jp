#!/usr/bin/env bash
# backup.sh — Daily PostgreSQL backup to Backblaze B2
#
# Usage (manual):   ./scripts/backup.sh
# Usage (cron):     See scripts/cron-backup for cron entry
#
# Required env vars (set in /opt/ancu365/ancu365-backend/.env or exported):
#   POSTGRES_USER, POSTGRES_DB, B2_KEY_ID, B2_APPLICATION_KEY, B2_BUCKET
#   NTFY_TOPIC (optional — ntfy alert on failure)
#   NTFY_URL   (optional — defaults to https://ntfy.sh)
#
# Dependencies: docker, b2 CLI (pip install b2), gzip
# Install b2: pip install --user b2  OR  apt install b2

set -euo pipefail

# ── Load .env if not already sourced ─────────────────────────────────────────
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
        echo "[backup] FATAL: Required env var '$var' is not set. Aborting." >&2
        exit 1
    fi
}

_require_env POSTGRES_USER
_require_env POSTGRES_DB
_require_env B2_KEY_ID
_require_env B2_APPLICATION_KEY
_require_env B2_BUCKET

NTFY_URL="${NTFY_URL:-https://ntfy.sh}"
NTFY_TOPIC="${NTFY_TOPIC:-}"

# ── Failure handler — post ntfy alert and exit non-zero ──────────────────────
_on_failure() {
    local exit_code=$?
    local line="$1"
    local msg="[ancu365-backup] FAILED at line ${line} (exit ${exit_code}) on $(hostname) at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "$msg" >&2
    if [[ -n "$NTFY_TOPIC" ]]; then
        curl -sf \
            -H "Title: ancu365 backup FAILED" \
            -H "Priority: urgent" \
            -H "Tags: warning,floppy_disk" \
            -d "$msg" \
            "${NTFY_URL}/${NTFY_TOPIC}" || true
    fi
    # Cleanup temp file if it exists
    [[ -n "${BACKUP_FILE:-}" && -f "${BACKUP_FILE}" ]] && rm -f "${BACKUP_FILE}"
    exit "$exit_code"
}
trap '_on_failure ${LINENO}' ERR

# ── Config ────────────────────────────────────────────────────────────────────
DATE="$(date +%Y%m%d_%H%M%S)"
BACKUP_NAME="ancu365-${DATE}.sql.gz"
BACKUP_FILE="/tmp/${BACKUP_NAME}"
RETENTION_DAYS=30

echo "[backup] Starting backup at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "[backup] Database: ${POSTGRES_DB} | User: ${POSTGRES_USER}"
echo "[backup] Output:   ${BACKUP_FILE}"

# ── Dump + compress ───────────────────────────────────────────────────────────
echo "[backup] Dumping database..."
docker exec ancu365-postgis \
    pg_dump \
    --no-password \
    -U "${POSTGRES_USER}" \
    "${POSTGRES_DB}" \
    | gzip -9 > "${BACKUP_FILE}"

BACKUP_SIZE="$(du -sh "${BACKUP_FILE}" | cut -f1)"
echo "[backup] Dump complete. Size: ${BACKUP_SIZE}"

# ── Upload to B2 ──────────────────────────────────────────────────────────────
echo "[backup] Authorizing B2..."
b2 authorize-account "${B2_KEY_ID}" "${B2_APPLICATION_KEY}" > /dev/null

echo "[backup] Uploading ${BACKUP_NAME} to B2 bucket '${B2_BUCKET}'..."
b2 upload-file "${B2_BUCKET}" "${BACKUP_FILE}" "${BACKUP_NAME}" > /dev/null

echo "[backup] Upload complete."

# ── Rotate — delete backups older than RETENTION_DAYS ────────────────────────
echo "[backup] Rotating backups older than ${RETENTION_DAYS} days..."
CUTOFF_DATE="$(date -d "-${RETENTION_DAYS} days" +%Y%m%d 2>/dev/null \
    || date -v -"${RETENTION_DAYS}"d +%Y%m%d)"  # macOS fallback

b2 ls --long "${B2_BUCKET}" | while IFS= read -r line; do
    # B2 ls --long format: <upload-timestamp-ms> <file-id> <action> <size> <filename>
    filename="$(echo "$line" | awk '{print $NF}')"
    # Extract date from filename pattern ancu365-YYYYMMDD_HHmmss.sql.gz
    file_date="$(echo "$filename" | grep -oE '[0-9]{8}' | head -1)"
    if [[ -n "$file_date" && "$file_date" < "$CUTOFF_DATE" ]]; then
        echo "[backup] Deleting old backup: ${filename}"
        b2 delete-file-version "${B2_BUCKET}" "${filename}" || true
    fi
done

# ── Cleanup local temp file ───────────────────────────────────────────────────
rm -f "${BACKUP_FILE}"
echo "[backup] Local temp file removed."

# ── Success notification (optional) ──────────────────────────────────────────
if [[ -n "$NTFY_TOPIC" ]]; then
    curl -sf \
        -H "Title: ancu365 backup OK" \
        -H "Priority: low" \
        -H "Tags: white_check_mark,floppy_disk" \
        -d "[ancu365-backup] OK — ${BACKUP_NAME} (${BACKUP_SIZE}) uploaded to B2 at $(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        "${NTFY_URL}/${NTFY_TOPIC}" || true
fi

echo "[backup] Done. $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
