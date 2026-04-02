#!/bin/bash
# Quick test of theory validation framework
# Usage: ./test_theory.sh [spec_name] [encounter]

SPEC=${1:-"MAGE_FIRE"}
ENCOUNTER=${2:-"gruul"}

echo "Testing $SPEC against $ENCOUNTER..."
cd "$(dirname "$0")/.."

lua theory_validation/validation_runner.lua 2>&1 | head -100

echo ""
echo "To test specific spec:"
echo "  lua -e \"local s=require('theory_validation.simulator_core'); local r=s.run_rotation('$SPEC', '$ENCOUNTER'); print(r.dps, r.verdict)\""
