#!/usr/bin/env bash
# run_all_checks.sh -- Single unified validation gate for EaxRotations.
# WHAT:  luac parse + rotation tests + leveling tests + badge drift check.
# WHEN:  local pre-commit hook and CI (`.github/workflows/ci.yml`).
# WHY:   one script == identical local/CI behavior (per AGENTS.md R5).
# SAFETY: exits non-zero on first failure; never swallows errors.
# USAGE: bash tools/run_all_checks.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== EaxRotations validation gate ==="
echo ""

# 1. luac -p on all .lua files under EaxRotations/
echo "[1/4] Parsing all .lua files with luac -p ..."
find "$ROOT/EaxRotations" -name "*.lua" -print0 | while IFS= read -r -d '' f; do
    luac -p "$f" || { echo "FAIL: luac -p $f"; exit 1; }
done
echo "  OK — all files parse."

# 2. Rotation test suite
echo ""
echo "[2/4] Running rotation test suite ..."
( cd "$ROOT" && lua EaxRotations/tests/run_rotation_tests.lua )

# 3. Leveling test suite
echo ""
echo "[3/4] Running leveling test suite ..."
( cd "$ROOT" && lua EaxRotations/tests/run_leveling_tests.lua )

# 4. Badge drift check
echo ""
echo "[4/4] Checking badge counts are in sync ..."
( cd "$ROOT" && lua tools/update_badges.lua --check )

# 5. Lua 5.1 compatibility check
echo ""
echo "[5/5] Checking Lua 5.1 compatibility (luac -p on all project .lua files) ..."
( cd "$ROOT" && lua tools/check_lua51_compat.lua )

echo ""
echo "=== All checks passed ==="
