#!/usr/bin/env python3
"""
json_to_lua_data.py — Convert wowhead_data JSON files to Lua tables embedded in a single module.

Generates: EaxRotations/shared/wowhead_data_bridge_sylvanas.lua

Consumers of this data:
  - spell_rank_resolver_sylvanas.lua  (spell_list → rank chains)
  - spell_corpus_sylvanas.lua         (spell_list index + individual spell detail)
  - dot_refresh_sylvanas.lua          (periodic tick data)
  - spell_flag_checker_sylvanas.lua   (spell flags — but hardcoded table already covers this)
  - gear_sets_sylvanas.lua            (item set data — but hardcoded table already covers this)
"""

import json
import os
import sys
import sqlite3

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED_DIR = os.path.join(ROOT, "EaxRotations", "shared")
OUTPUT_WRAPPER = os.path.join(SHARED_DIR, "wowhead_data_bridge_sylvanas.lua")
OUTPUT_SPELL_TBC = os.path.join(SHARED_DIR, "wowhead_data_bridge_spell_index_tbc_sylvanas.lua")
OUTPUT_SPELL_VANILLA = os.path.join(SHARED_DIR, "wowhead_data_bridge_spell_index_vanilla_sylvanas.lua")
OUTPUT_SPELL_DETAIL = os.path.join(SHARED_DIR, "wowhead_data_bridge_spell_detail_sylvanas.lua")
OUTPUT_ITEM = os.path.join(SHARED_DIR, "wowhead_data_bridge_item_index_sylvanas.lua")
DBC_DB = os.path.join(ROOT, "wowheadScrape", "dbc_extract", "wowsims.db")

def load_json(path):
    with open(path, "rb") as f:
        return json.loads(f.read().decode("utf-8", errors="replace"))

def lua_escape(s):
    """Escape a string for Lua — handle backslashes, quotes, newlines."""
    if s is None:
        return "nil"
    s = str(s)
    s = s.replace("\\", "\\\\")
    s = s.replace('"', '\\"')
    s = s.replace("\n", "\\n")
    s = s.replace("\r", "\\r")
    return '"' + s + '"'

def lua_value(v):
    """Convert a Python value to Lua literal."""
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        if isinstance(v, float) and v == int(v):
            return str(int(v))
        return str(v)
    if isinstance(v, str):
        return lua_escape(v)
    if isinstance(v, list):
        items = [lua_value(x) for x in v]
        return "{" + ", ".join(items) + "}"
    if isinstance(v, dict):
        items = []
        for k, val in v.items():
            items.append(f"[{lua_value(k)}] = {lua_value(val)}")
        return "{" + ", ".join(items) + "}"
    return lua_escape(str(v))

def _is_debug_spell_name(name):
    """Return True for QA/DEBUG/placeholder spell names that should not be emitted."""
    if not name:
        return False
    upper = name.upper()
    return any(p in upper for p in ("DEBUG", "QA DEBUG", "XXXX", "ALEX BUG", "TEST SPELL", "PLACEHOLDER"))


def load_dbc_spells():
    """Load spell data from DBC-extracted SQLite database.
    
    Returns dict keyed by spell_id with fields from the client DB.
    """
    if not os.path.exists(DBC_DB):
        print(f"  WARNING: DBC database not found at {DBC_DB}, skipping DBC merge")
        return {}
    
    conn = sqlite3.connect(DBC_DB)
    cursor = conn.cursor()
    
    # Query to get spell data with related tables
    cursor.execute("""
    SELECT 
        s.ID,
        sn.Name_lang,
        sm.SchoolMask,
        sm.CastingTimeIndex,
        sm.DurationIndex,
        sm.RangeIndex,
        sl.SpellLevel,
        sc.RecoveryTime,
        sc.CategoryRecoveryTime,
        sco.SpellClassSet
    FROM Spell s
    LEFT JOIN SpellName sn ON s.ID = sn.ID
    LEFT JOIN SpellMisc sm ON s.ID = sm.SpellID
    LEFT JOIN SpellLevels sl ON s.ID = sl.SpellID
    LEFT JOIN SpellCooldowns sc ON s.ID = sc.SpellID
    LEFT JOIN SpellClassOptions sco ON s.ID = sco.SpellID
    """)
    
    # School mask mapping (from WoW DBC constants)
    SCHOOL_MAP = {
        1: "physical",
        2: "holy",
        4: "fire",
        8: "nature",
        16: "frost",
        32: "shadow",
        64: "arcane",
    }
    
    # Class set mapping (from SpellClassSet)
    # Verified against DBC: 3=Mage, 4=Warrior, 5=Warlock, 6=Priest, 7=Druid,
    # 8=Rogue, 9=Hunter, 10=Paladin, 11=Shaman
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
    
    result = {}
    for row in cursor.fetchall():
        spell_id = row[0]
        name = row[1] or None
        school_mask = row[2] or 0
        cast_time_idx = row[3]
        duration_idx = row[4]
        range_idx = row[5]
        spell_level = row[6]
        recovery_time = row[7]
        category_recovery = row[8]
        spell_class_set = row[9]
        
        # Determine school from mask
        school = None
        if school_mask:
            for mask, school_name in SCHOOL_MAP.items():
                if school_mask & mask:
                    school = school_name
                    break
        
        # Determine class
        class_name = None
        if spell_class_set and spell_class_set in CLASS_MAP:
            class_name = CLASS_MAP[spell_class_set]
        
        # Convert cast time index to seconds (approximate)
        cast_time = None
        if cast_time_idx == 1:
            cast_time = 0  # Instant
        elif cast_time_idx == 2:
            cast_time = 1.5
        elif cast_time_idx == 3:
            cast_time = 2
        elif cast_time_idx == 4:
            cast_time = 2.5
        elif cast_time_idx == 5:
            cast_time = 3
        elif cast_time_idx == 6:
            cast_time = 3.5
        elif cast_time_idx == 7:
            cast_time = 10
        elif cast_time_idx == 8:
            cast_time = 0
        
        # Cooldown in seconds
        cooldown = None
        if recovery_time and recovery_time > 0:
            cooldown = recovery_time / 1000.0
        elif category_recovery and category_recovery > 0:
            cooldown = category_recovery / 1000.0
        
        result[spell_id] = {
            "name": name,
            "class": class_name,
            "level": spell_level,
            "school": school,
            "cast_time": cast_time,
            "cooldown_seconds": cooldown,
        }
    
    conn.close()
    print(f"  DBC extracted: {len(result)} entries")
    return result


def build_spell_list():
    """Extract spell_list data — the most critical data set.
    
    Format per spell_id:
      {name, required_class, required_level, school, is_heal, aoe, cast_time, rank, gcd, cooldown_seconds}
    
    Positional: 1=name, 2=class, 3=level, 4=school, 5=is_heal, 6=aoe, 7=cast_time, 8=rank, 9=gcd, 10=cooldown_seconds
    """
    result = {"tbc": {}, "vanilla": {}}
    stats = {"tbc": 0, "vanilla": 0}
    
    # Load DBC data as the authoritative source
    dbc_spells = load_dbc_spells()
    
    # Merge with wowhead_data (which has additional fields like is_heal, aoe, rank, gcd)
    for expansion in ("tbc", "vanilla"):
        path = os.path.join(ROOT, "wowhead_data", f"spell_list_{expansion}.json")
        if not os.path.exists(path):
            print(f"  WARNING: {path} not found, skipping")
            continue
        
        data = load_json(path)
        for entry in data:
            sid = entry.get("id")
            if not sid:
                continue
            
            # Start with DBC data if available
            dbc_data = dbc_spells.get(sid, {})
            
            name = dbc_data.get("name") or entry.get("name")
            if _is_debug_spell_name(name):
                continue
            
            result[expansion][sid] = {
                "name": dbc_data.get("name") or entry.get("name"),
                "class": dbc_data.get("class") or entry.get("required_class"),
                "level": dbc_data.get("level") or entry.get("required_level"),
                "school": dbc_data.get("school") or entry.get("school"),
                "is_heal": entry.get("is_heal", False),
                "aoe": entry.get("aoe", False),
                "cast_time": dbc_data.get("cast_time") or entry.get("cast_time"),
                "rank": entry.get("rank"),
                "gcd": entry.get("gcd"),
                "cooldown_seconds": dbc_data.get("cooldown_seconds") or entry.get("cooldown_seconds"),
            }
            stats[expansion] += 1
    
    # Add DBC spells that are missing from wowhead_data (for both expansions).
    # TBC gets the full DBC fallback; vanilla uses DBC as a fallback when JSON
    # is missing/dropped (TBC Anniversary's 2.5.x client is authoritative for
    # spell availability — any spell in the client also existed in Classic).
    wowhead_ids_tbc = set(result["tbc"].keys())
    wowhead_ids_vanilla = set(result["vanilla"].keys())
    added_tbc = 0
    added_vanilla = 0
    for spell_id, dbc_data in dbc_spells.items():
        name = dbc_data.get("name")
        if not name:
            continue
        if _is_debug_spell_name(name):
            continue
        entry = {
            "name": dbc_data.get("name"),
            "class": dbc_data.get("class"),
            "level": dbc_data.get("level"),
            "school": dbc_data.get("school"),
            "is_heal": False,
            "aoe": False,
            "cast_time": dbc_data.get("cast_time"),
            "rank": None,
            "gcd": None,
            "cooldown_seconds": dbc_data.get("cooldown_seconds"),
        }
        if spell_id not in wowhead_ids_tbc:
            result["tbc"][spell_id] = entry
            added_tbc += 1
        if spell_id not in wowhead_ids_vanilla:
            result["vanilla"][spell_id] = entry
            added_vanilla += 1

    print(f"  spell_list_tbc: {stats['tbc']} entries (+{added_tbc} from DBC)")
    print(f"  spell_list_vanilla: {stats['vanilla']} entries (+{added_vanilla} from DBC)")
    return result

def build_spell_detail():
    """Extract individual spell detail: cost, periodic, range, cast_time, duration, school, flags.

    Only includes spells that have at least one useful field beyond what's in spell_list.

    TBC takes precedence over vanilla for shared spell_ids (TBC is the primary
    target). Vanilla is only used as a fallback when no TBC file exists.
    """
    detail = {}
    tbc_seen = set()
    stats = {"total": 0, "with_cost": 0, "with_periodic": 0, "with_flags": 0, "with_range": 0,
             "tbc_entries": 0, "vanilla_only": 0}

    # Pass 1: TBC (primary)
    tbc_dir = os.path.join(ROOT, "wowhead_data", "spells", "tbc")
    if os.path.exists(tbc_dir):
        for fname in os.listdir(tbc_dir):
            if not fname.endswith(".json"):
                continue

            spell_id = int(fname[:-5])
            path = os.path.join(tbc_dir, fname)

            try:
                raw = load_json(path)
                data = raw.get("data", raw)
                if not isinstance(data, dict):
                    continue
            except Exception:
                continue

            entry = _build_spell_detail_entry(data, stats)
            if entry:
                detail[spell_id] = entry
                tbc_seen.add(spell_id)
                stats["tbc_entries"] += 1

    # Pass 2: vanilla (only for spell_ids not already covered by TBC)
    vanilla_dir = os.path.join(ROOT, "wowhead_data", "spells", "vanilla")
    if os.path.exists(vanilla_dir):
        for fname in os.listdir(vanilla_dir):
            if not fname.endswith(".json"):
                continue

            spell_id = int(fname[:-5])
            if spell_id in tbc_seen:
                # TBC takes precedence — skip
                continue
            path = os.path.join(vanilla_dir, fname)

            try:
                raw = load_json(path)
                data = raw.get("data", raw)
                if not isinstance(data, dict):
                    continue
            except Exception:
                continue

            entry = _build_spell_detail_entry(data, stats)
            if entry:
                detail[spell_id] = entry
                stats["vanilla_only"] += 1

    stats["total"] = len(detail)
    print(f"  spell_detail: {stats['total']} spells with useful data")
    print(f"    tbc primary: {stats['tbc_entries']}, vanilla fallback: {stats['vanilla_only']}")
    print(f"    with cost: {stats['with_cost']}, periodic: {stats['with_periodic']}, flags: {stats['with_flags']}, range: {stats['with_range']}")
    return detail


def _build_spell_detail_entry(data, stats):
    entry = {}
    has_useful = False

    # Cost
    cost = data.get("cost")
    if isinstance(cost, dict) and cost.get("type"):
        entry["cost_type"] = cost["type"]
        entry["cost_amount"] = cost.get("amount")
        has_useful = True
        stats["with_cost"] += 1

    # Periodic
    periodic = data.get("periodic")
    if isinstance(periodic, dict) and periodic.get("interval"):
        entry["periodic_amount"] = periodic.get("amount")
        entry["periodic_school"] = periodic.get("school")
        entry["periodic_interval"] = periodic.get("interval")
        has_useful = True
        stats["with_periodic"] += 1

    # Flags (rare in data, but checked by spell_flag_checker)
    flags = data.get("flags")
    if isinstance(flags, list) and len(flags) > 0:
        entry["flags"] = flags
        has_useful = True
        stats["with_flags"] += 1

    # Range
    rng = data.get("range")
    if rng is not None:
        entry["range"] = rng
        has_useful = True
        stats["with_range"] += 1

    # Cast time (from individual file, may differ from spell_list)
    ct = data.get("cast_time")
    if ct is not None:
        entry["cast_time"] = ct

    # Duration
    dur = data.get("duration")
    if dur is not None:
        entry["duration"] = dur

    # School (from individual file)
    school = data.get("school")
    if school:
        entry["school"] = school

    gcd = data.get("gcd")
    if gcd is not None:
        entry["gcd"] = gcd

    return entry if has_useful else None

def build_item_index():
    """Extract item index data from DBC database (authoritative source).

    Reads from ItemSparse table in wowheadScrape/dbc_extract/wowsims.db
    (WoW client 2.5.5.68101). Falls back to legacy JSON if DBC missing.
    """
    if os.path.exists(DBC_DB):
        conn = sqlite3.connect(DBC_DB)
        cursor = conn.cursor()
        cursor.execute("""
        SELECT ID, Display_lang, ItemLevel, RequiredLevel, OverallQualityID, InventoryType
        FROM ItemSparse
        WHERE Display_lang IS NOT NULL
        """)
        result = {}
        for row in cursor.fetchall():
            item_id, name, ilvl, req_level, quality, inv_type = row
            result[item_id] = {
                "name": name,
                "quality": quality,
                "ilvl": ilvl,
                "slot": inv_type,
                "subclass": None,
                "required_level": req_level,
            }
        conn.close()
        print(f"  item_index_tbc: {len(result)} entries (from DBC)")
        return result

    path = os.path.join(ROOT, "wowhead_data", "item_index_tbc.json")
    if not os.path.exists(path):
        print("  WARNING: no DBC and no item_index_tbc.json — item_index empty")
        return {}

    data = load_json(path)
    result = {}
    for k, v in data.items():
        result[int(k)] = {
            "name": v.get("name"),
            "quality": v.get("quality"),
            "ilvl": v.get("ilvl"),
            "slot": v.get("slot"),
            "subclass": v.get("subclass"),
            "required_level": v.get("required_level"),
        }
    print(f"  item_index_tbc: {len(result)} entries (from legacy JSON)")
    return result

def _write_data_module(path, header_lines, table_name, entries, entry_formatter):
    """Write a single data table to its own file to stay under Lua's constant limit."""
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        for line in header_lines:
            f.write(line + "\n")
        f.write("\nlocal M = {}\n\n")
        f.write(f"M.{table_name} = {{\n")
        items = [entry_formatter(k, v) for k, v in sorted(entries.items())]
        f.write(",\n".join(items))
        f.write("\n}\n\n")
        f.write(f"return M.{table_name}\n")
    size = os.path.getsize(path)
    print(f"  Generated: {path}")
    print(f"  Size: {size:,} bytes")


def write_lua_module(spell_list, spell_detail, item_index):
    """Write the split Lua data modules."""

    # ---- spell_index_tbc ----
    def fmt_spell_index(sid, e):
        fields = [
            lua_escape(e["name"]),
            lua_escape(e["class"]),
            lua_value(e["level"]),
            lua_escape(e["school"]),
            "true" if e["is_heal"] else "false",
            "true" if e["aoe"] else "false",
            lua_value(e["cast_time"]),
            lua_value(e["rank"]),
            lua_value(e.get("gcd")),
            lua_value(e.get("cooldown_seconds")),
        ]
        return f"    [{sid}] = {{{', '.join(fields)}}}"

    _write_data_module(
        OUTPUT_SPELL_TBC,
        [
            "-- ============================================================================",
            "-- Shared Data: Wowhead Spell Index TBC",
            "-- ============================================================================",
            "-- Generated by: build_tools/json_to_lua_data.py",
            "-- ============================================================================",
            "-- Format: [spell_id] = {name, class, level, school, is_heal, aoe, cast_time, rank, gcd, cooldown_seconds}",
            "-- Positional: 1=name, 2=class, 3=level, 4=school, 5=is_heal, 6=aoe, 7=cast_time, 8=rank, 9=gcd, 10=cooldown_seconds",
            "-- ============================================================================",
        ],
        "spell_index_tbc",
        spell_list.get("tbc", {}),
        fmt_spell_index,
    )

    # ---- spell_index_vanilla ----
    _write_data_module(
        OUTPUT_SPELL_VANILLA,
        [
            "-- ============================================================================",
            "-- Shared Data: Wowhead Spell Index Vanilla",
            "-- ============================================================================",
            "-- Generated by: build_tools/json_to_lua_data.py",
            "-- ============================================================================",
            "-- Format: [spell_id] = {name, class, level, school, is_heal, aoe, cast_time, rank, gcd, cooldown_seconds}",
            "-- Positional: 1=name, 2=class, 3=level, 4=school, 5=is_heal, 6=aoe, 7=cast_time, 8=rank, 9=gcd, 10=cooldown_seconds",
            "-- ============================================================================",
        ],
        "spell_index_vanilla",
        spell_list.get("vanilla", {}),
        fmt_spell_index,
    )

    # ---- spell_detail ----
    def fmt_spell_detail(sid, e):
        fields = [
            lua_escape(e.get("cost_type")),           # 1
            lua_value(e.get("cost_amount")),          # 2
            lua_value(e.get("range")),                # 3
            lua_value(e.get("cast_time")),            # 4
            lua_value(e.get("duration")),             # 5
            lua_value(e.get("periodic_amount")),      # 6
            lua_escape(e.get("periodic_school")),    # 7
            lua_value(e.get("periodic_interval")),   # 8
            lua_value(e.get("flags")),                # 9
            lua_escape(e.get("school")),              # 10
            lua_value(e.get("gcd")),                  # 11
        ]
        return f"    [{sid}] = {{{', '.join(fields)}}}"

    _write_data_module(
        OUTPUT_SPELL_DETAIL,
        [
            "-- ============================================================================",
            "-- Shared Data: Wowhead Spell Detail",
            "-- ============================================================================",
            "-- Generated by: build_tools/json_to_lua_data.py",
            "-- ============================================================================",
            "-- Format: [spell_id] = {cost_type, cost_amount, range, cast_time, duration,",
            "--                       periodic_amount, periodic_school, periodic_interval, flags, school, gcd}",
            "-- Only spells with useful data beyond spell_index are included.",
            "-- ============================================================================",
        ],
        "spell_detail",
        spell_detail,
        fmt_spell_detail,
    )

    # ---- item_index ----
    def fmt_item_index(iid, e):
        fields = [
            lua_escape(e.get("name")),
            lua_value(e.get("quality")),
            lua_value(e.get("ilvl")),
            lua_escape(e.get("slot")),
            lua_escape(e.get("subclass")),
            lua_value(e.get("required_level")),
        ]
        return f"    [{iid}] = {{{', '.join(fields)}}}"

    _write_data_module(
        OUTPUT_ITEM,
        [
            "-- ============================================================================",
            "-- Shared Data: Wowhead Item Index",
            "-- ============================================================================",
            "-- Generated by: build_tools/json_to_lua_data.py",
            "-- ============================================================================",
            "-- Format: [item_id] = {name, quality, ilvl, slot, subclass, required_level}",
            "-- ============================================================================",
        ],
        "item_index",
        item_index,
        fmt_item_index,
    )

    # ---- WRAPPER ----
    with open(OUTPUT_WRAPPER, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- ============================================================================\n")
        f.write("-- Shared Data: Wowhead Data Bridge (Embedded Lua Tables)\n")
        f.write("-- ============================================================================\n")
        f.write("-- What:   Pre-extracted spell, item, and NPC data converted from wowhead JSON.\n")
        f.write("-- When:   Module load (cached). Used by spell_rank_resolver, spell_corpus,\n")
        f.write("--         dot_refresh, and spell_flag_checker.\n")
        f.write("-- Why:    Ship constraint — only .lua files allowed in EaxRotations.\n")
        f.write("--         All data embedded as Lua tables; no io.open or JSON parsing needed.\n")
        f.write("-- Safety: Read-only. All data is static at module load time.\n")
        f.write("--\n")
        f.write("-- Generated by: build_tools/json_to_lua_data.py\n")
        f.write("-- ============================================================================\n\n")

        f.write("local M = {}\n\n")

        f.write("-- ============================================================================\n")
        f.write("-- Sub-modules — split to avoid Lua's 65,536 constant-per-function limit\n")
        f.write("-- ============================================================================\n\n")

        f.write('M.spell_index_tbc    = require("shared/wowhead_data_bridge_spell_index_tbc_sylvanas")\n')
        f.write('M.spell_index_vanilla= require("shared/wowhead_data_bridge_spell_index_vanilla_sylvanas")\n')
        f.write('M.item_index         = require("shared/wowhead_data_bridge_item_index_sylvanas")\n')
        f.write('M.spell_detail       = require("shared/wowhead_data_bridge_spell_detail_sylvanas")\n')
        f.write("\n")

        f.write("-- ============================================================================\n")
        f.write("-- Public API — mimics the old io.open-based interfaces\n")
        f.write("-- ============================================================================\n\n")

        f.write("--- Get spell index entry (lightweight, from spell_list data).\n")
        f.write("--- Returns positional array {name, class, level, school, is_heal, aoe, cast_time, rank, gcd, cooldown_seconds}\n")
        f.write("--- @param spell_id number\n")
        f.write("--- @param expansion string|nil 'tbc' or 'vanilla' (default: 'tbc')\n")
        f.write("function M.get_spell_index(spell_id, expansion)\n")
        f.write("    if not spell_id then return nil end\n")
        f.write("    expansion = expansion or 'tbc'\n")
        f.write("    if expansion == 'vanilla' then\n")
        f.write("        return M.spell_index_vanilla[spell_id]\n")
        f.write("    end\n")
        f.write("    return M.spell_index_tbc[spell_id]\n")
        f.write("end\n\n")

        f.write("--- Get spell detail entry (from individual spell files).\n")
        f.write("--- Returns positional array {cost_type, cost_amount, range, cast_time, duration,\n")
        f.write("---                           periodic_amount, periodic_school, periodic_interval,\n")
        f.write("---                           flags, school}\n")
        f.write("--- @param spell_id number\n")
        f.write("function M.get_spell_detail(spell_id)\n")
        f.write("    if not spell_id then return nil end\n")
        f.write("    return M.spell_detail[spell_id]\n")
        f.write("end\n\n")

        f.write("--- Get all spell IDs for a class from the spell index.\n")
        f.write("--- @param class_name string Class name (e.g., 'Mage')\n")
        f.write("--- @param expansion string|nil\n")
        f.write("--- @return table Array of {id, name, school, is_heal, aoe, cast_time, level}\n")
        f.write("function M.get_class_spells(class_name, expansion)\n")
        f.write("    if not class_name then return {} end\n")
        f.write("    expansion = expansion or 'tbc'\n")
        f.write("    local index = (expansion == 'vanilla') and M.spell_index_vanilla or M.spell_index_tbc\n")
        f.write("    local result = {}\n")
        f.write("    local n = 0\n")
        f.write("    for id, entry in pairs(index) do\n")
        f.write("        if entry[2] == class_name then\n")
        f.write("            n = n + 1\n")
        f.write("            result[n] = {\n")
        f.write("                id = id,\n")
        f.write("                name = entry[1],\n")
        f.write("                school = entry[4],\n")
        f.write("                is_heal = entry[5],\n")
        f.write("                aoe = entry[6],\n")
        f.write("                cast_time = entry[7],\n")
        f.write("                level = entry[3],\n")
        f.write("            }\n")
        f.write("        end\n")
        f.write("    end\n")
        f.write("    table.sort(result, function(a, b) return (a.id or 0) < (b.id or 0) end)\n")
        f.write("    return result\n")
        f.write("end\n\n")

        f.write("--- Get item index entry.\n")
        f.write("--- @param item_id number\n")
        f.write("--- @return table|nil {name, quality, ilvl, slot, subclass, required_level}\n")
        f.write("function M.get_item_index(item_id)\n")
        f.write("    if not item_id then return nil end\n")
        f.write("    return M.item_index[item_id]\n")
        f.write("end\n\n")

        f.write("--- Get the full spell index table for an expansion.\n")
        f.write("--- @param expansion string|nil 'tbc' or 'vanilla' (default: 'tbc')\n")
        f.write("--- @return table\n")
        f.write("function M.get_full_index(expansion)\n")
        f.write("    expansion = expansion or 'tbc'\n")
        f.write("    if expansion == 'vanilla' then\n")
        f.write("        return M.spell_index_vanilla\n")
        f.write("    end\n")
        f.write("    return M.spell_index_tbc\n")
        f.write("end\n\n")

        f.write("return M\n")

    size = os.path.getsize(OUTPUT_WRAPPER)
    print(f"\n  Generated: {OUTPUT_WRAPPER}")
    print(f"  Size: {size:,} bytes")

def main():
    print("Converting wowhead_data JSON to Lua tables...\n")
    
    print("[1/3] Building spell index...")
    spell_list = build_spell_list()
    
    print("\n[2/3] Building spell detail...")
    spell_detail = build_spell_detail()
    
    print("\n[3/3] Building item index...")
    item_index = build_item_index()
    
    print("\nWriting Lua module...")
    write_lua_module(spell_list, spell_detail, item_index)
    
    print("\nDone!")

if __name__ == "__main__":
    main()
