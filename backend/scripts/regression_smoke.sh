#!/usr/bin/env bash
# Regression smoke suite — Phase 11 pre-launch gate
#
# Usage:
#   ./scripts/regression_smoke.sh
#   ./scripts/regression_smoke.sh --quick   (skip E2E, run only regression)
#
# Exit codes:
#   0 — all checks GREEN
#   1 — one or more checks RED
#
# Reports:
#   Prints RED/GREEN per check to stdout.
#   Saves summary to plans/reports/smoke-$(date +%Y%m%d-%H%M%S).txt

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORTS_DIR="${REPO_ROOT}/plans/reports"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
REPORT_FILE="${REPORTS_DIR}/smoke-${TIMESTAMP}.txt"
QUICK_MODE=0

# Parse args
for arg in "$@"; do
  if [[ "$arg" == "--quick" ]]; then
    QUICK_MODE=1
  fi
done

mkdir -p "${REPORTS_DIR}"

# Colour helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Colour

PASS=0
FAIL=0
RESULTS=()

log() {
  echo -e "$@" | tee -a "${REPORT_FILE}"
}

run_check() {
  local label="$1"
  shift
  local cmd=("$@")

  log "\n${YELLOW}[RUN]${NC} ${label}"
  if "${cmd[@]}" >> "${REPORT_FILE}" 2>&1; then
    log "${GREEN}[PASS]${NC} ${label}"
    RESULTS+=("PASS: ${label}")
    ((PASS++))
  else
    local exit_code=$?
    log "${RED}[FAIL]${NC} ${label} (exit ${exit_code})"
    RESULTS+=("FAIL: ${label}")
    ((FAIL++))
  fi
}

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------

log "=================================================="
log "  Regression Smoke Suite — Phase 11"
log "  $(date -u)"
log "  Repo: ${REPO_ROOT}"
log "  Quick mode: ${QUICK_MODE}"
log "=================================================="

# ---------------------------------------------------------------------------
# Check 1: AC-52 guard — no host_id ALTER in migrations
# ---------------------------------------------------------------------------

run_check "AC-52: no host_id ALTER in migrations" \
  python "${REPO_ROOT}/scripts/check_no_host_id_alter.py"

# ---------------------------------------------------------------------------
# Check 2: Regression tests (backward compat)
# ---------------------------------------------------------------------------

run_check "Regression suite: existing host flows" \
  python -m pytest "${REPO_ROOT}/tests/regression/test_existing_host_flows_unchanged.py" \
    -v --tb=short -q

run_check "Regression suite: invoice commission v1 freemium" \
  python -m pytest "${REPO_ROOT}/tests/regression/test_invoice_flow_with_commission_v1_freemium.py" \
    -v --tb=short -q

run_check "Regression suite: changelog dual-identity backward compat" \
  python -m pytest "${REPO_ROOT}/tests/regression/test_changelog_dual_identity_does_not_break_existing_readers.py" \
    -v --tb=short -q

# ---------------------------------------------------------------------------
# Check 3: E2E tests (skip if --quick)
# ---------------------------------------------------------------------------

if [[ "${QUICK_MODE}" -eq 0 ]]; then
  run_check "E2E: full lifecycle" \
    python -m pytest "${REPO_ROOT}/tests/e2e/test_owner_operator_full_lifecycle.py" \
      -v --tb=short -q

  run_check "E2E: KB04 fast-track flow" \
    python -m pytest "${REPO_ROOT}/tests/e2e/test_kb04_fast_track_flow.py" \
      -v --tb=short -q

  run_check "E2E: owner death + heir" \
    python -m pytest "${REPO_ROOT}/tests/e2e/test_owner_death_heir_flow.py" \
      -v --tb=short -q

  run_check "E2E: fraud termination" \
    python -m pytest "${REPO_ROOT}/tests/e2e/test_fraud_termination_flow.py" \
      -v --tb=short -q

  run_check "E2E: actor context isolation" \
    python -m pytest "${REPO_ROOT}/tests/e2e/test_actor_context_isolation.py" \
      -v --tb=short -q
else
  log "\n${YELLOW}[SKIP]${NC} E2E tests (--quick mode)"
fi

# ---------------------------------------------------------------------------
# Check 4: Security tests (IDOR matrix)
# ---------------------------------------------------------------------------

if [[ -f "${REPO_ROOT}/tests/security/test_idor_across_delegations.py" ]]; then
  run_check "Security: IDOR across delegations" \
    python -m pytest "${REPO_ROOT}/tests/security/test_idor_across_delegations.py" \
      -v --tb=short -q
fi

if [[ -f "${REPO_ROOT}/tests/security/test_lockdown_window_enforcement.py" ]]; then
  run_check "Security: lockdown window enforcement" \
    python -m pytest "${REPO_ROOT}/tests/security/test_lockdown_window_enforcement.py" \
      -v --tb=short -q
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

TOTAL=$((PASS + FAIL))

log "\n=================================================="
log "  RESULTS SUMMARY"
log "=================================================="
for result in "${RESULTS[@]}"; do
  if [[ "$result" == PASS* ]]; then
    log "  ${GREEN}${result}${NC}"
  else
    log "  ${RED}${result}${NC}"
  fi
done

log ""
log "  Total: ${TOTAL} | ${GREEN}PASS: ${PASS}${NC} | ${RED}FAIL: ${FAIL}${NC}"
log "  Report: ${REPORT_FILE}"
log "=================================================="

if [[ "${FAIL}" -gt 0 ]]; then
  log "\n${RED}SMOKE: RED — ${FAIL} check(s) failed. DO NOT ship.${NC}"
  exit 1
else
  log "\n${GREEN}SMOKE: GREEN — all ${PASS} checks passed.${NC}"
  exit 0
fi
