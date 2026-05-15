#!/usr/bin/env bash
# =============================================================================
# run_leveling_tests.sh — Run all leveling rotation test suites
#
# Usage:
#   bash run_leveling_tests.sh        # Per-suite summary
#   bash run_leveling_tests.sh -v     # Verbose (full output per suite)
#   bash run_leveling_tests.sh -q     # Quiet (only final summary table)
#
# Exits 0 if all pass, 1 if any fail.
# =============================================================================
set -o pipefail

# --- Detect project root (two levels up from tests/) -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [[ ! -d "$PROJECT_DIR/EaxRotations" ]]; then
    PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

cd "$PROJECT_DIR" || { echo "ERROR: cannot cd to $PROJECT_DIR"; exit 1; }

LUA="lua"

# --- Config ------------------------------------------------------------------
MODE="${1:-normal}"  # normal, verbose, quiet

TEST_FILES=(
    test_leveling_mage.lua
    test_leveling_warlock.lua
    test_leveling_priest.lua
    test_leveling_rogue.lua
    test_leveling_shaman.lua
    test_leveling_warrior.lua
    test_leveling_druid.lua
    test_leveling_hunter.lua
    test_leveling_paladin.lua
    test_leveling_load.lua
    test_leveling_shared.lua
)

TOTAL_TESTS=${#TEST_FILES[@]}
PASSED=0
FAILED=0
FAILURE_NAMES=()

# --- Parse flags -------------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        -v|--verbose) MODE="verbose" ;;
        -q|--quiet)   MODE="quiet"   ;;
    esac
done

# --- Validate Lua ------------------------------------------------------------
if ! command -v "$LUA" &>/dev/null; then
    echo "ERROR: '$LUA' not found in PATH"
    exit 1
fi

# --- Header ------------------------------------------------------------------
if [[ "$MODE" != "quiet" ]]; then
    echo "============================================================================="
    echo "  EAX Leveling Rotation Tests"
    echo "  Project: $PROJECT_DIR"
    echo "  Files:   $TOTAL_TESTS suites"
    echo "============================================================================="
    echo ""
fi

# --- Run each test suite -----------------------------------------------------
for file in "${TEST_FILES[@]}"; do
    test_path="$SCRIPT_DIR/$file"

    if [[ ! -f "$test_path" ]]; then
        if [[ "$MODE" != "quiet" ]]; then
            echo "  [ MISSING ] $file — file not found"
        fi
        FAILED=$((FAILED + 1))
        FAILURE_NAMES+=("$file (missing)")
        continue
    fi

    if [[ "$MODE" == "verbose" ]]; then
        echo "━━━ $file ━━━"
        "$LUA" "$test_path" 2>&1
        exit_code=$?
        echo ""
    else
        output=$("$LUA" "$test_path" 2>&1)
        exit_code=$?
    fi

    if [[ $exit_code -eq 0 ]]; then
        PASSED=$((PASSED + 1))
        if [[ "$MODE" != "quiet" ]]; then
            # Extract summary line from output
            summary=$(echo "$output" | grep -iE "(passed.*failed|results:.*passed|all.*passed)" | tail -1)
            if [[ -z "$summary" ]]; then
                summary="ok"
            fi
            printf "  [ PASS ] %-32s %s\n" "$file" "$summary"
        fi
    else
        FAILED=$((FAILED + 1))
        FAILURE_NAMES+=("$file")
        if [[ "$MODE" != "quiet" ]]; then
            # Show failure context
            failure_line=$(echo "$output" | grep -iE "(FAIL|error|assert)" | head -5)
            printf "  [ FAIL ] %-32s\n" "$file"
            if [[ -n "$failure_line" ]]; then
                echo "           $failure_line"
            fi
            # Show last 10 lines of output for context
            echo "$output" | tail -10 | sed 's/^/           /'
        fi
    fi
done

# --- Summary table -----------------------------------------------------------
echo ""
echo "============================================================================="
echo "  RESULTS"
echo "============================================================================="
printf "  Total:  %3d suites\n" "$TOTAL_TESTS"
printf "  Passed: %3d\n" "$PASSED"
printf "  Failed: %3d\n" "$FAILED"

if [[ ${#FAILURE_NAMES[@]} -gt 0 ]]; then
    echo "  ──────────────────────────────────────"
    echo "  Failed suites:"
    for name in "${FAILURE_NAMES[@]}"; do
        echo "    - $name"
    done
fi

echo "============================================================================="

# --- Exit code ---------------------------------------------------------------
if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
