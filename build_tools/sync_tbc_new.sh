#!/bin/bash
# sync_tbc_new.sh — Pull upstream wowsims/tbc-new while preserving local customizations.
# WHAT:  resets CRLF noise, fetches upstream, restores our custom files.
# WHEN:  run periodically to stay current with upstream.
# USAGE: cd repo_root && bash build_tools/sync_tbc_new.sh

set -e

TBC_DIR="tbc-new"
CUSTOM_FILES=(
  "tools/DB2ToSqlite/appsettings.classic_era.json"
)

echo "=== TBC-New Upstream Sync ==="
cd "$TBC_DIR"

# Save our custom files
BACKUP_DIR="../.tbc_new_backup_$(date +%s)"
mkdir -p "$BACKUP_DIR"
for f in "${CUSTOM_FILES[@]}"; do
  if [ -f "$f" ]; then
    cp "$f" "$BACKUP_DIR/$(basename "$f")"
    echo "  Backed up: $f"
  fi
done

# Remove stale untracked files that upstream now tracks (prevents merge conflicts)
rm -f ui/druid/balance/gear_sets/p5.gear.json
rm -f ui/priest/dps/gear_sets/p3.gear.json
rm -f ui/shaman/elemental/gear_sets/p5.gear.json
rm -f ui/warrior/dps/gear_sets/p5_arms.gear.json
rm -f ui/warrior/dps/gear_sets/p5_fury.gear.json
rm -f ui/warrior/protection/gear_sets/p5_bis.gear.json

# Fetch and pull upstream
echo "  Fetching upstream..."
git fetch origin
echo "  Pulling latest..."
git pull origin $(git rev-parse --abbrev-ref HEAD)

# Restore custom files
for f in "${CUSTOM_FILES[@]}"; do
  if [ -f "$BACKUP_DIR/$(basename "$f")" ]; then
    cp "$BACKUP_DIR/$(basename "$f")" "$f"
    echo "  Restored: $f"
  fi
done

# Cleanup
rm -rf "$BACKUP_DIR"

echo "=== Done. tbc-new is now at: ==="
git log --oneline -1
