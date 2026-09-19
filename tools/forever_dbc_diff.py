#!/usr/bin/env python3
"""forever_dbc_diff.py -- diff two Forever DBC extractions through the lane surface.

WHAT:  compares two client DBC extractions (old vs new beta build) and reports
       every delta ON THE SURFACE THE ROTATIONS ACTUALLY USE: player spell
       rows (name, class, level, school, is_heal, aoe, cast_time, gcd,
       cooldown), per-name rank-1 / max-rank / buff mirror ids, and the
       buff-role overrides. Maps each delta to the _forever lanes that
       resolve through it (from the bridge's by-name mirrors + the delta
       files' resolve_id call sites) so the report names files, not just ids.
WHEN:  whenever a new beta build drops (dbc_runbook.md "Beta-day diff"
       section): extract both builds to known paths, run this script, then
       rebuild the bridge and re-run the gates.
WHY:   repo law: the DBC is the authoritative source of truth. A new build
       can silently move a spell row (rename, re-rank, cooldown change, row
       removal) and every lane that resolves through it changes behavior or
       goes dormant -- audit green (IDs still exist) while rotations degrade.
       This harness makes that visible in one command instead of a
       rediscovery pass.
SAFETY: read-only on both DBs; never writes the bridge or any tracked file.
       Single extraction owner: reuses tools/build_forever_bridge.py's
       load_forever_spells() so the diff can never drift from what the
       bridge actually emits. `--self-test` builds synthetic old/new DBs in
       the system temp dir and asserts the full diff surface -- it never
       touches the canonical DB path (that fixture builder overwrites it).

Usage:
    python tools/forever_dbc_diff.py --old <old.db> --new <new.db>
        [--impact-dir EaxRotations/classes]  # default; lane-impact mapping
        [--exit-on-action]                   # exit 1 when action items exist
    python tools/forever_dbc_diff.py --self-test
    python tools/forever_dbc_diff.py --write-fixtures   # regenerate the pair
    python tools/forever_dbc_diff.py --check-fixtures   # CI gate over the pair

Exit codes: 0 clean/no findings, 1 findings (with --exit-on-action) or
self-test failure, 2 usage/environment error.
"""

import argparse
import json
import os
import sqlite3
import sys
import tempfile

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)  # import tools.build_forever_bridge as a module

import tools.build_forever_bridge as builder  # noqa: E402


def _normalize_extracted(extracted):
    """(result, maxrank, buff_ids, all_player_ids) -> flat, JSON-safe maps."""
    result, maxrank, buff_ids, all_player_ids = extracted
    by_name = {}
    for (_cls, name), e in result.items():
        by_name[name] = e  # lowest-id rank-1 rule already applied by builder
    return {
        "rows": {e["spell_id"]: e for e in result.values()},
        "rank1": {n: e["spell_id"] for n, e in by_name.items()},
        "maxrank": {n: sid for (_cls, n), (_lvl, sid) in maxrank.items()},
        "buff": {n: sid for (_cls, n), sid in buff_ids.items()},
        "all_ids": sorted(all_player_ids),
    }


def extract(db_path):
    """Extract the lane surface from a DBC via the bridge builder (one owner)."""
    if not os.path.exists(db_path):
        print("ERROR: DBC not found: %s" % db_path)
        print("       Extract it per docs/forever/dbc_runbook.md step 1.")
        sys.exit(2)
    conn = sqlite3.connect(db_path)
    try:
        return _normalize_extracted(builder.load_forever_spells(conn))
    finally:
        conn.close()


def _row_field_deltas(old_row, new_row):
    """Human-readable field deltas between two index rows."""
    deltas = []
    for field in ("class", "level", "school", "is_heal", "aoe", "cast_time",
                  "gcd", "cooldown_seconds"):
        if old_row.get(field) != new_row.get(field):
            deltas.append("%s %r -> %r" % (field, old_row.get(field),
                                           new_row.get(field)))
    return deltas


def diff_surfaces(old, new):
    """Diff two normalized surfaces. Returns (findings, names_in_flight).

    findings: list of (kind, name, detail) with kind in
              removed/rename/add/role-switch/re-rank/field.
    names_in_flight: names whose rank-1/maxrank/buff mirror id moved at all
              (the raw signal the lane mapper consumes).
    """
    findings = []
    flight = set()
    old_rows, new_rows = old["rows"], new["rows"]

    for sid in sorted(set(old_rows) - set(new_rows)):
        e = old_rows[sid]
        findings.append(("removed", e["name"],
                         "player row %d (%s) gone from the new build" % (sid, e["class"])))
        flight.add(e["name"])
    for sid in sorted(set(new_rows) - set(old_rows)):
        e = new_rows[sid]
        findings.append(("add", e["name"],
                         "new player row %d (%s, lvl %s)" % (sid, e["class"], e["level"])))
    for sid in sorted(set(old_rows) & set(new_rows)):
        d = _row_field_deltas(old_rows[sid], new_rows[sid])
        if d:
            findings.append(("field", old_rows[sid]["name"],
                             "row %d: %s" % (sid, "; ".join(d))))
            flight.add(old_rows[sid]["name"])

    # Same-name different-id = rename/re-rank is the highest-signal shape:
    # the lane keeps resolving (audit stays green) but at a different row.
    moved_rank1 = {n for n in set(old["rank1"]) & set(new["rank1"])
                   if old["rank1"][n] != new["rank1"][n]}
    for n in sorted(moved_rank1):
        findings.append(("re-rank", n, "rank-1 id %d -> %d" % (old["rank1"][n], new["rank1"][n])))
        flight.add(n)
    # Removed/renamed rank-1 names (name present in one map only).
    for n in sorted(set(old["rank1"]) - set(new["rank1"])):
        findings.append(("rename", n, "rank-1 name vanished (was id %d)" % old["rank1"][n]))
        flight.add(n)
    for n in sorted(set(new["rank1"]) - set(old["rank1"])):
        findings.append(("add", n, "rank-1 name added (id %d)" % new["rank1"][n]))
    # Maxrank + buff mirror moves (name kept, id changed) -- these are what
    # CAST and BUFF lanes resolve through, so they matter even when the
    # rank-1 map is untouched.
    for mirror, label in (("maxrank", "max-rank"), ("buff", "buff")):
        moved = {n for n in set(old[mirror]) & set(new[mirror])
                 if old[mirror][n] != new[mirror][n]}
        for n in sorted(moved - flight):
            findings.append(("re-rank", n,
                             "%s id %d -> %d" % (label, old[mirror][n], new[mirror][n])))
            flight.add(n)
        gone = sorted(set(old[mirror]) - set(new[mirror]))
        if gone:
            findings.append(("rename", "%s-mirror lost %d name(s)" % (label, len(gone)),
                             ", ".join(gone[:8]) + ("..." if len(gone) > 8 else "")))
            flight.update(gone)
        added = sorted(set(new[mirror]) - set(old[mirror]))
        if added:
            findings.append(("add", "%s-mirror gained %d name(s)" % (label, len(added)),
                             ", ".join(added[:8]) + ("..." if len(added) > 8 else "")))
    # ROLE-SWITCH: buff id diverges from rank-1 (the builder's override
    # mechanism); a new override (or a lost one) silently changes what
    # buff-gated lanes read.
    switched = {n for n in set(old["buff"]) & set(new["buff"])
                if (old["buff"][n] == old["rank1"].get(n)) !=
                   (new["buff"][n] == new["rank1"].get(n))}
    for n in sorted(switched):
        findings.append(("role-switch", n,
                         "buff mirror %s rank-1 (was %s)"
                         % ("leaves" if old["buff"][n] == old["rank1"].get(n) else "enters",
                            "override" if new["buff"][n] == new["rank1"].get(n) else "distinct row")))
    return findings, flight


def collect_lane_names(impact_dir):
    """Map delta-file path -> set of spell names its lanes resolve by name.

    Parses resolve_id(<alias>, "Name") call sites from every *_forever.lua
    under impact_dir's class subdirectories.
    """
    import glob
    import re
    pat = re.compile(r"resolve_id\([A-Za-z_.]+,\s*\"([^\"]+)\"")
    lanes = {}
    for path in sorted(glob.glob(os.path.join(impact_dir, "*", "*_forever.lua"))):
        with open(path, encoding="utf-8", errors="replace") as f:
            names = set(pat.findall(f.read()))
        if names:
            lanes[path.replace(os.sep, "/")] = names
    return lanes


def map_impact(flight, lane_names):
    """Map in-flight names to delta files. Returns (impacted, unmapped).

    impacted: list of (file, [names...]) sorted for a stable report.
    unmapped: in-flight names no delta resolves through (world-level signal).
    """
    impacted = []
    for path in sorted(lane_names):
        hits = sorted(lane_names[path] & flight)
        if hits:
            impacted.append((path, hits))
    covered = set()
    for _f, hits in impacted:
        covered.update(hits)
    unmapped = sorted(flight - covered)
    return impacted, unmapped


def write_json_report(path, old_v, new_v, findings, impacted, unmapped):
    payload = {
        "old_build": old_v,
        "new_build": new_v,
        "findings": [{"kind": k, "name": n, "detail": d} for k, n, d in findings],
        "impacted_lanes": [{"file": f, "names": n} for f, n in impacted],
        "unmapped_in_flight": unmapped,
    }
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(payload, f, indent=2)
        f.write("\n")


def print_report(old_v, new_v, findings, impacted, unmapped, json_path):
    action_kinds = {"removed", "rename", "role-switch"}
    action = [f for f in findings if f[0] in action_kinds or
              (f[0] == "re-rank" and impacted)]
    print("=" * 78)
    print("FOREVER DBC DIFF   old=%s   new=%s" % (old_v, new_v))
    print("=" * 78)
    for kind, name, detail in findings:
        mark = "!" if (kind, name, detail) in action else " "
        print("  %s %-12s %s: %s" % (mark, kind, name, detail))
    if not findings:
        print("  (no lane-surface deltas between the two builds)")
    if impacted:
        print()
        print("IMPACTED LANES:")
        for path, hits in impacted:
            print("  %s" % path)
            for n in hits:
                print("    - %s" % n)
    if unmapped:
        print()
        print("IN-FLIGHT OUTSIDE THE LANE SURFACE (no _forever lane resolves these):")
        for n in unmapped:
            print("  %s" % n)
    print()
    print("JSON report: %s" % json_path)
    print("ACTION: %d finding(s) need review before rotations go live on the new build."
          % len(action))
    print("        Then: rebuild bridge -> run_forever_audit_tests + rotation suite.")
    return 1 if action else 0


FIXTURE_DIR_DEFAULT = os.path.join(ROOT, "EaxRotations", "tests", "fixtures", "forever_dbc")


def write_fixtures(path):
    """Regenerate the committed synthetic build pair (provenance is code).

    The pair is the self-test's SPELLS_OLD/SPELLS_NEW rows, so every seeded
    finding shape is reviewable in this file rather than frozen in a blob.
    Committing the DBs lets CI run the full CLI path (extract -> diff ->
    lane-impact scan over the real _forever call sites -> report + exit
    contract) with no client and no runtime generation step.
    """
    os.makedirs(path, exist_ok=True)
    for fname, spells in (("build_old.db", SPELLS_OLD), ("build_new.db", SPELLS_NEW)):
        target = os.path.join(path, fname)
        if os.path.exists(target):
            os.remove(target)
        _build_db(target, spells)
        print("wrote %s (%d synthetic rows)" % (target, len(spells)))
    return 0


def check_fixtures(path):
    """CI gate: the committed fixture pair through the real end-to-end path.

    Unlike --self-test (in-process, scratch lanes in TEMP), this exercises
    the CLI's own pipeline against the actual repo: the lane-impact scan
    reads the real classes/*/*_forever.lua resolve_id call sites, so a
    fixture in-flight name must land on a real delta file when the two sets
    intersect. If a future pass retires every lane the fixtures name, refresh
    the seed names (the intersection assertion exists to keep the scan
    honest, not to freeze today's lane set).
    """
    old_db = os.path.join(path, "build_old.db")
    new_db = os.path.join(path, "build_new.db")
    for p in (old_db, new_db):
        if not os.path.exists(p):
            print("FAIL: fixture missing: %s" % p)
            print("      regenerate: python tools/forever_dbc_diff.py --write-fixtures")
            return 1

    old = extract(old_db)
    new = extract(new_db)
    findings, flight = diff_surfaces(old, new)
    lane_names = collect_lane_names(os.path.join(ROOT, "EaxRotations", "classes"))
    impacted, unmapped = map_impact(flight, lane_names)

    failures = []
    kinds = {}
    for kind, name, _d in findings:
        kinds.setdefault(kind, set()).add(name)

    def want(kind, name):
        if name not in kinds.get(kind, set()):
            failures.append("%s not flagged as %s" % (name, kind))

    want("re-rank", "Holy Strike")
    want("field", "Molten Blast")
    want("removed", "Curse of the Vault")
    want("rename", "Prayer of Fortitude")
    want("add", "Curse of the Vault II")

    if len(lane_names) < 25:
        failures.append("lane scan found only %d _forever file(s) with resolve_id "
                        "call sites -- expected the real delta set" % len(lane_names))
    for f in [f for f, _names in impacted]:
        if not f.endswith("_forever.lua"):
            failures.append("impacted path is not a _forever file: %s" % f)
    if not impacted:
        failures.append("no real _forever file impacted by the fixture's in-flight "
                        "names (refresh the seed names if the lane set moved)")
    if "Molten Blast" not in unmapped:
        failures.append("Molten Blast (in-flight, lane-less in the real deltas) "
                        "not reported as unmapped")

    old_v = "fixture-old rows=%d names=%d" % (len(old["rows"]), len(old["rank1"]))
    new_v = "fixture-new rows=%d names=%d" % (len(new["rows"]), len(new["rank1"]))
    report_path = os.path.join(tempfile.gettempdir(), "forever_dbc_diff_fixture_report.json")
    write_json_report(report_path, old_v, new_v, findings, impacted, unmapped)
    try:
        with open(report_path, encoding="utf-8") as f:
            payload = json.load(f)
    except (OSError, ValueError) as exc:
        failures.append("report JSON unreadable: %s" % exc)
    else:
        if not payload.get("impacted_lanes"):
            failures.append("report carries no impacted_lanes")
    rc = print_report(old_v, new_v, findings, impacted, unmapped, report_path)
    if rc != 1:
        failures.append("exit contract: expected 1 for the seeded diff, got %d" % rc)

    if failures:
        for f in failures:
            print("FAIL: %s" % f)
        print("FAIL: forever DBC diff fixture check (%d failure(s))" % len(failures))
        return 1
    print("verdict: fixtures in sync (%d findings, %d lane file(s) impacted, %d unmapped)"
          % (len(findings), len(impacted), len(unmapped)))
    print("[PASS] forever DBC diff fixture check")
    return 0


# --------------------------------------------------------------------------
# Self-test: synthetic old/new DBs in TEMP (never the canonical fixture path
# that build_forever_bridge_fixture.py overwrites).
# --------------------------------------------------------------------------

SCHEMA = {
    "Spell": [("ID", "INTEGER PRIMARY KEY")],
    "SpellName": [("ID", "INTEGER PRIMARY KEY"), ("Name_lang", "TEXT")],
    "SpellMisc": [("ID", "INTEGER PRIMARY KEY"), ("SpellID", "INTEGER"),
                  ("SchoolMask", "INTEGER"), ("CastingTimeIndex", "INTEGER")],
    "SpellLevels": [("ID", "INTEGER PRIMARY KEY"), ("SpellID", "INTEGER"),
                    ("BaseLevel", "INTEGER"), ("MaxLevel", "INTEGER"),
                    ("SpellLevel", "INTEGER")],
    "SpellClassOptions": [("ID", "INTEGER PRIMARY KEY"), ("SpellID", "INTEGER"),
                          ("SpellClassSet", "INTEGER")],
    "SpellCooldowns": [("ID", "INTEGER PRIMARY KEY"), ("SpellID", "INTEGER"),
                       ("CategoryRecoveryTime", "INTEGER"), ("RecoveryTime", "INTEGER"),
                       ("StartRecoveryTime", "INTEGER")],
    "SpellEffect": [("ID", "INTEGER PRIMARY KEY"), ("SpellID", "INTEGER"),
                    ("EffectIndex", "INTEGER"), ("Effect", "INTEGER"),
                    ("EffectAura", "INTEGER"), ("EffectBasePoints", "INTEGER"),
                    ("EffectDieSides", "INTEGER"), ("ImplicitTarget", "TEXT")],
}

# (id, class_set, name, base_level, school, cast_ms, gcd_ms, cd_ms, effects)
SPELLS_OLD = [
    # stable: identical in both builds
    (133, 3, "Fireball", 1, 4, 1500, 1500, 0, [(2, 0, 13, 9, "[6,0]")]),
    # re-rank: every rank id moves between builds (class 10 = Paladin
    # on this classic-line client; 2 is a non-class set here).
    (900001, 10, "Holy Strike", 6, 2, 0, 1500, 12000, [(3, 0, 40, 5, "[1,0]")]),
    # field change: cooldown moves 6s -> 10s on the same row
    (900004, 7, "Molten Blast", 10, 4, 2000, 1500, 6000, [(2, 0, 55, 9, "[21,0]")]),
    # removal: gone from the new build entirely
    (900010, 5, "Curse of the Vault", 20, 32, 0, 1500, 0, [(2, 0, 5, 1, "[1,0]")]),
    # rename: row keeps existing under a new name (name deliberately NOT in
    # any builder override namespace -- BUFF_OVERRIDES/MAXRANK_OVERRIDES pin
    # real-client names like "Prayer of Mending" and would orphan-fail).
    (900020, 6, "Prayer of Fortitude", 30, 2, 0, 1500, 0,
     [(6, 4, 1902, 1, "[21,0]")]),
]
SPELLS_NEW = [
    (133, 3, "Fireball", 1, 4, 1500, 1500, 0, [(2, 0, 13, 9, "[6,0]")]),
    (910001, 10, "Holy Strike", 6, 2, 0, 1500, 12000, [(3, 0, 40, 5, "[1,0]")]),
    (900004, 7, "Molten Blast", 10, 4, 2000, 1500, 10000, [(2, 0, 55, 9, "[21,0]")]),
    # 900010 removed; 900020 renamed:
    (900020, 6, "Prayer of Fortitude Reworked", 30, 2, 0, 1500, 0,
     [(6, 4, 1902, 1, "[21,0]")]),
    # rename target's new name + brand-new player row:
    (910010, 5, "Curse of the Vault II", 20, 32, 0, 1500, 0, [(2, 0, 5, 1, "[1,0]")]),
]


def _build_db(path, spells):
    conn = sqlite3.connect(path)
    try:
        for table, cols in SCHEMA.items():
            defs = ", ".join("%s %s" % (n, t) for n, t in cols)
            conn.execute("CREATE TABLE %s (%s)" % (table, defs))
        for (sid, cset, name, blvl, school, cast_ms, gcd_ms, cd_ms, effects) in spells:
            conn.execute("INSERT INTO Spell (ID) VALUES (?)", (sid,))
            conn.execute("INSERT INTO SpellName (ID, Name_lang) VALUES (?, ?)", (sid, name))
            conn.execute("INSERT INTO SpellMisc (ID, SpellID, SchoolMask, CastingTimeIndex) "
                         "VALUES (?, ?, ?, ?)", (sid, sid, school, int(cast_ms / 100)))
            conn.execute("INSERT INTO SpellLevels (ID, SpellID, BaseLevel, MaxLevel, SpellLevel) "
                         "VALUES (?, ?, ?, 80, ?)", (sid, sid, blvl, blvl))
            conn.execute("INSERT INTO SpellClassOptions (ID, SpellID, SpellClassSet) "
                         "VALUES (?, ?, ?)", (sid, sid, cset))
            conn.execute("INSERT INTO SpellCooldowns (ID, SpellID, CategoryRecoveryTime, "
                         "RecoveryTime, StartRecoveryTime) VALUES (?, ?, 0, ?, ?)",
                         (sid, sid, cd_ms, gcd_ms))
            for i, (eff, aura, bp, ds, tgt) in enumerate(effects):
                conn.execute("INSERT INTO SpellEffect (ID, SpellID, EffectIndex, Effect, "
                             "EffectAura, EffectBasePoints, EffectDieSides, ImplicitTarget) "
                             "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                             (sid * 10 + i, sid, i, eff, aura, bp, ds, tgt))
        conn.commit()
    finally:
        conn.close()


def _write_scratch_deltas(tmp):
    """Two scratch _forever files (one lane each) + a decoy class dir."""
    pal_dir = os.path.join(tmp, "paladin")
    wl_dir = os.path.join(tmp, "warlock")
    os.makedirs(pal_dir, exist_ok=True)
    os.makedirs(wl_dir, exist_ok=True)
    with open(os.path.join(pal_dir, "protection_forever.lua"), "w",
              encoding="utf-8") as f:
        f.write('local x = resolve_id(by_maxrank, "Holy Strike")\n'
                'local y = resolve_id(by_name, "Curse of the Vault")\n')
    with open(os.path.join(wl_dir, "affliction_forever.lua"), "w",
              encoding="utf-8") as f:
        f.write('local z = resolve_id(by_buff, "Prayer of Fortitude")\n')
    # Class dir with no _forever files: collect_lane_names must skip it.
    os.makedirs(os.path.join(tmp, "mage"), exist_ok=True)


def run_self_test():
    print("forever_dbc_diff self-test")
    failures = []
    with tempfile.TemporaryDirectory() as tmp:
        old_db = os.path.join(tmp, "old.db")
        new_db = os.path.join(tmp, "new.db")
        _build_db(old_db, SPELLS_OLD)
        _build_db(new_db, SPELLS_NEW)

        old = extract(old_db)
        new = extract(new_db)

        # 1. Extraction sanity through the real builder path.
        if 133 not in old["rows"] or "Fireball" not in old["rank1"]:
            failures.append("extraction: stable Fireball row missing")
        if 900010 not in old["rows"]:
            failures.append("extraction: removal-side row missing from old surface")
        for mirror in ("maxrank", "buff"):
            if "Holy Strike" not in old[mirror]:
                failures.append("extraction: %s mirror missing Holy Strike" % mirror)

        # 2. Bridge equivalence: a bridge built from the synthetic old DB
        #    must expose the same mirror ids the diff surface extracted.
        out = os.path.join(tmp, "bridge.lua")
        saved_out = builder.OUTPUT
        builder.OUTPUT = out
        try:
            conn = sqlite3.connect(old_db)
            try:
                spells, maxrank, buff_ids, all_ids = builder.load_forever_spells(conn)
            finally:
                conn.close()
            builder.write_bridge(spells, maxrank, buff_ids, all_ids)
            with open(out, encoding="utf-8") as f:
                lua = f.read()
            for probe in ('["Holy Strike"] = 900001,', '["Fireball"] = 133,'):
                if probe not in lua:
                    failures.append("bridge equivalence: %s not emitted" % probe)
        except Exception as exc:  # write_bridge or its checks failed
            failures.append("bridge equivalence: write_bridge failed: %s" % exc)
        finally:
            builder.OUTPUT = saved_out

        # 3. Diff findings -- every seeded shape must be caught, no extras.
        findings, flight = diff_surfaces(old, new)
        kinds = {}
        for kind, name, _d in findings:
            kinds.setdefault(kind, set()).add(name)

        def expect(kind, names):
            # Subset check: removed names also vanish from the rank-1 map
            # (dual lens), and mirror findings are aggregate-labeled rows.
            got = kinds.get(kind, set())
            for n in names:
                if n not in got:
                    failures.append("diff: %s not flagged as %s" % (n, kind))

        def expect_exact(kind, names):
            expect(kind, names)
            extra = kinds.get(kind, set()) - set(names)
            if extra:
                failures.append("diff: unexpected %s findings: %s" % (kind, sorted(extra)))

        expect_exact("re-rank", {"Holy Strike"})
        expect_exact("field", {"Molten Blast"})
        expect("removed", {"Curse of the Vault"})
        expect("rename", {"Prayer of Fortitude"})
        expect("add", {"Curse of the Vault II", "Prayer of Fortitude Reworked"})
        expect_exact("role-switch", set())  # no override in play on these rows
        if "Prayer of Fortitude" not in flight:
            failures.append("diff: rename's old name not in flight set")
        # No false positives on the stable row:
        for kind, names in kinds.items():
            if "Fireball" in names:
                failures.append("diff: stable Fireball flagged as %s" % kind)

        # 4. Lane mapping: scratch deltas + decoy dir.
        scratch = os.path.join(tmp, "classes")
        _write_scratch_deltas(scratch)
        lane_names = collect_lane_names(scratch)
        if len(lane_names) != 2:
            failures.append("lanes: expected 2 scratch files, got %d" % len(lane_names))
        impacted, unmapped = map_impact(flight, lane_names)
        by_file = dict(impacted)
        pal = os.path.join(scratch, "paladin", "protection_forever.lua").replace(os.sep, "/")
        wl = os.path.join(scratch, "warlock", "affliction_forever.lua").replace(os.sep, "/")
        if set(by_file.get(pal, [])) != {"Holy Strike", "Curse of the Vault"}:
            failures.append("lanes: paladin delta impact wrong: %s" % by_file.get(pal))
        if set(by_file.get(wl, [])) != {"Prayer of Fortitude"}:
            failures.append("lanes: warlock delta impact wrong: %s" % by_file.get(wl))
        if "Molten Blast" not in unmapped:
            failures.append("lanes: Molten Blast (in-flight, lane-less) not unmapped")
        if "Holy Strike" in unmapped:
            failures.append("lanes: Holy Strike double-counted as unmapped")

        # 5. Report exit-code contract: action kinds must be nonzero-exit.
        report_json = os.path.join(tmp, "report.json")
        write_json_report(report_json, "synthetic-old", "synthetic-new",
                          findings, impacted, unmapped)
        with open(report_json, encoding="utf-8") as f:
            payload = json.load(f)
        if {d["file"] for d in payload["impacted_lanes"]} != {pal, wl}:
            failures.append("report: json impacted_lanes mismatch")
        rc = print_report("synthetic-old", "synthetic-new", findings,
                          impacted, unmapped, report_json)
        if rc != 1:
            failures.append("report: exit code %d for a finding-bearing diff" % rc)
        if os.path.getsize(report_json) == 0:
            failures.append("report: json empty")

    # 6. Clean-diff contract on a REAL artifact pair if one exists: a DB
    #    diffed against itself must yield zero findings (guards against
    #    false-positive surfaces like degenerate-name churn).
    real = os.path.join(ROOT, "wowheadScrape", "dbc_extract", "wowsims_forever.db")
    if os.path.exists(real):
        r_old = extract(real)
        r_new = extract(real)
        f2, _fl = diff_surfaces(r_old, r_new)
        if f2:
            failures.append("clean-diff: self-diff of the real DBC produced %d findings" % len(f2))
        print("  real-DBC self-diff: %d findings (expected 0)" % len(f2))
    else:
        print("  real DBC absent; skipping real-DBC self-diff (expected pre-beta builds)")

    if failures:
        print()
        for f in failures:
            print("FAIL: %s" % f)
        print("self-test: %d failure(s)" % len(failures))
        return 1
    print("self-test: all assertions passed")
    return 0


def main():
    parser = argparse.ArgumentParser(
        description="Diff two Forever DBC extractions on the lane surface")
    parser.add_argument("--old", help="old-build extraction (SQLite)")
    parser.add_argument("--new", help="new-build extraction (SQLite)")
    parser.add_argument("--impact-dir",
                        default=os.path.join(ROOT, "EaxRotations", "classes"),
                        help="class dirs holding *_forever.lua (default: EaxRotations/classes)")
    parser.add_argument("--exit-on-action", action="store_true",
                        help="exit 1 when action-required findings exist")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--fixture-dir", default=FIXTURE_DIR_DEFAULT,
                        help="committed synthetic build pair (default: %s)"
                             % FIXTURE_DIR_DEFAULT)
    parser.add_argument("--write-fixtures", action="store_true",
                        help="regenerate the committed synthetic build pair")
    parser.add_argument("--check-fixtures", action="store_true",
                        help="CI gate: run the committed pair end-to-end")
    args = parser.parse_args()

    if args.write_fixtures:
        sys.exit(write_fixtures(args.fixture_dir))
    if args.check_fixtures:
        sys.exit(check_fixtures(args.fixture_dir))
    if args.self_test:
        sys.exit(run_self_test())
    if not args.old or not args.new:
        parser.error("--old and --new are required (or use --self-test)")

    old = extract(args.old)
    new = extract(args.new)
    old_v = "rows=%d names=%d" % (len(old["rows"]), len(old["rank1"]))
    new_v = "rows=%d names=%d" % (len(new["rows"]), len(new["rank1"]))
    findings, flight = diff_surfaces(old, new)
    lane_names = collect_lane_names(args.impact_dir)
    impacted, unmapped = map_impact(flight, lane_names)
    json_path = os.path.join(ROOT, "tools", "forever_dbc_diff_report.json")
    write_json_report(json_path, old_v, new_v, findings, impacted, unmapped)
    rc = print_report(old_v, new_v, findings, impacted, unmapped, json_path)
    if args.exit_on_action:
        sys.exit(rc)
    sys.exit(0)


if __name__ == "__main__":
    main()
