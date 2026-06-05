#!/usr/bin/env python3
"""
Bulk data fetcher: Downloads all spell/item/NPC/quest data from lexxer.org
for both TBC and Vanilla, and regenerates wowhead_data JSON files.

Usage:
    python build_tools/fetch_all_lexxer_data.py [--spells] [--items] [--npcs] [--quests] [--all]

Options:
    --spells    Fetch and merge spell data for both expansions
    --items     Fetch and merge item data for both expansions
    --npcs      Fetch and rebuild NPC index for both expansions
    --quests    Fetch quest data for both expansions
    --all       Fetch everything (default if no flags given)

Output files (in wowhead_data/):
    spell_list_tbc.json, spell_list_vanilla.json
    spell_index_tbc.json, spell_index_vanilla.json
    item_index_tbc.json, item_index_vanilla.json
    npc_index_tbc.json
"""

import json
import os
import sys
import urllib.request
from datetime import datetime

LEXXER_API = "https://lexxer.org/api/v1"
WOWHEAD_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "wowhead_data"
)
TIMEOUT = 30
MIN_SPELLS = 500
KNOWN_CREATURE_TYPES = {
    "Beast", "Critter", "Demon", "Dragonkin", "Elemental",
    "Giant", "Humanoid", "Mechanical", "Undead",
}


def fetch_list(resource, game):
    """Fetch all entries for a resource+game from lexxer.org."""
    url = f"{LEXXER_API}/{resource}?game={game}"
    print(f"  Fetching {url} ...")
    resp = urllib.request.urlopen(url, timeout=TIMEOUT)
    data = json.loads(resp.read())
    if not data.get("ok"):
        print(f"  ERROR: API returned ok=false for {resource}/{game}")
        return []
    entries = data.get("data", [])
    print(f"  Got {len(entries)} {resource} for {game}")
    return entries


def load_json(path):
    """Load a JSON file, return empty dict/list on failure."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_json(path, data):
    """Save data to a JSON file with consistent formatting."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"  Wrote {path} ({os.path.getsize(path)} bytes)")


def merge_spell_data(existing_path, lexxer_entries):
    """Merge lexxer spell entries into existing spell list. Returns (merged_list, new_count)."""
    existing = load_json(existing_path)
    if not isinstance(existing, list):
        existing = []
    existing_ids = set(s["id"] for s in existing)
    new_count = 0
    for entry in lexxer_entries:
        if entry["id"] not in existing_ids:
            existing.append(entry)
            existing_ids.add(entry["id"])
            new_count += 1
    existing.sort(key=lambda x: x.get("id", 0))
    return existing, new_count


def merge_spell_index(existing_path, lexxer_entries):
    """Merge lexxer entries into spell index (id->name mapping). Returns (merged, new_count)."""
    existing = load_json(existing_path)
    if not isinstance(existing, dict):
        existing = {}
    new_count = 0
    for entry in lexxer_entries:
        sid = str(entry["id"])
        if sid not in existing:
            existing[sid] = entry.get("name", "?")
            new_count += 1
    sorted_idx = {k: existing[k] for k in sorted(existing.keys(), key=lambda x: int(x))}
    return sorted_idx, new_count


def merge_item_index(existing_path, lexxer_entries):
    """Merge lexxer entries into item index. Returns (merged, new_count)."""
    existing = load_json(existing_path)
    if not isinstance(existing, dict):
        existing = {}
    new_count = 0
    for entry in lexxer_entries:
        iid = str(entry["id"])
        if iid not in existing:
            existing[iid] = {
                "name": entry.get("name", ""),
                "quality": entry.get("quality", 0),
                "ilvl": entry.get("ilvl", 0),
                "slot": entry.get("slot") or entry.get("item_class_name", ""),
                "subclass": entry.get("item_subclass_name") or "",
                "required_level": entry.get("required_level") or 0,
            }
            new_count += 1
    sorted_idx = {k: existing[k] for k in sorted(existing.keys(), key=lambda x: int(x))}
    return sorted_idx, new_count


def clean_creature_type(ct):
    """Clean creature type parsing artifacts like '- 55 Beast'."""
    if not ct:
        return None
    if ct.startswith("- "):
        parts = ct.split(" ", 2)
        if len(parts) >= 3 and parts[2] in KNOWN_CREATURE_TYPES:
            return parts[2]
        if len(parts) >= 2 and parts[1] in KNOWN_CREATURE_TYPES:
            return parts[1]
    if ct in KNOWN_CREATURE_TYPES:
        return ct
    return ct


def build_npc_index(npc_list):
    """Build NPC index from list data with only non-null fields."""
    index = {}
    for npc in npc_list:
        entry = {}
        for field in ["name", "level", "creature_type", "role", "difficulty", "location"]:
            val = npc.get(field)
            if val is not None and val != "":
                entry[field] = val
        ct = entry.get("creature_type")
        if ct:
            cleaned = clean_creature_type(ct)
            if cleaned:
                entry["creature_type"] = cleaned
            else:
                del entry["creature_type"]
        if entry.get("level") == -1:
            del entry["level"]
        if len(entry) > 1:
            index[str(npc["id"])] = entry
    return {k: index[k] for k in sorted(index.keys(), key=lambda x: int(x))}


def fetch_spells():
    """Fetch and merge spell data for both expansions."""
    print("\n=== Spells ===")
    for game in ["tbc", "vanilla"]:
        print(f"\nFetching {game.upper()} spells...")
        entries = fetch_list("spells", game)
        if not entries:
            print(f"  ERROR: No {game} spells fetched")
            continue
        if len(entries) < MIN_SPELLS:
            print(f"  ERROR: Too few {game} spells ({len(entries)} < {MIN_SPELLS})")
            continue

        list_path = os.path.join(WOWHEAD_DIR, f"spell_list_{game}.json")
        idx_path = os.path.join(WOWHEAD_DIR, f"spell_index_{game}.json")

        merged_list, list_new = merge_spell_data(list_path, entries)
        save_json(list_path, merged_list)
        print(f"  spell_list_{game}.json: +{list_new} new, total {len(merged_list)}")

        merged_idx, idx_new = merge_spell_index(idx_path, entries)
        save_json(idx_path, merged_idx)
        print(f"  spell_index_{game}.json: +{idx_new} new, total {len(merged_idx)}")


def fetch_items():
    """Fetch and merge item data for both expansions."""
    print("\n=== Items ===")
    for game in ["tbc", "vanilla"]:
        print(f"\nFetching {game.upper()} items...")
        entries = fetch_list("items", game)
        if not entries:
            print(f"  WARNING: No {game} items fetched")
            continue

        idx_path = os.path.join(WOWHEAD_DIR, f"item_index_{game}.json")
        merged, new_count = merge_item_index(idx_path, entries)
        save_json(idx_path, merged)
        print(f"  item_index_{game}.json: +{new_count} new, total {len(merged)}")


def fetch_npcs():
    """Fetch and rebuild NPC index for TBC."""
    print("\n=== NPCs ===")
    print("\nFetching TBC NPCs...")
    entries = fetch_list("npcs", "tbc")
    if not entries:
        print("  WARNING: No TBC NPCs fetched")
        return

    index = build_npc_index(entries)
    idx_path = os.path.join(WOWHEAD_DIR, "npc_index_tbc.json")

    # Don't overwrite enriched data — only write if existing file is missing
    # or has fewer entries (list-only data is sparse; enriched data is better)
    existing = load_json(idx_path)
    if isinstance(existing, dict) and len(existing) > len(index):
        msg = f"  Skipping npc_index_tbc.json: existing={len(existing)} (enriched) > list-only={len(index)}"
        print(msg)
        return

    save_json(idx_path, index)
    print(f"  npc_index_tbc.json: {len(index)} entries")

    # Stats
    has_type = sum(1 for v in index.values() if "creature_type" in v)
    has_diff = sum(1 for v in index.values() if "difficulty" in v)
    boss_count = sum(1 for v in index.values() if v.get("difficulty") == "Boss")
    print(f"  creature_type: {has_type}, difficulty: {has_diff}, bosses: {boss_count}")


def fetch_quests():
    """Fetch quest data for both expansions."""
    print("\n=== Quests ===")
    for game in ["tbc", "vanilla"]:
        print(f"\nFetching {game.upper()} quests...")
        entries = fetch_list("quests", game)
        if not entries:
            print(f"  WARNING: No {game} quests fetched")
            continue

        idx_path = os.path.join(WOWHEAD_DIR, f"quest_index_{game}.json")
        index = {}
        for q in entries:
            entry = {}
            for field in ["name", "level", "required_level", "side_name", "xp"]:
                val = q.get(field)
                if val is not None and val != "":
                    entry[field] = val
            if len(entry) > 1:
                index[str(q["id"])] = entry
        sorted_idx = {k: index[k] for k in sorted(index.keys(), key=lambda x: int(x))}
        save_json(idx_path, sorted_idx)
        print(f"  quest_index_{game}.json: {len(sorted_idx)} entries")


def main():
    args = set(sys.argv[1:])
    fetch_all = "--all" in args or not args

    print("=== Lexxer.org Bulk Data Fetcher ===")
    print(f"Output directory: {WOWHEAD_DIR}")
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    if fetch_all or "--spells" in args:
        fetch_spells()
    if fetch_all or "--items" in args:
        fetch_items()
    if fetch_all or "--npcs" in args:
        fetch_npcs()
    if fetch_all or "--quests" in args:
        fetch_quests()

    print("\n=== Done! ===")


if __name__ == "__main__":
    main()
