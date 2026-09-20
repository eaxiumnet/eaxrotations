#!/usr/bin/env python3
"""build_forever_settings.py -- emit the DB2ToSqlite settings file for a Forever beta refresh.

WHAT:  writes appsettings.forever_world.json, the extraction contract the
       runbook calls for: client product + install root + the table list (the
       13 core spell/talent tables from probe_forever_tables.CORE13 plus
       WORLD_TABLES from build_forever_database.py).
WHEN:  before every beta refresh (docs/forever/dbc_runbook.md step 1), after
       probe_forever_tables.py has confirmed which candidate tables exist on
       the new build -- a table that is absent aborts the extraction with
       "File not found in root" and the DB is only written once every table
       loads.
WHY:   the 2026-09-17 extraction used a hand-written settings file inside a
       throwaway copy of the DB2ToSqlite tree; that file no longer exists on
       disk, so the refresh could not be reproduced from the repo. Deriving
       the list from the scripts that read the extraction means it cannot
       drift from them (a table added to WORLD_TABLES shows up here), and the
       client product/root/output DB name come from build_forever_database.py.
SAFETY: writes one file inside --tool-dir (the throwaway tool copy); never
        touches the client install or the repo. --check compares an existing
        file against the canonical list and writes nothing; --print dumps the
        settings to stdout.

Usage:
    python tools/build_forever_settings.py --tool-dir <tool copy>
    python tools/build_forever_settings.py --tool-dir <tool copy> --check
    python tools/build_forever_settings.py --tool-dir <tool copy> --print
Exit codes: 0 ok, 1 --check mismatch, 2 usage error.
"""

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_forever_database as bd  # noqa: E402
from probe_forever_tables import CORE13  # noqa: E402

SETTINGS_NAME = "appsettings.forever_world.json"
REGION = "us"

# The runbook's two hard-won constraints for this classic-line client:
#   * TargetDirectory stays "dbfilesclient" -- the tool resolves
#     {TargetDirectory}/{table}.db2 against listfile FDIDs, so renaming the
#     output dir (the obvious edit when --output points elsewhere) breaks
#     every lookup.
#   * ItemRandomProperties must stay out of the table list -- it crashes this
#     DB2ToSqlite build deterministically ("File not found in root"). Neither
#     CORE13 nor WORLD_TABLES names it, so deriving the list keeps it out.
TARGET_DIRECTORY = "dbfilesclient"


def canonical_tables():
    return list(CORE13) + [t for t in bd.WORLD_TABLES if t not in CORE13]


def build_settings():
    return {
        "Logging": {"LogLevel": {"Default": "Warning",
                                 "Microsoft.AspNetCore": "Warning"}},
        "AllowedHosts": "*",
        "Settings": {
            "BaseDir": bd.DEFAULT_BASE_DIR,
            "BuildConfig": "buildConfig",
            "CDNConfig": "cdnConfig",
            "Region": REGION,
            "Product": bd.CLIENT_PRODUCT,
        },
        "TargetDirectory": TARGET_DIRECTORY,
        "GameTables": [],
        "DatabaseFile": os.path.basename(bd.SRC_DB),
        "Tables": canonical_tables(),
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--tool-dir", required=True,
                    help="working copy of DB2ToSqlite that will run the "
                         "extraction (holds listfile.csv + the DLL)")
    ap.add_argument("--check", action="store_true",
                    help="verify an existing settings file instead of writing")
    ap.add_argument("--print", dest="show", action="store_true",
                    help="print the settings without writing")
    args = ap.parse_args()

    if not os.path.isdir(args.tool_dir):
        print("ERROR: --tool-dir is not a directory: %s" % args.tool_dir)
        return 2
    out_path = os.path.join(args.tool_dir, SETTINGS_NAME)
    settings = build_settings()
    tables = settings["Tables"]

    if args.show:
        print(json.dumps(settings, indent=1))
        return 0

    if args.check:
        if not os.path.isfile(out_path):
            print("MISSING: %s" % out_path)
            return 1
        with open(out_path, encoding="utf-8") as f:
            existing = json.load(f)
        expected = settings
        # BaseDir/region are machine choices; the contract is the table list,
        # the product line and the target directory.
        drift = []
        for key in ("Tables", "TargetDirectory", "DatabaseFile"):
            if existing.get(key) != expected[key]:
                drift.append(key)
        if existing.get("Settings", {}).get("Product") != \
                expected["Settings"]["Product"]:
            drift.append("Settings.Product")
        if drift:
            print("DRIFT: %s differs (%s)" % (out_path, ", ".join(drift)))
            return 1
        print("OK: %s matches the canonical %d-table list"
              % (out_path, len(tables)))
        return 0

    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(settings, f, indent=1)
        f.write("\n")
    print("wrote %s (%d tables: %d core + %d world)"
          % (out_path, len(tables), len(CORE13),
             len(tables) - len(CORE13)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
