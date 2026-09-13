#!/usr/bin/env python3
"""spell_id_sweep.py -- cross-check every pinned spell id against the local sources.

WHAT   Parses every id-pinning site (spec `define` ladders, `ids = {...}` ladders,
       shared id tables) and classifies each id against:
         DBC     shared/_dbc_spell_ids.lua  (every id in the TBC client DBC)
         CLASSIC shared/wowhead_data_bridge_spell_index_tbc_sylvanas.lua (name/class/level/rank/cd)
         WOTLK   shared/wowhead_data_bridge_spell_index_wotlk_sylvanas.lua
         FIXTURE tools/evidence/apl/*.apl.json (ids the pinned wowsims APLs cast)
         PINS    the wotlk audit's WOTLK_REFERENCE_ALIASES / WOTLK_SHARED_IDS /
                 WOTLK_REJECTED_IDS tables
WHY    48927 (Holy Shield) and the Chaos Bolt rank-1 head were shipped pins no
       offline gate could disprove: the audit accepts a bridge-gap id once it is
       pinned, so a fabricated pin is self-certifying.  This re-derives, from the
       raw sources, which pins are DEAD, REDIRECTED or parked on the WRONG RANK.
WHEN   python EaxRotations/tools/spell_id_sweep.py [--file P] [--md out.md] [--json out.json] [--strict]
       python EaxRotations/tools/spell_id_sweep.py --check           # gate: compare to the baseline
       python EaxRotations/tools/spell_id_sweep.py --self-test       # prove the gate is non-vacuous
       python EaxRotations/tools/spell_id_sweep.py --write-baseline  # re-pin deliberately
GATE   --check is wired into EaxRotations/tests/run_verify_all.lua (via
       tests/run_spell_id_sweep_check.lua). Every bucket carries a disposition
       frozen in CHECK_DISPOSITION and the exact finding set is pinned in the
       committed baseline, so a NEW wrong-family id fails the build -- and so
       does clearing one, until the pin is moved on purpose.
SAFETY Read-only except --write-baseline (one tracked JSON).  Exit 1 with
       --strict on a HARD finding, or with --check on any drift.
"""

import argparse, collections, glob, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(ROOT)
DBC_PATH = os.path.join(ROOT, "shared", "_dbc_spell_ids.lua")
CLASSIC_PATH = os.path.join(ROOT, "shared", "wowhead_data_bridge_spell_index_tbc_sylvanas.lua")
WOTLK_PATH = os.path.join(ROOT, "shared", "wowhead_data_bridge_spell_index_wotlk_sylvanas.lua")
WOTLK_AUDIT = os.path.join(ROOT, "tests", "run_wotlk_audit_tests.lua")
VANILLA_AUDIT = os.path.join(ROOT, "tests", "run_vanilla_audit_tests.lua")
SYLVANAS_AUDIT = os.path.join(ROOT, "tests", "run_sylvanas_audit_tests.lua")
FIXTURE_DIR = os.path.join(REPO, "tools", "evidence", "apl")
SCAN_DIRS = [os.path.join(ROOT, "classes"), os.path.join(ROOT, "shared")]


def read(path):
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read().replace("\r\n", "\n")


def split_lua_fields(body):
    """Split a Lua table body into top-level fields.

    Token-based on purpose: the earlier comma-walk appended a phantom empty
    field after every quoted value, which shifted every positional field
    (name/class/level/rank/cd) and silently made the level checks vacuous.
    """
    out = []
    for tok in re.findall('"[^"]*"|[^,]+', body):
        tok = tok.strip()
        if tok[:1] == '"' and tok[-1:] == '"':
            tok = tok[1:-1]
        out.append(tok)
    return out


def num(text):
    text = (text or "").strip()
    return int(text) if re.fullmatch(r"-?\d+", text) else None


def str_or_none(text):
    text = (text or "").strip()
    return None if text in ("", "nil") else text


def load_dbc():
    return {int(m.group(1)) for m in
            (re.match(r"\s*\[(\d+)\]\s*=\s*true", ln) for ln in read(DBC_PATH).split("\n")) if m}


def load_classic():
    out = {}
    for ln in read(CLASSIC_PATH).split("\n"):
        m = re.match(r"\s*\[(\d+)\]\s*=\s*\{(.*)\},\s*$", ln)
        if not m:
            continue
        f = split_lua_fields(m.group(2))
        out[int(m.group(1))] = {
            "name": str_or_none(f[0]) if len(f) > 0 else None,
            "cls": str_or_none(f[1]) if len(f) > 1 else None,
            "level": num(f[2]) if len(f) > 2 else None,
            "rank": num(f[7]) if len(f) > 7 else None,
            "cd": num(f[9]) if len(f) > 9 else None,
        }
    return out


def load_wotlk():
    out = {}
    for ln in read(WOTLK_PATH).split("\n"):
        m = re.match(r"\s*\[(\d+)\]\s*=\s*\{(.*)\},\s*$", ln)
        if not m:
            continue
        body = m.group(2)
        name = re.search(r'name\s*=\s*"([^"]*)"', body)
        cls = re.search(r'class\s*=\s*"([^"]*)"', body)
        lvl = re.search(r"level\s*=\s*(\d+|nil)", body)
        out[int(m.group(1))] = {
            "name": name.group(1) if name else None,
            "cls": cls.group(1) if cls else None,
            "level": int(lvl.group(1)) if lvl and lvl.group(1) != "nil" else None,
        }
    return out


def load_pins():
    pins, rejected, tables, cur = {}, set(), [], None
    for ln in read(WOTLK_AUDIT).split("\n"):
        m = re.match(r"local\s+(\w+)\s*=\s*\{", ln)
        if m:
            cur = m.group(1); tables.append(cur); continue
        if cur is None:
            continue
        if cur == "WOTLK_REJECTED_IDS":
            m = re.match(r"\s*\[(\d+)\]\s*=\s*true", ln)
            if m:
                rejected.add(int(m.group(1)))
            continue
        m = re.match(r'\s*\[(\d+)\]\s*=\s*\{\s*kind\s*=\s*"([^"]+)"\s*,\s*family\s*=\s*"([^"]*)"', ln)
        if m:
            pins[int(m.group(1))] = {"kind": m.group(2), "family": m.group(3), "table": cur}
    return pins, rejected, tables


def load_audit_id_set(path, table_name):
    out, cur = set(), None
    for ln in read(path).split("\n"):
        m = re.match(r"local\s+(\w+)\s*=\s*\{", ln)
        if m:
            cur = m.group(1); continue
        if cur == table_name:
            m = re.match(r"\s*\[(\d+)\]\s*=", ln)
            if m:
                out.add(int(m.group(1)))
    return out


def load_fixture_ids():
    out = {}
    for path in sorted(glob.glob(os.path.join(FIXTURE_DIR, "*.apl.json"))):
        ids = set()

        def walk(node):
            if isinstance(node, dict):
                for k, v in node.items():
                    if k in ("spellId", "auraId") and isinstance(v, int):
                        ids.add(v)
                    else:
                        walk(v)
            elif isinstance(node, list):
                for v in node:
                    walk(v)

        try:
            walk(json.loads(read(path)))
        except Exception:
            continue
        out[os.path.basename(path).replace(".apl.json", "")] = ids
    return out


DEFINE_RE = re.compile(r'define\(\s*"([^"]+)"\s*,\s*')


def find_matching_brace(src, start):
    depth, i, n = 0, start, len(src)
    while i < n:
        c = src[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i
        elif c == '"':
            i += 1
            while i < n and src[i] != '"':
                i += 2 if src[i] == "\\" else 1
        i += 1
    return -1


def line_of(src, pos):
    return src.count("\n", 0, pos) + 1


def extract_defines(src, path):
    sites = []
    for m in DEFINE_RE.finditer(src):
        label = m.group(1)
        i = m.end()
        while i < len(src) and src[i] in " \n\t":
            i += 1
        ids = []
        if i < len(src) and src[i] == "{":
            end = find_matching_brace(src, i)
            if end < 0:
                continue
            ids = [int(t) for t in re.findall(r"\d+", src[i + 1:end])]
            i = end + 1
        else:
            nm = re.match(r"(\d+)", src[i:])
            if not nm:
                continue
            ids = [int(nm.group(1))]
            i += nm.end()
        nm = re.match(r'\s*,\s*"([^"]*)"', src[i:])
        sites.append({"file": path, "line": line_of(src, m.start()), "kind": "define",
                      "label": label, "name": nm.group(1) if nm else None, "ids": ids})
    return sites


IDS_RE = re.compile(r"\bids\s*=\s*\{([\d,\s]+)\}")
NAME_BACK_RE = re.compile(r'name\s*=\s*"([^"]+)"')


def extract_ids_blocks(src, path):
    sites = []
    for m in IDS_RE.finditer(src):
        ids = [int(t) for t in re.findall(r"\d+", m.group(1))]
        if not ids:
            continue
        names = NAME_BACK_RE.findall(src[max(0, m.start() - 900):m.start()])
        label = names[-1] if names else "(unlabeled)"
        sites.append({"file": path, "line": line_of(src, m.start()), "kind": "ids-block",
                      "label": label, "name": label, "ids": ids})
    return sites


def era_of(path):
    base = os.path.basename(path)
    # death knight is a WotLK-only class: its *_sylvanas.lua files carry WotLK ids
    if "/deathknight/" in path.replace("\\", "/"):
        return "wotlk"
    # shared modules are era-agnostic: no era assertion applies to them
    if "/shared/" in path.replace("\\", "/"):
        return "shared"
    if "_vanilla" in base:
        return "vanilla"
    if "_wotlk" in base:
        return "wotlk"
    if "_sod" in base:
        return "sod"
    if "_sylvanas" in base:
        return "tbc"
    return "shared"


def normalize(text):
    return re.sub(r"[^a-z0-9]", "", (text or "").lower())


def norm_family(text):
    t = text or ""
    t = re.sub(r"^(Pet|Talent):\s*", "", t)
    t = re.sub(r"\s*\(.*?\)\s*", " ", t)
    t = re.sub(r"\s*r\d+\s*$", "", t)
    t = re.sub(r"\s*(max|top|rank)\s*$", "", t)
    return normalize(t)


SKIP_WORDS = {"the", "of", "a", "rank", "max", "top", "pet", "talent", "spell"}


def words(text):
    return {w for w in re.findall(r"[a-z0-9]+", (text or "").lower()) if w not in SKIP_WORDS}


def names_agree(label, name, bridge_name):
    """True when a pinned label/name plausibly denotes the bridge spell."""
    bw = words(bridge_name)
    if not bw:
        return True
    for cand in (name, label, norm_family(name or ""), norm_family(label or "")):
        cw = words(cand)
        if cw and (cw <= bw or bw <= cw):
            return True
        cn, bn = normalize(cand), normalize(bridge_name)
        if cn and bn and (cn in bn or bn in cn):
            return True
    return False


CHECK_ORDER = ["DEAD", "REJECTED-ID-IN-USE", "ERA-TBC-IN-VANILLA", "ERA-WOTLK-IN-TBC",
               "WRONG-RANK", "RANK-ORDER", "REDIRECTED", "PIN-FAMILY-MISMATCH",
               "DUPLICATE-CONFLICT", "UNSOURCED"]

CHECK_BLURB = {
    "DEAD": "no local source knows the id",
    "REJECTED-ID-IN-USE": "id is in WOTLK_REJECTED_IDS (previously disproven)",
    "RANK-ORDER": "a higher rank is listed after a lower rank of the same spell. Adjudicated 2026-09-13: every standing row is an ORDER-INSENSITIVE rank list (talent_inference_sylvanas.lua TALENT_SIGNATURES, dispel_manager_sylvanas.lua pet-rank tables) or the deliberate vanilla Lightning Bolt downrank lane (elemental_vanilla.lua prefers a *lower* rank on purpose), so order carries no cast meaning at those sites; a NEW row means a real cast ladder has a lower rank ahead of a higher one and every cast from it silently down-ranks",
    "ERA-TBC-IN-VANILLA": "post-60 id in a vanilla file",
    "ERA-WOTLK-IN-TBC": "WotLK-only id in a TBC file",
    "REDIRECTED": "bridge name disagrees with the pinned label (wrong-family id)",
    "WRONG-RANK": "a higher rank of the same spell exists outside the ladder (the bridge names cast/effect twins alike, so verify before acting)",
    "PIN-FAMILY-MISMATCH": "audit pin family disagrees with the bridge name",
    "DUPLICATE-CONFLICT": "one id pinned under two different names",
    "UNSOURCED": "no local source knows the id (WotLK triage only: the local index is a subset)",
}


# ---------------------------------------------------------------- baseline --
# Classified once (2026-09-13). Every bucket gets a disposition, and --check
# enforces it:
#   gate   -- the bucket is a *proof of wrongness*: a fabricated id, a
#             cross-era leak, or a pin the repo already disproved. It must stay
#             empty, so --write-baseline refuses to freeze one (a dead id is
#             never "acceptable"); any finding here fails the build.
#   pinned -- the bucket is an adjudicated *triage lead*. The exact finding set
#             (the check|id|file multiset in the committed baseline) is frozen,
#             so a NEW wrong-family id still hard-fails the gate, and clearing
#             one requires a deliberate re-baseline.
# This is the never-fires discipline (verify_all pins "never-firing 11")
# applied to ids: gate buckets read zero, pinned buckets read their classified
# count, and drift in EITHER direction fails until the pin is moved on purpose.
CHECK_DISPOSITION = {
    "DEAD": "gate",
    "REJECTED-ID-IN-USE": "gate",
    "ERA-TBC-IN-VANILLA": "gate",
    "ERA-WOTLK-IN-TBC": "gate",
    "REDIRECTED": "pinned",
    "WRONG-RANK": "pinned",
    "RANK-ORDER": "pinned",
    "PIN-FAMILY-MISMATCH": "pinned",
    "DUPLICATE-CONFLICT": "pinned",
    "UNSOURCED": "pinned",
}

BASELINE_PATH = os.path.join(ROOT, "tools", "spell_id_sweep_baseline.json")
BASELINE_RELPATH = "EaxRotations/tools/spell_id_sweep_baseline.json"
BASELINE_SCHEMA = 1
REBASELINE_CMD = "python EaxRotations/tools/spell_id_sweep.py --write-baseline"


def finding_key(f):
    """Stable finding identity: the check, the id, and the file that pins it.

    Line numbers and labels are deliberately excluded -- they drift with every
    edit, and pinning them would turn a whitespace change into phantom id
    drift. The invariant frozen in the baseline is "this id, in this file,
    trips this check".
    """
    return "%s|%s|%s" % (f["check"], f.get("id"), f.get("file"))


def bucket_totals(findings):
    out = {}
    for f in findings:
        entry = out.setdefault(f["check"], {"hard": 0, "review": 0})
        entry[f["severity"]] = entry.get(f["severity"], 0) + 1
    return out


def gate_buckets_hit(findings):
    return sorted({f["check"] for f in findings
                   if CHECK_DISPOSITION.get(f["check"]) == "gate"})


def ordered_checks(present, base):
    names = set(present) | set(((base or {}).get("buckets") or {}).keys())
    return ([c for c in CHECK_ORDER if c in names]
            + sorted(c for c in names if c not in set(CHECK_ORDER)))


def resolve_paths(args):
    if args.file:
        return [p if os.path.isabs(p) else os.path.join(REPO, p) for p in args.file]
    paths = []
    for d in SCAN_DIRS:
        for root, _dirs, files in os.walk(d):
            for fn in sorted(files):
                if fn.endswith(".lua"):
                    paths.append(os.path.join(root, fn))
    return paths


def write_baseline(findings):
    hit = gate_buckets_hit(findings)
    if hit:
        print("REFUSING to write the baseline: %s %s a 'gate' bucket (must stay empty) but "
              "carries %d finding(s). Fix the ids; do not pin them."
              % (", ".join(hit), "is" if len(hit) == 1 else "are",
                 sum(1 for f in findings if f["check"] in hit)))
        return 1
    keys = collections.Counter(finding_key(f) for f in findings)
    doc = {
        "schema": BASELINE_SCHEMA,
        "note": "Frozen spell-id sweep baseline -- the classified-once pin. "
                "Regenerate deliberately with: " + REBASELINE_CMD,
        "dispositions": dict(CHECK_DISPOSITION),
        "buckets": bucket_totals(findings),
        "totals": {"hard": sum(1 for f in findings if f["severity"] == "hard"),
                   "review": sum(1 for f in findings if f["severity"] != "hard"),
                   "findings": len(findings)},
        "findings": dict(sorted(keys.items())),
    }
    with open(BASELINE_PATH, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(doc, fh, indent=1)
        fh.write("\n")
    print("wrote %s: %d findings / %d unique keys / hard %d"
          % (BASELINE_RELPATH, len(findings), len(keys), doc["totals"]["hard"]))
    return 0


def load_baseline():
    try:
        with open(BASELINE_PATH, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return None


def check_baseline(findings):
    """Compare the live sweep to the pinned baseline; 0 = in sync, 1 = drift."""
    hard = sum(1 for f in findings if f["severity"] == "hard")
    review = len(findings) - hard
    now = bucket_totals(findings)
    base = load_baseline()
    if base is None:
        print("spell-id sweep --check: %d findings (hard %d / review %d)"
              % (len(findings), hard, review))
        print("NEW: %d" % len(findings))
        print("CLEARED: 0")
        print("HARD: %d" % hard)
        print("REVIEW: %d" % review)
        print("verdict: NO BASELINE (%s missing or unreadable)" % BASELINE_RELPATH)
        print("         create one deliberately with: " + REBASELINE_CMD)
        return 1

    pinned = collections.Counter(base.get("findings") or {})
    current = collections.Counter(finding_key(f) for f in findings)
    new, cleared = current - pinned, pinned - current
    pin = base.get("totals") or {}
    print("spell-id sweep --check: %d findings (hard %d / review %d) vs pinned baseline "
          "(%s findings, hard %s)"
          % (len(findings), hard, review, pin.get("findings", "?"), pin.get("hard", "?")))
    pin_buckets = base.get("buckets") or {}
    for check in ordered_checks(now, base):
        got = now.get(check, {"hard": 0, "review": 0})
        was = pin_buckets.get(check, {"hard": 0, "review": 0})
        same = (got.get("hard", 0) == was.get("hard", 0)
                and got.get("review", 0) == was.get("review", 0))
        print("  bucket %-19s %-7s now hard %d / review %d   pinned hard %d / review %d   %s"
              % (check, CHECK_DISPOSITION.get(check, "(unclassified)"),
                 got.get("hard", 0), got.get("review", 0),
                 was.get("hard", 0), was.get("review", 0), "ok" if same else "DRIFT"))
    for key, n in sorted(new.items()):
        print("  + NEW     %s  x%d" % (key, n))
    for key, n in sorted(cleared.items()):
        print("  - CLEARED %s  x%d" % (key, n))
    print("NEW: %d" % sum(new.values()))
    print("CLEARED: %d" % sum(cleared.values()))
    print("HARD: %d" % hard)
    print("REVIEW: %d" % review)

    problems = []
    if base.get("schema") != BASELINE_SCHEMA:
        problems.append("baseline schema mismatch")
    if base.get("dispositions") != dict(CHECK_DISPOSITION):
        problems.append("disposition drift (CHECK_DISPOSITION != baseline)")
    if sum(new.values()):
        problems.append("%d new" % sum(new.values()))
    if sum(cleared.values()):
        problems.append("%d cleared" % sum(cleared.values()))
    if hard:
        problems.append("%d hard" % hard)
    if problems:
        print("verdict: OUT OF SYNC (%s)" % ", ".join(problems))
        print("         re-baseline deliberately: " + REBASELINE_CMD)
        return 1
    print("verdict: in sync with the classified-once baseline")
    return 0


def self_test():
    """Prove the gate is non-vacuous, end to end, without writing to the tree.

    Runs the REAL extractor + classifier over synthetic ladders authored here:
    one pins 2048 (Battle Shout in the TBC client) under a Frostbolt label --
    the wrong-family shape that shipped as `SodCleave` = Heroic Strike -- one
    pins an id no local source knows (the DEAD/gate shape), and one pins 2048
    correctly, which must stay silent. The committed comparator must then
    classify the first two as NEW, so a mislabelled pin can never pass.
    """
    import shutil
    import tempfile

    checks, fails = [], []

    def expect(cond, msg):
        checks.append(msg)
        if not cond:
            fails.append(msg)

    tmp = tempfile.mkdtemp(prefix="spell_id_sweep_selftest_")
    try:
        wrong = os.path.join(tmp, "zz_selftest_wrongfamily_sylvanas.lua")
        dead = os.path.join(tmp, "zz_selftest_unknownid_sylvanas.lua")
        right = os.path.join(tmp, "zz_selftest_correct_sylvanas.lua")
        with open(wrong, "w", encoding="utf-8", newline="\n") as fh:
            fh.write('local S = {}\nS.zz = { define("Frostbolt", 2048, "Frostbolt") }\n')
        with open(dead, "w", encoding="utf-8", newline="\n") as fh:
            fh.write('local S = {}\nS.zz = { define("Frostbolt", 989898989, "Frostbolt") }\n')
        with open(right, "w", encoding="utf-8", newline="\n") as fh:
            fh.write('local S = {}\nS.zz = { define("BattleShout", 2048, "Battle Shout") }\n')

        _summary, findings = sweep([wrong, dead, right])
        wrong_rel = os.path.relpath(wrong, REPO).replace("\\", "/")
        right_rel = os.path.relpath(right, REPO).replace("\\", "/")

        redirected = [f for f in findings
                      if f["check"] == "REDIRECTED" and f.get("id") == 2048
                      and f["file"] == wrong_rel]
        unknown = [f for f in findings if f["severity"] == "hard" and f.get("id") == 989898989]
        silent = [f for f in findings if f["file"] == right_rel]

        expect(bool(redirected),
               "wrong-family pin (2048 = Battle Shout under a Frostbolt label) must flag REDIRECTED")
        expect(bool(unknown), "an id no local source knows must flag a HARD (gate) bucket")
        expect(not silent, "a correctly labelled pin must stay silent (the check must discriminate)")
        expect(redirected and not gate_buckets_hit(redirected),
               "REDIRECTED must be a 'pinned' bucket, so a wrong-family id is pinnable-but-flagged")

        base = load_baseline()
        if base is None:
            checks.append("baseline present")
            fails.append("baseline %s is missing -- the comparator cannot be proven"
                         % BASELINE_RELPATH)
        else:
            pinned = collections.Counter(base.get("findings") or {})
            new = collections.Counter(finding_key(f) for f in findings) - pinned
            for f in redirected + unknown:
                expect(finding_key(f) in new,
                       "injected finding must classify NEW vs the baseline: %s" % finding_key(f))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    if fails:
        print("[FAIL] spell_id_sweep self-test: %d of %d checks failed" % (len(fails), len(checks)))
        for msg in fails:
            print("   !! " + msg)
        return 1
    print("[PASS] spell_id_sweep self-test: injected wrong-family pin flagged REDIRECTED, "
          "injected unknown id flagged HARD, correctly labelled pin stayed silent, and both "
          "injected findings classify NEW vs the committed baseline (%d/%d checks)"
          % (len(checks), len(checks)))
    return 0


def load_sources():
    pins, rejected, tables = load_pins()
    fixtures = load_fixture_ids()
    fixture_ids = set()
    for ids in fixtures.values():
        fixture_ids |= ids
    return {
        "dbc": load_dbc(), "classic": load_classic(), "wotlk": load_wotlk(),
        "pins": pins, "rejected": rejected, "pin_tables": tables,
        "fixtures": fixtures, "fixture_ids": fixture_ids,
        "v_tbc": load_audit_id_set(VANILLA_AUDIT, "TBC_IDS"),
        "s_wotlk": load_audit_id_set(SYLVANAS_AUDIT, "WOTLK_ONLY_IDS"),
    }


def extract_sites(paths):
    sites = []
    for path in paths:
        src = read(path)
        sites += extract_defines(src, path)
        sites += extract_ids_blocks(src, path)
    return sites


def add_finding(findings, code, sev, site, msg, **extra):
    try:
        rel = os.path.relpath(site["file"], REPO)
    except ValueError:
        # different Windows drive (repo on D:, temp file on C:): the self-test
        # feeds sweep() a synthetic source outside the repo, so never crash here.
        rel = site["file"]
    rec = {"check": code, "severity": sev,
           "file": rel.replace("\\", "/"),
           "line": site["line"], "label": site["label"], "msg": msg}
    rec.update(extra)
    findings.append(rec)


ERA_CAP = {"vanilla": 60, "sod": 60, "tbc": 70}


def era_max_index(classic, dbc, cap):
    """(name, class) -> the highest rank learnable within an era level cap."""
    out = {}
    for sid, rec in classic.items():
        if sid not in dbc or not rec["name"] or rec["level"] is None or rec["level"] > cap:
            continue
        key = (normalize(rec["name"]), normalize(rec["cls"] or ""))
        cur = out.get(key)
        if cur is None or rec["level"] > cur[1]:
            out[key] = (sid, rec["level"])
    return out


def sweep(paths):
    S = load_sources()
    dbc, classic, wotlk = S["dbc"], S["classic"], S["wotlk"]
    pins, rejected = S["pins"], S["rejected"]
    fixture_ids = S["fixture_ids"]
    era_max = {cap: era_max_index(classic, dbc, cap) for cap in (60, 70)}
    sites = extract_sites(paths)
    findings = []
    checked = 0

    for site in sites:
        era = era_of(site["file"])
        for pos, sid in enumerate(site["ids"]):
            checked += 1
            rec, wrec = classic.get(sid), wotlk.get(sid)
            known_dbc, known_wotlk = sid in dbc, wrec is not None
            pinned = sid in pins
            # Names are only comparable when the id is era-real for the index
            # used: the classic dump and the DBC set disagree outside that
            # overlap (51414 = Frost Strike in 3.3.5, an NPC spell in the dump).
            bridge_name = None
            if era == "wotlk":
                if wrec and wrec.get("name"):
                    bridge_name = wrec["name"]
            elif era in ("tbc", "vanilla", "sod") and rec and sid in dbc:
                bridge_name = rec["name"]
            where = "head" if pos == 0 else "body"
            base = dict(id=sid, era=era, position=where)

            if not (known_dbc or rec or known_wotlk or pinned or sid in fixture_ids):
                # Absence is proof for the TBC/vanilla eras (the DBC set and the
                # index are the era universe) but only a triage lead for WotLK,
                # whose local index is a curated subset.
                code = "DEAD" if era in ("tbc", "vanilla") else "UNSOURCED"
                add_finding(findings, code, "hard" if code == "DEAD" else "review", site,
                            "id unknown to the DBC set, both bridges, the fixtures and the pin tables",
                            **base)
            if bridge_name and not names_agree(site["label"], site["name"], bridge_name):
                add_finding(findings, "REDIRECTED", "review", site,
                            "bridge calls this id %r" % bridge_name, bridge_name=bridge_name, **base)
            if era == "vanilla" and rec and rec["level"] is not None and rec["level"] > 60:
                add_finding(findings, "ERA-TBC-IN-VANILLA",
                            "review" if sid in S["v_tbc"] else "hard", site,
                            "classic index learn level %d > 60 (TBC-era rank)" % rec["level"],
                            covered_by_audit=(sid in S["v_tbc"]), **base)
            if era == "tbc" and not known_dbc and not rec and known_wotlk:
                add_finding(findings, "ERA-WOTLK-IN-TBC",
                            "review" if sid in S["s_wotlk"] else "hard", site,
                            "id is only in the WotLK bridge (absent from the TBC DBC set and classic index)",
                            covered_by_audit=(sid in S["s_wotlk"]), **base)
            if sid in rejected:
                add_finding(findings, "REJECTED-ID-IN-USE", "hard", site,
                            "id is pinned in WOTLK_REJECTED_IDS as disproven", **base)

            if pinned and bridge_name and not names_agree(pins[sid]["family"], pins[sid]["family"], bridge_name):
                add_finding(findings, "PIN-FAMILY-MISMATCH", "review", site,
                            "pin table calls this id %r, the bridge calls it %r"
                            % (pins[sid]["family"], bridge_name),
                            pin_table=pins[sid]["table"], **base)
            # WRONG-RANK: the ladder HEAD must be the highest rank its own era
            # can learn. Tails are fallbacks by design, so only the head is
            # checked: a lower rank leading the ladder is the Chaos Bolt /
            # Holy Shield failure shape.
            if pos == 0 and era in ERA_CAP and rec and sid in dbc and rec["name"] and rec["level"] is not None:
                key = (normalize(rec["name"]), normalize(rec["cls"] or ""))
                best = era_max[ERA_CAP[era]].get(key)
                # the vanilla audit's curated TBC_IDS list already classifies the
                # late-vanilla 25xxx boundary ids as TBC-era: suppressing those
                # keeps this check to ids the repo has not already adjudicated.
                head_below_era_max = (best and best[1] > rec["level"]
                                      and best[0] not in site["ids"][1:]
                                      and best[0] not in S["v_tbc"])
                if head_below_era_max:
                    add_finding(findings, "WRONG-RANK", "review", site,
                                "%s ladder head is the level-%d rank, but %d is the level-%d rank of the same spell"
                                % (era, rec["level"], best[0], best[1]),
                                better_id=best[0], better_level=best[1], **base)
            # RANK-ORDER: a higher rank must never sit after a lower one
            if pos > 0 and rec and sid in dbc and rec["level"] is not None:
                prior = [(q, classic[q]["level"]) for q in site["ids"][:pos]
                         if q in dbc and classic[q]["level"] is not None
                         and normalize(classic[q]["name"] or "") == normalize(rec["name"] or "")]
                if prior:
                    prev_sid, prev_lvl = max(prior, key=lambda t: t[1])
                    if rec["level"] > prev_lvl:
                        add_finding(findings, "RANK-ORDER", "review", site,
                                    "this rank (level %d) is listed after id %d (level %d) of the same spell"
                                    % (rec["level"], prev_sid, prev_lvl), **base)

    claims = {}
    for site in sites:
        for sid in site["ids"]:
            claims.setdefault(sid, set()).add(norm_family(site["name"] or site["label"]))
    for sid, raw in sorted(claims.items()):
        fams = {f for f in raw if f}
        fams = {f[3:] if f.startswith("sod") and f[3:] in fams else f for f in fams}

        def related(a, b):
            if a in b or b in a:
                return True
            return bool(words(a) & words(b))

        fam_list = sorted(fams)
        mismatch = any(not related(a, b)
                       for i, a in enumerate(fam_list) for b in fam_list[i + 1:])
        if len(fams) > 1 and mismatch:
            where = [s for s in sites if sid in s["ids"]]
            add_finding(findings, "DUPLICATE-CONFLICT", "review", where[0],
                        "same id pinned under %d different names: %s"
                        % (len(fams), ", ".join(sorted(fams))),
                        id=sid, era=era_of(where[0]["file"]),
                        sites=["%s:%d" % (os.path.relpath(s["file"], REPO).replace("\\", "/"), s["line"])
                               for s in where][:5])

    summary = {
        "sites": len(sites), "pins_checked": checked, "unique_ids": len(claims),
        "sources": {"dbc_ids": len(dbc), "classic_index_ids": len(classic),
                    "wotlk_index_ids": len(wotlk), "pin_table_ids": len(pins),
                    "rejected_ids": len(rejected), "fixture_ids": len(fixture_ids),
                    "fixtures": len(S["fixtures"]), "audit_vanilla_tbc_ids": len(S["v_tbc"]),
                    "audit_sylvanas_wotlk_only_ids": len(S["s_wotlk"])},
        "pin_tables": S["pin_tables"], "by_check": {},
    }
    for f in findings:
        entry = summary["by_check"].setdefault(f["check"], {"hard": 0, "review": 0})
        entry[f["severity"]] += 1
    return summary, findings


def main():
    ap = argparse.ArgumentParser(description="sweep every pinned spell id against the local sources")
    ap.add_argument("--file", action="append", default=[])
    ap.add_argument("--md")
    ap.add_argument("--json")
    ap.add_argument("--strict", action="store_true")
    ap.add_argument("--limit", type=int, default=40)
    ap.add_argument("--check", action="store_true",
                    help="gate mode: compare to the committed classified-once baseline; exit 1 on any "
                         "new/cleared finding, a non-empty gate bucket, or a hard finding")
    ap.add_argument("--write-baseline", action="store_true",
                    help="regenerate the committed baseline (refuses to pin a non-empty gate bucket)")
    ap.add_argument("--self-test", action="store_true",
                    help="inject a wrong-family pin + an unknown id into synthetic ladders and assert "
                         "the sweep and the baseline comparator flag them")
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    # The baseline is a whole-tree artifact: a partial --file sweep would either
    # clobber it with a subset (--write-baseline) or read every id as NEW
    # (--check), so both refuse the flag rather than quietly mislead.
    if args.file and (args.write_baseline or args.check):
        print("%s pins/checks the WHOLE tree; --file is not allowed with it."
              % ("--write-baseline" if args.write_baseline else "--check"))
        return 1

    paths = resolve_paths(args)
    summary, findings = sweep(paths)

    if args.write_baseline:
        return write_baseline(findings)
    if args.check:
        return check_baseline(findings)

    print("spell-id sweep -- %d ladders, %d ids checked, %d unique ids"
          % (summary["sites"], summary["pins_checked"], summary["unique_ids"]))
    print("sources: " + ", ".join("%s=%s" % kv for kv in sorted(summary["sources"].items())))
    print("")
    for check in CHECK_ORDER:
        entry = summary["by_check"].get(check)
        if not entry:
            continue
        rows = [f for f in findings if f["check"] == check]
        print("[%s] %d hard / %d review -- %s"
              % (check, entry["hard"], entry["review"], CHECK_BLURB[check]))
        for f in rows[:args.limit]:
            print("   %s:%d  %s  id=%s  %s"
                  % (f["file"], f["line"], f["label"], f.get("id"), f["msg"]))
        if len(rows) > args.limit:
            print("   ... %d more" % (len(rows) - args.limit))
        print("")
    hard = [f for f in findings if f["severity"] == "hard"]
    print("HARD: %d   REVIEW: %d" % (len(hard), len(findings) - len(hard)))

    if args.json:
        with open(args.json, "w", encoding="utf-8", newline="\n") as fh:
            json.dump({"summary": summary, "findings": findings}, fh, indent=1)
        print("wrote " + args.json)
    if args.md:
        with open(args.md, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("# Spell-id sweep\n\n")
            fh.write("Ladders: %d. Ids checked: %d. Unique ids: %d.\n\n"
                     % (summary["sites"], summary["pins_checked"], summary["unique_ids"]))
            fh.write("| check | hard | review |\n|---|---:|---:|\n")
            for check in CHECK_ORDER:
                entry = summary["by_check"].get(check)
                if entry:
                    fh.write("| %s | %d | %d |\n" % (check, entry["hard"], entry["review"]))
            fh.write("\n")
            for check in CHECK_ORDER:
                rows = [f for f in findings if f["check"] == check]
                if not rows:
                    continue
                fh.write("## %s\n\n%s\n\n" % (check, CHECK_BLURB[check]))
                fh.write("| file:line | label | id | finding |\n|---|---|---|---|\n")
                for f in rows:
                    fh.write("| `%s:%d` | %s | %s | %s |\n"
                             % (f["file"], f["line"], f["label"], f.get("id"), f["msg"]))
                fh.write("\n")
        print("wrote " + args.md)

    return 1 if (args.strict and hard) else 0


if __name__ == "__main__":
    sys.exit(main())
