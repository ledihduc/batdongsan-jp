#!/usr/bin/env bash
# Cấu hình pipeline self-heal. Nạp bởi selfheal.sh.
# Chỉnh ở đây, KHÔNG hardcode trong orchestrator.

# ── Đường dẫn ─────────────────────────────────────────────────────────────────
REPO_ROOT="${REPO_ROOT:-/home/sysadmin/deploy/ancu365/ancu365-backend}"
LOG_DIR="${LOG_DIR:-$REPO_ROOT/storage/logs}"
RUN_DIR="${RUN_DIR:-$LOG_DIR/selfheal_runs}"
STATE_FILE="${STATE_FILE:-$LOG_DIR/.selfheal_state.json}"
ESCALATION_DIR="${ESCALATION_DIR:-$LOG_DIR/escalations}"

# ── Cờ điều khiển (SAFE-BY-DEFAULT) ──────────────────────────────────────────
# File phải TỒN TẠI để bật từng năng lực. Mặc định KHÔNG có → pipeline chỉ
# phát hiện + báo cáo, KHÔNG sửa code, KHÔNG deploy. Bật bằng cách tạo file.
ENABLE_AUTOFIX_FLAG="${ENABLE_AUTOFIX_FLAG:-$REPO_ROOT/scripts/observability/ENABLE_AUTOFIX}"
ENABLE_AUTODEPLOY_FLAG="${ENABLE_AUTODEPLOY_FLAG:-$REPO_ROOT/scripts/observability/ENABLE_AUTODEPLOY}"
# Kill-switch: nếu file này TỒN TẠI → dừng ngay mọi hành động.
KILLSWITCH_FILE="${KILLSWITCH_FILE:-$REPO_ROOT/scripts/observability/KILLSWITCH}"

# ── Claude headless ──────────────────────────────────────────────────────────
CLAUDE_BIN="${CLAUDE_BIN:-/home/sysadmin/.local/bin/claude}"
POLICY_FILE="${POLICY_FILE:-$REPO_ROOT/scripts/observability/AUTOFIX_POLICY.md}"

# ── Staging (verify) — DB ẩn danh, KHÔNG bao giờ trỏ prod ─────────────────────
STAGING_DB_URL="${STAGING_DB_URL:-sqlite:////tmp/ancu365_staging.db}"
PYTEST_ARGS="${PYTEST_ARGS:--q -x}"
SMOKE_SCRIPT="${SMOKE_SCRIPT:-$REPO_ROOT/scripts/regression_smoke.sh}"

# ── Deploy (canary + rollback) ───────────────────────────────────────────────
BACKEND_IMAGE="${BACKEND_IMAGE:-ancu365-backend:local}"
BACKEND_CONTAINER="${BACKEND_CONTAINER:-ancu365-backend}"
ROLLBACK_IMAGE="${ROLLBACK_IMAGE:-ancu365-backend:rollback}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:3010/health}"
HEALTH_RETRIES="${HEALTH_RETRIES:-10}"
HEALTH_INTERVAL_S="${HEALTH_INTERVAL_S:-3}"

# ── Ngưỡng ───────────────────────────────────────────────────────────────────
MIN_COUNT="${MIN_COUNT:-1}"          # cluster phải có >= n lần lỗi mới xét
