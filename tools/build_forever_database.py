#!/usr/bin/env python3
"""build_forever_database.py -- WoW Forever community datamine package builder.

WHAT:  turns the beta-client DBC extraction (wowsims_forever.db, 108 tables
        as of the 2026-09-17 1.60.1.69893 extraction) into a community-ready
        dataset under wowheadScrape/dbc_extract/forever_community/:
        an enriched SQLite database (forever_datamine.db) carrying the curated
        spell/talent tables PLUS a verbatim mirror of every world/NPC/item
        table (AreaTable, UiMap, Taxi*, Creature*, Item*, Spell* meta...), and
        grep-friendly JSON artifacts -- spells.jsonl, by_name.json,
        talents.json, trainers.json, races.json, procs.json, plus the world
        set: items.jsonl, zones.json, points.json, taxi.json, creatures.json,
        spell_meta.json. Full spell descriptions are first-class fields
        everywhere -- they are the most useful rotation-design input.
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

Item stats: ItemSparse stores stat *types* (StatModifier_bonusStat) and
budget *shares in basis points* (StatPercentEditor), NOT final numbers --
the client derives final values from ilvl/quality via the budget tables.
This package now COMPUTES the values (RandPropPoints x share x slot tier;
see the STAT_TIER calibration note below) and keeps the raw share alongside;
the raw budget tables (RandPropPoints, ItemArmor*, ItemDamage*) ship as-is
for anyone re-deriving. Armor and weapon damage are not computed (their
tables do not reproduce classic values -- verify in-game).
"""

import argparse
import datetime
import json
import os
import re
import sqlite3
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_forever_bridge as bb

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DB = os.path.join(ROOT, "wowheadScrape", "dbc_extract", "wowsims_forever.db")

# The Forever beta product line in .build.info. The DB2ToSqlite output carries
# no build stamp, so the client install is the only local authority on which
# build a package describes.
CLIENT_PRODUCT = "wow_classic_beta"
DEFAULT_BASE_DIR = r"C:\Program Files (x86)\World of Warcraft"
OUT_DIR = os.path.join(ROOT, "wowheadScrape", "dbc_extract", "forever_community")

OUT_DB = os.path.join(OUT_DIR, "forever_datamine.db")
OUT_JSONL = os.path.join(OUT_DIR, "spells.jsonl")
OUT_BY_NAME = os.path.join(OUT_DIR, "by_name.json")
OUT_TALENTS = os.path.join(OUT_DIR, "talents.json")
OUT_TRAINERS = os.path.join(OUT_DIR, "trainers.json")
OUT_RACES = os.path.join(OUT_DIR, "races.json")
OUT_PROCS = os.path.join(OUT_DIR, "procs.json")
OUT_ITEMS = os.path.join(OUT_DIR, "items.jsonl")
OUT_ZONES = os.path.join(OUT_DIR, "zones.json")
OUT_POINTS = os.path.join(OUT_DIR, "points.json")
OUT_TAXI = os.path.join(OUT_DIR, "taxi.json")
OUT_CREATURES = os.path.join(OUT_DIR, "creatures.json")
OUT_SPELL_META = os.path.join(OUT_DIR, "spell_meta.json")
OUT_MOUNTS = os.path.join(OUT_DIR, "mounts.json")

# Verbatim mirror of the world/NPC/item/spell-meta DBC tables extracted from
# the 1.60.1.69893 beta client (probe-confirmed on this client; the probe
# recipe lives in the runbook). Names match the DBC table names so queries
# read like wowdev docs. Everything else stays in wowsims_forever.db.
WORLD_TABLES = (
    # creature / NPC
    "Creature", "CreatureFamily", "CreatureType", "CreatureDisplayInfo",
    "CreatureDisplayInfoExtra", "CreatureModelData", "CreatureMovementInfo",
    "CreatureImmunities", "CreatureSoundData", "CreatureDifficulty",
    "CreatureXDisplayInfo", "NPCSounds",
    # faction
    "Faction", "FactionTemplate", "FactionGroup",
    # world / areas / maps
    "Map", "MapDifficulty", "AreaTable", "AreaTrigger", "AreaPOI",
    "UiMap", "UiMapAssignment", "UiMapGroup", "UiMapGroupMember", "UiMapLink",
    "UiMapFogOfWar", "UiMapXMapArt", "WorldMapOverlay",
    "LiquidType", "LiquidObject", "LiquidMaterial",
    "BattlemasterList", "LFGDungeons",
    # navigation / transport
    "TaxiNodes", "TaxiPath", "TaxiPathNode", "TransportAnimation",
    "TransportRotation", "TransportPhysics",
    # gameobjects
    "GameObjectDisplayInfo", "GameObjectArtKit",
    # mounts / appearance / file manifests
    "Mount", "MountXDisplay", "MountType", "MountCapability",
    "MountEquipment", "ItemAppearance", "ItemModifiedAppearance",
    "ItemSearchName", "ModelFileData", "TextureFileData",
    # items
    "Item", "ItemSparse", "ItemNameDescription", "ItemClass", "ItemSubClass",
    "ItemSubClassMask", "ItemDisplayInfo", "ItemArmorQuality",
    "ItemArmorShield", "ItemArmorTotal", "ArmorLocation",
    "ItemDamageAmmo", "ItemDamageOneHand", "ItemDamageOneHandCaster",
    "ItemDamageRanged", "ItemDamageThrown", "ItemDamageTwoHand",
    "ItemDamageTwoHandCaster", "ItemDamageWand", "ItemSet", "ItemSetSpell",
    "ItemExtendedCost", "ItemEffect", "ItemXItemEffect", "ItemBonus",
    "SpellItemEnchantment",
    "GemProperties", "RandPropPoints",
    # spell metadata (rotation dev)
    "SpellCastTimes", "SpellDuration", "SpellRadius", "SpellRange",
    "SpellShapeshiftForm", "SpellMechanic", "SpellDispelType",
    "SpellCategory", "SpellCategories", "SpellPower",
    "SpellTargetRestrictions", "SpellInterrupts", "SpellEquippedItems",
    "SpellProcsPerMinute", "SpellProcsPerMinuteMod", "SpellFocusObject",
    # characters / emotes / scaling
    "ChrClasses", "ChrSpecialization", "ChrClassesXPowerTypes",
    "PowerDisplay", "SkillRaceClassInfo", "Emotes", "EmotesText",
    "ExpectedStat", "ExpectedStatMod", "ContentTuning",
    "ContentTuningXExpected",
)

# Item stat budget rule (1.60 client): ItemSparse stores stat TYPES +
# budget SHARES in basis points (StatPercentEditor); the client computes the
# final values from RandPropPoints(ItemLevel)[quality column][slot tier].
# Tier + column mapping derived by cross-checking the 2.5.5 reference client
# (which stores final values in StatModifier_bonusAmount): spot-verified on
# Lionheart Helm (18 Str / 28 crit / 20 hit) and Thunderfury (5 agi / 8 sta)
# and consistent across slots/subclasses. Caveats: trinket tier is ambiguous,
# items without ItemLevel fall back to shares only, and armor/damage are NOT
# computed (their tables do not reproduce classic values).
STAT_QUALITY_COL = {0: "good", 1: "good", 2: "good", 3: "superior",
                    4: "epic", 5: "epic", 6: "epic"}
STAT_TIER = {1: 0, 5: 0, 7: 0, 17: 0, 20: 0,          # head chest legs 2H robe
             3: 1, 6: 1, 8: 1, 10: 1,                # shoulder waist feet hands
             2: 2, 9: 2, 11: 2, 14: 2, 16: 2, 23: 2,  # neck wrist finger back shield holdable
             13: 3, 21: 3, 22: 3,                     # one-hand / main / off
             15: 4, 25: 4, 26: 4}                     # ranged / thrown / ranged-right
STAT_TIER_DEFAULT = 1

# Classic inventory-slot names (InventoryType enum) for item display.
INV_SLOT = {
    0: "Non-equip", 1: "Head", 2: "Neck", 3: "Shoulder", 4: "Shirt",
    5: "Chest", 6: "Waist", 7: "Legs", 8: "Feet", 9: "Wrist", 10: "Hands",
    11: "Finger", 12: "Trinket", 13: "One-Hand", 14: "Shield", 15: "Ranged",
    16: "Back", 17: "Two-Hand", 18: "Bag", 19: "Tabard", 20: "Robe",
    21: "Main Hand", 22: "Off Hand", 23: "Holdable", 24: "Ammo",
    25: "Thrown", 26: "Ranged Right", 27: "Relic",
}

# Classic ITEM_MOD_* stat-type names (TrinityCore 3.3.5 enum; -1 = empty).
STAT_TYPE = {
    0: "mana", 1: "health", 3: "agility", 4: "strength", 5: "intellect",
    6: "spirit", 7: "stamina", 12: "defense_rating", 13: "dodge_rating",
    14: "parry_rating", 15: "block_rating", 16: "hit_melee_rating",
    17: "hit_ranged_rating", 18: "hit_spell_rating", 19: "crit_melee_rating",
    20: "crit_ranged_rating", 21: "crit_spell_rating",
    22: "hit_taken_melee_rating", 23: "hit_taken_ranged_rating",
    24: "hit_taken_spell_rating", 25: "crit_taken_melee_rating",
    26: "crit_taken_ranged_rating", 27: "crit_taken_spell_rating",
    28: "haste_melee_rating", 29: "haste_ranged_rating",
    30: "haste_spell_rating", 31: "hit_rating", 32: "crit_rating",
    33: "hit_taken_rating", 34: "crit_taken_rating", 35: "resilience_rating",
    36: "haste_rating", 37: "expertise_rating", 38: "attack_power",
    39: "ranged_attack_power", 40: "feral_attack_power",
    41: "spell_healing_done", 42: "spell_damage_done",
    43: "mana_regeneration", 44: "armor_penetration_rating",
    45: "spell_power", 46: "health_regen", 47: "spell_penetration",
    48: "block_value", 49: "mastery", 50: "extra_armor",
    51: "fire_resistance", 52: "frost_resistance", 53: "holy_resistance",
    54: "shadow_resistance", 55: "nature_resistance",
    56: "arcane_resistance",
}

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


def _arr(text):
    """Parse a DBC array-of-scalars text field ('[1,2,3]') into raw strings."""
    if text is None:
        return []
    s = str(text).strip()
    if s.startswith("[") and s.endswith("]"):
        s = s[1:-1]
    if not s:
        return []
    return [x.strip().strip("'\"") for x in s.split(",")]


def _fvec(text):
    out = []
    for x in _arr(text):
        try:
            out.append(float(x))
        except ValueError:
            out.append(0.0)
    return out


def _render_tokens(desc, effects, radius_by_idx, duration_ms, max_targets):
    """Render the common client tooltip tokens ($s1/$m1/$d/$t1/$a1/$o1/$x1,
    $/N;sM) into numbers. Unknown/expression tokens ($<var>, ${...}, $?a..)
    are left verbatim (documented in the README)."""
    if not desc or "$" not in desc:
        return desc

    def base_of(n):
        i = n - 1
        if 0 <= i < len(effects):
            b = effects[i].get("base")
            if isinstance(b, (int, float)):
                return b + 1
        return None

    def ticks_of(n):
        i = n - 1
        if 0 <= i < len(effects):
            amp = effects[i].get("amplitude")
            if duration_ms and amp:
                return max(1, int(duration_ms / (amp * 1000)))
        return 1

    # $/N;sM  -> effect M base divided by N
    def div_sub(m):
        div, eff = int(m.group(1)), int(m.group(2))
        b = base_of(eff)
        return str(int(round(b / div))) if b is not None else m.group(0)
    desc = re.sub(r"\$/(\d+);s(\d+)", div_sub, desc)

    def sub(m):
        body = m.group(1)
        v = None
        try:
            if body.startswith("s") or body.startswith("S"):
                b = base_of(int(body[1:]))
                v = str(int(round(b))) if b is not None else None
            elif body.startswith("o") and body[1:].isdigit():
                b = base_of(int(body[1:]))
                v = str(int(round(b * ticks_of(int(body[1:]))))) \
                    if b is not None else None
            elif body.startswith("m"):
                i = int(body[1:]) - 1
                if 0 <= i < len(effects) and effects[i].get("misc") is not None:
                    v = str(effects[i]["misc"])
            elif body.startswith("a"):
                i = int(body[1:]) - 1
                if 0 <= i < len(effects):
                    r = radius_by_idx.get(effects[i].get("radius"))
                    if r:
                        v = "%g" % r
            elif body.startswith("x") and body[1:].isdigit():
                if max_targets:
                    v = str(max_targets)
            elif body == "d":
                v = str(int(duration_ms / 1000)) if duration_ms else None
            elif body.startswith("t") and body[1:].isdigit():
                if duration_ms:
                    v = str(ticks_of(int(body[1:])))
        except (ValueError, TypeError):
            v = None
        return v if v is not None else m.group(0)

    return re.sub(r"\$([sSomaAx]?\d+|\d+|[dt]\d*)", sub, desc)


def load(conn):
    """Read the raw extraction into plain structures."""
    conn.row_factory = sqlite3.Row
    spells = {}
    for r in conn.execute(
            "SELECT s.ID, sn.Name_lang, sm.SchoolMask, sm.CastingTimeIndex, "
            "sl.SpellLevel, sl.BaseLevel, sco.SpellClassSet, sc.RecoveryTime, "
            "sc.CategoryRecoveryTime, "
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
            "EffectRadiusIndex, Coefficient, EffectAmplitude FROM SpellEffect"):
        effects.setdefault(r["SpellID"], []).append(dict(r))
    durations = {r["ID"]: r["Duration"] for r in conn.execute(
        "SELECT ID, Duration FROM SpellDuration")}
    radii = {r["ID"]: r["Radius"] for r in conn.execute(
        "SELECT ID, Radius FROM SpellRadius")}
    dur_index = {r["SpellID"]: r["DurationIndex"] for r in conn.execute(
        "SELECT SpellID, DurationIndex FROM SpellMisc")}
    target_caps = {r["SpellID"]: r["MaxTargets"] for r in conn.execute(
        "SELECT SpellID, MaxTargets FROM SpellTargetRestrictions")}
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
        all_names, all_descs, durations, radii, dur_index, target_caps


def build(spells, effects, talents, tabs, skills, sla, races, procs,
          all_names, all_descs, durations, radii, dur_index, target_caps):
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
    #
    # Only rows that carry a cast/timing row are ranks. The client ships
    # aura/trigger/legacy rows under the same name -- Lightning Shield has 4
    # rows per level -- and counting them inflated every chip in the viewer
    # (a 7-rank ladder showed "R9"/"R13", 2026-09-20 playtest). A name with no
    # cast rows at all (passive auras) keeps plain numbering so nothing loses
    # its ladder, and rows left unnumbered get no rank field at all.
    def _is_cast_rank(s):
        return (isinstance(s.get("StartRecoveryTime"), (int, float))
                or isinstance(s.get("RecoveryTime"), (int, float)))

    ladders = {}
    for s in spells.values():
        key = ((class_of(s["SpellClassSet"]) or ""), s["Name_lang"])
        ladders.setdefault(key, []).append(s)
    rank_of = {}
    for rows in ladders.values():
        numbered = [s for s in rows if _is_cast_rank(s)] or rows
        numbered.sort(key=lambda s: (level_of(s) if level_of(s) else 9999,
                                     s["ID"]))
        for i, s in enumerate(numbered, 1):
            rank_of[s["ID"]] = i

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
        # BOTH cooldown columns count. The client files a spell's real cooldown
        # under CategoryRecoveryTime whenever it shares a recovery category
        # (Consecration 8s, Holy Strike 12s, Lay on Hands 20min, Rebirth 30min);
        # reading RecoveryTime alone shipped cooldown_s = 0.0 for 1,687 spells
        # that do have one, and the viewer printed "0s CD" for them
        # (2026-09-20 playtest). max() is what the game enforces and what
        # wowsims computes for a lone caster.
        # None (row absent) stays distinct from 0 (row present, no cooldown):
        # the viewer prints "— (no DBC row)" for the first and "none" for the
        # second, and collapsing them would lose that.
        if s["RecoveryTime"] is None and s["CategoryRecoveryTime"] is None:
            rec = None
        else:
            rec = max(s["RecoveryTime"] or 0, s["CategoryRecoveryTime"] or 0)
        grec = s["StartRecoveryTime"]
        dms = durations.get(dur_index.get(sid, 0)) or 0
        rendered = _render_tokens(s["Description_lang"] or "", effs, radii,
                                  dms, target_caps.get(sid))
        aura_rendered = _render_tokens(s["AuraDescription_lang"] or "", effs,
                                       radii, dms, target_caps.get(sid))
        out_spells[sid] = {
            "id": sid, "name": s["Name_lang"],
            "subtext": s["NameSubtext_lang"] or "",
            "class": cls, "class_set": s["SpellClassSet"],
            "level": lvl, "rank": rank_of.get(sid),
            "school": _school(s["SchoolMask"] or 1),
            "school_mask": s["SchoolMask"],
            "cast_idx": s["CastingTimeIndex"],
            "gcd_s": round(grec / 1000, 2) if isinstance(grec, (int, float)) else None,
            "cooldown_s": round(rec / 1000, 2) if isinstance(rec, (int, float)) else None,
            "description": s["Description_lang"] or "",
            "aura_description": s["AuraDescription_lang"] or "",
            "description_rendered": rendered,
            "aura_description_rendered": aura_rendered,
            "is_heal": is_heal, "aoe": aoe,
            "effects": effs,
        }

    by_name = {}
    for sid in sorted(out_spells):
        by_name.setdefault(out_spells[sid]["name"], []).append(sid)

    # expand $@spelldesc<id> references (iterate for nesting)
    ref = re.compile(r"\$@spelldesc(\d+)")
    for _ in range(3):
        changed = False
        for sid in out_spells:
            for field in ("description_rendered",
                          "aura_description_rendered"):
                txt = out_spells[sid].get(field) or ""
                if "$@spelldesc" not in txt:
                    continue

                def repl(m):
                    other = out_spells.get(int(m.group(1)))
                    return (other.get(field) if other else "") or ""

                new = ref.sub(repl, txt)
                if new != txt:
                    out_spells[sid][field] = new
                    changed = True
        if not changed:
            break

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
        # Not `or -1`: race 1 (Human) carries PlayableRaceBit 0, and `0 or -1`
        # is -1, which marked every classic race with bit 0 unplayable
        # (viewer showed Human as "—", 2026-09-20 playtest).
        "playable": (r["PlayableRaceBit"] is not None
                     and r["PlayableRaceBit"] >= 0),
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
        for t in WORLD_TABLES:
            conn.execute('DROP TABLE IF EXISTS "%s"' % t)
        for v in ("player_spells", "heals", "creature_displays", "zones",
                  "taxi_nodes", "item_index"):
            conn.execute("DROP VIEW IF EXISTS %s" % v)
        conn.execute("""CREATE TABLE spells(
            id INTEGER PRIMARY KEY, name TEXT, subtext TEXT, class TEXT,
            class_set INTEGER, level INTEGER, school TEXT, school_mask INTEGER,
            cast_idx INTEGER, gcd_s REAL, cooldown_s REAL, description TEXT,
            aura_description TEXT, is_heal INTEGER, aoe INTEGER,
            description_rendered TEXT, aura_description_rendered TEXT)""")
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
                "INSERT INTO spells VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (s["id"], s["name"], s["subtext"], s["class"], s["class_set"],
                 s["level"], s["school"], s["school_mask"], s["cast_idx"],
                 s["gcd_s"], s["cooldown_s"], s["description"],
                 s["aura_description"], int(s["is_heal"]), int(s["aoe"]),
                 s.get("description_rendered") or "",
                 s.get("aura_description_rendered") or ""))
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
        # Verbatim world/NPC/item mirror: copy straight from the extraction
        # DB so the package is self-contained for every downstream query.
        conn.execute("ATTACH DATABASE ? AS src", (SRC_DB,))
        try:
            for t in WORLD_TABLES:
                conn.execute('CREATE TABLE "%s" AS SELECT * FROM src."%s"'
                             % (t, t))
            conn.commit()
        finally:
            conn.execute("DETACH DATABASE src")
        conn.execute("""CREATE VIEW creature_displays AS
            SELECT cd.ID AS display_id, cd.ModelID AS model_id,
                   cm.FileDataID AS model_fdid, cm.RunSpeed AS run_speed,
                   cm.WalkSpeed AS walk_speed, cm.CollisionWidth AS width,
                   cm.CollisionHeight AS height, cd.SizeClass AS size_class,
                   cd.CreatureModelScale AS scale, cd.SoundID AS sound_id
            FROM CreatureDisplayInfo cd
            LEFT JOIN CreatureModelData cm ON cm.ID = cd.ModelID""")
        conn.execute("""CREATE VIEW zones AS
            SELECT a.ID AS id, a.AreaName_lang AS name,
                   a.ContinentID AS map_id, m.MapName_lang AS map,
                   m.MapType AS map_type, a.ParentAreaID AS parent_id,
                   a.Flags AS flags
            FROM AreaTable a LEFT JOIN Map m ON m.ID = a.ContinentID""")
        conn.execute("""CREATE VIEW taxi_nodes AS
            SELECT ID AS id, Name_lang AS name, ContinentID AS map_id,
                   Pos AS pos, Flags AS flags FROM TaxiNodes""")
        conn.execute("""CREATE VIEW item_index AS
            SELECT sp.ID AS id, sp.Display_lang AS name,
                   sp.ItemLevel AS ilvl, sp.OverallQualityID AS quality,
                   sp.RequiredLevel AS req_level, i.ClassID AS class_id,
                   i.SubclassID AS subclass_id, i.InventoryType AS inv_type,
                   sp.BuyPrice AS buy, sp.SellPrice AS sell,
                   sp.ItemSet AS set_id
            FROM ItemSparse sp LEFT JOIN Item i ON i.ID = sp.ID""")
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
    with open(OUT_RACES, "w", encoding="utf-8") as f:
        json.dump(data["races"], f, ensure_ascii=False, indent=1)
    with open(OUT_PROCS, "w", encoding="utf-8") as f:
        json.dump(data["procs"], f, ensure_ascii=False, indent=1)
    return {
        "db": OUT_DB, "jsonl": OUT_JSONL, "by_name": OUT_BY_NAME,
        "talents": OUT_TALENTS, "trainers": OUT_TRAINERS,
        "races": OUT_RACES, "procs": OUT_PROCS,
    }


def write_world_artifacts():
    """Curated grep/viewer-friendly views over the raw world mirror."""
    conn = sqlite3.connect(OUT_DB)
    conn.row_factory = sqlite3.Row
    try:
        item_class = {r["ClassID"]: r["ClassName_lang"] for r in conn.execute(
            "SELECT ClassID, ClassName_lang FROM ItemClass")}
        item_sub = {}
        for r in conn.execute(
                "SELECT ClassID, SubClassID, DisplayName_lang, VerboseName_lang"
                " FROM ItemSubClass"):
            item_sub[(r["ClassID"], r["SubClassID"])] = (
                r["DisplayName_lang"] or r["VerboseName_lang"] or "")
        maps = {r["ID"]: r["MapName_lang"] for r in conn.execute(
            "SELECT ID, MapName_lang FROM Map")}
        rpp = {}
        for r in conn.execute(
                "SELECT ID, Epic, Superior, Good FROM RandPropPoints"):
            rpp[r["ID"]] = {"epic": _fvec(r["Epic"]),
                            "superior": _fvec(r["Superior"]),
                            "good": _fvec(r["Good"])}
        spell_names = {r["id"]: (r["name"], r["description"] or "")
                       for r in conn.execute(
                           "SELECT id, name, description FROM spells")}
        effects_by_item = {}
        for r in conn.execute(
                "SELECT x.ItemID, e.SpellID, e.Charges, e.CoolDownMSec"
                " FROM ItemXItemEffect x JOIN ItemEffect e"
                " ON e.ID = x.ItemEffectID ORDER BY x.ItemID, e.ID"):
            effects_by_item.setdefault(r["ItemID"], []).append(r)
        with open(OUT_ITEMS, "w", encoding="utf-8") as f:
            for r in conn.execute(
                    "SELECT sp.ID, sp.Display_lang, sp.ItemLevel,"
                    " sp.OverallQualityID, sp.RequiredLevel, sp.Stackable,"
                    " sp.BuyPrice, sp.SellPrice, sp.ItemSet,"
                    " sp.StatModifier_bonusStat, sp.StatPercentEditor,"
                    " sp.SocketType, sp.ItemDelay, sp.Bonding,"
                    " sp.ContainerSlots, sp.Description_lang,"
                    " i.ClassID, i.SubclassID, i.InventoryType,"
                    " i.IconFileDataID"
                    " FROM ItemSparse sp LEFT JOIN Item i ON i.ID = sp.ID"
                    " WHERE sp.Display_lang IS NOT NULL"
                    " AND sp.Display_lang != '' ORDER BY sp.ID"):
                types = [int(x) for x in _arr(r["StatModifier_bonusStat"])
                         if x.lstrip("-").isdigit()]
                pcts = _fvec(r["StatPercentEditor"])
                col = STAT_QUALITY_COL.get(r["OverallQualityID"] or 0, "good")
                tier = STAT_TIER.get(r["InventoryType"], STAT_TIER_DEFAULT)
                vals = rpp.get(r["ItemLevel"] or 0, {}).get(col) or []
                budget = vals[tier] if tier < len(vals) else 0
                stats = []
                for i, t in enumerate(types):
                    if t < 0:
                        continue
                    pct = pcts[i] if i < len(pcts) else 0.0
                    if pct <= 0:
                        continue
                    val = round(pct / 10000.0 * budget) if budget else None
                    stats.append([t, STAT_TYPE.get(t, "stat%d" % t),
                                  val, int(round(pct))])
                entry = {
                    "id": r["ID"], "name": r["Display_lang"],
                    "quality": r["OverallQualityID"], "ilvl": r["ItemLevel"],
                    "req": r["RequiredLevel"],
                    "class": item_class.get(r["ClassID"]) or "",
                    "subclass": item_sub.get(
                        (r["ClassID"], r["SubclassID"])) or "",
                    "slot": INV_SLOT.get(r["InventoryType"], ""),
                }
                if r["Stackable"] and r["Stackable"] > 1:
                    entry["stack"] = r["Stackable"]
                if r["BuyPrice"]:
                    entry["buy"] = r["BuyPrice"]
                if r["SellPrice"]:
                    entry["sell"] = r["SellPrice"]
                if r["ItemSet"]:
                    entry["set"] = r["ItemSet"]
                if r["ItemDelay"]:
                    entry["delay_ms"] = r["ItemDelay"]
                if r["ContainerSlots"]:
                    entry["slots"] = r["ContainerSlots"]
                if r["Bonding"]:
                    entry["bonding"] = r["Bonding"]
                if stats:
                    entry["stats"] = stats
                if r["Description_lang"]:
                    entry["desc"] = r["Description_lang"]
                effs = []
                for e in effects_by_item.get(r["ID"], []):
                    name, desc = spell_names.get(e["SpellID"], ("", ""))
                    eff = {"spell": e["SpellID"], "name": name}
                    if desc:
                        eff["desc"] = desc
                    if e["Charges"]:
                        eff["charges"] = e["Charges"]
                    if e["CoolDownMSec"]:
                        eff["cd_s"] = round(e["CoolDownMSec"] / 1000.0, 2)
                    effs.append(eff)
                if effs:
                    entry["effects"] = effs
                socks = [int(x) for x in _arr(r["SocketType"])
                         if x.lstrip("-").isdigit()]
                if any(socks):
                    entry["sockets"] = socks
                if r["IconFileDataID"]:
                    entry["icon_fdid"] = r["IconFileDataID"]
                f.write(json.dumps(entry, ensure_ascii=False,
                                   separators=(",", ":")) + "\n")
        # --- zones
        zones = []
        for r in conn.execute(
                "SELECT id, name, map_id, map, map_type, parent_id FROM zones"
                " WHERE name IS NOT NULL AND name != '' ORDER BY id"):
            zones.append({
                "id": r["id"], "name": r["name"], "map": r["map"] or "",
                "map_id": r["map_id"], "map_type": r["map_type"] or 0,
                "parent": r["parent_id"] or 0,
            })
        with open(OUT_ZONES, "w", encoding="utf-8") as f:
            json.dump(zones, f, ensure_ascii=False, indent=1)
        # --- points (POIs + area triggers + taxi nodes in one place index)
        points = []
        for r in conn.execute(
                "SELECT ID, Name_lang, Pos, ContinentID, AreaID, Importance"
                " FROM AreaPOI WHERE Name_lang IS NOT NULL"
                " AND Name_lang != '' ORDER BY ID"):
            x, y, z = (_fvec(r["Pos"]) + [0.0, 0.0, 0.0])[:3]
            points.append({
                "type": "poi", "id": r["ID"], "name": r["Name_lang"],
                "map": maps.get(r["ContinentID"], ""),
                "map_id": r["ContinentID"], "x": round(x, 2),
                "y": round(y, 2), "z": round(z, 2),
                "area": r["AreaID"] or 0, "importance": r["Importance"] or 0,
            })
        for r in conn.execute(
                "SELECT ID, Pos, ContinentID, Radius FROM AreaTrigger"
                " ORDER BY ID"):
            x, y, z = (_fvec(r["Pos"]) + [0.0, 0.0, 0.0])[:3]
            points.append({
                "type": "trigger", "id": r["ID"], "name": "",
                "map": maps.get(r["ContinentID"], ""),
                "map_id": r["ContinentID"], "x": round(x, 2),
                "y": round(y, 2), "z": round(z, 2),
                "radius": r["Radius"] or 0,
            })
        for r in conn.execute(
                "SELECT ID, Name_lang, Pos, ContinentID, Flags FROM TaxiNodes"
                " ORDER BY ID"):
            x, y, z = (_fvec(r["Pos"]) + [0.0, 0.0, 0.0])[:3]
            points.append({
                "type": "taxi", "id": r["ID"], "name": r["Name_lang"] or "",
                "map": maps.get(r["ContinentID"], ""),
                "map_id": r["ContinentID"], "x": round(x, 2),
                "y": round(y, 2), "z": round(z, 2),
                "flags": r["Flags"] or 0,
            })
        with open(OUT_POINTS, "w", encoding="utf-8") as f:
            json.dump(points, f, ensure_ascii=False, indent=1)
        # --- taxi network (nodes + path summaries)
        taxi_nodes = []
        for r in conn.execute(
                "SELECT ID, Name_lang, Pos, ContinentID, Flags FROM TaxiNodes"
                " ORDER BY ID"):
            x, y, z = (_fvec(r["Pos"]) + [0.0, 0.0, 0.0])[:3]
            taxi_nodes.append({
                "id": r["ID"], "name": r["Name_lang"] or "",
                "map": maps.get(r["ContinentID"], ""),
                "x": round(x, 2), "y": round(y, 2), "z": round(z, 2),
                "flags": r["Flags"] or 0,
            })
        taxi_paths = []
        for r in conn.execute(
                "SELECT ID, FromTaxiNode, ToTaxiNode, Cost,"
                " (SELECT COUNT(*) FROM TaxiPathNode n WHERE n.PathID ="
                " TaxiPath.ID) AS wp FROM TaxiPath ORDER BY ID"):
            taxi_paths.append({
                "id": r["ID"], "from": r["FromTaxiNode"],
                "to": r["ToTaxiNode"], "cost": r["Cost"] or 0,
                "waypoints": r["wp"],
            })
        with open(OUT_TAXI, "w", encoding="utf-8") as f:
            json.dump({"nodes": taxi_nodes, "paths": taxi_paths}, f,
                      ensure_ascii=False, indent=1)
        # --- creatures (companion catalogue + families/types/difficulty)
        family = {r["ID"]: r["Name_lang"] for r in conn.execute(
            "SELECT ID, Name_lang FROM CreatureFamily")}
        ctype = {r["ID"]: r["Name_lang"] for r in conn.execute(
            "SELECT ID, Name_lang FROM CreatureType")}
        companions = []
        for r in conn.execute(
                "SELECT ID, Name_lang, Title_lang, Classification,"
                " CreatureType, CreatureFamily, DisplayID FROM Creature"
                " ORDER BY ID"):
            companions.append({
                "id": r["ID"], "name": r["Name_lang"] or "",
                "title": r["Title_lang"] or "",
                "classification": r["Classification"] or 0,
                "type": ctype.get(r["CreatureType"], ""),
                "family": family.get(r["CreatureFamily"]) or "",
                "displays": [int(x) for x in _arr(r["DisplayID"])
                             if x.lstrip("-").isdigit() and int(x) > 0],
            })
        families = [{
            "id": r["ID"], "name": r["Name_lang"] or "",
            "min_scale": r["MinScale"], "max_scale": r["MaxScale"],
            "pet_food_mask": r["PetFoodMask"], "talent_type":
            r["PetTalentType"], "skill_line": r["SkillLine"],
        } for r in conn.execute("SELECT * FROM CreatureFamily ORDER BY ID")]
        difficulty = [{
            "creature": r["CreatureID"], "min_level": r["MinLevel"],
            "max_level": r["MaxLevel"], "faction_template":
            r["FactionTemplateID"], "content_tuning": r["ContentTuningID"],
        } for r in conn.execute("SELECT * FROM CreatureDifficulty"
                                " ORDER BY CreatureID")]
        with open(OUT_CREATURES, "w", encoding="utf-8") as f:
            json.dump({
                "companions": companions,
                "families": families,
                "types": [{"id": i, "name": n}
                          for i, n in sorted(ctype.items())],
                "difficulty": difficulty,
            }, f, ensure_ascii=False, indent=1)
        # --- spell_meta (rotation-relevant per-spell metadata, joined)
        cast = {r["ID"]: r["Base"] for r in conn.execute(
            "SELECT ID, Base FROM SpellCastTimes")}
        dur = {r["ID"]: r["Duration"] for r in conn.execute(
            "SELECT ID, Duration FROM SpellDuration")}
        range_tbl = {}
        for r in conn.execute("SELECT * FROM SpellRange"):
            k = r.keys()

            def pick(*names):
                for n in names:
                    if n in k and r[n] is not None:
                        return r[n]
                return None
            range_tbl[r["ID"]] = (pick("MinRangeHostile", "MinRange"),
                                  pick("MaxRangeHostile", "MaxRange"))
        dispel = {r["ID"]: r["Name_lang"] for r in conn.execute(
            "SELECT ID, Name_lang FROM SpellDispelType")}
        mech = {r["ID"]: r["StateName_lang"] for r in conn.execute(
            "SELECT ID, StateName_lang FROM SpellMechanic")}
        cat = {}
        try:
            cat = {r["ID"]: r["Name_lang"] for r in conn.execute(
                "SELECT ID, Name_lang FROM SpellCategory")}
        except sqlite3.OperationalError:
            pass

        def first_map(sql):
            out = {}
            for r in conn.execute(sql):
                out.setdefault(r["SpellID"], r)
            return out

        src = sqlite3.connect(SRC_DB)
        src.row_factory = sqlite3.Row
        try:
            misc = {r["SpellID"]: r for r in src.execute(
                "SELECT SpellID, CastingTimeIndex, DurationIndex, RangeIndex,"
                " SpellIconFileDataID FROM SpellMisc ORDER BY SpellID")}
            effects_radius = {r["SpellID"]: r["rad"] for r in src.execute(
                "SELECT e.SpellID AS SpellID, MAX(sr.Radius) AS rad"
                " FROM SpellEffect e JOIN SpellRadius sr"
                " ON sr.ID = e.EffectRadiusIndex GROUP BY e.SpellID")}
        finally:
            src.close()
        restrictions = first_map(
            "SELECT SpellID, MaxTargets, ConeDegrees, Targets"
            " FROM SpellTargetRestrictions ORDER BY SpellID")
        cats = first_map(
            "SELECT SpellID, DispelType, Mechanic, Category"
            " FROM SpellCategories ORDER BY SpellID")
        powers = first_map(
            "SELECT SpellID, ManaCost, PowerType, PowerCostPct"
            " FROM SpellPower ORDER BY SpellID, OrderIndex")
        interrupts = first_map(
            "SELECT SpellID, InterruptFlags FROM SpellInterrupts"
            " ORDER BY SpellID")
        meta = {}
        for (sid,) in conn.execute("SELECT id FROM spells ORDER BY id"):
            m = {}
            mr = misc.get(sid)
            if mr:
                if mr["CastingTimeIndex"] in cast:
                    m["cast_ms"] = cast[mr["CastingTimeIndex"]]
                if mr["DurationIndex"] in dur:
                    m["dur_ms"] = dur[mr["DurationIndex"]]
                if mr["RangeIndex"] in range_tbl:
                    mn, mx = range_tbl[mr["RangeIndex"]]
                    if mx:
                        m["range_max"] = mx
                    if mn:
                        m["range_min"] = mn
                if mr["SpellIconFileDataID"]:
                    m["icon"] = mr["SpellIconFileDataID"]
            rad = effects_radius.get(sid)
            if rad:
                m["radius_yd"] = round(rad, 2)
            tr = restrictions.get(sid)
            if tr:
                if tr["MaxTargets"]:
                    m["max_targets"] = tr["MaxTargets"]
                if tr["ConeDegrees"]:
                    m["cone_deg"] = tr["ConeDegrees"]
                if tr["Targets"]:
                    m["targets"] = tr["Targets"]
            sc = cats.get(sid)
            if sc:
                if sc["DispelType"]:
                    m["dispel"] = dispel.get(sc["DispelType"],
                                             sc["DispelType"])
                if sc["Mechanic"]:
                    m["mechanic"] = mech.get(sc["Mechanic"], sc["Mechanic"])
                if sc["Category"]:
                    m["category"] = cat.get(sc["Category"], sc["Category"])
            sp = powers.get(sid)
            if sp:
                if sp["ManaCost"]:
                    m["mana"] = sp["ManaCost"]
                if sp["PowerType"]:
                    m["power"] = sp["PowerType"]
                if sp["PowerCostPct"]:
                    m["mana_pct"] = sp["PowerCostPct"]
            si = interrupts.get(sid)
            if si and si["InterruptFlags"]:
                m["interrupt"] = si["InterruptFlags"]
            if m:
                meta[str(sid)] = m
        with open(OUT_SPELL_META, "w", encoding="utf-8") as f:
            json.dump(meta, f, ensure_ascii=False, separators=(",", ":"))
        # --- mounts (name, source spell, type, display, journal text)
        type_names = {r["ID"]: r for r in conn.execute(
            "SELECT * FROM MountType")}
        displays = {}
        for r in conn.execute("SELECT MountID, CreatureDisplayInfoID FROM "
                              "MountXDisplay ORDER BY MountID, ID"):
            displays.setdefault(r["MountID"], []).append(
                r["CreatureDisplayInfoID"])
        mounts = []
        for r in conn.execute(
                "SELECT m.ID, m.Name_lang, m.SourceSpellID, m.MountTypeID,"
                " m.SourceTypeEnum, m.Flags, m.Description_lang,"
                " m.SourceText_lang FROM Mount m ORDER BY m.ID"):
            sname = spell_names.get(r["SourceSpellID"], ("", ""))[0]
            mt = type_names.get(r["MountTypeID"], {})
            mounts.append({
                "id": r["ID"], "name": r["Name_lang"] or "",
                "spell": r["SourceSpellID"], "spell_name": sname,
                "type": r["MountTypeID"],
                "kind": (mt["Type"] if mt else 0) or 0,
                "flags": r["Flags"] or 0,
                "source": r["SourceTypeEnum"] or 0,
                "displays": sorted(set(displays.get(r["ID"], []))),
            })
        with open(OUT_MOUNTS, "w", encoding="utf-8") as f:
            json.dump(mounts, f, ensure_ascii=False, indent=1)
    finally:
        conn.close()


def check_package():
    """Verify a built package (exit codes mirror build_forever_bridge)."""
    missing = [p for p in (OUT_DB, OUT_JSONL, OUT_BY_NAME, OUT_TALENTS,
                           OUT_TRAINERS, OUT_RACES, OUT_PROCS, OUT_ITEMS,
                           OUT_ZONES, OUT_POINTS, OUT_TAXI, OUT_CREATURES,
                           OUT_SPELL_META, OUT_MOUNTS)
               if not os.path.exists(p)]
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
    if not meta.get("client_build") or meta.get("client_build") == "unknown":
        problems.append("meta table lacks a resolved client_build "
                        "(rebuild with --client-build or a readable "
                        ".build.info)")
    # World/NPC mirror + curated artifacts.
    conn2 = sqlite3.connect(OUT_DB)
    try:
        spots = {
            "ItemSparse": 19000, "Item": 31000, "AreaTable": 1300,
            "AreaPOI": 300, "AreaTrigger": 300, "TaxiNodes": 100,
            "TaxiPath": 300, "TaxiPathNode": 10000, "Creature": 178,
            "CreatureFamily": 27, "CreatureDisplayInfo": 13000,
            "UiMap": 60, "Map": 70, "ChrSpecialization": 10,
            "SpellPower": 3000, "SpellTargetRestrictions": 4000,
        }
        for table, floor in spots.items():
            n2 = conn2.execute('SELECT COUNT(*) FROM "%s"' % table
                               ).fetchone()[0]
            if n2 < floor:
                problems.append("%s has %d rows (<%d)" % (table, n2, floor))
    except sqlite3.OperationalError as e:
        problems.append("world mirror incomplete: %s" % e)
    finally:
        conn2.close()
    with open(OUT_ITEMS, encoding="utf-8") as f:
        items_text = f.read()
    if "Thunderfury" not in items_text:
        problems.append("items.jsonl lacks Thunderfury")
    with open(OUT_ZONES, encoding="utf-8") as f:
        zones = json.load(f)
    if not any(z["name"] == "Elwynn Forest" for z in zones):
        problems.append("zones.json lacks Elwynn Forest")
    with open(OUT_TAXI, encoding="utf-8") as f:
        taxi = json.load(f)
    if len(taxi.get("nodes", [])) < 100 or len(taxi.get("paths", [])) < 300:
        problems.append("taxi.json too small: %d nodes / %d paths" % (
            len(taxi.get("nodes", [])), len(taxi.get("paths", []))))
    with open(OUT_CREATURES, encoding="utf-8") as f:
        creatures = json.load(f)
    if len(creatures.get("companions", [])) != 178:
        problems.append("creatures.json companions != 178")
    with open(OUT_SPELL_META, encoding="utf-8") as f:
        spell_meta = json.load(f)
    fb = spell_meta.get("133", {})
    if not fb.get("mana") or not fb.get("cast_ms"):
        problems.append("spell_meta.json lacks Fireball (133) mana/cast")
    if len(spell_meta) < 20000:
        problems.append("spell_meta.json only %d entries" % len(spell_meta))
    conn3 = sqlite3.connect(OUT_DB)
    try:
        fb = conn3.execute("SELECT description, description_rendered FROM "
                           "spells WHERE id = 133").fetchone()
        if fb and fb[0] and "$s" in (fb[0] or "") and \
                (not fb[1] or "$s" in fb[1]):
            problems.append("Fireball 133 description tokens not rendered")
    finally:
        conn3.close()
    with open(OUT_MOUNTS, encoding="utf-8") as f:
        mounts = json.load(f)
    if len(mounts) < 100:
        problems.append("mounts.json only %d mounts" % len(mounts))
    if not any(m["name"] == "Brown Horse" for m in mounts):
        problems.append("mounts.json lacks Brown Horse")
    if problems:
        for p in problems:
            print("FAIL:", p)
        return 1
    print("OK: Forever datamine package verified "
          "(%d spells, %d player spells, %d talents; client %s)" % (
              n, players, ntal, meta.get("client_version", "?")))
    return 0


def build_info_versions(base_dir):
    """{product: version} from <base_dir>/.build.info (empty if unreadable).

    Single owner of .build.info parsing: the stamp and the client-freshness
    check both read it, so they cannot disagree about the beta product line.
    """
    versions = {}
    try:
        with open(os.path.join(base_dir, ".build.info"),
                  encoding="utf-8", errors="replace") as f:
            lines = f.read().splitlines()
    except OSError:
        return versions
    for line in lines[1:]:
        parts = line.split("|")
        if len(parts) >= 15:
            product, version = parts[14].strip(), parts[12].strip()
            if product and version:
                versions[product] = version
    return versions


def client_stamp():
    """(version, build) of the installed client this package describes.

    Returns (None, None) when .build.info carries no CLIENT_PRODUCT line, so
    the caller writes "unknown" rather than a stale constant -- the 69893
    constant survived a 69913 re-extraction that way, which is exactly the
    drift this package exists to make visible.
    """
    version = build_info_versions(DEFAULT_BASE_DIR).get(CLIENT_PRODUCT)
    if version:
        return version, version.split(".")[-1]
    return None, None


def package_stamp(db_path=OUT_DB):
    """(client_version, extracted_at_utc) recorded in the package's meta table.

    Single owner of "which build does this package describe": the bundle names
    the zip from it and the freshness check compares it with the client.
    """
    conn = sqlite3.connect(db_path)
    try:
        meta = dict(conn.execute("SELECT k, v FROM meta").fetchall())
    finally:
        conn.close()
    return meta.get("client_version"), meta.get("extracted_at_utc")


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
    client_version, client_build = client_stamp()
    if client_version is None:
        print("WARNING: no %s entry in %s/.build.info -- client_version "
              "stays 'unknown' and --check will fail"
              % (CLIENT_PRODUCT, DEFAULT_BASE_DIR))
    stamp = {
        "client_version": client_version or "unknown",
        "client_build": client_build or "unknown",
        "client_product": CLIENT_PRODUCT,
        "extracted_at_utc": datetime.datetime.now(
            datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        "generator": "tools/build_forever_database.py",
        "source_db": os.path.basename(SRC_DB),
        "dbc_tables": str(13 + len(WORLD_TABLES)),
    }
    conn = sqlite3.connect(SRC_DB)
    try:
        (spells, effects, talents, tabs, skills, sla, races, procs,
         all_names, all_descs, durations, radii, dur_index,
         target_caps) = load(conn)
    finally:
        conn.close()
    data = build(spells, effects, talents, tabs, skills, sla, races, procs,
                 all_names, all_descs, durations, radii, dur_index,
                 target_caps)
    paths = write_package(data, stamp)
    write_world_artifacts()
    paths.update({
        "items": OUT_ITEMS, "zones": OUT_ZONES, "points": OUT_POINTS,
        "taxi": OUT_TAXI, "creatures": OUT_CREATURES,
        "spell_meta": OUT_SPELL_META, "mounts": OUT_MOUNTS,
    })
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
