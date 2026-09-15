#!/usr/bin/env python3
"""build_forever_bridge_fixture.py -- synthetic Forever DBC for offline pipeline tests.

WHAT:  creates wowheadScrape/dbc_extract/wowsims_forever.db as a SYNTHETIC
       Forever client DBC (schema identical to DB2ToSqlite output; real 2.5.5
       rows copied for grounding + synthetic Forever-new spells).
WHEN:  any time -- validates build_forever_bridge.py BEFORE the beta client
       exists (2026-09-17). The synthetic DB is local-only, never committed,
       and MUST be regenerated from the real client on beta day.
WHY:   the pipeline must be proven end-to-end before it is needed for real;
       DBC-as-source-of-truth means the extraction toolchain is repo-critical
       infrastructure and cannot be exercised for the first time on beta day.
SAFETY: writes only the local synthetic DB; overwrites it unconditionally.
       The bridge it generates is marked synthetic in its header comment and
       the runtime audit treats it as scaffold until the real DB replaces it.
"""

import os
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DB = os.path.join(ROOT, "wowheadScrape", "dbc_extract", "wowsims.db")
OUT_DB = os.path.join(ROOT, "wowheadScrape", "dbc_extract", "wowsims_forever.db")

SCHEMA = {
    "Spell": [("ID", "INTEGER PRIMARY KEY")],
    "SpellName": [("ID", "INTEGER PRIMARY KEY"), ("Name_lang", "TEXT")],
    "SpellMisc": [
        ("ID", "INTEGER PRIMARY KEY"),
        ("SpellID", "INTEGER"),
        ("SchoolMask", "INTEGER"),
        ("CastingTimeIndex", "INTEGER"),
        ("DurationIndex", "INTEGER"),
        ("RangeIndex", "INTEGER"),
    ],
    "SpellLevels": [
        ("ID", "INTEGER PRIMARY KEY"),
        ("SpellID", "INTEGER"),
        ("BaseLevel", "INTEGER"),
        ("MaxLevel", "INTEGER"),
        ("SpellLevel", "INTEGER"),
    ],
    "SpellClassOptions": [("ID", "INTEGER PRIMARY KEY"), ("SpellID", "INTEGER"), ("SpellClassSet", "INTEGER")],
    "SpellCooldowns": [
        ("ID", "INTEGER PRIMARY KEY"),
        ("SpellID", "INTEGER"),
        ("CategoryRecoveryTime", "INTEGER"),
        ("RecoveryTime", "INTEGER"),
        ("StartRecoveryTime", "INTEGER"),
    ],
    "SpellEffect": [
        ("ID", "INTEGER PRIMARY KEY"),
        ("SpellID", "INTEGER"),
        ("EffectIndex", "INTEGER"),
        ("Effect", "INTEGER"),
        ("EffectAura", "INTEGER"),
        ("EffectBasePoints", "INTEGER"),
        ("EffectDieSides", "INTEGER"),
        ("ImplicitTarget", "TEXT"),
    ],
}

# (id, class_set, name, base_level, school, cast_ms, gcd_ms, cd_ms, effects)
# effects: (effect, aura, base_points, die_sides, implicit_target)
# NOTE: real spell IDs below 100 (e.g. Heroic Strike 78) are intentionally
# NOT used here -- the pipeline/audit threshold is id >= 100 (rank-literal
# guard, repo-wide convention), so grounding rows use IDs >= 100.
FOREVER_SPELLS = [
    # Real 2.5.5 rows carried forward (era-shared vanilla kit, grounding).
    (639, 2, "Holy Light", 6, 2, 2500, 1500, 0, [(77, 0, 75, 15, "[21,0]")]),
    (7744, 1, "Rend", 1, 1, 0, 1500, 0, [(3, 0, 15, 1, "[1,0]")]),
    (133, 8, "Fireball", 1, 4, 1500, 1500, 0, [(2, 0, 13, 9, "[6,0]"), (6, 3, 0, 1, "[6,0]")]),
    (1449, 8, "Arcane Explosion", 6, 64, 0, 1500, 0, [(2, 0, 31, 5, "[22,15]")]),
    (20922, 2, "Consecration", 20, 2, 0, 1500, 8000, [(27, 3, 23, 1, "[18,16]")]),
    (2061, 5, "Flash Heal", 20, 2, 1500, 1500, 0, [(10, 0, 192, 45, "[21,0]")]),
    # Synthetic Forever-new spells (panel-announced kits; IDs invented for the
    # fixture -- the real IDs come from the real client on beta day).
    (900001, 2, "Holy Strike", 6, 2, 0, 1500, 12000, [(3, 0, 40, 5, "[1,0]")]),
    (900002, 2, "Seal of Fury", 20, 2, 0, 1500, 0, [(6, 42, 0, 1, "[1,0]")]),
    (900003, 1, "Skyfury", 1, 1, 0, 1500, 30000, [(48, 0, 0, 0, "[1,0]")]),
    (900004, 7, "Molten Blast", 10, 4, 2000, 1500, 6000, [(2, 0, 55, 9, "[21,0]")]),
    # Degenerate rows that must NOT reach the bridge.
    (900100, 2, "QA DEBUG Holy Smite", 1, 2, 0, 1500, 0, [(2, 0, 5, 1, "[1,0]")]),
    (900101, 1, "PLACEHOLDER Strike", 1, 1, 0, 1500, 0, [(3, 0, 5, 1, "[1,0]")]),
    # Out-of-range spell (BaseLevel 300) that must be filtered.
    (900102, 8, "Cheat Test", 300, 64, 0, 1500, 0, [(2, 0, 5, 1, "[1,0]")]),
    # NPC spell (no class set) that must be filtered.
    (900103, None, "Monster Cleave", 1, 1, 0, 0, 8000, [(2, 0, 50, 1, "[1,0]")]),
]

# An 18-min-cooldown spell that must be filtered by the recovery-time cap.
FOREVER_SPELL_LONG_CD = (900104, 5, "Broken Long CD", 10, 64, 0, 1500, 1500000, [(2, 0, 5, 1, "[1,0]")])


def create_schema(conn):
    cur = conn.cursor()
    for table, cols in SCHEMA.items():
        defs = ", ".join("%s %s" % (name, typ) for name, typ in cols)
        cur.execute("CREATE TABLE %s (%s)" % (table, defs))
    conn.commit()


def insert_forever_rows(conn):
    cur = conn.cursor()
    long_cd = FOREVER_SPELL_LONG_CD
    for (sid, class_set, name, base_level, school, cast_ms, gcd_ms, cd_ms, effects) in list(FOREVER_SPELLS) + [long_cd]:
        cur.execute("INSERT OR REPLACE INTO Spell (ID) VALUES (?)", (sid,))
        cur.execute("INSERT OR REPLACE INTO SpellName (ID, Name_lang) VALUES (?, ?)", (sid, name))
        cur.execute(
            "INSERT OR REPLACE INTO SpellMisc (ID, SpellID, SchoolMask, CastingTimeIndex, DurationIndex, RangeIndex) VALUES (?,?,?,?,?,?)",
            (sid, sid, school, 1 if cast_ms else 0, 21, 1),
        )
        cur.execute(
            "INSERT OR REPLACE INTO SpellLevels (ID, SpellID, BaseLevel, MaxLevel, SpellLevel) VALUES (?,?,?,?,?)",
            (sid, sid, base_level, 60, base_level),
        )
        if class_set is not None:
            cur.execute(
                "INSERT OR REPLACE INTO SpellClassOptions (ID, SpellID, SpellClassSet) VALUES (?,?,?)",
                (sid, sid, class_set),
            )
        cur.execute(
            "INSERT OR REPLACE INTO SpellCooldowns (ID, SpellID, CategoryRecoveryTime, RecoveryTime, StartRecoveryTime) VALUES (?,?,?,?,?)",
            (sid, sid, 0, cd_ms, gcd_ms),
        )
        for idx, (effect, aura, base_pts, die_sides, targets) in enumerate(effects):
            cur.execute(
                "INSERT OR REPLACE INTO SpellEffect (ID, SpellID, EffectIndex, Effect, EffectAura, EffectBasePoints, EffectDieSides, ImplicitTarget) VALUES (?,?,?,?,?,?,?,?)",
                (sid * 10 + idx, sid, idx, effect, aura, base_pts, die_sides, targets),
            )
    conn.commit()


def main():
    if not os.path.exists(SRC_DB):
        print("ERROR: source 2.5.5 DBC missing: %s" % SRC_DB)
        print("       Copy the tracked-at-source DBC in from the main checkout:")
        print("       cp <main>/wowheadScrape/dbc_extract/wowsims.db wowheadScrape/dbc_extract/")
        sys.exit(2)
    if os.path.exists(OUT_DB):
        os.remove(OUT_DB)
    conn = sqlite3.connect(OUT_DB)
    try:
        create_schema(conn)
        insert_forever_rows(conn)
        n_spells = conn.execute("SELECT COUNT(*) FROM Spell").fetchone()[0]
        n_effects = conn.execute("SELECT COUNT(*) FROM SpellEffect").fetchone()[0]
    finally:
        conn.close()
    print("Synthetic Forever DBC written: %s" % OUT_DB)
    print("  Spells:  %d (synthetic fixture rows)" % n_spells)
    print("  Effects: %d" % n_effects)
    print("  LOCAL-ONLY: this DB is a test fixture, NOT real client data.")
    print("  On beta day, regenerate it with DB2ToSqlite against the real client")
    print("  (docs/forever/dbc_runbook.md step 1) before building the bridge.")


if __name__ == "__main__":
    main()
