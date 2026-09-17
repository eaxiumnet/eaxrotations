#!/usr/bin/env python3
"""probe_forever_tables.py -- probe the Forever beta client for DB2 tables.

WHAT:  runs the DB2ToSqlite extractor in bisecting batches to find out which
        candidate tables actually exist in the installed beta client build.
        A table whose FDID is absent from the build's root aborts the tool
        with "File not found in root" *before* the database is written, and
        the error never names the table -- this driver isolates the culprit
        by bisection (a batch that fails is split until the missing table is
        alone) and reports confirmed/missing lists.
WHEN:  after every beta client patch, before refreshing the extraction
        (`appsettings.forever_world.json`); also when adding new candidate
        tables to WORLD_TABLES in tools/build_forever_database.py.
WHY:   the 2026-09-17 beta build ships 108 of the ~1,373 community-listfile
        table names; knowing which are real avoids trial-and-error full
        extractions. One batch run per ~8 candidates keeps each run short.
SAFETY: read-only against the client install (extracts DB2 files from CASC
        into the tool workspace and writes throwaway probe DBs there).
        Stdlib only.

Usage:
    python tools/probe_forever_tables.py --tool-dir C:\\path\\to\\db2tool
    python tools/probe_forever_tables.py --tool-dir ... --tables extra.txt
    python tools/probe_forever_tables.py --tool-dir ... --product wow_classic_beta

Defaults: candidates = 13 core spell tables + WORLD_TABLES from
tools/build_forever_database.py. The tool dir must contain
DB2ToSqliteTool.dll, listfile.csv and a settings template (any of the
appsettings*.json files is used as the base shape).
"""

import argparse
import json
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_forever_database as bd

CORE13 = ("Spell", "SpellName", "SpellMisc", "SpellLevels",
          "SpellClassOptions", "SpellCooldowns", "SpellEffect", "Talent",
          "TalentTab", "SkillLineAbility", "SkillLine", "ChrRaces",
          "SpellAuraOptions")

SETTINGS = {
    "Logging": {"LogLevel": {"Default": "Warning",
                             "Microsoft.AspNetCore": "Warning"}},
    "AllowedHosts": "*",
    "Settings": {
        "BaseDir": "C:\\Program Files (x86)\\World of Warcraft",
        "BuildConfig": "buildConfig",
        "CDNConfig": "cdnConfig",
        "Region": "us",
        "Product": "wow_classic_beta",
    },
    "TargetDirectory": "dbfilesclient",
    "GameTables": [],
}


def run_batch(tool_dir, tables, tag, timeout):
    path = os.path.join(tool_dir, "appsettings.probe_%s.json" % tag)
    cfg = dict(SETTINGS)
    cfg["DatabaseFile"] = "probe_%s.db" % tag
    cfg["Tables"] = tables
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(cfg, f, indent=1)
    t0 = time.time()
    proc = subprocess.run(
        ["dotnet", "DB2ToSqliteTool.dll", "-s", os.path.basename(path),
         "-o", cfg["DatabaseFile"]],
        cwd=tool_dir, capture_output=True, text=True, errors="replace",
        timeout=timeout)
    return proc.returncode, proc.stdout + proc.stderr, time.time() - t0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--tool-dir", required=True,
                    help="dir with DB2ToSqliteTool.dll + listfile.csv")
    ap.add_argument("--tables", help="file with one candidate table per line")
    ap.add_argument("--out", default=None,
                    help="write probe_result.json here (default: tool dir)")
    ap.add_argument("--batch", type=int, default=8,
                    help="initial batch size (default 8)")
    ap.add_argument("--timeout", type=int, default=1800,
                    help="per-run timeout seconds (default 1800)")
    args = ap.parse_args()

    if args.tables:
        with open(args.tables, encoding="utf-8") as f:
            candidates = [ln.strip() for ln in f
                          if ln.strip() and not ln.startswith("#")]
    else:
        candidates = list(CORE13) + [t for t in bd.WORLD_TABLES
                                     if t not in CORE13]
    print("probing %d candidate tables (batch %d)" % (len(candidates),
                                                      args.batch))

    queue = [candidates[i:i + args.batch]
             for i in range(0, len(candidates), args.batch)][::-1]
    confirmed, missing, runs = [], [], 0
    while queue:
        batch = queue.pop(0)
        runs += 1
        tag = "b%02d" % runs
        rc, out, dur = run_batch(args.tool_dir, batch, tag, args.timeout)
        if rc == 0:
            confirmed.extend(batch)
            print("[%02d] %2d tables OK (%.0fs)" % (runs, len(batch), dur),
                  flush=True)
        elif len(batch) == 1:
            missing.append(batch[0])
            print("[%02d] MISSING %s (%.0fs)" % (runs, batch[0], dur),
                  flush=True)
        else:
            mid = len(batch) // 2
            queue.insert(0, batch[:mid])
            queue.insert(0, batch[mid:])
            print("[%02d] %2d tables FAIL -> bisect (%.0fs)"
                  % (runs, len(batch), dur), flush=True)
    result = {"confirmed": confirmed, "missing": missing}
    out_path = args.out or os.path.join(args.tool_dir, "probe_result.json")
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(result, f, indent=1)
    print("confirmed: %d | missing: %d | result: %s"
          % (len(confirmed), len(missing), out_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
