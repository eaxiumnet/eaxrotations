#!/usr/bin/env python3
"""
Build script: Fetches spell data from lexxer.org for TBC and Vanilla,
identifies spells with swapped IDs between expansions, and generates
a Lua lookup table for runtime expansion-aware resolution.

Usage:
    python build_tools/build_spell_resolver.py

Output:
    EaxRotations/shared/spell_id_table_sylvanas.lua

The generated table maps spell names to {tbc_id, vanilla_id} for spells
whose IDs differ between expansions. All other spells use the same ID
in both expansions and don't need resolution.
"""

import json
import os
import sys
import urllib.request
from datetime import datetime

LEXXER_API = "https://lexxer.org/api/v1"
OUTPUT_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "EaxRotations", "shared", "spell_id_table_sylvanas.lua"
)


def fetch_spell_list(game):
    """Fetch all spells for a game variant from lexxer.org."""
    url = f"{LEXXER_API}/spells?game={game}"
    print(f"  Fetching {url} ...")
    resp = urllib.request.urlopen(url, timeout=30)
    data = json.loads(resp.read())
    if not data.get("ok"):
        print(f"  ERROR: API returned ok=false for {game}")
        return []
    spells = data.get("data", [])
    print(f"  Got {len(spells)} spells for {game}")
    return spells


def find_swapped_spells(tbc_spells, vanilla_spells):
    """
    Find spell names that exist in both expansions but have different IDs
    for the SAME rank/level. This avoids false positives from spells that
    simply have different highest ranks in each expansion (e.g. Fireball
    rank 14 in TBC vs rank 12 in Vanilla).

    Strategy: group by (name, class), then compare IDs at matching
    required_level values. Only flag as 'swapped' if the same spell
    at the same level has different IDs.

    Returns dict: name -> {tbc_id, vanilla_id, class, school}
    """
    # Group spells by (name, class) -> {level: spell_entry}
    def group_by_level(spells):
        groups = {}
        for s in spells:
            key = (s["name"], s.get("required_class", ""))
            level = s.get("required_level") or 0
            g = groups.get(key)
            if not g:
                g = {}
                groups[key] = g
            g[level] = s
        return groups

    tbc_groups = group_by_level(tbc_spells)
    vanilla_groups = group_by_level(vanilla_spells)

    swapped = {}
    for key, tbc_by_level in tbc_groups.items():
        vanilla_by_level = vanilla_groups.get(key)
        if not vanilla_by_level:
            continue

        # Check if any matching level has different IDs
        for level, tbc_entry in tbc_by_level.items():
            vanilla_entry = vanilla_by_level.get(level)
            if vanilla_entry and tbc_entry["id"] != vanilla_entry["id"]:
                name, class_name = key
                swapped[name] = {
                    "tbc_id": tbc_entry["id"],
                    "vanilla_id": vanilla_entry["id"],
                    "class": class_name,
                    "school": tbc_entry.get("school", ""),
                }
                break  # One mismatch per spell name is enough

    return swapped


def generate_lua_table(swapped_spells):
    """Generate a Lua source file with the spell ID lookup table."""
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Sort by class then name for readability
    sorted_spells = sorted(swapped_spells.items(), key=lambda x: (x[1]["class"], x[0]))

    lines = []
    lines.append("-- =============================================================================")
    lines.append("-- Expansion-aware Spell ID Table (AUTO-GENERATED)")
    lines.append("-- =============================================================================")
    lines.append(f"-- Generated: {now}")
    lines.append("-- Source: lexxer.org API (TBC + Vanilla)")
    lines.append("--")
    lines.append("-- Maps spell names to their expansion-specific IDs.")
    lines.append("-- Only includes spells whose IDs DIFFER between TBC and Vanilla.")
    lines.append("-- All other spells use the same ID in both expansions.")
    lines.append("--")
    lines.append("-- Usage:")
    lines.append("--   local table = require('shared/spell_id_table_sylvanas')")
    lines.append("--   local id = table.resolve('Death Wish')  -- returns expansion-correct ID")
    lines.append("-- =============================================================================")
    lines.append("")
    lines.append("local M = {}")
    lines.append("")
    lines.append("-- Lookup: spell_name -> { tbc = id, vanilla = id }")
    lines.append("local SWAPPED_SPELLS = {")

    current_class = None
    for name, info in sorted_spells:
        class_name = info["class"]
        if class_name != current_class:
            if current_class is not None:
                lines.append("")
            lines.append(f"    -- {class_name}")
            current_class = class_name

        tbc_id = info["tbc_id"]
        van_id = info["vanilla_id"]
        school = info.get("school", "")
        comment = f"  -- TBC={tbc_id}, Vanilla={van_id}"
        if school:
            comment += f" ({school})"
        lines.append(f'    ["{name}"] = {{ tbc = {tbc_id}, vanilla = {van_id} }},{comment}')

    lines.append("}")
    lines.append("")
    lines.append("-- Cached expansion key (populated on first call)")
    lines.append("local _expansion = nil")
    lines.append("")
    lines.append("--- Resolve a spell name to its expansion-specific ID.")
    lines.append("--- Returns nil if the spell is not in the swapped table.")
    lines.append("--- For non-swapped spells, use the ID directly (same in both expansions).")
    lines.append("---")
    lines.append("--- @param spell_name string The spell name (e.g., 'Death Wish')")
    lines.append("--- @return number|nil spell_id The expansion-correct spell ID, or nil")
    lines.append("function M.resolve(spell_name)")
    lines.append("    local entry = SWAPPED_SPELLS[spell_name]")
    lines.append("    if not entry then return nil end")
    lines.append("    -- Lazy-init expansion detection")
    lines.append("    if _expansion == nil then")
    lines.append("        local NS = _G.EaxRotations")
    lines.append("        if NS and NS.is_vanilla and NS.is_vanilla() then")
    lines.append('            _expansion = "vanilla"')
    lines.append("        else")
    lines.append('            _expansion = "tbc"')
    lines.append("        end")
    lines.append("    end")
    lines.append("    return entry[_expansion]")
    lines.append("end")
    lines.append("")
    lines.append("--- Get the TBC ID for a swapped spell.")
    lines.append("--- @param spell_name string")
    lines.append("--- @return number|nil")
    lines.append("function M.tbc_id(spell_name)")
    lines.append("    local entry = SWAPPED_SPELLS[spell_name]")
    lines.append("    return entry and entry.tbc or nil")
    lines.append("end")
    lines.append("")
    lines.append("--- Get the Vanilla ID for a swapped spell.")
    lines.append("--- @param spell_name string")
    lines.append("--- @return number|nil")
    lines.append("function M.vanilla_id(spell_name)")
    lines.append("    local entry = SWAPPED_SPELLS[spell_name]")
    lines.append("    return entry and entry.vanilla or nil")
    lines.append("end")
    lines.append("")
    lines.append("--- Check if a spell name has swapped IDs between expansions.")
    lines.append("--- @param spell_name string")
    lines.append("--- @return boolean")
    lines.append("function M.is_swapped(spell_name)")
    lines.append("    return SWAPPED_SPELLS[spell_name] ~= nil")
    lines.append("end")
    lines.append("")
    lines.append("--- Get all swapped spell names (for debugging/testing).")
    lines.append("--- @return string[]")
    lines.append("function M.get_all_swapped()")
    lines.append("    local result = {}")
    lines.append("    local n = 0")
    lines.append("    for name in pairs(SWAPPED_SPELLS) do")
    lines.append("        n = n + 1")
    lines.append("        result[n] = name")
    lines.append("    end")
    lines.append("    table.sort(result)")
    lines.append("    return result")
    lines.append("end")
    lines.append("")
    lines.append("--- Force re-detection of expansion (for testing).")
    lines.append("function M._reset_expansion()")
    lines.append("    _expansion = nil")
    lines.append("end")
    lines.append("")
    lines.append("--- Raw table access (for testing).")
    lines.append("M._SWAPPED_SPELLS = SWAPPED_SPELLS")
    lines.append("")
    lines.append("return M")

    return "\n".join(lines) + "\n"


def main():
    print("=== Spell Resolver Build Script ===")
    print(f"Output: {OUTPUT_PATH}")
    print()

    # Fetch spell lists from both expansions
    print("Fetching TBC spells...")
    tbc_spells = fetch_spell_list("tbc")
    if not tbc_spells:
        print("ERROR: Failed to fetch TBC spells")
        sys.exit(1)

    print("Fetching Vanilla spells...")
    vanilla_spells = fetch_spell_list("vanilla")
    if not vanilla_spells:
        print("ERROR: Failed to fetch Vanilla spells")
        sys.exit(1)

    # Sanity check: ensure we got a reasonable number of spells
    if len(tbc_spells) < 500 or len(vanilla_spells) < 500:
        print(f"ERROR: Too few spells returned (TBC={len(tbc_spells)}, Vanilla={len(vanilla_spells)}). API may be down.")
        sys.exit(1)

    # Find swapped spells
    print("\nAnalyzing ID differences...")
    swapped = find_swapped_spells(tbc_spells, vanilla_spells)
    print(f"Found {len(swapped)} spells with swapped IDs between expansions")

    if swapped:
        print("\nSwapped spells:")
        for name, info in sorted(swapped.items()):
            print(f"  {name}: TBC={info['tbc_id']}, Vanilla={info['vanilla_id']} ({info['class']})")

    # Generate Lua file
    print(f"\nGenerating {OUTPUT_PATH}...")
    lua_code = generate_lua_table(swapped)

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        f.write(lua_code)

    print(f"Done! Generated {len(swapped)} swapped spell entries.")
    print(f"File size: {os.path.getsize(OUTPUT_PATH)} bytes")


if __name__ == "__main__":
    main()
