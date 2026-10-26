#!/usr/bin/env bash
# verify_jp_build.sh — Launch build verification for JP market.
#
# Usage:
#   tools/verify_jp_build.sh
#
# Must be run from the repo root (ancu365-app/).
# Requires: Docker (for flutter), python3.
#
# Exit codes:
#   0 — all checks pass
#   1 — one or more checks failed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

fail=0

ok() { echo -e "${GREEN}[PASS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[FAIL]${NC} $1"; fail=1; }

echo "=== JP Launch Build Verification ==="
echo "Repo root: ${REPO_ROOT}"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 1: flutter test (baseline 1845+)
# ──────────────────────────────────────────────────────────────────────────────
echo "--- Step 1: flutter test ---"
TEST_OUTPUT=$(docker run --rm \
  -v "${REPO_ROOT}":/app \
  -w /app \
  ghcr.io/cirruslabs/flutter:stable \
  bash -lc 'flutter pub get >/dev/null && flutter test --reporter=expanded 2>&1' \
  || true)

echo "${TEST_OUTPUT}" | tail -5

# Extract pass count from output like "+1845: All tests passed"
PASS_COUNT=$(echo "${TEST_OUTPUT}" | grep -oE '\+([0-9]+): All tests passed' | grep -oE '[0-9]+' | tail -1 || echo "0")
if [ -z "${PASS_COUNT}" ]; then
  # Try alternate format
  PASS_COUNT=$(echo "${TEST_OUTPUT}" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | tail -1 || echo "0")
fi

if [ "${PASS_COUNT:-0}" -ge 1845 ] 2>/dev/null; then
  ok "Tests: ${PASS_COUNT} passed (>= 1845 baseline)"
elif echo "${TEST_OUTPUT}" | grep -q "All tests passed"; then
  ok "Tests: All tests passed"
else
  err "Tests: expected >= 1845 passing tests. Got: ${PASS_COUNT}"
  echo "${TEST_OUTPUT}" | grep -E "(FAIL|Error)" | head -10
fi

# ──────────────────────────────────────────────────────────────────────────────
# Step 2: flutter build web --release --dart-define=REGION=jp
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- Step 2: flutter build web --release ---"
BUILD_OUTPUT=$(docker run --rm \
  -v "${REPO_ROOT}":/app \
  -w /app \
  ghcr.io/cirruslabs/flutter:stable \
  bash -lc 'flutter pub get >/dev/null && flutter build web --release --dart-define=REGION=jp 2>&1' \
  || true)

if echo "${BUILD_OUTPUT}" | grep -q "Built build/web"; then
  ok "flutter build web: success"
else
  err "flutter build web: FAILED"
  echo "${BUILD_OUTPUT}" | tail -20
fi

# ──────────────────────────────────────────────────────────────────────────────
# Step 3: bundle size check (<15 MB JS)
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- Step 3: JS bundle size check (<15 MB) ---"
MAIN_JS="${REPO_ROOT}/build/web/main.dart.js"
if [ -f "${MAIN_JS}" ]; then
  JS_SIZE_BYTES=$(wc -c < "${MAIN_JS}")
  JS_SIZE_MB=$(echo "scale=2; ${JS_SIZE_BYTES} / 1048576" | bc)
  if [ "${JS_SIZE_BYTES}" -lt 15728640 ]; then # 15 MB = 15*1024*1024
    ok "main.dart.js: ${JS_SIZE_MB} MB (< 15 MB)"
  else
    err "main.dart.js: ${JS_SIZE_MB} MB exceeds 15 MB budget"
  fi
else
  warn "main.dart.js not found — skipping size check (build may have failed)"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Step 4: run nen_gz.py (gzip + brotli static compression)
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- Step 4: nen_gz.py static compression ---"
if [ -d "${REPO_ROOT}/build/web" ]; then
  if python3 "${SCRIPT_DIR}/nen_gz.py" "${REPO_ROOT}/build/web" >/dev/null 2>&1; then
    ok "nen_gz.py: .gz and .br files generated"
  else
    err "nen_gz.py: failed to compress build artifacts"
  fi
else
  warn "build/web not found — skipping compression (build may have failed)"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Step 5: no console.log in release config files
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- Step 5: no debug console.log in release config ---"
# Check only release-relevant config files, not test/debug files.
CONSOLE_LOG_FILES=$(grep -rn "console\.log\|debugPrint\|print(" \
  "${REPO_ROOT}/lib/core/config/" \
  "${REPO_ROOT}/lib/main.dart" \
  --include="*.dart" \
  --exclude="*_test.dart" \
  2>/dev/null || true)

if [ -z "${CONSOLE_LOG_FILES}" ]; then
  ok "No console.log/debugPrint in release config files"
else
  err "Found debug prints in release config:"
  echo "${CONSOLE_LOG_FILES}"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Step 6: no TODO/FIXME in release-critical JP config
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- Step 6: no TODO/FIXME in JP release config ---"
TODO_FILES=$(grep -rn "TODO\|FIXME" \
  "${REPO_ROOT}/lib/core/config/" \
  --include="*.dart" \
  2>/dev/null || true)

if [ -z "${TODO_FILES}" ]; then
  ok "No TODO/FIXME in release config"
else
  warn "TODO/FIXME in config files (review before launch):"
  echo "${TODO_FILES}"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Summary ==="
if [ "${fail}" -eq 0 ]; then
  echo -e "${GREEN}All checks PASSED. JP build is launch-ready.${NC}"
  exit 0
else
  echo -e "${RED}One or more checks FAILED. Review output above.${NC}"
  exit 1
fi
