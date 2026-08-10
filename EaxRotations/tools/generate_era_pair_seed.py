#!/usr/bin/env python3
"""Regenerate EaxRotations/tests/era_pair_seed.lua from the current class tree.

LOCAL-ONLY manual step (like generate_buff_debuff_verification.py): run after a
deliberate era-mirror re-baseline and commit the resulting seed diff together
with the rotation changes that caused it. The era-pair audit
(run_era_pair_audit_tests.lua) reads the seed as its baseline and FAILS when the
live tree's divergence set grows beyond it — so the seed must only be
regenerated when the divergence set is INTENTIONALLY changing (a new strategy
added to every era, or an era file gaining/losing strategies by design).

The audit is intentionally NOT wired into this generator: it is not run in CI
because CI's clean checkout has no way to know which divergences are intended.
The committed seed is the reviewed, reasoned baseline; regeneration is a
human-reviewed commit like the scorecard doc.

The generator does expose a drift guard (scorecard --check discipline):
`--check` compares the committed seed against a fresh in-memory regeneration
(no writes) and fails if they differ — wired into verify_all and the
pre-commit gate so a stale or hand-edited seed can never silently weaken the
era-pair audit. `--self-test` proves the drift detection is non-vacuous
(in-memory corruption is caught).

Usage:
  python EaxRotations/tools/generate_era_pair_seed.py          # regenerate (manual, commit with the change)
  python EaxRotations/tools/generate_era_pair_seed.py --check  # drift guard (verify_all / pre-commit)
  python EaxRotations/tools/generate_era_pair_seed.py --self-test
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CLASS = os.path.normpath(os.path.join(ROOT, "EaxRotations", "classes"))
OUT = os.path.normpath(os.path.join(ROOT, "EaxRotations", "tests", "era_pair_seed.lua"))

ERAS = ("sylvanas", "vanilla", "wotlk")
# Files that are class infrastructure, not per-spec era rotations.
SKIP_BITS = ("leveling", "middleware", "class_sylvanas", "schema", "shared_helpers")


def strip_comments(s):
    s = re.sub(r"--\[=*\[.*?\]=*\]", " ", s, flags=re.S)
    s = re.sub(r"--[^\n]*", " ", s)
    return s


def names_in(src):
    """Strategy-name resolver: literal `name = "X"` (strategy tables, DSL defs,
    name-only placeholders) and `build_action("X", ...)` (warrior helper).
    Comment text is stripped first so it can never count as a definition."""
    src = strip_comments(src)
    names = set()
    for m in re.finditer(r'name\s*=\s*"([A-Za-z0-9_]+)"', src):
        names.add(m.group(1))
    for m in re.finditer(r'build_action\s*\(\s*"([A-Za-z0-9_]+)"', src):
        names.add(m.group(1))
    return names


def middleware_interrupts():
    """Per class: interrupt spell names the class middleware registers via
    interrupt_manager (register_interrupt_spell). These are class-baseline
    capabilities the middleware provides to every TBC spec of the class, so they
    fold into the sylvanas era set."""
    mid = {}
    for f in glob.glob(os.path.join(CLASS, "*", "middleware_sylvanas.lua")):
        cls = os.path.basename(os.path.dirname(f))
        src = strip_comments(open(f, encoding="utf-8", errors="replace").read())
        regs = set()
        for m in re.finditer(
            r'register_interrupt_spell\s*\(\s*"[^"]*"\s*,\s*"([A-Za-z0-9_]+)"', src
        ):
            regs.add(m.group(1))
        for m in re.finditer(
            r'create_interrupt_strategy\s*\(\s*\{\s*[^}]*?name\s*=\s*"([A-Za-z0-9_]+)"',
            src,
            re.S,
        ):
            regs.add(m.group(1))
        mid[cls] = regs
    return mid


def collect_specs():
    specs = {}
    for f in glob.glob(os.path.join(CLASS, "*", "*.lua")):
        base = os.path.basename(f)
        m = re.match(r"(.+?)_(sylvanas|vanilla|wotlk)\.lua$", base)
        if not m:
            continue
        if any(b in base for b in SKIP_BITS):
            continue
        spec, era = m.group(1), m.group(2)
        cls = os.path.basename(os.path.dirname(f))
        specs.setdefault((cls, spec), {})[era] = f
    return specs


REASONS = {
    "wotlk": (
        "WotLK-era build-out: <SPEC>_wotlk.lua is a minimal APL-mirror rotation; "
        "utility/PvP/consumable/defensive strategies are TBC/vanilla-era "
        "(see docs/scorecard.md WotLK rows)"
    ),
    "vanilla": (
        "vanilla mirror implements the core rotation only; the TBC-era utility "
        "suite (consumables, PvP, hit-cap, spreads) is not mirrored"
    ),
    "sylvanas": (
        "TBC covers this via the class middleware or a different strategy name; "
        "vanilla/wotlk-only strategy"
    ),
}


def _normalize(s):
    """Content comparison is line-ending agnostic: git may check the seed out
    as CRLF on Windows (autocrlf), while the generator emits LF. Strip \r so
    a checkout-mode difference can never false-fail the drift guard."""
    return s.replace("\r\n", "\n")


def generate_content():
    """Build the seed file content in memory. Returns (content, entries, total)."""
    mid = middleware_interrupts()
    specs = collect_specs()
    entries = []
    for (cls, spec), eras in sorted(specs.items()):
        if len(eras) < 2:
            continue
        sets = {}
        for era, f in eras.items():
            s = names_in(open(f, encoding="utf-8", errors="replace").read())
            if era == "sylvanas":
                s |= mid.get(cls, set())
            sets[era] = s
        for era in sorted(eras):
            missing = set()
            for other in eras:
                if other == era:
                    continue
                missing |= sets[other] - sets[era]
            if missing:
                entries.append((f"{cls}/{spec}", era, sorted(missing)))

    lines = [
        "-- era_pair_seed.lua -- baseline era-mirror divergence table.",
        "-- WHAT:  for each spec with era sibling files (sylvanas/vanilla/wotlk),",
        "--        the strategy names present in one era but missing in a sibling",
        "--        era file. Read by the era-pair audit",
        "--        (run_era_pair_audit_tests.lua) as its reviewed allowlist",
        "--        baseline: divergences outside this table fail the audit.",
        "-- WHEN:  regenerated deliberately via",
        "--        EaxRotations/tools/generate_era_pair_seed.py (local-only",
        "--        manual step, like generate_buff_debuff_verification.py) and",
        "--        committed together with the rotation change that re-baselines",
        "--        it; consumed on every verify_all / pre-commit run.",
        "-- WHY:   the WotLK rogue Kick-interrupt gap was found only by hand; the",
        "--        seed pins the accepted divergence set so a strategy added to",
        "--        one era without its siblings, or removed from one sibling,",
        "--        fails loudly (same drift pattern as the scorecard/badge pins).",
        "-- SAFETY: data table only; no code, no side effects.",
        "--",
        "-- SCAN SCOPE (documented, not silent):",
        "--   * leveling_* files are era-specific teaching rotations, not mirror-",
        "--     synced (see test_leveling_* suites) -- excluded by design.",
        "--   * *_sod.lua is the separate SoD experiment (runes) -- excluded.",
        "--   * TBC (sylvanas) sets fold in the class middleware's interrupt",
        "--     registrations (register_interrupt_spell), since interrupts are a",
        "--     class-baseline capability the middleware provides era-wide.",
        "return {",
    ]
    total = 0
    for spec, era, names in entries:
        total += len(names)
        reason = REASONS[era].replace("<SPEC>", spec.replace("/", "_"))
        lines.append("    {")
        lines.append(f"        spec = {json.dumps(spec)},")
        lines.append(f"        missing_in = {json.dumps(era)},")
        lines.append(f"        names = {{ {', '.join(json.dumps(n) for n in names)} }},")
        lines.append(f"        reason = {json.dumps(reason)},")
        lines.append("    },")
    lines.append("}")
    return "\n".join(lines) + "\n", len(entries), total


def check_freshness(committed_content=None):
    """Drift guard: the committed seed must match a fresh regeneration.
    committed_content is optional for the in-memory self-test; when omitted,
    the committed file on disk is read. Returns 0 (in sync) or 1 (drift)."""
    content, entries, total = generate_content()
    if committed_content is None:
        if not os.path.exists(OUT):
            print(f"era-pair seed freshness: MISSING {OUT} (expected a committed seed)")
            return 1
        with open(OUT, encoding="utf-8", errors="replace") as fh:
            committed_content = fh.read()
    if _normalize(content) == _normalize(committed_content):
        print(f"era-pair seed freshness: in sync ({entries} entries, {total} names)")
        return 0
    print("era-pair seed freshness: DRIFT — committed " + OUT + " does not match a fresh")
    print("  regeneration of EaxRotations/tools/generate_era_pair_seed.py.")
    print("  Fix: regenerate and commit the seed TOGETHER with the rotation change that")
    print("  re-baselined it:  python EaxRotations/tools/generate_era_pair_seed.py")
    return 1


def self_test():
    """In-memory non-vacuity: the clean comparison passes and a corrupted
    copy of the generated content is detected as drift. No filesystem writes."""
    content, _, _ = generate_content()
    ok = True
    if check_freshness(content) != 0:
        ok = False
    corrupt = content.replace('"Pummel"', '"PummelX"', 1)
    if corrupt == content:  # Pummel absent from the generated content — corrupt a name instead
        corrupt = content.replace('names = { "', 'names = { "X', 1)
    if check_freshness(corrupt) != 1:
        ok = False
    if not ok:
        print("era-pair seed freshness self-test: FAILED")
        return 1
    print("[PASS] Era-pair seed freshness self-tests: clean comparison passes, corrupted-seed drift detection fires")
    return 0


def main():
    if "--check" in sys.argv:
        sys.exit(check_freshness())
    if "--self-test" in sys.argv:
        sys.exit(self_test())
    content, entries, total = generate_content()
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(content)
    print(f"wrote {OUT}: {entries} entries, {total} names")


if __name__ == "__main__":
    main()
