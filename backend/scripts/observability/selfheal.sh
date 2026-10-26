#!/usr/bin/env bash
# selfheal.sh — Orchestrator pipeline tự-sửa-lỗi (bước 2→4).
#
#   detect (collect_errors) → [autofix (claude)] → guardrail → verify (staging)
#                           → [deploy canary + rollback] → audit
#
# SAFE-BY-DEFAULT: nếu chưa tạo file cờ ENABLE_AUTOFIX / ENABLE_AUTODEPLOY thì
# pipeline chỉ PHÁT HIỆN + LƯU BÁO CÁO, không sửa code, không deploy.
# KILLSWITCH tồn tại → dừng ngay.
#
# Cờ:
#   --dry-run   : không gọi claude thật, không deploy thật (dùng để thử luồng).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/selfheal.config.sh"

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

RUN_ID="$(date -u +%Y%m%d-%H%M%S)-$$"
RUN_PATH="$RUN_DIR/$RUN_ID"
mkdir -p "$RUN_PATH" "$ESCALATION_DIR"
RUN_LOG="$RUN_PATH/run.log"

log(){ echo "[selfheal $(date -u +%H:%M:%S)] $*" | tee -a "$RUN_LOG"; }
audit(){ echo "$1" > "$RUN_PATH/verdict.txt"; }
finish(){ audit "$1"; log "VERDICT=$1"; exit "${2:-0}"; }

# ── 0. Kill-switch + lock ────────────────────────────────────────────────────
if [ -f "$KILLSWITCH_FILE" ]; then log "KILLSWITCH bật — dừng."; finish "killswitch"; fi

LOCK="$LOG_DIR/.selfheal.lock"
exec 9>"$LOCK"
if ! flock -n 9; then log "Đang có run khác — bỏ qua."; exit 0; fi

log "== self-heal run $RUN_ID (dry_run=$DRY_RUN) =="

# ── 1. Detect: lọc lỗi ───────────────────────────────────────────────────────
set +e
python3 "$HERE/collect_errors.py" --logs "$LOG_DIR" --state "$STATE_FILE" \
  --out "$LOG_DIR" --min-count "$MIN_COUNT" | tee -a "$RUN_LOG"
DETECT_RC=${PIPESTATUS[0]}
set -e
cp -f "$LOG_DIR/error_report.json" "$RUN_PATH/" 2>/dev/null || true
cp -f "$LOG_DIR/error_report.md" "$RUN_PATH/" 2>/dev/null || true

if [ "$DETECT_RC" != "10" ]; then
  log "Không có cluster lỗi MỚI (rc=$DETECT_RC)."; finish "no-new-errors"
fi
log "Có cluster lỗi mới → tiếp tục."

# ── 2. Gate: autofix có được bật? ────────────────────────────────────────────
if [ ! -f "$ENABLE_AUTOFIX_FLAG" ]; then
  log "AUTOFIX chưa bật (thiếu $ENABLE_AUTOFIX_FLAG). Chế độ CHỈ BÁO CÁO."
  log "Báo cáo lưu ở: $RUN_PATH/error_report.md"
  finish "report-only"
fi

# ── 3. Chuẩn bị git branch (yêu cầu cây làm việc sạch) ───────────────────────
cd "$REPO_ROOT"
if [ -n "$(git status --porcelain)" ]; then
  log "Cây git KHÔNG sạch — không tự sửa để tránh trộn thay đổi. Escalate."
  git status --short | tee -a "$RUN_LOG"
  finish "dirty-tree" 0
fi
BASE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
FIX_BRANCH="autofix/$RUN_ID"
git checkout -b "$FIX_BRANCH" >/dev/null 2>&1
log "Branch: $FIX_BRANCH (base $BASE_BRANCH)"

SUMMARY_FILE="$RUN_PATH/SUMMARY.json"

# ── 4. Autofix bằng Claude headless ──────────────────────────────────────────
PROMPT="$(cat "$POLICY_FILE")

# BÁO CÁO LỖI
$(cat "$LOG_DIR/error_report.md")

Hãy sửa nguyên nhân gốc theo đúng chính sách trên. Ghi kết quả JSON vào file:
$SUMMARY_FILE"

if [ "$DRY_RUN" = "1" ]; then
  log "[dry-run] bỏ qua gọi claude."
else
  log "Gọi claude headless để phân tích + vá…"
  AUTOFIX_SUMMARY="$SUMMARY_FILE" "$CLAUDE_BIN" -p "$PROMPT" \
      --permission-mode acceptEdits \
      --allowedTools "Read Edit Write Grep Glob" \
      >"$RUN_PATH/claude.out" 2>&1 || log "claude thoát khác 0 (xem claude.out)"
fi

# ── 5. Guardrail: kiểm tra diff ──────────────────────────────────────────────
git add -A >/dev/null 2>&1 || true
git diff --cached --name-only > "$RUN_PATH/changed_files.txt"
log "File thay đổi:"; cat "$RUN_PATH/changed_files.txt" | tee -a "$RUN_LOG"

set +e
python3 "$HERE/guardrail_check.py" --files "$RUN_PATH/changed_files.txt" | tee -a "$RUN_LOG"
GR_RC=${PIPESTATUS[0]}
set -e

revert_all(){ git reset --hard "$BASE_BRANCH" >/dev/null 2>&1 || true; git checkout "$BASE_BRANCH" >/dev/null 2>&1 || true; git branch -D "$FIX_BRANCH" >/dev/null 2>&1 || true; }

escalate(){
  local reason="$1"
  log "ESCALATE ($reason) — lưu patch cho người duyệt, KHÔNG deploy."
  git diff --cached > "$ESCALATION_DIR/$RUN_ID.patch" 2>/dev/null || true
  cp -f "$SUMMARY_FILE" "$ESCALATION_DIR/$RUN_ID.summary.json" 2>/dev/null || true
  cp -f "$LOG_DIR/error_report.md" "$ESCALATION_DIR/$RUN_ID.error_report.md" 2>/dev/null || true
  revert_all
  finish "escalate:$reason" 0
}

case "$GR_RC" in
  3) log "Claude không đổi gì."; revert_all; finish "no-change" 0 ;;
  2) escalate "guardrail-sensitive" ;;
  0) log "Guardrail: SAFE → verify." ;;
  *) escalate "guardrail-unknown-$GR_RC" ;;
esac

# ── 6. Verify trên staging (pytest + smoke) — KHÔNG đụng prod DB ─────────────
log "Verify trên staging DB: $STAGING_DB_URL"
set +e
docker run --rm -v "$REPO_ROOT":/app -w /app \
  -e DATABASE_URL="$STAGING_DB_URL" -e ENVIRONMENT=development -e LOG_DIR=/tmp/logs \
  "$BACKEND_IMAGE" bash -c "pip install -q pytest >/dev/null 2>&1; pytest $PYTEST_ARGS" \
  >"$RUN_PATH/pytest.out" 2>&1
PYTEST_RC=$?
set -e
tail -n 15 "$RUN_PATH/pytest.out" | tee -a "$RUN_LOG"
if [ "$PYTEST_RC" != "0" ]; then escalate "tests-failed"; fi
log "Tests PASS trên staging."

# Commit bản vá đã verify.
git commit -q -m "autofix($RUN_ID): $(head -c 80 "$SUMMARY_FILE" 2>/dev/null || echo fix)" || true

# ── 7. Deploy (chỉ khi bật ENABLE_AUTODEPLOY) ────────────────────────────────
if [ ! -f "$ENABLE_AUTODEPLOY_FLAG" ]; then
  log "AUTODEPLOY chưa bật — bản vá đã verify nằm ở branch $FIX_BRANCH, chờ deploy tay."
  git checkout "$BASE_BRANCH" >/dev/null 2>&1 || true
  finish "verified-hold-deploy" 0
fi

if [ "$DRY_RUN" = "1" ]; then
  log "[dry-run] bỏ qua deploy thật."; git checkout "$BASE_BRANCH" >/dev/null 2>&1 || true
  finish "dry-run-verified" 0
fi

# Merge vào base rồi deploy (deploy build từ cây làm việc).
git checkout "$BASE_BRANCH" >/dev/null 2>&1
git merge --no-ff -q "$FIX_BRANCH" -m "autofix merge $RUN_ID" || { log "Merge conflict — escalate."; escalate "merge-conflict"; }

log "Deploy canary + rollback…"
set +e
bash "$HERE/deploy_backend.sh" >>"$RUN_LOG" 2>&1
DEPLOY_RC=$?
set -e
if [ "$DEPLOY_RC" = "0" ]; then
  log "DEPLOY THÀNH CÔNG."; finish "deployed" 0
else
  log "DEPLOY FAIL/ROLLBACK (rc=$DEPLOY_RC) — hoàn tác merge."
  git revert --no-edit HEAD >/dev/null 2>&1 || git reset --hard HEAD~1 >/dev/null 2>&1 || true
  finish "deploy-rolled-back" 0
fi
