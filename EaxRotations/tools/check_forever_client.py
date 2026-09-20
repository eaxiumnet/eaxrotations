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

import importlib
import json
import os
import re
import subprocess
import sys

KNOWN_PRODUCTS = {
    "wow",
    "wow_classic",
    "wow_classic_era",
    "wow_classic_anniversary",
    "wow_anniversary",
    "wow_classic_beta",
}

# The Forever beta shipped as `wow_classic_beta` (folder `_classic_beta_`);
# no `wow_forever` product exists. Detection keys on these surfaces rather
# than on the word "forever" in a name -- which is why the 2026-09-20 scan
# reported an installed 1.60.1.69913 client as NOT PRESENT.
FOREVER_PRODUCTS = {"wow_classic_beta"}
FOREVER_FOLDERS = {"_classic_beta_"}

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
    """(forever_hits, version_strings, forever_version) from every known
    product surface."""
    hits, versions = [], []

    # 1. Install-root folders (a _forever_ folder or any new product folder).
    try:
        for entry in os.listdir(WOW_ROOT):
            if entry.startswith("_") and entry.endswith("_"):
                tag = entry.strip("_").lower()
                if tag not in {"retail", "classic", "classic era",
                               "classic_era", "anniversary"} and tag:
                    hits.append("folder:" + entry)
                if "forever" in tag or entry in FOREVER_FOLDERS:
                    hits.append("FOREVER-FOLDER:" + entry)
    except OSError:
        pass

    # 2. .build.info product lines (any product outside the known set),
    # parsed by the module that owns that file's shape.
    for product, version in _repo_tool("build_forever_database") \
            .build_info_versions(WOW_ROOT).items():
        if product not in KNOWN_PRODUCTS:
            hits.append("build-info:" + product)
        if "forever" in product.lower() or product in FOREVER_PRODUCTS:
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

    forever_version = None
    for v in versions:
        product, _, ver = v.partition("=")
        if product in FOREVER_PRODUCTS and ver:
            forever_version = ver
    return sorted(set(hits)), versions, forever_version


def _repo_tool(name):
    """Import a module from the repo's tools/ directory (not a package, so it
    has to go on sys.path).

    Import failure raises on purpose: a silent fallback is what produced the
    false "stub" reading this tool was fixed for (2026-09-20).
    """
    tools_dir = os.path.join(REPO, "tools")
    if tools_dir not in sys.path:
        sys.path.insert(0, tools_dir)
    return importlib.import_module(name)


def datamine_stamp():
    """(client_version, extracted_at) of the built community package.

    Consumes tools/build_forever_database.py, which stamps the package and owns
    its path. No zip-name fallback: a folder name is not evidence of what a
    package contains.
    """
    bd = _repo_tool("build_forever_database")
    if not os.path.isfile(bd.OUT_DB):
        return None, None
    return bd.package_stamp(bd.OUT_DB)


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
    # Reported as "bridge_live" so an OK reads as good news: pre-beta the
    # correct answer is the stub, from beta day on it is a real index (the
    # audit flips modes on the same signal).
    out["bridge_live"] = not _repo_tool(
        "build_forever_bridge").bridge_is_stub(bridge)
    return out


def main():
    as_json = "--json" in sys.argv
    hits, versions, client_version = scan_products()
    prereqs = prereq_report()
    detected = any(h.startswith("FOREVER-") for h in hits)
    data_version, data_when = datamine_stamp()
    up_to_date = bool(client_version and data_version
                      and client_version == data_version)

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
        print("datamine freshness:")
        if not data_version:
            print("  datamine: no built package found (%s)"
                  % _repo_tool("build_forever_database").OUT_DB)
        elif not client_version:
            print("  datamine %s; client build unknown" % data_version)
        elif up_to_date:
            print("  UP TO DATE  datamine %s == client %s"
                  % (data_version, client_version))
        else:
            print("  STALE       datamine %s (extracted %s) vs client %s"
                  % (data_version, data_when, client_version))
            print("              re-run dbc_runbook.md step 1 for this build")
        print("runbook prereqs:")
        for k, ok in sorted(prereqs.items()):
            print(f"  {'OK ' if ok else '-- '} {k}")
        if prereqs["bridge_live"]:
            print("  bridge: live (audit enforces real spell-ID resolution)")
        else:
            print("  bridge: stub (audit in scaffold mode -- correct pre-beta)")
    return 0 if detected else 1


if __name__ == "__main__":
    sys.exit(main())
