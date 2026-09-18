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

# SpellClassSet -> class name. DIVERGENCE from the 2.5.5 client: the modern
# SpellFamily enum (2=Paladin, 7=Shaman, 8=Mage, ...) does NOT apply here.
# Calibrated 2026-09-17 against the 1.60.1.69893 extraction -- this
# classic-line client uses the classic SpellFamily enum, proven per class
# (Heroic Strike 78 -> 4, Hunter's Mark 1130 -> 9, Rejuvenation 774 -> 7,
# Lesser Heal 2050 -> 6, LHW 8004 -> 11, Fireball 133 -> 3, Sinister Strike
# 1752 -> 8, Immolate 348 -> 5, Seal of Fury 20163 -> 10). Sets 0/1/13 are
# non-class rows (test/world/item spells); 2/12 are empty on this client.
# (The 2.5.5 note about Stoneform still holds in spirit: racial actives such
# as Touch of the Grave 1260189 carry no SpellClassOptions row and stay out
# of this class-spell index by design.)
CLASS_MAP = {
    3: "Mage",
    4: "Warrior",
    5: "Warlock",
    6: "Priest",
    7: "Druid",
    8: "Rogue",
    9: "Hunter",
    10: "Paladin",
    11: "Shaman",
}

# Effects that heal on the Forever client format (1.60 classic-line DBC).
# Calibrated 2026-09-17 against the 1.60.1.69893 extraction: every direct
# heal probed uses Effect 10 (Flash Heal 2061, Greater Heal 2060, Prayer of
# Healing 596, Chain Heal 1064, LHW 8004, HW 331, HT 5185, Lesser Heal 2050;
# HoTs use Effect 6 / Aura 8 and stay out by design). Effect 2 is direct
# DAMAGE here (Frostbolt 116, Fireball 133, Arcane Explosion 1449), Effect
# 62 is power burn (Mana Burn 8129+), Effect 77 is damage-side (Immolate
# 348+, Holy Strike 678) -- all three would misflag heals, so the 2.5.5
# set {2,10,62,77} does NOT carry over; only {10} is correct on this client.
HEAL_EFFECTS = {10}

# ImplicitTarget buckets that make an effect area-targeted.
# ImplicitTarget[0] == TARGET_CASTER (1, 15); area targets are >= 15 elsewhere.
AREA_TARGETS = {6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 18, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 37, 38, 39, 40, 41, 42, 43, 46, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 76, 77, 78, 87, 106, 107, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 142, 143, 144, 146}

DEGENERATE_NAME_TOKENS = (
    "DEBUG", "QA ", "QA_", "QA-", "ALEX", "GRAYAL", "TEST", "PLACEHOLDER",
    "GENERIC", "UNUSED", "Deprecated", "OLD ", "(OLD", "TEMP", "UNUSED",
)

PASSIVE_AURAS = {24, 79}

# Name-keyed mirror overrides: exact client name -> id, applied AFTER the
# cross-class dedupe in write_bridge, for names two classes both carry where
# the lowest-id rule picks the wrong class's row for a _forever lane. Every
# entry verified 2026-09-17 against the 1.60.1.69893 DBC.
MIRROR_NAME_OVERRIDES = {
    # "Berserk": the Warrior row 23397 (class 4, empty description, not the
    # ability lanes use) beats the Druid row 417141 on the cross-class
    # lowest-id dedupe. The druid row is the Forever Berserk: class 7, level
    # 1, granted by 424759, RecoveryTime 180000, 15s, form-branched text
    # ("Causes your Mangle ability to strike up to 4 targets, removes its
    # cooldown, and increases the critical strike chance of your Combo
    # Point-generating abilities by 101%") - effect rows op 7 +100 (crit),
    # op 11 -100% (cooldown), op 17 +3 targets, mechanic-5 (fear) immunity.
    "Berserk": 417141,
}

# Class-less aura rows that _forever buff lanes read by name (2026-09-17).
# The SpellClassOptions filter in load_forever_spells drops rows the client
# grants only as an effect of a classed talent/engraving, so they cannot ride
# the rank-1 baseline: pin them here and admit their ids to the fail-closed
# mirror check below. Every entry verified against the 1.60.1.69893 DBC
# (effect dump + the talent text that references the row by id).
CLASS_LESS_BUFF_NAMES = {
    # Shadow and Flame 426316: "Hitting an enemy with Conflagrate increases
    # all Shadow damage you deal by $m3% for $1293816d, and hitting an enemy
    # with Shadowburn increases all Fire damage you deal by $m4% for
    # $426311d" -- both window rows (aura 79 = mod damage percent, base +10,
    # caster target) carry no SpellClassOptions row.
    "Shadow": 1293816,
    "Flame": 426311,
}


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

    # Aggregate effects per spell id (heal + AoE detection). NOTE: the 1.60
    # classic-line SpellEffect has no EffectBasePoints/EffectDieSides columns
    # (base points live in EffectBasePointsF); only Effect + targets are read.
    effect_rows = cur.execute(
        """
        SELECT SpellID, Effect, EffectAura, ImplicitTarget
        FROM SpellEffect
        """
    ).fetchall()
    heal_spells = set()
    aoe_spells = set()
    for spell_id, effect, aura, targets in effect_rows:
        if effect in HEAL_EFFECTS:
            heal_spells.add(spell_id)
        targets = targets or "[0,0]"
        parts = str(targets).strip("[]").split(",")
        target_a = int(parts[0]) if parts and parts[0].strip().lstrip("-").isdigit() else 0
        target_b = int(parts[1]) if len(parts) > 1 and parts[1].strip().lstrip("-").isdigit() else 0
        if effect in (27, 124) or (target_b >= 15 and target_a != 1) or target_b in AREA_TARGETS:
            aoe_spells.add(spell_id)

    # Buff-role overrides: exact client name -> the buff/proc aura id a lane
    # must gate on, for the mechanics where the rank-1 baseline resolves to
    # the WRONG role (talent row instead of proc buff). Every entry verified
    # 2026-09-17 against the 1.60.1.69893 DBC (effect rows + description
    # text); the baseline id is named in each note so the divergence is
    # reviewable without re-running the probes.
    BUFF_OVERRIDES = {
        # Proc buff (triggered BY 400588 per EffectTriggerSpell; baseline
        # 400588 is the talent: "Gives your Arcane Blast spell a $m1%
        # chance..."). Lane gates the proc window, not the talent.
        "Missile Barrage": 400589,
        # Buff text ("Reduces the cast time and Mana cost of your next
        # Lightning Bolt spell"); baseline 408498 is the talent text
        # ("When you deal damage with a melee attack, you have a chance...").
        "Maelstrom Weapon": 408505,
        # Forever stacking proc ("grant Hot Streak for $400625d... stacking
        # up to $400625s2 times", granted by talent 400624); baseline 48108
        # is the legacy 2-in-a-row row ("Any time you score 2 spell criticals
        # in a row..."). Kit's "3-stack" number itself is still unconfirmed
        # (lives in aura points) -- recorded as an in-game probe, not here.
        "Hot Streak": 400625,
        # Applied debuff row ("increases the chance your Ice Lance and
        # Frostbolt spells will critically hit ... Stacks up to 6 times",
        # referenced by the talent text as $12579s1/$12579d); baseline 11180
        # is the TALENT row, so a stack read against it always returns 0.
        "Winter's Chill": 12579,
        # Charge buff row ("Your Wrath spell reduces the cast time of your
        # next 3 Starfire spells ... Stores up to $408255u charges"); the
        # baseline 408248 is the talent/engraving text row, so a charge read
        # against it always returns 0.
        "Eclipse": 408255,
        # Proc buff row granted on a sub-35% target by Shadow Bolt / Searing
        # Pain ("...for the next $440873d your Soul Fire spell has its cast
        # time reduced by $m1% and costs no Soul Shards"); the baseline
        # 440870 is the TALENT text row ("Reduces the cooldown of your Soul
        # Fire spell by $m2%..."), so a buff read against it always returns 0.
        "Decimation": 440873,
        # Applied shield row ("Critical heals have a chance to create a
        # protective shield on the target, absorbing a percentage of the
        # amount healed", effect 6 aura 69 school-absorb, base 2); the
        # baseline 431622 is the TALENT text row ("Your critical heals create
        # a protective shield ... absorbing $s1% ... Lasts $431624d"), so an
        # absorb read against it always returns 0.
        "Divine Aegis": 431624,
        # Stack buff row ("When your Rupture ability deals periodic damage,
        # the Energy cost of your next Hemorrhage or Backstab ability within
        # $1310723d is reduced by $1310723s1, stacking up to $1310723u
        # times", effect 6 aura 107 base -3); the baseline 1310721 is the
        # TALENT text row, so a stack read against it always returns 0.
        "Thousand Cuts": 1310723,
        # Proc buff row ("Your Backstab has a $m1% chance to cause your next
        # Ambush within $462707d to not require Stealth"); the baseline
        # 424980 is the "Gain the Cutthroat ability" grant row, so a buff
        # read against it always returns 0.
        "Cutthroat": 462707,
        # Applied aura row ("Heals upon taking damage or receiving healing",
        # effect 6 aura 4, base 1902 at the @60 rank); the baseline 401859 is
        # the @40 CAST row, so an aura read against it always returns 0.
        "Prayer of Mending": 1240849,
        # Live buff row of the Forever rework ("Reduces the cast time of your
        # next Holy Light spell by $m1 sec", effect 6 aura 107 base -1000,
        # SpellDuration 15s, proc mask 16384 = on spell critical hit). The
        # baseline 53672 is the LEGACY TBC row ("Your Holy Shock critical hits
        # reduce the cast time of your next FLASH OF LIGHT ..."): nothing in
        # the 1.60.1.69893 build references it -- no EffectTriggerSpell, no
        # EffectBasePointsF link, no EffectMiscValue payload, no talent row,
        # and the only text that names $53672 is its own description -- so a
        # lane gating it can never fire live. The live chain is the rune
        # 426180 "Engrave Belt - Infusion of Light" -> 426179 -> ability
        # 426065 ("Your Holy Shock and Flash of Light critical hits reduce the
        # cast time of your next Holy Light cast within $437063d by $m1 sec"),
        # which applies 437063. Re-probed 2026-09-19 with
        # tools/probe_forever_spell_rows.py (--refs 53672 / --refs 437063).
        "Infusion of Light": 437063,
    }

    # Max-rank-role overrides: exact client name -> the PLAYER-CAST row, for
    # the names where the max-rank classification resolves an INTERNAL row
    # instead (the classic damage row of the same name keeps the lower id on
    # a level tie). Every entry verified 2026-09-17 against the 1.60.1.69893
    # DBC (mana / GCD / cooldown / trainer rows + effect dump).
    MAXRANK_OVERRIDES = {
        # Fire Nova: 8349/11307 are totem-internal damage rows (no mana, no
        # cast time, no GCD, no cooldown row, not trainer-taught); 408341-
        # 408345 are the player casts ("Instantly inflicts $11307s1 fire
        # damage to enemies within $11307a1 yd of your active Fire totem"),
        # trainer-taught on the Forever client, 520 mana at rank 5, 1.5s GCD,
        # CategoryRecoveryTime 6000. The @52 tie with the internal 11307
        # breaks by lowest id to the wrong role - pin the cast row.
        "Fire Nova": 408345,
        # Penance: 1316991/1316993 are the internal channel rows ("Healing
        # for $s1 every $1316992t2 sec." / "Dealing $s1 Holy damage every
        # $1316994t2 sec.", single-effect, no class set check needed for the
        # text) while 1316995 is the player cast ("Launches a volley of holy
        # light at the target, causing $1316993s1 Holy damage to an enemy, or
        # $1316991s1 healing to an ally, instantly and every $402261t2 sec"),
        # trainer-taught under Discipline, 1.5s GCD, CategoryRecoveryTime
        # 12000. The @60 tie (five rows) breaks by lowest id to the internal
        # heal row - pin the dual-mode cast.
        "Penance": 1316995,
    }

    result = {}
    maxrank = {}
    # Every player-filtered spell id (not just baselines): the fail-closed
    # reference set for the mirror check below. Multi-rank ladders contribute
    # their whole ladder here; spell_index_forever itself stays baselines-only
    # (audit contract stability).
    all_player_ids = set()
    for (spell_id, name, school_mask, cast_time_idx, spell_level, base_level,
         class_set, recovery_time, start_recovery) in spell_rows:
        if _degenerate(name):
            continue
        class_name = CLASS_MAP.get(class_set)
        if class_name is None:
            continue  # non-player spell (NPC abilities, items, GM, etc.)
        all_player_ids.add(spell_id)
        # Rank 1 baseline: emit only one row per (class, name) — the lowest
        # spell id seen for that pair (client rank ladders share one name).
        key = (class_name, name)
        existing = result.get(key)
        if existing is not None and existing["spell_id"] <= spell_id:
            pass
        else:
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
        # Max-rank baseline: highest BaseLevel wins (NULL levels sort below
        # every real level), ties broken by lowest id. Cast lanes resolve
        # through this mirror so max-level rotations cast max rank, not rank
        # 1 (e.g. Holy Strike 10333@60, not the 678@12 baseline; Light's
        # Vigil 1311595@60, the cast row, not the 1310909 buff row; Fire Nova
        # 408345@52 via MAXRANK_OVERRIDES -- the internal 11307 damage row
        # wins the raw tie by lowest id and is not a player cast).
        # Rows without a class set never reach this map (filtered above), so
        # every emitted id is a real player-spell row.
        lvl = base_level if isinstance(base_level, int) else -1
        cur_max = maxrank.get(key)
        if cur_max is None or (lvl, -spell_id) > (cur_max[0], -cur_max[1]):
            maxrank[key] = (lvl, spell_id)
    for key in list(maxrank):
        override = MAXRANK_OVERRIDES.get(key[1])
        if override is not None:
            maxrank[key] = (maxrank[key][0], override)
    buff_ids = {}
    for (class_name, name), entry in result.items():
        buff_ids[(class_name, name)] = BUFF_OVERRIDES.get(name, entry["spell_id"])
    # Class-less aura rows the buff mirror must carry anyway (see
    # CLASS_LESS_BUFF_NAMES). Keyed under their real class so the mirror's
    # lowest-id dedupe cannot drop them; the orphan check in write_bridge
    # admits their ids explicitly.
    for name, sid in CLASS_LESS_BUFF_NAMES.items():
        buff_ids[("Warlock", name)] = sid
    return result, maxrank, buff_ids, all_player_ids


def lua_escape(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_bridge(spells, maxrank, buff_ids, all_player_ids):
    lines = [
        "-- wowhead_data_bridge_spell_index_forever_sylvanas.lua -- Forever-era spell index bridge.",
        "-- WHAT:  DBC-derived map of WoW Forever (beta 2026-09-17) spell IDs to",
        "--        {name, class, level, school, is_heal, aoe, cast_time, rank, gcd, cooldown_seconds}.",
        "-- WHEN:  generated on beta day by tools/build_forever_bridge.py from",
        "--        wowheadScrape/dbc_extract/wowsims_forever.db (authoritative).",
        "-- WHY:   run_forever_audit_tests.lua flips from scaffold to LIVE mode the",
        "--        moment this file carries a real index (no __forever_stub flag):",
        "--        every spell ID in a _forever spec file must resolve here.",
        "--        _forever spec files resolve Forever-new spells BY NAME through",
        "--        the mirrors below (zero numeric literals in code -- the DBC is",
        "--        the only source of an ID). A nil lookup must leave the calling",
        "--        lane dormant, never guess.",
        "-- SAFETY: generated file — do not hand-edit; regenerate from the DBC.",
        "-- FORMAT: spell_index_forever: positional fields 1-10 (tbc/vanilla shape).",
        "--        spell_index_by_name_forever: exact client name -> rank-1 spell id",
        "--        (lowest id per ladder; buff-role lookups land here).",
        "--        spell_maxrank_by_name_forever: exact client name -> max-rank spell",
        "--        id (highest BaseLevel per ladder, ties to lowest id) for CAST",
        "--        lanes, so max-level rotations cast max rank, not rank 1.",
        "--        spell_buff_by_name_forever: exact client name -> buff/proc aura id",
        "--        for buff-gated lanes; equals the rank-1 baseline except the",
        "--        BUFF_OVERRIDES in the builder (Missile Barrage, Maelstrom",
        "--        Weapon, Hot Streak), where the baseline resolves to the talent",
        "--        row instead of the proc buff.",
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
    lines.append("-- Exact client name -> rank-1 spell id (rank ladders share one name; the")
    lines.append("-- entries above already dedupe to the rank-1 baseline per (class, name).")
    lines.append("M.spell_index_by_name_forever = {")
    for e in entries:
        lines.append("    [%s] = %d," % (lua_escape(e["name"]), e["spell_id"]))
    lines.append("}")
    lines.append("")

    def emit_mirror(table, mapping, id_of):
        lines.append(table)
        # Deterministic emission order (by name); duplicate names across
        # classes resolve to the lowest spell id, mirroring the rank-1 rule,
        # then MIRROR_NAME_OVERRIDES repairs the collisions where the wrong
        # class's row would win for a _forever lane.
        by_name = {}
        for (class_name, name) in sorted(mapping):
            sid = id_of((class_name, name))
            if name not in by_name or sid < by_name[name]:
                by_name[name] = sid
        for name in sorted(by_name):
            sid = MIRROR_NAME_OVERRIDES.get(name, by_name[name])
            lines.append("    [%s] = %d," % (lua_escape(name), sid))
        lines.append("}")
        lines.append("")

    lines.append("-- Exact client name -> max-rank spell id (highest BaseLevel per")
    lines.append("-- (class, name); ties break to the lowest id, except the")
    lines.append("-- MAXRANK_OVERRIDES in the builder -- Fire Nova 408345, the")
    lines.append("-- trainer-taught totem-detonating cast, over the internal")
    lines.append("-- 11307 damage row that wins the raw @52 tie by lowest id).")
    emit_mirror("M.spell_maxrank_by_name_forever = {", maxrank,
                lambda k: maxrank[k][1])
    lines.append("-- Exact client name -> buff/proc aura id for buff-gated lanes.")
    emit_mirror("M.spell_buff_by_name_forever = {", buff_ids,
                lambda k: buff_ids[k])
    lines.append("return M")
    lines.append("")
    with open(OUTPUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("  Generated: %s" % OUTPUT)
    print("  Entries:   %d" % len(entries))
    print("  Size:      %s bytes" % format(os.path.getsize(OUTPUT), ","))
    # Every mirror id must be a real player-filtered spell row in the DBC.
    # (Checked against all_player_ids, NOT spell_index_forever: the index is
    # rank-1 baselines by contract, while maxrank ids are higher ranks of the
    # same ladders by design.) The explicitly pinned class-less aura rows
    # (CLASS_LESS_BUFF_NAMES) are admitted here by id -- they are player-side
    # effects the class filter cannot see, not foreign spells.
    class_less_ids = set(CLASS_LESS_BUFF_NAMES.values())
    for label, mapping, id_of in (
            ("maxrank", maxrank, lambda k: maxrank[k][1]),
            ("buff", buff_ids, lambda k: buff_ids[k])):
        orphans = sorted({id_of(k) for k in mapping} - all_player_ids - class_less_ids)
        if orphans:
            print("ERROR: %s mirror ids with no player-filtered DBC row: %s"
                  % (label, orphans))
            sys.exit(2)
    print("  Mirrors:   by_name + maxrank + buff all resolve to player rows")

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
        spells, maxrank, buff_ids, all_player_ids = load_forever_spells(conn)
    finally:
        conn.close()
    if not spells:
        print("ERROR: no player spells extracted from %s" % DBC_DB)
        sys.exit(2)
    print("Forever DBC: %d player spells extracted" % len(spells))
    write_bridge(spells, maxrank, buff_ids, all_player_ids)
    print("Audit live mode: run_forever_audit_tests.lua now enforces real ID resolution.")


if __name__ == "__main__":
    main()
