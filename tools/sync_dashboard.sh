#!/bin/bash
# Dashboard Sync Script for EAX TBC Classic Rotations
# Copies root libraries/dashboard.lua to all 29 spec directories
#
# Usage: ./tools/sync_dashboard.sh

set -e

ROOT_FILE="libraries/dashboard.lua"
SPEC_COUNT=0
SYNC_COUNT=0

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=== EAX Dashboard Sync Tool ==="
echo ""

# Verify root file exists
if [ ! -f "$ROOT_FILE" ]; then
    echo -e "${RED}[ERROR] Root dashboard.lua not found: $ROOT_FILE${NC}"
    exit 1
fi

echo "Root file: $ROOT_FILE"
echo "Scanning for EAX spec directories..."
echo ""

# Find all EAX directories and sync
for dir in EAX*/; do
    if [ -d "$dir" ]; then
        SPEC_COUNT=$((SPEC_COUNT + 1))
        target_dir="${dir}libraries"
        target_file="${target_dir}/dashboard.lua"
        
        # Check if libraries directory exists
        if [ -d "$target_dir" ]; then
            cp "$ROOT_FILE" "$target_file"
            echo -e "${GREEN}[SYNCED]${NC} $dir"
            SYNC_COUNT=$((SYNC_COUNT + 1))
        else
            echo -e "${YELLOW}[SKIP]${NC} $dir (no libraries folder)"
        fi
    fi
done

echo ""
echo "=== Sync Complete ==="
echo -e "Specs found: ${SPEC_COUNT}"
echo -e "Synced: ${SYNC_COUNT}"
echo ""

if [ $SYNC_COUNT -eq 0 ]; then
    echo -e "${YELLOW}Warning: No specs were synced. Check directory structure.${NC}"
    exit 1
elif [ $SYNC_COUNT -lt 29 ]; then
    echo -e "${YELLOW}Warning: Only $SYNC_COUNT of 29 specs were synced.${NC}"
    exit 0
else
    echo -e "${GREEN}All $SYNC_COUNT specs synced successfully!${NC}"
    exit 0
fi
