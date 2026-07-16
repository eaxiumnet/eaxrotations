#!/usr/bin/env python3
"""Extract and verify buff/debuff spell IDs from EaxRotations against local indexes + optional live APIs.

Usage:
  python EaxRotations/tools/verify_buff_debuff_ids.py
  python EaxRotations/tools/verify_buff_debuff_ids.py --online-sample 40
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
import urllib.request
from collections import Counter, defaultdict

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
EAX = os.path.join(ROOT, "EaxRotations")
TOOLS = os.path.join(EAX, "tools")


def extract_ids() -> dict:
    var_start = re.compile(
        r"(?i)^\s*(?:local\s+)?([A-Za-z0-9_]*?(?:BUFF|DEBUFF|AURA|_buff|_debuff|Buffs|Debuffs|buffs|debuffs)[A-Za-z0-9_]*)\s*=\s*\{"
    )
    num_pat = re.compile(r"\b(\d{2,6})\b")
    id_to_meta: dict[int, dict] = defaultdict(lambda: {"names": set(), "files": set(), "kind": set()})
    table_count = 0
    skip_name_bits = ("wowhead_data_bridge", "spell_id_table", "_dbc_spell", "spell_corpus")

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
            try:
                lines = open(path, encoding="utf-8", errors="ignore").read().splitlines()
            except OSError:
                continue
            i = 0
            while i < len(lines):
                line = lines[i]
                if line.strip().startswith("--"):
                    i += 1
                    continue
                m = var_start.match(line)
                if not m:
                    i += 1
                    continue
                name = m.group(1)
                buf = line
                depth = line.count("{") - line.count("}")
                j = i
                while depth > 0 and j + 1 < len(lines):
                    j += 1
                    if lines[j].strip().startswith("--"):
                        continue
                    buf += " " + lines[j]
                    depth += lines[j].count("{") - lines[j].count("}")
                    if j - i > 80:
                        break
                ids = [int(x) for x in num_pat.findall(buf) if 17 <= int(x) <= 90000]
                if not ids:
                    i += 1
                    continue
                lname = name.lower()
                if "debuff" in lname:
                    kind = "debuff"
                elif "buff" in lname or "aura" in lname:
                    kind = "buff"
                else:
                    kind = "unknown"
                table_count += 1
                for sid in ids:
                    id_to_meta[sid]["names"].add(name)
                    id_to_meta[sid]["files"].add(rel)
                    id_to_meta[sid]["kind"].add(kind)
                i = j + 1

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


def fetch_lexxer(sid: int, game: str) -> dict | None:
    url = f"https://lexxer.org/api/v1/spells/{sid}?game={game}"
    try:
        with urllib.request.urlopen(url, timeout=12) as resp:
            payload = json.loads(resp.read().decode("utf-8", errors="replace"))
        if not payload.get("ok"):
            return None
        data = payload.get("data") or {}
        return {
            "name": data.get("name"),
            "class": data.get("required_class"),
            "level": data.get("required_level") or data.get("spell_level"),
            "game": game,
            "source": "lexxer",
        }
    except Exception as e:
        return {"error": str(e), "game": game, "source": "lexxer"}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--online-sample", type=int, default=0, help="Fetch N missing/random IDs via lexxer")
    ap.add_argument("--online-all-missing", action="store_true")
    args = ap.parse_args()

    os.makedirs(TOOLS, exist_ok=True)
    print("Extracting buff/debuff table IDs...")
    extracted = extract_ids()
    open(os.path.join(TOOLS, "_buff_debuff_ids_extracted.json"), "w", encoding="utf-8").write(
        json.dumps(extracted, indent=2)
    )
    print(f"  tables={extracted['tables']} unique_ids={extracted['unique']}")

    print("Loading local spell indexes...")
    tbc = parse_spell_index(os.path.join(EAX, "shared", "wowhead_data_bridge_spell_index_tbc_sylvanas.lua"))
    van = parse_spell_index(os.path.join(EAX, "shared", "wowhead_data_bridge_spell_index_vanilla_sylvanas.lua"))
    print(f"  tbc_index={len(tbc)} vanilla_index={len(van)}")

    print("Loading DBC (if present)...")
    dbc = load_dbc_names()
    print(f"  dbc_spells={len(dbc)}")

    ids = [int(k) for k in extracted["ids"]]
    detail = {}
    missing = []
    in_tbc = in_van = in_dbc = 0
    kind_counter: Counter = Counter()

    for sid in ids:
        meta = extracted["ids"][str(sid)]
        for k in meta["kind"]:
            kind_counter[k] += 1
        t = tbc.get(sid)
        v = van.get(sid)
        d = dbc.get(sid)
        if t:
            in_tbc += 1
        if v:
            in_van += 1
        if d is not None:
            in_dbc += 1
        found = bool(t or v or (d is not None))
        if not found:
            missing.append(sid)
        detail[str(sid)] = {
            "kind": meta["kind"],
            "table_names": meta["names"][:8],
            "files": meta["files"][:6],
            "tbc_name": t["name"] if t else None,
            "tbc_class": t["class"] if t else None,
            "tbc_level": t["level"] if t else None,
            "van_name": v["name"] if v else None,
            "van_level": v["level"] if v else None,
            "dbc_name": d,
            "found_local": found,
        }

    # Ranked families explicit cross-check
    rbf_path = os.path.join(EAX, "shared", "ranked_buff_families_sylvanas.lua")
    rbf_ids = []
    if os.path.exists(rbf_path):
        rbf_text = open(rbf_path, encoding="utf-8", errors="ignore").read()
        rbf_ids = sorted({int(x) for x in re.findall(r"\b(\d{2,6})\b", rbf_text) if 17 <= int(x) <= 90000})

    online = {}
    sample_targets = []
    if args.online_all_missing:
        sample_targets = missing[:]
    elif args.online_sample > 0:
        # prioritize missing, then ranked-family max ranks, then sample of found
        prioritized = missing[:]
        for sid in (48469, 48470, 42995, 43002, 48161, 48162, 53307, 47436, 47893, 57960, 26990, 27126, 25389):
            if sid not in prioritized:
                prioritized.append(sid)
        # add some from extract
        for sid in ids[:: max(1, len(ids) // max(1, args.online_sample))]:
            if sid not in prioritized:
                prioritized.append(sid)
        sample_targets = prioritized[: args.online_sample]

    if sample_targets:
        print(f"Online sample via lexxer: {len(sample_targets)} IDs...")
        for sid in sample_targets:
            # try tbc then wotlk then classic
            hit = None
            for game in ("tbc", "wotlk", "classic"):
                res = fetch_lexxer(sid, game)
                if res and res.get("name"):
                    hit = res
                    break
                if res and res.get("error") and not hit:
                    hit = res
            online[str(sid)] = hit
            status = (hit or {}).get("name") or (hit or {}).get("error") or "none"
            print(f"  {sid}: {status}")

    summary = {
        "tables_scanned": extracted["tables"],
        "unique_ids": len(ids),
        "in_tbc_index": in_tbc,
        "in_van_index": in_van,
        "in_dbc": in_dbc,
        "found_local": len(ids) - len(missing),
        "missing_local": len(missing),
        "missing_ids": missing,
        "kind_counts": dict(kind_counter),
        "ranked_family_ids": len(rbf_ids),
        "online_sampled": len(online),
    }

    report = {
        "summary": summary,
        "online": online,
        "ids": detail,
    }
    report_path = os.path.join(TOOLS, "buff_debuff_verification_report.json")
    open(report_path, "w", encoding="utf-8").write(json.dumps(report))

    # Markdown report
    md_path = os.path.join(TOOLS, "buff_debuff_verification_report.md")
    lines = []
    lines.append("# Buff / Debuff ID Verification Report")
    lines.append("")
    lines.append(f"- Tables scanned (name contains buff/debuff/aura): **{summary['tables_scanned']}**")
    lines.append(f"- Unique spell IDs extracted: **{summary['unique_ids']}**")
    lines.append(f"- Found in TBC spell index: **{summary['in_tbc_index']}**")
    lines.append(f"- Found in Vanilla spell index: **{summary['in_van_index']}**")
    lines.append(f"- Found in local DBC: **{summary['in_dbc']}**")
    lines.append(f"- Found in any local source: **{summary['found_local']}**")
    lines.append(f"- Missing all local sources: **{summary['missing_local']}**")
    lines.append(f"- Kind counts: `{summary['kind_counts']}`")
    lines.append("")
    lines.append("## Scope notes")
    lines.append("")
    lines.append("- Extraction only includes Lua tables whose **variable name** contains `buff`/`debuff`/`aura`.")
    lines.append("- Spell ID tables, wowhead bridge indexes, and tests are excluded from extraction.")
    lines.append("- Local pass uses TBC/Vanilla spell indexes + DBC when present.")
    lines.append("- Online sample uses lexxer.org (`tbc` → `wotlk` → `classic`).")
    lines.append("")
    if missing:
        lines.append("## Missing locally")
        lines.append("")
        lines.append("| ID | Kind | Table names | Files |")
        lines.append("|----|------|-------------|-------|")
        for sid in missing[:200]:
            m = detail[str(sid)]
            lines.append(
                f"| {sid} | {','.join(m['kind'])} | {', '.join(m['table_names'][:3])} | {', '.join(os.path.basename(f) for f in m['files'][:2])} |"
            )
        if len(missing) > 200:
            lines.append(f"| ... | {len(missing)-200} more | see JSON | |")
        lines.append("")
    if online:
        lines.append("## Online sample results")
        lines.append("")
        lines.append("| ID | Name | Class | Level | Game |")
        lines.append("|----|------|-------|-------|------|")
        for sid, res in sorted(online.items(), key=lambda x: int(x[0])):
            if not res:
                lines.append(f"| {sid} | (no data) | | | |")
            elif res.get("error") and not res.get("name"):
                lines.append(f"| {sid} | ERROR: {res.get('error')} | | | {res.get('game','')} |")
            else:
                lines.append(
                    f"| {sid} | {res.get('name','')} | {res.get('class','')} | {res.get('level','')} | {res.get('game','')} |"
                )
        lines.append("")
    lines.append("## Verdict")
    lines.append("")
    pct = 100.0 * summary["found_local"] / max(1, summary["unique_ids"])
    lines.append(f"- Local coverage: **{pct:.1f}%** of extracted buff/debuff table IDs.")
    if summary["missing_local"] == 0:
        lines.append("- All extracted IDs resolved in local indexes/DBC.")
    else:
        lines.append(
            f"- **{summary['missing_local']}** IDs need manual/online follow-up (WotLK-only, typos, or non-spell noise)."
        )
    lines.append("")
    open(md_path, "w", encoding="utf-8").write("\n".join(lines))
    print("Wrote", report_path)
    print("Wrote", md_path)
    print("SUMMARY", json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
