#!/usr/bin/env python3
"""check_forever_client.py -- P0 beta-client detection + runbook prereq report.

WHAT:  scans the machine for the WoW Forever beta client (no Battle.net install
       needed to detect it) and reports whether every dbc_runbook.md prereq is
       satisfied. Re-runnable: run after installing the beta; exit 0 means
       "client present, proceed to runbook steps 1-3".
WHEN:  beta window 2026-09-17+ (docs/forever/dbc_runbook.md).
WHY:   the 2026-09-17 P0 scan found the beta NOT installed while the anniversary
       client self-updated to 2.5.6.69795 on beta eve (2026-09-13) -- so Forever
       may arrive EITHER as a new Battle.net product (_forever_ folder) OR as an
       anniversary product line update. This script watches both surfaces plus
       the P0 environment intel (install root, DB2ToSqlite backup, dotnet).
SAFETY: read-only; no network; never mutates game or repo state.

Usage:
    python tools/check_forever_client.py           # human report
    python tools/check_forever_client.py --json    # machine-readable
Exit codes: 0 = Forever client detected; 1 = not detected (prereqs reported).
"""

import json
import os
import re
import shutil
import subprocess
import sys

KNOWN_PRODUCTS = {
    "wow",
    "wow_classic",
    "wow_classic_era",
    "wow_classic_anniversary",
    "wow_anniversary",
}

BNET_AGENT_DIR = r"C:\ProgramData\Battle.net\Agent"
BNET_CONFIG = os.path.join(
    os.environ.get("APPDATA", ""), "Battle.net", "Battle.net.config"
)
WOW_ROOT = r"C:\Program Files (x86)\World of Warcraft"
REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))  # EaxRotations/tools/ -> repo root

DB2TOSQLITE_BACKUP = (
    r"C:\newbot\scripts-backup-20260630-095300\tbc-new\tools\DB2ToSqlite"
)
FOREVER_DB = os.path.join(REPO, "wowheadScrape", "dbc_extract", "wowsims_forever.db")
BRIDGE = os.path.join(
    REPO, "EaxRotations", "shared",
    "wowhead_data_bridge_spell_index_forever_sylvanas.lua",
)


def read_bytes(path):
    try:
        with open(path, "rb") as f:
            return f.read()
    except OSError:
        return b""


def scan_products():
    """Return (forever_hits, version_strings) from every known product surface."""
    hits, versions = [], []

    # 1. Install-root folders (a _forever_ folder or any new product folder).
    try:
        for entry in os.listdir(WOW_ROOT):
            if entry.startswith("_") and entry.endswith("_"):
                tag = entry.strip("_").lower()
                if tag not in {"retail", "classic", "classic era",
                               "classic_era", "anniversary"} and tag:
                    hits.append("folder:" + entry)
                if "forever" in tag:
                    hits.append("FOREVER-FOLDER:" + entry)
    except OSError:
        pass

    # 2. .build.info product lines (any product outside the known set).
    build_info = read_bytes(os.path.join(WOW_ROOT, ".build.info")).decode(
        "utf-8", "replace")
    for line in build_info.splitlines()[1:]:
        if not line.strip():
            continue
        parts = line.split("|")
        if len(parts) >= 15:
            product, version = parts[14].strip(), parts[12].strip()
            if product and product not in KNOWN_PRODUCTS:
                hits.append("build-info:" + product)
            if "forever" in product.lower():
                hits.append("FOREVER-PRODUCT:" + product)
            if version:
                versions.append(product + "=" + version)

    # 3. Battle.net agent product.db + user config.
    agent_db = read_bytes(os.path.join(BNET_AGENT_DIR, "product.db"))
    for name in set(re.findall(rb"wow[a-z_]{2,40}", agent_db)):
        prod = name.decode("ascii", "replace")
        if "forever" in prod:
            hits.append("FOREVER-AGENT:" + prod)
    cfg = read_bytes(BNET_CONFIG).decode("utf-8", "replace")
    try:
        games = json.loads(cfg).get("Games", {})
        for prod in games:
            if "forever" in prod.lower():
                hits.append("FOREVER-CONFIG:" + prod)
    except ValueError:
        pass

    return sorted(set(hits)), versions


def prereq_report():
    """Runbook prereqs independent of the client install."""
    out = {}
    out["db2tosqlite_backup"] = os.path.isdir(DB2TOSQLITE_BACKUP)
    out["dotnet_9"] = False
    try:
        v = subprocess.run(["dotnet", "--version"], capture_output=True,
                           text=True, timeout=20).stdout.strip()
        out["dotnet_9"] = v.startswith("9.")
    except (OSError, subprocess.SubprocessError):
        pass
    # The TBC DBC is gitignored, so a worktree sees only its own copy;
    # accept the main checkout's copy as the calibration source too.
    tbc_candidates = [
        os.path.join(REPO, "wowheadScrape", "dbc_extract", "wowsims.db"),
        "C:/newbot/scripts/wowheadScrape/dbc_extract/wowsims.db",
    ]
    out["anniversary_tbc_db"] = any(os.path.isfile(p) for p in tbc_candidates)
    out["forever_db_extracted"] = os.path.isfile(FOREVER_DB)
    bridge = read_bytes(BRIDGE).decode("utf-8", "replace")
    out["bridge_is_stub"] = "__forever_stub" in bridge
    return out


def main():
    as_json = "--json" in sys.argv
    hits, versions = scan_products()
    prereqs = prereq_report()
    detected = any(h.startswith("FOREVER-") for h in hits)

    if as_json:
        print(json.dumps({
            "forever_client_detected": detected,
            "unusual_product_hits": hits,
            "product_versions": versions,
            "runbook_prereqs": prereqs,
        }, indent=2))
    else:
        print("== WoW Forever client scan ==")
        print("install root:", WOW_ROOT)
        for v in versions:
            print("  product version:", v)
        if detected:
            print("FOREVER CLIENT DETECTED:")
            for h in hits:
                if h.startswith("FOREVER-"):
                    print("  *", h)
            print("-> proceed to dbc_runbook.md steps 1-3 (DB2ToSqlite,")
            print("   build_forever_bridge.py, --check-bridge) then probes P1-P2.")
        else:
            print("FOREVER CLIENT: NOT PRESENT",
                  "(unusual surfaces: " + (", ".join(hits) or "none") + ")")
        print("runbook prereqs:")
        for k, ok in sorted(prereqs.items()):
            print(f"  {'OK ' if ok else '-- '} {k}")
        if prereqs["bridge_is_stub"]:
            print("  bridge: stub (audit in scaffold mode -- correct pre-beta)")
    return 0 if detected else 1


if __name__ == "__main__":
    sys.exit(main())
