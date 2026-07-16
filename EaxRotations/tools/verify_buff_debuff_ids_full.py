#!/usr/bin/env python3
"""Full three-expansion verification of every buff/debuff table spell ID.

For each ID extracted from *BUFF*/*DEBUFF*/*AURA* tables:
  1. Local: TBC DBC + TBC/Vanilla spell indexes
  2. Online: lexxer.org for game=classic, tbc, wotlk (name/class/level)

Usage:
  python EaxRotations/tools/verify_buff_debuff_ids_full.py
  python EaxRotations/tools/verify_buff_debuff_ids_full.py --resume
  python EaxRotations/tools/verify_buff_debuff_ids_full.py --limit 50
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
import time
import urllib.error
import urllib.request
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
EAX = os.path.join(ROOT, "EaxRotations")
TOOLS = os.path.join(EAX, "tools")
CACHE_PATH = os.path.join(TOOLS, "_lexxer_spell_cache.json")
EXTRACT_PATH = os.path.join(TOOLS, "_buff_debuff_ids_extracted.json")
REPORT_JSON = os.path.join(TOOLS, "buff_debuff_full_verification.json")
REPORT_MD = os.path.join(TOOLS, "buff_debuff_full_verification.md")

GAMES = ("classic", "tbc", "wotlk")


def _record(id_to_meta, sid: int, name: str, rel: str, kind: str) -> None:
    id_to_meta[sid]["names"].add(name)
    id_to_meta[sid]["files"].add(rel)
    id_to_meta[sid]["kind"].add(kind)


def _strip_lua_comment(line: str) -> str:
    """Remove Lua `--` comments without eating later lines (must run per-line)."""
    # Prefer full-line comments
    if line.lstrip().startswith("--"):
        return ""
    # Inline: cut at first -- that is not inside a string (simple heuristic)
    out = []
    in_sq = in_dq = False
    i = 0
    while i < len(line):
        ch = line[i]
        if ch == "'" and not in_dq:
            in_sq = not in_sq
            out.append(ch)
        elif ch == '"' and not in_sq:
            in_dq = not in_dq
            out.append(ch)
        elif ch == "-" and not in_sq and not in_dq and i + 1 < len(line) and line[i + 1] == "-":
            break
        else:
            out.append(ch)
        i += 1
    return "".join(out)


def _extract_brace_block(lines: list[str], start: int) -> tuple[str, int]:
    """Return (block_text, end_line_index) for `{...}` starting at start line.

    Comments are stripped **per line** before joining so multi-line tables with
    trailing `-- notes` still inventory every ID (not only those before the
    first comment).
    """
    cleaned = []
    first = _strip_lua_comment(lines[start])
    cleaned.append(first)
    depth = first.count("{") - first.count("}")
    j = start
    while depth > 0 and j + 1 < len(lines):
        j += 1
        cl = _strip_lua_comment(lines[j])
        if not cl.strip():
            # still need braces from raw? skip pure comments
            continue
        cleaned.append(cl)
        depth += cl.count("{") - cl.count("}")
        if j - start > 200:
            break
    return " ".join(cleaned), j


def _numeric_ids(body: str) -> list[int]:
    num_pat = re.compile(r"\b(\d{3,6})\b")
    return [int(x) for x in num_pat.findall(body) if 100 <= int(x) <= 90000]


def extract_ids() -> dict:
    """Inventory rotation spell IDs from buff/debuff tables AND cast/rank ladders."""
    # A) Named buff/debuff/aura tables
    buff_var = re.compile(
        r"(?i)^\s*(?:local\s+)?([A-Za-z0-9_]*?(?:BUFF|DEBUFF|AURA|_buff|_debuff|Buffs|Debuffs|buffs|debuffs)[A-Za-z0-9_]*)\s*=\s*\{"
    )
    # B) Cast/rank ladders: ids = { ... }, define("X", { ... }), spell_action({ ... })
    ids_field = re.compile(r"(?i)\bids\s*=\s*\{")
    define_arr = re.compile(r'\bdefine\s*\(\s*"([^"]+)"\s*,\s*\{')
    # Scalar: define("Name", 46924, "Label") or define("Name", 46924)
    define_scalar = re.compile(r'\bdefine\s*\(\s*"([^"]+)"\s*,\s*(\d{2,6})\s*[,)]')
    spell_action_arr = re.compile(r"\bspell_action\s*\(\s*\{")
    spell_action_scalar = re.compile(r"\bspell_action\s*\(\s*(\d{2,6})\s*[,)]")
    # C) Pure numeric local rank arrays e.g. local FOO_RANKS = { 1, 2, 3 }
    # Exclude item/map/npc tables (*POTION*_IDS, HEALTHSTONE_IDS, MAP_IDS, etc.)
    # NOTE: SUCC_LASH_IDS and similar pet *spell* ladders are intentionally included.
    rank_var = re.compile(
        r"(?i)^\s*(?:local\s+)?([A-Za-z0-9_]*(?:RANKS?|RANK_IDS|SPELL_IDS|_IDS|_CAST|_DETECT|CAST|DETECT|AURAS)[A-Za-z0-9_]*)\s*=\s*\{"
    )
    # D) Unnamed ALL_CAPS ladders used as buff/debuff/proc sets:
    #    FROST_FEVER, BLOOD_PLAGUE, COMMON_SNARES, MISSILE_BARRAGE_PROC, FIRE_RESIST_TOTEM, etc.
    allcaps_ladder = re.compile(
        r"^\s*(?:local\s+)?([A-Z][A-Z0-9_]{2,})\s*=\s*\{"
    )
    allcaps_spellish = re.compile(
        r"(?i)(FEVER|PLAGUE|SNARE|ROOT|STUN|SLOW|PROC|TOTEM|AURA|SHIELD|SEAL|"
        r"BLESSING|CURSE|DISEASE|POISON|DEBUFF|BUFF|STRIKE|SHOT|FORM|"
        r"PRESENCE|ASPECT|SHOUT|WARD|BARRIER|BOLT|BLAST|STING|TRAP|"
        r"FIREBALL|FROSTBOLT|SHADOW|HOLY|NATURE|ARCANE)"
    )
    non_spell_name = re.compile(
        r"(?i)(potion|healthstone|manastone|dark_rune|weapon_buff|item|map_ids|bg_map|"
        r"food|flask|elixir|bandage|scroll|gem|trinket|npc|quest|object|vendor|"
        r"fear_caster|empty|schema|state|const|config|settings|defaults|"
        r"colors?|priority|mode|flags?|opts?|options|cache|throttle)"
    )

    id_to_meta: dict[int, dict] = defaultdict(lambda: {"names": set(), "files": set(), "kind": set()})
    table_count = 0
    skip_name_bits = ("wowhead_data_bridge", "spell_id_table", "_dbc_spell", "spell_corpus", "item_index")

    for dirpath, dirnames, files in os.walk(EAX):
        dirnames[:] = [
            d
            for d in dirnames
            if d not in (".git", "tests", "tools")
            and "wowhead_data_bridge" not in d
            and "dbc_extract" not in d
        ]
        for fn in files:
            if not fn.endswith(".lua"):
                continue
            if any(b in fn for b in skip_name_bits):
                continue
            path = os.path.join(dirpath, fn)
            rel = os.path.relpath(path, ROOT).replace("\\", "/")
            if rel.endswith("tbc_data_sylvanas.lua") or rel.endswith("wotlk_data_sylvanas.lua"):
                continue
            if "consumable" in rel and "manager" not in rel:
                # keep consumable_manager (uses buff checks); skip pure item DB dumps if any
                pass
            try:
                lines = open(path, encoding="utf-8", errors="ignore").read().splitlines()
            except OSError:
                continue

            i = 0
            while i < len(lines):
                line = lines[i]
                stripped = line.strip()
                if stripped.startswith("--"):
                    i += 1
                    continue

                recorded = False

                # --- A: buff/debuff/aura named tables ---
                m = buff_var.match(line)
                if m:
                    name = m.group(1)
                    if not re.search(r"(?i)weapon_buff|item_buff|food_buff|flask", name):
                        buf, j = _extract_brace_block(lines, i)
                        ids = _numeric_ids(buf)
                        if ids:
                            lname = name.lower()
                            if "debuff" in lname:
                                kind = "debuff"
                            elif "buff" in lname or "aura" in lname:
                                kind = "buff"
                            else:
                                kind = "unknown"
                            table_count += 1
                            for sid in ids:
                                _record(id_to_meta, sid, name, rel, kind)
                            i = j + 1
                            recorded = True

                if recorded:
                    continue

                # --- C: rank/spell id arrays ---
                m = rank_var.match(line)
                if m:
                    name = m.group(1)
                    if not non_spell_name.search(name):
                        buf, j = _extract_brace_block(lines, i)
                        # pure-ish numeric body
                        body = re.sub(r"^[^{]*\{", "", buf)
                        body = re.sub(r"\}[^}]*$", "", body)
                        if re.search(r"[A-Za-z_]{4,}\s*=", body):
                            i += 1
                            continue
                        ids = _numeric_ids(buf)
                        if ids:
                            table_count += 1
                            for sid in ids:
                                _record(id_to_meta, sid, name, rel, "cast")
                            i = j + 1
                            continue

                # --- D: ALL_CAPS ladders (FROST_FEVER, COMMON_SNARES, MISSILE_BARRAGE_PROC, …) ---
                m = allcaps_ladder.match(line)
                if m:
                    name = m.group(1)
                    if allcaps_spellish.search(name) and not non_spell_name.search(name):
                        buf, j = _extract_brace_block(lines, i)
                        body = re.sub(r"^[^{]*\{", "", buf)
                        body = re.sub(r"\}[^}]*$", "", body)
                        # Allow map style [id] = n but not string keys
                        if re.search(r"[A-Za-z_]{4,}\s*=", body) and not re.search(r"\[\s*\d+\s*\]", body):
                            i += 1
                            continue
                        ids = _numeric_ids(buf)
                        # Heuristic: at least one plausible spell id, table not huge noise
                        if ids and len(ids) <= 80:
                            lname = name.lower()
                            if any(x in lname for x in ("debuff", "snare", "plague", "fever", "disease", "poison", "curse", "root", "stun", "slow")):
                                kind = "debuff"
                            elif any(x in lname for x in ("buff", "aura", "proc", "shield", "seal", "form", "presence", "aspect", "shout", "totem")):
                                kind = "buff"
                            else:
                                kind = "cast"
                            table_count += 1
                            for sid in ids:
                                _record(id_to_meta, sid, name, rel, kind)
                            i = j + 1
                            continue

                # --- B1: ids = { ... } (class_sylvanas spell defs) ---
                if ids_field.search(line):
                    # find the brace start on this line
                    brace_pos = line.find("{", line.lower().find("ids"))
                    if brace_pos >= 0:
                        # synthesize line slice for block extract
                        synth = [" " * brace_pos + line[brace_pos:]]
                        # multi-line: use full lines from i
                        if line.count("{") > line.count("}"):
                            buf, j = _extract_brace_block(lines, i)
                        else:
                            buf = re.sub(r"--[^\n]*", "", line)
                            j = i
                        # only take numbers after ids =
                        m_body = re.search(r"(?i)ids\s*=\s*\{([^}]*)\}", buf, re.S)
                        if m_body:
                            body = m_body.group(1)
                        else:
                            # incomplete single-line — try block numbers if mostly numeric
                            body = buf
                        if not re.search(r"[A-Za-z_]{4,}\s*=", body):
                            ids = _numeric_ids(body)
                            if ids:
                                table_count += 1
                                for sid in ids:
                                    _record(id_to_meta, sid, "ids", rel, "cast")
                                i = j + 1
                                continue

                # --- B2: define("Name", { ranks }) ---
                m = define_arr.search(line)
                if m:
                    spell_name = m.group(1)
                    buf, j = _extract_brace_block(lines, i)
                    # extract first array after define(
                    m2 = re.search(r'define\s*\(\s*"[^"]+"\s*,\s*\{([^}]*)\}', buf, re.S)
                    if m2:
                        body = m2.group(1)
                        if not re.search(r"[A-Za-z_]{4,}\s*=", body):
                            ids = _numeric_ids(body)
                            if ids:
                                table_count += 1
                                for sid in ids:
                                    _record(id_to_meta, sid, f"define:{spell_name}", rel, "cast")
                                i = j + 1
                                continue

                # --- B2b: define("Name", 12345, ...) scalar spell ID ---
                m = define_scalar.search(line)
                if m:
                    spell_name = m.group(1)
                    sid = int(m.group(2))
                    if 100 <= sid <= 90000:
                        table_count += 1
                        _record(id_to_meta, sid, f"define:{spell_name}", rel, "cast")
                        i += 1
                        continue

                # --- B3: spell_action({ ranks }) or spell_action({ name=, ids= }) ---
                if spell_action_arr.search(line):
                    buf, j = _extract_brace_block(lines, i)
                    ids = _numeric_ids(buf)
                    # Prefer ids= sublist if present
                    m_ids = re.search(r"(?i)ids\s*=\s*\{([^}]*)\}", buf)
                    if m_ids:
                        ids = _numeric_ids(m_ids.group(1))
                    if ids:
                        table_count += 1
                        for sid in ids:
                            _record(id_to_meta, sid, "spell_action", rel, "cast")
                        i = j + 1
                        continue

                # --- B3b: spell_action(12345, ...) scalar ---
                m = spell_action_scalar.search(line)
                if m:
                    sid = int(m.group(1))
                    if 100 <= sid <= 90000:
                        table_count += 1
                        _record(id_to_meta, sid, "spell_action", rel, "cast")
                        i += 1
                        continue

                i += 1

    serial = {}
    for sid in sorted(id_to_meta):
        meta = id_to_meta[sid]
        serial[str(sid)] = {
            "names": sorted(meta["names"]),
            "files": sorted(meta["files"])[:12],
            "kind": sorted(meta["kind"]),
        }
    return {"tables": table_count, "unique": len(serial), "ids": serial}


def parse_spell_index(path: str) -> dict[int, dict]:
    if not os.path.exists(path):
        return {}
    text = open(path, encoding="utf-8", errors="ignore").read()
    pat = re.compile(r'\[(\d+)\]\s*=\s*\{"([^"]+)",\s*([^,]+),\s*([^,]+)')
    out = {}
    for m in pat.finditer(text):
        sid = int(m.group(1))
        cls = m.group(3).strip().strip('"')
        if cls == "nil":
            cls = None
        lvl = m.group(4).strip()
        if lvl == "nil":
            lvl = None
        else:
            try:
                lvl = int(lvl)
            except ValueError:
                lvl = None
        out[sid] = {"name": m.group(2), "class": cls, "level": lvl}
    return out


def load_dbc_names() -> dict[int, str]:
    db_path = os.path.join(ROOT, "wowheadScrape", "dbc_extract", "wowsims.db")
    if not os.path.exists(db_path):
        return {}
    con = sqlite3.connect(db_path)
    cur = con.cursor()
    tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table'")]
    spell_table = None
    for t in tables:
        if t.lower() in ("spell", "spells"):
            spell_table = t
            break
    if not spell_table:
        for t in tables:
            if "spell" in t.lower():
                cols = [r[1] for r in cur.execute(f"PRAGMA table_info({t})")]
                if any("name" in c.lower() for c in cols):
                    spell_table = t
                    break
    dbc: dict[int, str] = {}
    if spell_table:
        cols = [r[1] for r in cur.execute(f"PRAGMA table_info({spell_table})")]
        idcol = "ID" if "ID" in cols else ("id" if "id" in cols else cols[0])
        namecol = next((c for c in cols if "name" in c.lower()), None)
        if namecol:
            for row in cur.execute(f"SELECT {idcol}, {namecol} FROM {spell_table}"):
                try:
                    dbc[int(row[0])] = str(row[1]) if row[1] is not None else ""
                except (TypeError, ValueError):
                    pass
    con.close()
    return dbc


def load_cache() -> dict:
    if os.path.exists(CACHE_PATH):
        try:
            return json.load(open(CACHE_PATH, encoding="utf-8"))
        except Exception:
            return {}
    return {}


def save_cache(cache: dict) -> None:
    open(CACHE_PATH, "w", encoding="utf-8").write(json.dumps(cache))


def fetch_lexxer(sid: int, game: str) -> dict | None:
    url = f"https://lexxer.org/api/v1/spells/{sid}?game={game}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "eax-buff-verify/1.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            payload = json.loads(resp.read().decode("utf-8", errors="replace"))
        if not payload.get("ok"):
            return None
        data = payload.get("data") or {}
        name = data.get("name")
        if not name:
            return None
        return {
            "name": name,
            "class": data.get("required_class"),
            "level": data.get("required_level") or data.get("spell_level"),
            "has_buff": data.get("has_buff"),
            "description": (data.get("description") or "")[:200],
        }
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        return {"error": f"HTTP {e.code}"}
    except Exception as e:
        return {"error": str(e)}


def verify_id_online(sid: int, cache: dict) -> dict:
    key = str(sid)
    if key in cache and all(g in cache[key] for g in GAMES):
        return cache[key]
    result = {}
    for game in GAMES:
        # cache per game
        if key in cache and game in cache[key] and cache[key][game] is not None:
            # allow re-fetch only if previous was error
            prev = cache[key][game]
            if isinstance(prev, dict) and prev.get("error"):
                pass
            else:
                result[game] = prev
                continue
        hit = fetch_lexxer(sid, game)
        result[game] = hit
        time.sleep(0.03)  # gentle rate limit
    cache[key] = result
    return result


def expansion_presence(online: dict) -> dict:
    """Which expansions know this spell ID."""
    out = {}
    for game in GAMES:
        hit = online.get(game)
        out[game] = bool(hit and hit.get("name") and not hit.get("error"))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0, help="Only first N IDs (debug)")
    ap.add_argument("--resume", action="store_true", help="Use lexxer cache")
    ap.add_argument("--workers", type=int, default=6)
    args = ap.parse_args()

    os.makedirs(TOOLS, exist_ok=True)
    print("1) Extracting buff/debuff table IDs...")
    extracted = extract_ids()
    open(EXTRACT_PATH, "w", encoding="utf-8").write(json.dumps(extracted, indent=2))
    print(f"   tables={extracted['tables']} unique={extracted['unique']}")

    print("2) Loading local TBC/Vanilla indexes + DBC...")
    tbc_idx = parse_spell_index(os.path.join(EAX, "shared", "wowhead_data_bridge_spell_index_tbc_sylvanas.lua"))
    van_idx = parse_spell_index(os.path.join(EAX, "shared", "wowhead_data_bridge_spell_index_vanilla_sylvanas.lua"))
    dbc = load_dbc_names()
    print(f"   tbc={len(tbc_idx)} vanilla={len(van_idx)} dbc={len(dbc)}")

    ids = [int(k) for k in extracted["ids"]]
    if args.limit:
        ids = ids[: args.limit]

    cache = load_cache() if args.resume else {}
    print(f"3) Online verify all {len(ids)} IDs x 3 expansions (cache={len(cache)})...")

    online_results: dict[str, dict] = {}
    # Sequential with cache is safer for API; optional workers for uncached
    done = 0
    for sid in ids:
        online_results[str(sid)] = verify_id_online(sid, cache)
        done += 1
        if done % 50 == 0:
            save_cache(cache)
            print(f"   ... {done}/{len(ids)}")
    save_cache(cache)
    print(f"   done online {len(ids)}")

    # Classify
    stats = Counter()
    rows = []
    fails = []
    for sid in ids:
        meta = extracted["ids"][str(sid)]
        local_tbc = tbc_idx.get(sid)
        local_van = van_idx.get(sid)
        local_dbc = dbc.get(sid)
        online = online_results[str(sid)]
        presence = expansion_presence(online)

        # Primary name from any expansion that has it
        name = None
        for g in ("tbc", "wotlk", "classic"):
            hit = online.get(g)
            if hit and hit.get("name"):
                name = hit["name"]
                break
        if not name and local_tbc:
            name = local_tbc["name"]
        if not name and local_van:
            name = local_van["name"]
        if not name and local_dbc:
            name = local_dbc

        any_online = any(presence.values())
        any_local = bool(local_tbc or local_van or local_dbc is not None)
        ok = any_online or any_local

        if ok:
            stats["ok"] += 1
        else:
            stats["fail"] += 1
            fails.append(sid)

        for g in GAMES:
            if presence[g]:
                stats[f"online_{g}"] += 1
        if local_tbc or local_dbc is not None:
            stats["local_tbc_family"] += 1
        if local_van:
            stats["local_vanilla"] += 1

        rows.append(
            {
                "id": sid,
                "name": name,
                "kind": meta["kind"],
                "tables": meta["names"][:6],
                "files": meta["files"][:4],
                "local": {
                    "tbc_index": local_tbc,
                    "vanilla_index": local_van,
                    "dbc_name": local_dbc,
                },
                "online": online,
                "present": presence,
                "ok": ok,
            }
        )

    # Ranked families complete check
    rbf_path = os.path.join(EAX, "shared", "ranked_buff_families_sylvanas.lua")
    rbf_ids = []
    if os.path.exists(rbf_path):
        txt = open(rbf_path, encoding="utf-8", errors="ignore").read()
        # Only numeric literals in code arrays — strip comments first so years like 2026 are ignored.
    txt_nocomment = re.sub(r"--[^\n]*", "", txt)
    rbf_ids = sorted({int(x) for x in re.findall(r"\b(\d{3,6})\b", txt_nocomment) if 100 <= int(x) <= 90000})
    rbf_status = []
    for sid in rbf_ids:
        # prefer online_results if in extract; else fetch
        if str(sid) in online_results:
            online = online_results[str(sid)]
        else:
            online = verify_id_online(sid, cache)
            save_cache(cache)
        presence = expansion_presence(online)
        name = None
        for g in GAMES:
            hit = online.get(g)
            if hit and hit.get("name"):
                name = hit["name"]
                break
        rbf_status.append({"id": sid, "name": name, "present": presence, "ok": any(presence.values()) or sid in tbc_idx or sid in dbc})

    save_cache(cache)

    report = {
        "summary": {
            "tables": extracted["tables"],
            "unique_ids": len(ids),
            "ok": stats["ok"],
            "fail": stats["fail"],
            "ok_pct": round(100.0 * stats["ok"] / max(1, len(ids)), 2),
            "online_classic": stats["online_classic"],
            "online_tbc": stats["online_tbc"],
            "online_wotlk": stats["online_wotlk"],
            "local_tbc_family": stats["local_tbc_family"],
            "local_vanilla": stats["local_vanilla"],
            "fail_ids": fails,
            "ranked_family_count": len(rbf_ids),
            "ranked_family_ok": sum(1 for r in rbf_status if r["ok"]),
        },
        "ranked_families": rbf_status,
        "ids": {str(r["id"]): r for r in rows},
    }
    open(REPORT_JSON, "w", encoding="utf-8").write(json.dumps(report))

    # Markdown
    s = report["summary"]
    lines = [
        "# Full Buff/Debuff Verification — Vanilla / TBC / WotLK",
        "",
        f"**IDs checked:** {s['unique_ids']} (from {s['tables']} named buff/debuff/aura tables)",
        f"**Resolved (any local or online expansion):** **{s['ok']} / {s['unique_ids']} ({s['ok_pct']}%)**",
        f"**Unresolved:** **{s['fail']}**",
        "",
        "## Expansion presence (online lexxer)",
        "",
        f"| Expansion | IDs with name on lexxer |",
        f"|-----------|------------------------:|",
        f"| Classic Vanilla (`classic`) | {s['online_classic']} |",
        f"| TBC (`tbc`) | {s['online_tbc']} |",
        f"| WotLK (`wotlk`) | {s['online_wotlk']} |",
        "",
        f"Local TBC DBC/index hits: **{s['local_tbc_family']}**",
        f"Local Vanilla index hits: **{s['local_vanilla']}**",
        "",
        "## Ranked self-buff families module",
        "",
        f"IDs in `ranked_buff_families_sylvanas.lua`: **{s['ranked_family_count']}**, ok: **{s['ranked_family_ok']}**",
        "",
        "| ID | Name | Classic | TBC | WotLK |",
        "|----|------|:-------:|:---:|:-----:|",
    ]
    for r in rbf_status:
        p = r["present"]
        lines.append(
            f"| {r['id']} | {r.get('name') or '?'} | {'Y' if p.get('classic') else '-'} | {'Y' if p.get('tbc') else '-'} | {'Y' if p.get('wotlk') else '-'} |"
        )

    if fails:
        lines += ["", "## Unresolved IDs (need manual review)", "", "| ID | Kind | Tables | Files |", "|----|------|--------|-------|"]
        for sid in fails:
            r = report["ids"][str(sid)]
            lines.append(
                f"| {sid} | {','.join(r['kind'])} | {', '.join(r['tables'][:3])} | {', '.join(os.path.basename(f) for f in r['files'][:2])} |"
            )

    lines += [
        "",
        "## Method",
        "",
        "1. Extract numeric IDs from Lua tables named like `*_BUFF`, `*_DEBUFF`, `*_AURA*` (skips tests, bridge indexes, consumable weapon_buff item tables).",
        "2. Local: TBC/Vanilla spell indexes + Anniversary DBC (`wowsims.db`).",
        "3. Online: lexxer.org for **each** ID on `classic`, `tbc`, and `wotlk` (cached in `_lexxer_spell_cache.json`).",
        "4. OK if the ID has a name in **any** local source **or** any expansion online.",
        "",
        "Wowhead URLs:",
        "- Vanilla: `https://www.wowhead.com/classic/spell={id}`",
        "- TBC: `https://www.wowhead.com/tbc/spell={id}`",
        "- WotLK: `https://www.wowhead.com/wotlk/spell={id}`",
        "",
        f"Full JSON: `{os.path.relpath(REPORT_JSON, ROOT)}`",
        "",
    ]
    open(REPORT_MD, "w", encoding="utf-8").write("\n".join(lines))

    print("SUMMARY", json.dumps(s, indent=2))
    print("Wrote", REPORT_JSON)
    print("Wrote", REPORT_MD)
    return 0 if s["fail"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
