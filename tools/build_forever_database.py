#!/usr/bin/env python3
"""build_forever_database.py -- WoW Forever community datamine package builder.

WHAT:  turns the beta-client DBC extraction (wowsims_forever.db) into a
        community-ready dataset under wowheadScrape/dbc_extract/
        forever_community/: an enriched SQLite database (forever_datamine.db),
        grep-friendly JSONL (spells.jsonl), lookup maps (by_name.json,
        talents.json, trainers.json). Full spell descriptions are first-class
        fields everywhere -- they are the most useful rotation-design input.
WHEN:  beta day 2026-09-17+; re-run after every beta build refresh.
WHY:   the DBC is the authoritative source of truth (AGENTS.md); this package
        is how the wider community -- humans and AI agents alike -- consumes
        it without re-running the extraction pipeline. See
        EaxRotations/docs/forever/datamine/README.md for the schema, usage
        recipes, and known data quirks.
SAFETY: read-only against the source DB; writes only inside
        forever_community/ (gitignored bulk-data area -- only this script and
        the README are tracked). Deterministic output (sorted keys/ids) so
        rebuilds diff cleanly. No third-party dependencies (stdlib only).

Usage:
    python tools/build_forever_database.py            # build the package
    python tools/build_forever_database.py --check    # verify a built package

Calibration: class family map, heal/aoe rules and degenerate-name tokens are
imported from tools/build_forever_bridge.py (single source -- do NOT fork
copies here). Rank numbers are positional conveniences computed per
(class, name) ordered by (level, id); see the README quirks section for the
cases where id order disagrees with level order (Holy Strike) or where one
name covers several roles (Arcane Blast aura vs nuke).
"""

import argparse
import datetime
import json
import os
import sqlite3
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_forever_bridge as bb

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DB = os.path.join(ROOT, "wowheadScrape", "dbc_extract", "wowsims_forever.db")
OUT_DIR = os.path.join(ROOT, "wowheadScrape", "dbc_extract", "forever_community")

OUT_DB = os.path.join(OUT_DIR, "forever_datamine.db")
OUT_JSONL = os.path.join(OUT_DIR, "spells.jsonl")
OUT_BY_NAME = os.path.join(OUT_DIR, "by_name.json")
OUT_TALENTS = os.path.join(OUT_DIR, "talents.json")
OUT_TRAINERS = os.path.join(OUT_DIR, "trainers.json")

# TalentTab.ClassMask / SkillLineAbility.ClassMask bit -> class (classic
# bitmask; verified against the extracted TalentTab rows, one tab per
# (class, tree)). Bit 32 (Death Knight) is absent on this client.
CLASS_BIT_MAP = {
    1: "Warrior", 2: "Paladin", 4: "Hunter", 8: "Rogue", 16: "Priest",
    64: "Shaman", 128: "Mage", 256: "Warlock", 1024: "Druid",
}

SCHOOL_BITS = {1: "physical", 2: "holy", 4: "fire", 8: "nature",
               16: "frost", 32: "shadow", 64: "arcane"}


def _school(mask):
    if mask in bb.SCHOOL_MAP:
        return bb.SCHOOL_MAP[mask]
    parts = [name for bit, name in sorted(SCHOOL_BITS.items()) if mask & bit]
    rest = mask
    for bit in SCHOOL_BITS:
        rest &= ~bit
    if rest:
        parts.append("mask%d" % rest)
    return "+".join(parts) if parts else "physical"


def _targets(raw):
    parts = str(raw or "[0,0]").strip("[]").split(",")
    def num(x):
        x = x.strip()
        return int(x) if x.lstrip("-").isdigit() else 0
    a = num(parts[0]) if parts else 0
    b = num(parts[1]) if len(parts) > 1 else 0
    return [a, b]


def _is_aoe(effect, a, b):
    return bool(effect in (27, 124) or (b >= 15 and a != 1)
                or b in bb.AREA_TARGETS)


def load(conn):
    """Read the raw extraction into plain structures."""
    conn.row_factory = sqlite3.Row
    spells = {}
    for r in conn.execute(
            "SELECT s.ID, sn.Name_lang, sm.SchoolMask, sm.CastingTimeIndex, "
            "sl.SpellLevel, sl.BaseLevel, sco.SpellClassSet, sc.RecoveryTime, "
            "sc.StartRecoveryTime, s.Description_lang, s.AuraDescription_lang, "
            "s.NameSubtext_lang "
            "FROM Spell s "
            "LEFT JOIN SpellName sn ON s.ID = sn.ID "
            "LEFT JOIN SpellMisc sm ON sm.SpellID = s.ID "
            "LEFT JOIN SpellLevels sl ON sl.SpellID = s.ID "
            "LEFT JOIN SpellClassOptions sco ON sco.SpellID = s.ID "
            "LEFT JOIN SpellCooldowns sc ON sc.SpellID = s.ID "
            "WHERE s.ID >= 100 AND sn.Name_lang IS NOT NULL AND sn.Name_lang != ''"):
        d = dict(r)
        if bb._degenerate(d["Name_lang"]):
            continue
        spells[d["ID"]] = d
    effects = {}
    for r in conn.execute(
            "SELECT SpellID, EffectIndex, Effect, EffectAura, EffectBasePointsF, "
            "EffectMiscValue, ImplicitTarget, EffectTriggerSpell, "
            "EffectRadiusIndex, Coefficient FROM SpellEffect"):
        effects.setdefault(r["SpellID"], []).append(dict(r))
    talents = [dict(r) for r in conn.execute("SELECT * FROM Talent")]
    tabs = [dict(r) for r in conn.execute("SELECT * FROM TalentTab")]
    skills = [dict(r) for r in conn.execute("SELECT * FROM SkillLine")]
    sla = [dict(r) for r in conn.execute("SELECT * FROM SkillLineAbility")]
    races = [dict(r) for r in conn.execute("SELECT * FROM ChrRaces")]
    procs = [dict(r) for r in conn.execute("SELECT * FROM SpellAuraOptions")]
    # Name/description lookup spans the WHOLE client SpellName table, not just
    # the filtered `spells` dict: trainers and talents reference sub-100 ids
    # (e.g. Block 107, skill ranks) that the rank-literal guard excludes.
    all_names, all_descs = {}, {}
    for r in conn.execute(
            "SELECT sn.ID, sn.Name_lang, s.Description_lang FROM SpellName sn "
            "LEFT JOIN Spell s ON s.ID = sn.ID"):
        if r["Name_lang"]:
            all_names[r["ID"]] = r["Name_lang"]
            all_descs[r["ID"]] = r["Description_lang"] or ""
    return spells, effects, talents, tabs, skills, sla, races, procs, \
        all_names, all_descs


def build(spells, effects, talents, tabs, skills, sla, races, procs,
          all_names, all_descs):
    """Shape the community dataset (JSON-serializable)."""
    tab_by_id = {t["ID"]: t for t in tabs}
    skill_by_id = {s["ID"]: s for s in skills}
    name_by_spell, desc_by_spell = all_names, all_descs

    def class_of(class_set):
        return bb.CLASS_MAP.get(class_set)

    def level_of(s):
        bl, sl = s["BaseLevel"], s["SpellLevel"]
        if isinstance(bl, int) and bl > 0:
            return bl
        if isinstance(sl, int) and sl > 0:
            return sl
        return None

    # Positional ranks per (class-or-'', name), ordered by (level, id).
    # Documented convenience, not client truth (see README quirks).
    order = sorted(spells.values(),
                   key=lambda s: (s["Name_lang"] or "",
                                  class_of(s["SpellClassSet"]) or "",
                                  level_of(s) if level_of(s) else 9999,
                                  s["ID"]))
    rank_of = {}
    last_key, n = None, 0
    for s in order:
        key = ((class_of(s["SpellClassSet"]) or ""), s["Name_lang"])
        n = n + 1 if key == last_key else 1
        last_key = key
        rank_of[s["ID"]] = n

    out_spells = {}
    for sid, s in spells.items():
        cls = class_of(s["SpellClassSet"])
        lvl = level_of(s)
        effs = []
        is_heal = aoe = False
        for e in effects.get(sid, []):
            a, b = _targets(e["ImplicitTarget"])
            effs.append({
                "idx": e["EffectIndex"], "effect": e["Effect"],
                "aura": e["EffectAura"], "base": e["EffectBasePointsF"],
                "misc": e["EffectMiscValue"], "targets": [a, b],
                "trigger": e["EffectTriggerSpell"],
                "radius": e["EffectRadiusIndex"],
                "coefficient": e["Coefficient"],
            })
            if e["Effect"] in bb.HEAL_EFFECTS:
                is_heal = True
            if _is_aoe(e["Effect"], a, b):
                aoe = True
        rec, grec = s["RecoveryTime"], s["StartRecoveryTime"]
        out_spells[sid] = {
            "id": sid, "name": s["Name_lang"],
            "subtext": s["NameSubtext_lang"] or "",
            "class": cls, "class_set": s["SpellClassSet"],
            "level": lvl, "rank": rank_of[sid],
            "school": _school(s["SchoolMask"] or 1),
            "school_mask": s["SchoolMask"],
            "cast_idx": s["CastingTimeIndex"],
            "gcd_s": round(grec / 1000, 2) if isinstance(grec, (int, float)) else None,
            "cooldown_s": round(rec / 1000, 2) if isinstance(rec, (int, float)) else None,
            "description": s["Description_lang"] or "",
            "aura_description": s["AuraDescription_lang"] or "",
            "is_heal": is_heal, "aoe": aoe,
            "effects": effs,
        }

    by_name = {}
    for sid in sorted(out_spells):
        by_name.setdefault(out_spells[sid]["name"], []).append(sid)

    out_tabs = []
    for t in sorted(tabs, key=lambda t: (t["ID"])):
        cls = CLASS_BIT_MAP.get(t["ClassMask"], "?bit%d" % (t["ClassMask"] or 0))
        t_talents = []
        for tal in sorted(
                [x for x in talents if x["TabID"] == t["ID"]],
                key=lambda x: (x["TierID"], x["ColumnIndex"])):
            ranks = []
            for rsid in str(tal["SpellRank"]).strip("[]").split(","):
                rsid = rsid.strip()
                if rsid and rsid != "0" and rsid.isdigit():
                    rid = int(rsid)
                    ranks.append({
                        "id": rid,
                        "name": name_by_spell.get(rid, ""),
                        "description": desc_by_spell.get(rid, ""),
                    })
            t_talents.append({
                "tier": tal["TierID"], "column": tal["ColumnIndex"],
                "spell_ranks": ranks,
                "prereq": str(tal["PrereqTalent"]),
            })
        out_tabs.append({
            "id": t["ID"], "tab": t["Name_lang"], "class": cls,
            "order": t["OrderIndex"], "talents": t_talents,
        })

    trainers = {}
    for row in sla:
        cm = row["ClassMask"] or 0
        if cm == 0:
            continue  # professions/riding/languages: not class spells
        sk = skill_by_id.get(row["SkillLine"], {})
        entry = {
            "id": row["Spell"], "name": name_by_spell.get(row["Spell"], ""),
            "level": row["MinSkillLineRank"],
            "skill": sk.get("DisplayName_lang", ""),
            "skill_id": row["SkillLine"],
            "method": row["AcquireMethod"],
            "races": row["RaceMasks"],
            "supercedes": row["SupercedesSpell"],
        }
        for bit, cls in sorted(CLASS_BIT_MAP.items()):
            if cm & bit:
                trainers.setdefault(cls, []).append(entry)
    for cls in trainers:
        trainers[cls].sort(key=lambda e: ((e["level"] if isinstance(e["level"], int) else 9999), e["id"]))

    out_races = [{
        "id": r["ID"], "name": r["Name_lang"], "alliance": r["Alliance"],
        "starting_level": r["StartingLevel"], "faction": r["FactionID"],
        "playable_bit": r["PlayableRaceBit"],
        "playable": (r["PlayableRaceBit"] or -1) >= 0,
    } for r in sorted(races, key=lambda r: r["ID"])]

    out_procs = []
    for p in procs:
        out_procs.append({
            "spell": p["SpellID"],
            "name": name_by_spell.get(p["SpellID"], ""),
            "chance": p["ProcChance"], "charges": p["ProcCharges"],
            "type_mask": p["ProcTypeMask"], "ppm": p["SpellProcsPerMinuteID"],
        })
    out_procs.sort(key=lambda p: (p["spell"] if isinstance(p["spell"], int) else 0))

    return {
        "spells": out_spells, "by_name": by_name, "tabs": out_tabs,
        "trainers": trainers, "races": out_races, "procs": out_procs,
    }


def write_package(data, stamp):
    os.makedirs(OUT_DIR, exist_ok=True)
    spells = data["spells"]

    conn = sqlite3.connect(OUT_DB)
    try:
        conn.execute("DROP VIEW IF EXISTS player_spells");
        conn.execute("DROP VIEW IF EXISTS heals");
        conn.execute("DROP TABLE IF EXISTS spells");
        conn.execute("DROP TABLE IF EXISTS spell_effects");
        conn.execute("DROP TABLE IF EXISTS spell_ranks");
        conn.execute("DROP TABLE IF EXISTS talents");
        conn.execute("DROP TABLE IF EXISTS talent_tabs");
        conn.execute("DROP TABLE IF EXISTS trainer_spells");
        conn.execute("DROP TABLE IF EXISTS races");
        conn.execute("DROP TABLE IF EXISTS procs");
        conn.execute("DROP TABLE IF EXISTS meta");
        conn.execute("""CREATE TABLE spells(
            id INTEGER PRIMARY KEY, name TEXT, subtext TEXT, class TEXT,
            class_set INTEGER, level INTEGER, school TEXT, school_mask INTEGER,
            cast_idx INTEGER, gcd_s REAL, cooldown_s REAL, description TEXT,
            aura_description TEXT, is_heal INTEGER, aoe INTEGER)""")
        conn.execute("""CREATE TABLE spell_effects(
            spell_id INTEGER, idx INTEGER, effect INTEGER, aura INTEGER,
            base_points REAL, misc TEXT, targets TEXT, trigger_spell INTEGER,
            radius TEXT, coefficient REAL)""")
        conn.execute("""CREATE TABLE spell_ranks(
            spell_id INTEGER PRIMARY KEY, name TEXT, class TEXT,
            rank_no INTEGER, level INTEGER)""")
        conn.execute("""CREATE TABLE talents(
            id INTEGER PRIMARY KEY, tab_id INTEGER, tab TEXT, class TEXT,
            tier INTEGER, column_no INTEGER, spell_rank_ids TEXT, prereq TEXT)""")
        conn.execute("""CREATE TABLE talent_tabs(
            id INTEGER PRIMARY KEY, tab TEXT, class TEXT, order_no INTEGER)""")
        conn.execute("""CREATE TABLE trainer_spells(
            spell_id INTEGER, name TEXT, class TEXT, level INTEGER,
            skill TEXT, skill_id INTEGER, method INTEGER, races TEXT,
            supercedes INTEGER)""")
        conn.execute("""CREATE TABLE races(
            id INTEGER PRIMARY KEY, name TEXT, alliance INTEGER,
            starting_level INTEGER, faction INTEGER, playable_bit INTEGER,
            playable INTEGER)""")
        conn.execute("""CREATE TABLE procs(
            spell_id INTEGER, name TEXT, chance INTEGER, charges INTEGER,
            type_mask INTEGER, ppm INTEGER)""")
        conn.execute("CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT)")
        for sid in sorted(spells):
            s = spells[sid]
            conn.execute(
                "INSERT INTO spells VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (s["id"], s["name"], s["subtext"], s["class"], s["class_set"],
                 s["level"], s["school"], s["school_mask"], s["cast_idx"],
                 s["gcd_s"], s["cooldown_s"], s["description"],
                 s["aura_description"], int(s["is_heal"]), int(s["aoe"])))
            for e in s["effects"]:
                conn.execute(
                    "INSERT INTO spell_effects VALUES (?,?,?,?,?,?,?,?,?,?)",
                    (sid, e["idx"], e["effect"], e["aura"], e["base"],
                     str(e["misc"]), str(e["targets"]), e["trigger"],
                     str(e["radius"]), e["coefficient"]))
            conn.execute("INSERT INTO spell_ranks VALUES (?,?,?,?,?)",
                         (sid, s["name"], s["class"], s["rank"], s["level"]))
        for t in data["tabs"]:
            conn.execute("INSERT INTO talent_tabs VALUES (?,?,?,?)",
                         (t["id"], t["tab"], t["class"], t["order"]))
            for tal in t["talents"]:
                conn.execute(
                    "INSERT INTO talents VALUES (?,?,?,?,?,?,?,?)",
                    (None, t["id"], t["tab"], t["class"], tal["tier"],
                     tal["column"],
                     ",".join(str(r["id"]) for r in tal["spell_ranks"]),
                     tal["prereq"]))
        for cls, rows in data["trainers"].items():
            for e in rows:
                conn.execute(
                    "INSERT INTO trainer_spells VALUES (?,?,?,?,?,?,?,?,?)",
                    (e["id"], e["name"], cls, e["level"], e["skill"],
                     e["skill_id"], e["method"], str(e["races"]),
                     e["supercedes"]))
        for r in data["races"]:
            conn.execute("INSERT INTO races VALUES (?,?,?,?,?,?,?)",
                         (r["id"], r["name"], r["alliance"],
                          r["starting_level"], r["faction"],
                          r["playable_bit"], int(r["playable"])))
        for p in data["procs"]:
            conn.execute("INSERT INTO procs VALUES (?,?,?,?,?,?)",
                         (p["spell"], p["name"], p["chance"], p["charges"],
                          p["type_mask"], p["ppm"]))
        for k, v in stamp.items():
            conn.execute("INSERT INTO meta VALUES (?,?)", (k, str(v)))
        conn.execute("""CREATE VIEW player_spells AS
            SELECT * FROM spells WHERE class IS NOT NULL""")
        conn.execute("""CREATE VIEW heals AS
            SELECT * FROM spells WHERE is_heal = 1 AND class IS NOT NULL""")
        conn.commit()
    finally:
        conn.close()

    with open(OUT_JSONL, "w", encoding="utf-8") as f:
        for sid in sorted(spells):
            f.write(json.dumps(spells[sid], ensure_ascii=False) + "\n")
    with open(OUT_BY_NAME, "w", encoding="utf-8") as f:
        json.dump(data["by_name"], f, ensure_ascii=False, indent=1,
                  sort_keys=True)
    with open(OUT_TALENTS, "w", encoding="utf-8") as f:
        json.dump(data["tabs"], f, ensure_ascii=False, indent=1)
    with open(OUT_TRAINERS, "w", encoding="utf-8") as f:
        json.dump(data["trainers"], f, ensure_ascii=False, indent=1,
                  sort_keys=True)
    return {
        "db": OUT_DB, "jsonl": OUT_JSONL, "by_name": OUT_BY_NAME,
        "talents": OUT_TALENTS, "trainers": OUT_TRAINERS,
    }


def check_package():
    """Verify a built package (exit codes mirror build_forever_bridge)."""
    missing = [p for p in (OUT_DB, OUT_JSONL, OUT_BY_NAME, OUT_TALENTS,
                           OUT_TRAINERS) if not os.path.exists(p)]
    if missing:
        print("FAIL: package files missing: %s" % missing)
        return 2
    conn = sqlite3.connect(OUT_DB)
    try:
        n = conn.execute("SELECT COUNT(*) FROM spells").fetchone()[0]
        players = conn.execute(
            "SELECT COUNT(*) FROM player_spells").fetchone()[0]
        ntabs = conn.execute("SELECT COUNT(*) FROM talent_tabs").fetchone()[0]
        ntal = conn.execute("SELECT COUNT(*) FROM talents").fetchone()[0]
        meta = dict(conn.execute("SELECT k, v FROM meta").fetchall())
    finally:
        conn.close()
    lines = sum(1 for _ in open(OUT_JSONL, encoding="utf-8"))
    problems = []
    if n < 20000:
        problems.append("spells table only %d rows" % n)
    if players < 1000:
        problems.append("player_spells view only %d rows" % players)
    if ntabs != 27:
        problems.append("talent_tabs has %d rows (expected 27)" % ntabs)
    if ntal == 0:
        problems.append("talents table is empty")
    if lines != n:
        problems.append("spells.jsonl lines %d != spells rows %d" % (lines, n))
    for spot in ("Holy Strike", "Seal of Fury", "Touch of the Grave",
                 "Maelstrom Weapon", "Hot Streak", "Arcane Blast",
                 "Missile Barrage", "Lava Burst", "Fire Nova"):
        with open(OUT_BY_NAME, encoding="utf-8") as f:
            by_name = json.load(f)
        if spot not in by_name:
            problems.append("by_name.json missing %r" % spot)
            break
    if not meta.get("client_build"):
        problems.append("meta table lacks client_build")
    if problems:
        for p in problems:
            print("FAIL:", p)
        return 1
    print("OK: Forever datamine package verified "
          "(%d spells, %d player spells, %d talents; client %s)" % (
              n, players, ntal, meta.get("client_version", "?")))
    return 0


def main():
    parser = argparse.ArgumentParser(description="Forever DBC -> community datamine package")
    parser.add_argument("--check", action="store_true",
                        help="verify the built package")
    args = parser.parse_args()
    if args.check:
        sys.exit(check_package())
    if not os.path.exists(SRC_DB):
        print("ERROR: Forever DBC not found: %s" % SRC_DB)
        print("       Run DB2ToSqlite on the Forever beta client first")
        print("       (docs/forever/dbc_runbook.md step 1).")
        sys.exit(2)
    stamp = {
        "client_version": "1.60.1.69893",
        "client_build": "69893",
        "client_product": "wow_classic_beta",
        "extracted_at_utc": datetime.datetime.now(
            datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        "generator": "tools/build_forever_database.py",
        "source_db": os.path.basename(SRC_DB),
    }
    conn = sqlite3.connect(SRC_DB)
    try:
        (spells, effects, talents, tabs, skills, sla, races, procs,
         all_names, all_descs) = load(conn)
    finally:
        conn.close()
    data = build(spells, effects, talents, tabs, skills, sla, races, procs,
                 all_names, all_descs)
    paths = write_package(data, stamp)
    print("Forever datamine: %d spells (%d player), %d talents, %d races" % (
        len(data["spells"]),
        sum(1 for s in data["spells"].values() if s["class"]),
        sum(len(t["talents"]) for t in data["tabs"]),
        len(data["races"])))
    for label, path in sorted(paths.items()):
        size = os.path.getsize(path)
        print("  %-8s %s (%s bytes)" % (label, path, format(size, ",")))
    print("Community package ready -- see EaxRotations/docs/forever/datamine/README.md.")


if __name__ == "__main__":
    main()
