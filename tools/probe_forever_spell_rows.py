#!/usr/bin/env python3
"""probe_forever_spell_rows.py -- answer spell-row questions from a DBC extraction.

WHAT:  two read-only views over a DB2ToSqlite extraction (default: the Forever
       beta DB at wowheadScrape/dbc_extract/wowsims_forever.db; point --db at
       wowsims.db for the 2.5.5 TBC client):

         --name / --like / --id   forward dossier: every matching row with the
                                  fields a rotation lane gates on -- class set,
                                  level, mana cost, cast time, cooldown trio,
                                  duration, cumulative aura, proc config, and
                                  the full effect list (effect, aura, base
                                  points, trigger spell, mechanic, targets).
         --refs ID                reverse view: every row that *references* an
                                  id (EffectTriggerSpell, EffectMiscValue,
                                  SpellCooldowns.AuraSpellID, SpellPower's
                                  RequiredAuraSpellID, Talent.SpellID /
                                  OverridesSpellID / RequiredSpellID). This is
                                  the "what applies this buff / is this proc
                                  wired at all?" question.

WHEN:  resolving an OPEN probe in docs/forever/beta_day1_probes.md that the
       DBC can answer, so the verdict carries reproducible evidence instead of
       an ad-hoc query transcript. Never needs a client login.

WHY:   the client DBC is the authoritative source of truth (AGENTS.md), and the
       distinction that matters for lanes is player-cast row vs internal row --
       the row with mana cost + GCD is the one a lane can cast (the Fire Nova
       408345-vs-8349 finding). This tool prints those columns side by side so
       that classification is one command, not a session of manual poking.

SAFETY: read-only sqlite; no network, no client process, stdlib only.

Usage:
    python tools/probe_forever_spell_rows.py --name "Holy Shock"
    python tools/probe_forever_spell_rows.py --like "Stormstrike"
    python tools/probe_forever_spell_rows.py --id 1311606 --id 20473
    python tools/probe_forever_spell_rows.py --refs 11078
    python tools/probe_forever_spell_rows.py --db wowheadScrape/dbc_extract/wowsims.db --name "Stormstrike"
"""

import argparse
import os
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_DB = os.path.join(ROOT, "wowheadScrape", "dbc_extract", "wowsims_forever.db")

MS = 1000.0


def _fmt_ms(value):
    if value in (None, 0):
        return "-"
    return "%.1fs" % (value / MS)


def _fmt_ms_raw(value):
    if value in (None, 0):
        return "-"
    return "%dms" % value


def resolve_ids(conn, names, likes, ids):
    """Union of explicit ids plus every id whose client name matches."""
    found = set(ids or [])
    cur = conn.cursor()
    for name in names or []:
        for (sid,) in cur.execute(
            "SELECT ID FROM SpellName WHERE Name_lang = ?", (name,)
        ):
            found.add(sid)
    for pat in likes or []:
        for (sid,) in cur.execute(
            "SELECT ID FROM SpellName WHERE Name_lang LIKE ?", ("%" + pat + "%",)
        ):
            found.add(sid)
    return sorted(found)


def row_dossier(conn, spell_id):
    cur = conn.cursor()
    name = cur.execute(
        "SELECT Name_lang FROM SpellName WHERE ID = ?", (spell_id,)
    ).fetchone()
    subtext = cur.execute(
        "SELECT NameSubtext_lang FROM Spell WHERE ID = ?", (spell_id,)
    ).fetchone()
    klass = cur.execute(
        "SELECT SpellClassSet, SpellClassMask FROM SpellClassOptions WHERE SpellID = ?",
        (spell_id,),
    ).fetchone()
    level = cur.execute(
        "SELECT SpellLevel, BaseLevel, MaxLevel FROM SpellLevels WHERE SpellID = ?",
        (spell_id,),
    ).fetchone()
    power = cur.execute(
        "SELECT PowerType, ManaCost, ManaCostPerLevel, PowerCostPct, RequiredAuraSpellID "
        "FROM SpellPower WHERE SpellID = ? ORDER BY OrderIndex LIMIT 1",
        (spell_id,),
    ).fetchone()
    cds = cur.execute(
        "SELECT CategoryRecoveryTime, RecoveryTime, StartRecoveryTime, AuraSpellID "
        "FROM SpellCooldowns WHERE SpellID = ? LIMIT 1",
        (spell_id,),
    ).fetchone()
    misc = cur.execute(
        "SELECT CastingTimeIndex, DurationIndex, SchoolMask FROM SpellMisc "
        "WHERE SpellID = ? LIMIT 1",
        (spell_id,),
    ).fetchone()
    cast_time = duration = None
    if misc:
        cast_time = cur.execute(
            "SELECT Base FROM SpellCastTimes WHERE ID = ?", (misc[0],)
        ).fetchone()
        duration = cur.execute(
            "SELECT Duration, MaxDuration FROM SpellDuration WHERE ID = ?", (misc[1],)
        ).fetchone()
    aura_opts = cur.execute(
        "SELECT CumulativeAura, ProcChance, ProcCharges, ProcTypeMask, ProcCategoryRecovery "
        "FROM SpellAuraOptions WHERE SpellID = ? LIMIT 1",
        (spell_id,),
    ).fetchone()
    category = cur.execute(
        "SELECT Category, StartRecoveryCategory, ChargeCategory, DispelType, Mechanic "
        "FROM SpellCategories WHERE SpellID = ? LIMIT 1",
        (spell_id,),
    ).fetchone()
    effects = cur.execute(
        "SELECT EffectIndex, Effect, EffectAura, EffectBasePointsF, EffectTriggerSpell, "
        "EffectMiscValue, EffectMechanic, ImplicitTarget, EffectAuraPeriod "
        "FROM SpellEffect WHERE SpellID = ? ORDER BY EffectIndex",
        (spell_id,),
    ).fetchall()
    return {
        "id": spell_id,
        "name": name[0] if name else None,
        "subtext": (subtext[0] if subtext else None),
        "class_set": klass[0] if klass else None,
        "level": level,
        "power": power,
        "cds": cds,
        "cast_time": cast_time[0] if cast_time else None,
        "duration": duration,
        "aura_opts": aura_opts,
        "category": category,
        "effects": effects,
        "school": misc[2] if misc else None,
    }


def print_dossier(conn, spell_id):
    d = row_dossier(conn, spell_id)
    print("=" * 78)
    label = d["name"] or "<no SpellName row>"
    if d["subtext"]:
        label += "  [%s]" % d["subtext"]
    print("%d  %s" % (d["id"], label))
    if d["class_set"] is not None:
        print("  class_set       : %s" % d["class_set"])
    else:
        print("  class_set       : (none -- class-less aura/talent-granted row)")
    if d["level"]:
        print("  levels          : spell=%s base=%s max=%s"
              % (d["level"][0], d["level"][1], d["level"][2]))
    if d["power"]:
        pts = "type=%s mana=%s mana/lvl=%s pct=%s" % (
            d["power"][0], d["power"][1], d["power"][2], d["power"][3])
        if d["power"][4]:
            pts += " requires_aura=%s" % d["power"][4]
        print("  power           : %s" % pts)
    if d["cds"]:
        print("  cooldowns       : category=%s recovery=%s start_recovery=%s aura=%s"
              % (_fmt_ms_raw(d["cds"][0]), _fmt_ms_raw(d["cds"][1]),
                 _fmt_ms_raw(d["cds"][2]), d["cds"][3]))
    print("  cast_time       : %s" % (_fmt_ms_raw(d["cast_time"])))
    if d["duration"]:
        print("  duration        : %s (max %s)"
              % (_fmt_ms(d["duration"][0]), _fmt_ms(d["duration"][1])))
    if d["aura_opts"]:
        print("  aura options    : cumulative=%s proc_chance=%s charges=%s "
              "procmask=%s proc_cd=%s"
              % tuple(d["aura_opts"]))
    if d["category"]:
        print("  categories      : category=%s start_recovery_cat=%s charge_cat=%s "
              "dispel=%s mechanic=%s" % tuple(d["category"]))
    if not d["effects"]:
        print("  effects         : (none)")
    for (idx, effect, aura, base, trigger, misc_value, mechanic, targets, period) in d["effects"]:
        line = ("  effect[%s]       : effect=%s aura=%s base=%s"
                % (idx, effect, aura, base))
        if trigger:
            line += " trigger=%s" % trigger
        if misc_value:
            line += " misc=%s" % misc_value
        if mechanic:
            line += " mechanic=%s" % mechanic
        if period:
            line += " period=%sms" % period
        line += " targets=%s" % (targets or "[]")
        print(line)


def print_refs(conn, target_id):
    """Every row that references target_id -- answers 'what applies this?'.

    Four link shapes, because a spell is referenced differently per mechanic:
    EffectTriggerSpell (proc/chain), EffectBasePointsF (aura-332 learn rows and
    several scripted links carry the id as a *value*), EffectMiscValue (effect
    payload), and the cooldown/requirement columns. A name-text scan runs last:
    engraving and talent text quote ids as $NNNNN / $NNNNNd, which is how the
    2026-09-17 session found the class-less buff rows.
    """
    cur = conn.cursor()
    print("=" * 78)
    print("REFERENCES TO %d" % target_id)
    nm = cur.execute("SELECT Name_lang FROM SpellName WHERE ID = ?", (target_id,)).fetchone()
    print("  target name     : %s" % (nm[0] if nm else "<unnamed>"))

    hits = 0
    for (sid, idx, aura, trigger) in cur.execute(
        "SELECT SpellID, EffectIndex, EffectAura, EffectTriggerSpell FROM SpellEffect "
        "WHERE EffectTriggerSpell = ? ORDER BY SpellID", (target_id,)
    ):
        name = cur.execute("SELECT Name_lang FROM SpellName WHERE ID = ?", (sid,)).fetchone()
        print("  triggers        : %d (%s) effect[%s] aura=%s -> %d"
              % (sid, name[0] if name else "?", idx, aura, target_id))
        hits += 1
    for (sid, idx, effect, aura, base) in cur.execute(
        "SELECT SpellID, EffectIndex, Effect, EffectAura, EffectBasePointsF FROM SpellEffect "
        "WHERE EffectBasePointsF = ? ORDER BY SpellID", (float(target_id),)
    ):
        name = cur.execute("SELECT Name_lang FROM SpellName WHERE ID = ?", (sid,)).fetchone()
        print("  base-point link : %d (%s) effect[%s] effect=%s aura=%s base=%s"
              % (sid, name[0] if name else "?", idx, effect, aura, base))
        hits += 1
    for (sid, misc_value, aura, effect) in cur.execute(
        "SELECT SpellID, EffectMiscValue, EffectAura, Effect FROM SpellEffect "
        "WHERE EffectMiscValue = ? ORDER BY SpellID", (target_id,)
    ):
        name = cur.execute("SELECT Name_lang FROM SpellName WHERE ID = ?", (sid,)).fetchone()
        print("  misc reference  : %d (%s) effect=%s aura=%s misc=%s"
              % (sid, name[0] if name else "?", effect, aura, misc_value))
        hits += 1
    for (sid,) in cur.execute(
        "SELECT SpellID FROM SpellCooldowns WHERE AuraSpellID = ?", (target_id,)
    ):
        print("  cooldown aura   : %d" % sid)
        hits += 1
    for (sid,) in cur.execute(
        "SELECT SpellID FROM SpellPower WHERE RequiredAuraSpellID = ?", (target_id,)
    ):
        name = cur.execute("SELECT Name_lang FROM SpellName WHERE ID = ?", (sid,)).fetchone()
        print("  requires aura   : %d (%s)" % (sid, name[0] if name else "?"))
        hits += 1
    for (tid, spell_id, overrides, required, tab, tier) in cur.execute(
        "SELECT ID, SpellID, OverridesSpellID, RequiredSpellID, TabID, TierID FROM Talent "
        "WHERE SpellID = ? OR OverridesSpellID = ? OR RequiredSpellID = ?",
        (target_id, target_id, target_id),
    ):
        print("  talent row      : id=%d grants=%s overrides=%s requires=%s tab=%s tier=%s"
              % (tid, spell_id, overrides, required, tab, tier))
        hits += 1
    token = "$%d" % target_id
    for (sid, desc, aura_desc) in cur.execute(
        "SELECT s.ID, s.Description_lang, s.AuraDescription_lang FROM Spell s "
        "WHERE s.Description_lang LIKE ? OR s.AuraDescription_lang LIKE ?",
        ("%" + token + "%", "%" + token + "%"),
    ):
        name = cur.execute("SELECT Name_lang FROM SpellName WHERE ID = ?", (sid,)).fetchone()
        text = desc or aura_desc or ""
        for part in text.replace("\\n", " ").split(". "):
            if token in part:
                print("  text mention    : %d (%s) %s"
                      % (sid, name[0] if name else "?", part.strip()[:150]))
                break
        hits += 1
    if not hits:
        print("  (no references found -- nothing in this build wires it:"
              " no trigger, no base-point link, no misc payload, no talent row,"
              " and no text mention)")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--db", default=DEFAULT_DB)
    ap.add_argument("--name", action="append", help="exact client name (repeatable)")
    ap.add_argument("--like", action="append", help="name substring (repeatable)")
    ap.add_argument("--id", action="append", type=int, help="explicit spell id (repeatable)")
    ap.add_argument("--refs", type=int, help="reverse view: who references this id")
    args = ap.parse_args()

    if not os.path.exists(args.db):
        print("FAIL: DB not found: %s" % args.db)
        return 2
    conn = sqlite3.connect(args.db)
    print("DB: %s" % os.path.relpath(os.path.abspath(args.db), ROOT))

    if args.refs is not None:
        print_refs(conn, args.refs)

    ids = resolve_ids(conn, args.name, args.like, args.id)
    if not (args.name or args.like or args.id):
        if args.refs is None:
            ap.print_help()
            return 2
    elif not ids:
        print("no rows matched -- names=%s likes=%s ids=%s"
              % (args.name, args.like, args.id))
        return 1
    for spell_id in ids:
        print_dossier(conn, spell_id)
    print("=" * 78)
    print("rows: %d" % len(ids))
    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
