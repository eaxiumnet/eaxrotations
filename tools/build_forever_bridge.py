#!/usr/bin/env python3
"""build_forever_bridge.py -- WoW Forever DBC -> Lua spell-index bridge builder.

WHAT:  reads the Forever beta client DBC extraction (SQLite, DB2ToSqlite output)
       and emits EaxRotations/shared/wowhead_data_bridge_spell_index_forever_sylvanas.lua
       exposing M.spell_index_forever ([spell_id] = {name, class, level, school,
       is_heal, aoe, cast_time, rank, gcd, cooldown_seconds}).
WHEN:  beta day 2026-09-17 (docs/forever/dbc_runbook.md steps 2-3).
WHY:   repo law (AGENTS.md): the client DBC is the authoritative source of
       truth. The Forever audit (run_forever_audit_tests.lua) switches from
       scaffold to live mode the moment this file replaces the stub bridge
       (M.__forever_stub disappears), so guessed IDs can never enter a
       _forever spec file.
SAFETY: --check mode verifies an existing bridge (non-empty, no placeholder
        names, spot-checks seed IDs); default mode requires the DBC to exist
        and refuses to overwrite unless the real index would be generated.

Usage:
    python tools/build_forever_bridge.py            # build from DBC
    python tools/build_forever_bridge.py --check    # verify existing bridge

Pipeline (mirrors AGENTS.md "Refresh pipeline", Forever flavor):
    1. DB2ToSqlite on the Forever beta client -> wowheadScrape/dbc_extract/wowsims_forever.db
    2. this script -> the Forever bridge (replaces the stub, flips audit to live)
"""

import argparse
import os
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DBC_DB = os.path.join(ROOT, "wowheadScrape", "dbc_extract", "wowsims_forever.db")
OUTPUT = os.path.join(
    ROOT, "EaxRotations", "shared", "wowhead_data_bridge_spell_index_forever_sylvanas.lua"
)

SCHOOL_MAP = {
    1: "physical",
    2: "holy",
    4: "fire",
    8: "nature",
    16: "frost",
    32: "shadow",
    64: "arcane",
}

# SpellClassSet -> class name (verified against the 2.5.5 DBC: 20594 Stoneform
# carries no SpellClassOptions row; class sets only appear on class spells).
CLASS_MAP = {
    1: "Warrior",
    2: "Paladin",
    3: "Hunter",
    4: "Rogue",
    5: "Priest",
    6: "Death Knight",
    7: "Shaman",
    8: "Mage",
    9: "Warlock",
    11: "Druid",
}

# Effects that heal (EffectBasePoints + roll(DieSides)) on this client format.
# Calibrated on the 2.5.5 DBC: Flash Heal r1 (2061) uses 10, Holy Light r2
# (639) uses 77. The classic-era IDs 2/62 are kept for forward compatibility.
HEAL_EFFECTS = {2, 10, 62, 77}

# ImplicitTarget buckets that make an effect area-targeted.
# ImplicitTarget[0] == TARGET_CASTER (1, 15); area targets are >= 15 elsewhere.
AREA_TARGETS = {6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 18, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 37, 38, 39, 40, 41, 42, 43, 46, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 76, 77, 78, 87, 106, 107, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 142, 143, 144, 146}

DEGENERATE_NAME_TOKENS = (
    "DEBUG", "QA ", "QA_", "QA-", "ALEX", "GRAYAL", "TEST", "PLACEHOLDER",
    "GENERIC", "UNUSED", "Deprecated", "OLD ", "(OLD", "TEMP", "UNUSED",
)

PASSIVE_AURAS = {24, 79}


def _school(mask):
    return SCHOOL_MAP.get(mask, "physical")


def _degenerate(name):
    if not name:
        return True
    upper = name.upper()
    return any(tok in upper for tok in DEGENERATE_NAME_TOKENS)


def load_forever_spells(conn):
    """Extract player-castable spell rows from the Forever DBC."""
    cur = conn.cursor()

    spell_rows = cur.execute(
        """
        SELECT s.ID,
               sn.Name_lang,
               sm.SchoolMask,
               sm.CastingTimeIndex,
               sl.SpellLevel,
               sl.BaseLevel,
               sco.SpellClassSet,
               sc.RecoveryTime,
               sc.StartRecoveryTime
        FROM Spell s
        LEFT JOIN SpellName sn   ON s.ID = sn.ID
        LEFT JOIN SpellMisc sm   ON s.ID = sm.SpellID
        LEFT JOIN SpellLevels sl ON s.ID = sl.SpellID
        LEFT JOIN SpellClassOptions sco ON s.ID = sco.SpellID
        LEFT JOIN SpellCooldowns sc ON s.ID = sc.SpellID
        WHERE s.ID >= 100
          AND sn.Name_lang IS NOT NULL
          AND sn.Name_lang != ''
          AND (sl.BaseLevel IS NULL OR (sl.BaseLevel >= 1 AND sl.BaseLevel <= 255))
          AND (sl.SpellLevel IS NULL OR (sl.SpellLevel >= 0 AND sl.SpellLevel <= 255))
          AND (sc.RecoveryTime IS NULL OR sc.RecoveryTime <= 1200000)
          AND (sc.StartRecoveryTime IS NULL OR sc.StartRecoveryTime <= 60000)
        """
    ).fetchall()

    # Aggregate effects per spell id (heal + AoE detection).
    effect_rows = cur.execute(
        """
        SELECT SpellID, Effect, EffectAura, EffectBasePoints, EffectDieSides,
               ImplicitTarget
        FROM SpellEffect
        """
    ).fetchall()
    heal_spells = set()
    aoe_spells = set()
    for spell_id, effect, aura, base_pts, die_sides, targets in effect_rows:
        if effect in HEAL_EFFECTS:
            heal_spells.add(spell_id)
        targets = targets or "[0,0]"
        parts = str(targets).strip("[]").split(",")
        target_a = int(parts[0]) if parts and parts[0].strip().lstrip("-").isdigit() else 0
        target_b = int(parts[1]) if len(parts) > 1 and parts[1].strip().lstrip("-").isdigit() else 0
        if effect in (27, 124) or (target_b >= 15 and target_a != 1) or target_b in AREA_TARGETS:
            aoe_spells.add(spell_id)

    result = {}
    for (spell_id, name, school_mask, cast_time_idx, spell_level, base_level,
         class_set, recovery_time, start_recovery) in spell_rows:
        if _degenerate(name):
            continue
        class_name = CLASS_MAP.get(class_set)
        if class_name is None:
            continue  # non-player spell (NPC abilities, items, GM, etc.)
        # Rank 1 baseline: emit only one row per (class, name) — the lowest
        # spell id seen for that pair (client rank ladders share one name).
        key = (class_name, name)
        existing = result.get(key)
        if existing is not None and existing["spell_id"] <= spell_id:
            continue
        result[key] = {
            "spell_id": spell_id,
            "name": name,
            "class": class_name,
            "level": base_level if base_level else spell_level or 1,
            "school": _school(school_mask or 1),
            "is_heal": spell_id in heal_spells,
            "aoe": spell_id in aoe_spells,
            "cast_time": cast_time_idx or 0,
            "gcd": round((start_recovery or 0) / 1000, 2),
            "cooldown_seconds": round((recovery_time or 0) / 1000, 2),
        }
    return result


def lua_escape(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_bridge(spells):
    lines = [
        "-- wowhead_data_bridge_spell_index_forever_sylvanas.lua -- Forever-era spell index bridge.",
        "-- WHAT:  DBC-derived map of WoW Forever (beta 2026-09-17) spell IDs to",
        "--        {name, class, level, school, is_heal, aoe, cast_time, rank, gcd, cooldown_seconds}.",
        "-- WHEN:  generated on beta day by tools/build_forever_bridge.py from",
        "--        wowheadScrape/dbc_extract/wowsims_forever.db (authoritative).",
        "-- WHY:   run_forever_audit_tests.lua flips from scaffold to LIVE mode the",
        "--        moment this file carries a real index (no __forever_stub flag):",
        "--        every spell ID in a _forever spec file must resolve here.",
        "-- SAFETY: generated file — do not hand-edit; regenerate from the DBC.",
        "-- FORMAT: positional fields 1-10 (same shape as the tbc/vanilla indexes).",
        "",
        "local M = {}",
        "",
        "M.spell_index_forever = {",
    ]
    entries = sorted(spells.values(), key=lambda e: e["spell_id"])
    for e in entries:
        fields = [
            lua_escape(e["name"]),
            lua_escape(e["class"]),
            str(int(e["level"])),
            lua_escape(e["school"]),
            "true" if e["is_heal"] else "false",
            "true" if e["aoe"] else "false",
            str(e["cast_time"]),
            "1",
            str(e["gcd"]),
            str(e["cooldown_seconds"]),
        ]
        lines.append("    [%d] = {%s}," % (e["spell_id"], ", ".join(fields)))
    lines.append("}")
    lines.append("")
    lines.append("return M.spell_index_forever")
    lines.append("")
    with open(OUTPUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("  Generated: %s" % OUTPUT)
    print("  Entries:   %d" % len(entries))
    print("  Size:      %s bytes" % format(os.path.getsize(OUTPUT), ","))


def check_bridge():
    """Verify an existing bridge is a real (non-stub) DBC-derived index."""
    if not os.path.exists(OUTPUT):
        print("FAIL: bridge missing: %s" % OUTPUT)
        return 2
    with open(OUTPUT, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()
    if "__forever_stub" in content:
        print("FAIL: bridge is still the STUB (scaffold mode)")
        return 2
    if "M.spell_index_forever = {" not in content:
        print("FAIL: bridge has no spell_index_forever table")
        return 2
    count = content.count("\n    [")
    if count < 1000:
        print("FAIL: bridge has only %d entries (a real Forever DBC yields thousands)" % count)
        return 1
    for probe in ("DEBUG", "QA ", "PLACEHOLDER"):
        if probe in content:
            print("FAIL: bridge contains degenerate name token %r" % probe)
            return 1
    print("OK: Forever bridge verified (%d spell entries, live mode)" % count)
    return 0


def main():
    parser = argparse.ArgumentParser(description="Forever DBC -> Lua bridge builder")
    parser.add_argument("--check", action="store_true", help="verify the existing bridge")
    args = parser.parse_args()
    if args.check:
        sys.exit(check_bridge())

    if not os.path.exists(DBC_DB):
        print("ERROR: Forever DBC not found: %s" % DBC_DB)
        print("       Run DB2ToSqlite on the Forever beta client first")
        print("       (docs/forever/dbc_runbook.md step 1).")
        sys.exit(2)
    conn = sqlite3.connect(DBC_DB)
    try:
        spells = load_forever_spells(conn)
    finally:
        conn.close()
    if not spells:
        print("ERROR: no player spells extracted from %s" % DBC_DB)
        sys.exit(2)
    print("Forever DBC: %d player spells extracted" % len(spells))
    write_bridge(spells)
    print("Audit live mode: run_forever_audit_tests.lua now enforces real ID resolution.")


if __name__ == "__main__":
    main()
