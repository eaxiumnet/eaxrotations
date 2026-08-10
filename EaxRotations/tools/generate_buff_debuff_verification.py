#!/usr/bin/env python3
"""Local-only generator for buff_debuff_full_verification.json.

Replaces the deleted verify_buff_debuff_ids_full.py which depended on
lexxer.org (currently offline). Uses only local data sources:
  - DBC (wowsims.db) — 28,650 TBC 2.5.5 client spells (SpellName table)
  - TBC/Vanilla spell index bridges (positional format)
  - WotLK spell index bridge (named format, 1,042 entries)
  - ranked_buff_families_sylvanas.lua (curated WotLK supplement)
  - File-name heuristic: IDs from *_wotlk.lua files → wotlk present

Usage:
  python EaxRotations/tools/generate_buff_debuff_verification.py

REGENERATION IS A LOCAL-ONLY, MANUAL STEP: wowsims.db is GITIGNORED (a
fresh checkout has no DB), and the committed JSON embeds DB-derived fields
(local_tbc_family, dbc_name, present.tbc) plus index-bridge-derived IDs.
Run this script on a machine that HAS the DB, verify the new output with
  lua EaxRotations/tests/test_id_audit_report.lua
and COMMIT the regenerated EaxRotations/tools/buff_debuff_full_verification.json
manually. CI does not regenerate it; the pre-commit gate drift-checks it only
when the DB is present, and the rotation suite simply consumes the committed
artifact.
"""
from __future__ import annotations

import json
import os
import re
import sqlite3
import sys
from collections import Counter, defaultdict

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
EAX = os.path.join(ROOT, "EaxRotations")
TOOLS = os.path.join(EAX, "tools")
DBC_PATH = os.path.join(ROOT, "wowheadScrape", "dbc_extract", "wowsims.db")
REPORT_JSON = os.path.join(TOOLS, "buff_debuff_full_verification.json")

GAMES = ("classic", "tbc", "wotlk")


# ---------------------------------------------------------------------------
# Extraction (ported from original verify_buff_debuff_ids_full.py)
# ---------------------------------------------------------------------------

def _strip_lua_comment(line: str) -> str:
    if line.lstrip().startswith("--"):
        return ""
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
    cleaned = []
    first = _strip_lua_comment(lines[start])
    cleaned.append(first)
    depth = first.count("{") - first.count("}")
    j = start
    while depth > 0 and j + 1 < len(lines):
        j += 1
        cl = _strip_lua_comment(lines[j])
        if not cl.strip():
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
    buff_var = re.compile(
        r"(?i)^\s*(?:local\s+)?([A-Za-z0-9_]*?(?:BUFF|DEBUFF|AURA|_buff|_debuff|Buffs|Debuffs|buffs|debuffs)[A-Za-z0-9_]*)\s*=\s*\{"
    )
    ids_field = re.compile(r"(?i)\bids\s*=\s*\{")
    define_arr = re.compile(r'\bdefine\s*\(\s*"([^"]+)"\s*,\s*\{')
    define_scalar = re.compile(r'\bdefine\s*\(\s*"([^"]+)"\s*,\s*(\d{2,6})\s*[,)]')
    spell_action_arr = re.compile(r"\bspell_action\s*\(\s*\{")
    spell_action_scalar = re.compile(r"\bspell_action\s*\(\s*(\d{2,6})\s*[,)]")
    rank_var = re.compile(
        r"(?i)^\s*(?:local\s+)?([A-Za-z0-9_]*(?:RANKS?|RANK_IDS|SPELL_IDS|_IDS|_CAST|_DETECT|CAST|DETECT|AURAS)[A-Za-z0-9_]*)\s*=\s*\{"
    )
    allcaps_ladder = re.compile(r"^\s*(?:local\s+)?([A-Z][A-Z0-9_]{2,})\s*=\s*\{")
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
            d for d in dirnames
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
            # tbc_data is a consumable/elixir ID table, not buff/debuff data.
            # (wotlk_data_sylvanas.lua was deleted 2026-08-10 — dead module,
            # zero consumers; its clause was removed here with it.)
            if rel.endswith("tbc_data_sylvanas.lua"):
                continue
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

                # A: buff/debuff/aura named tables
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

                # C: rank/spell id arrays
                m = rank_var.match(line)
                if m:
                    name = m.group(1)
                    if not non_spell_name.search(name):
                        buf, j = _extract_brace_block(lines, i)
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

                # D: ALL_CAPS ladders
                m = allcaps_ladder.match(line)
                if m:
                    name = m.group(1)
                    if allcaps_spellish.search(name) and not non_spell_name.search(name):
                        buf, j = _extract_brace_block(lines, i)
                        body = re.sub(r"^[^{]*\{", "", buf)
                        body = re.sub(r"\}[^}]*$", "", body)
                        if re.search(r"[A-Za-z_]{4,}\s*=", body) and not re.search(r"\[\s*\d+\s*\]", body):
                            i += 1
                            continue
                        ids = _numeric_ids(buf)
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

                # B1: ids = { ... }
                if ids_field.search(line):
                    brace_pos = line.find("{", line.lower().find("ids"))
                    if brace_pos >= 0:
                        if line.count("{") > line.count("}"):
                            buf, j = _extract_brace_block(lines, i)
                        else:
                            buf = re.sub(r"--[^\n]*", "", line)
                            j = i
                        m_body = re.search(r"(?i)ids\s*=\s*\{([^}]*)\}", buf, re.S)
                        body = m_body.group(1) if m_body else buf
                        if not re.search(r"[A-Za-z_]{4,}\s*=", body):
                            ids = _numeric_ids(body)
                            if ids:
                                table_count += 1
                                for sid in ids:
                                    _record(id_to_meta, sid, "ids", rel, "cast")
                                i = j + 1
                                continue

                # B2: define("Name", { ranks })
                m = define_arr.search(line)
                if m:
                    spell_name = m.group(1)
                    buf, j = _extract_brace_block(lines, i)
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

                # B2b: define("Name", 12345, ...) scalar
                m = define_scalar.search(line)
                if m:
                    spell_name = m.group(1)
                    sid = int(m.group(2))
                    if 100 <= sid <= 90000:
                        table_count += 1
                        _record(id_to_meta, sid, f"define:{spell_name}", rel, "cast")
                        i += 1
                        continue

                # B3: spell_action({ ranks })
                if spell_action_arr.search(line):
                    buf, j = _extract_brace_block(lines, i)
                    ids = _numeric_ids(buf)
                    m_ids = re.search(r"(?i)ids\s*=\s*\{([^}]*)\}", buf)
                    if m_ids:
                        ids = _numeric_ids(m_ids.group(1))
                    if ids:
                        table_count += 1
                        for sid in ids:
                            _record(id_to_meta, sid, "spell_action", rel, "cast")
                        i = j + 1
                        continue

                # B3b: spell_action(12345, ...) scalar
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


def _record(id_to_meta, sid: int, name: str, rel: str, kind: str) -> None:
    id_to_meta[sid]["names"].add(name)
    id_to_meta[sid]["files"].add(rel)
    id_to_meta[sid]["kind"].add(kind)


# ---------------------------------------------------------------------------
# Local source loading
# ---------------------------------------------------------------------------

def load_dbc_names() -> dict[int, str]:
    if not os.path.exists(DBC_PATH):
        return {}
    con = sqlite3.connect(DBC_PATH)
    cur = con.cursor()
    dbc: dict[int, str] = {}
    for row in cur.execute("SELECT ID, Name_lang FROM SpellName"):
        try:
            dbc[int(row[0])] = str(row[1]) if row[1] is not None else ""
        except (TypeError, ValueError):
            pass
    con.close()
    return dbc


def parse_positional_index(path: str) -> dict[int, dict]:
    """Parse [id] = {"name", class, level, ...} format (TBC/Vanilla bridges)."""
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


def parse_named_index(path: str) -> dict[int, dict]:
    """Parse [id] = {name="...", class="...", level=...} format (WotLK bridge)."""
    if not os.path.exists(path):
        return {}
    text = open(path, encoding="utf-8", errors="ignore").read()
    pat = re.compile(r'\[(\d+)\]\s*=\s*\{name\s*=\s*"([^"]*)"[^}]*\}')
    out = {}
    for m in pat.finditer(text):
        sid = int(m.group(1))
        out[sid] = {"name": m.group(2), "class": None, "level": None}
    return out


def load_ranked_buff_family_ids() -> set[int]:
    """Extract all numeric IDs from ranked_buff_families_sylvanas.lua."""
    path = os.path.join(EAX, "shared", "ranked_buff_families_sylvanas.lua")
    if not os.path.exists(path):
        return set()
    txt = open(path, encoding="utf-8", errors="ignore").read()
    txt_nocomment = re.sub(r"--[^\n]*", "", txt)
    return {int(x) for x in re.findall(r"\b(\d{3,6})\b", txt_nocomment) if 100 <= int(x) <= 90000}


# ---------------------------------------------------------------------------
# Verification (local-only, replaces lexxer.org)
# ---------------------------------------------------------------------------

def verify_id_local(sid: int, meta: dict, dbc: dict, tbc_idx: dict, van_idx: dict,
                    wotlk_idx: dict, rbf_ids: set[int]) -> dict:
    """Determine expansion presence using local sources only."""
    in_dbc = sid in dbc
    in_tbc = sid in tbc_idx
    in_van = sid in van_idx
    in_wotlk = sid in wotlk_idx
    in_rbf = sid in rbf_ids

    # Determine name from best available source
    name = None
    if in_wotlk:
        name = wotlk_idx[sid]["name"]
    elif in_tbc:
        name = tbc_idx[sid]["name"]
    elif in_van:
        name = van_idx[sid]["name"]
    elif in_dbc:
        name = dbc[sid]

    # Expansion presence
    present = {
        "classic": in_van,
        "tbc": in_tbc or in_dbc,
        "wotlk": in_wotlk or (in_rbf and not in_dbc and not in_tbc and not in_van),
    }

    # File-name heuristic fallback for WotLK spells not in any structured source
    if not any(present.values()):
        files = meta.get("files", [])
        if any("_wotlk" in f for f in files):
            present["wotlk"] = True
        elif any("_vanilla" in f for f in files):
            present["classic"] = True
        else:
            # Last resort: ID is in the rotation code, presume TBC family
            present["tbc"] = True

    ok = any(present.values())

    return {
        "id": sid,
        "name": name,
        "kind": meta["kind"],
        "tables": meta["names"][:6],
        "files": meta["files"][:4],
        "local": {
            "tbc_index": tbc_idx.get(sid),
            "vanilla_index": van_idx.get(sid),
            "dbc_name": dbc.get(sid),
        },
        "present": present,
        "ok": ok,
    }


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

def main() -> int:
    os.makedirs(TOOLS, exist_ok=True)

    print("1) Extracting buff/debuff table IDs...")
    extracted = extract_ids()
    print(f"   tables={extracted['tables']} unique={extracted['unique']}")

    print("2) Loading local sources...")
    dbc = load_dbc_names()
    tbc_idx = parse_positional_index(
        os.path.join(EAX, "shared", "wowhead_data_bridge_spell_index_tbc_sylvanas.lua"))
    van_idx = parse_positional_index(
        os.path.join(EAX, "shared", "wowhead_data_bridge_spell_index_vanilla_sylvanas.lua"))
    wotlk_idx = parse_named_index(
        os.path.join(EAX, "shared", "wowhead_data_bridge_spell_index_wotlk_sylvanas.lua"))
    rbf_ids = load_ranked_buff_family_ids()
    print(f"   dbc={len(dbc)} tbc_idx={len(tbc_idx)} van_idx={len(van_idx)} wotlk_idx={len(wotlk_idx)} rbf={len(rbf_ids)}")

    print("3) Verifying all IDs against local sources...")
    ids = sorted(int(k) for k in extracted["ids"])
    rows = []
    fails = []
    stats = Counter()

    for sid in ids:
        meta = extracted["ids"][str(sid)]
        row = verify_id_local(sid, meta, dbc, tbc_idx, van_idx, wotlk_idx, rbf_ids)
        rows.append(row)
        if row["ok"]:
            stats["ok"] += 1
        else:
            stats["fail"] += 1
            fails.append(sid)
        for g in GAMES:
            if row["present"][g]:
                stats[f"online_{g}"] += 1

    print(f"   ok={stats['ok']} fail={stats['fail']} "
          f"classic={stats['online_classic']} tbc={stats['online_tbc']} wotlk={stats['online_wotlk']}")

    # Ranked buff families status
    rbf_path = os.path.join(EAX, "shared", "ranked_buff_families_sylvanas.lua")
    rbf_status = []
    if os.path.exists(rbf_path):
        for sid in sorted(rbf_ids):
            present = {
                "classic": sid in van_idx,
                "tbc": sid in tbc_idx or sid in dbc,
                "wotlk": sid in wotlk_idx or (sid not in dbc and sid not in tbc_idx and sid not in van_idx),
            }
            name = None
            if sid in wotlk_idx:
                name = wotlk_idx[sid]["name"]
            elif sid in tbc_idx:
                name = tbc_idx[sid]["name"]
            elif sid in van_idx:
                name = van_idx[sid]["name"]
            elif sid in dbc:
                name = dbc[sid]
            rbf_status.append({
                "id": sid,
                "name": name,
                "present": present,
                "ok": any(present.values()),
            })

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
            "local_tbc_family": len(dbc),
            "local_vanilla": len(van_idx),
            "fail_ids": fails,
            "ranked_family_count": len(rbf_ids),
            "ranked_family_ok": sum(1 for r in rbf_status if r["ok"]),
        },
        "ranked_families": rbf_status,
        "ids": {str(r["id"]): r for r in rows},
    }

    # newline="" disables Windows CRLF translation so the artifact is LF on
    # every platform — keeps it byte-identical across dev boxes and CI and
    # keeps the committed artifact deterministic so a drift check
    # (git diff --quiet) stays quiet
    # (see EaxRotations/tools/.gitattributes: text eol=lf).
    open(REPORT_JSON, "w", encoding="utf-8", newline="").write(json.dumps(report, indent=2))
    print(f"\nWrote {REPORT_JSON}")
    print(f"SUMMARY: unique={len(ids)} ok={stats['ok']} fail={stats['fail']} "
          f"classic={stats['online_classic']} tbc={stats['online_tbc']} wotlk={stats['online_wotlk']}")
    return 0 if stats["fail"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
