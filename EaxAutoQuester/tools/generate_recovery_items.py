#!/usr/bin/env python3
"""Generate EaxAutoQuester/shared/recovery_items_sylvanas.lua from the TBC item corpus.

WHAT:  writes { [item_id] = { name, kind, min_level } } for every consumable whose use
       restores health or mana over time ("food" / "drink"), which is what
       shared/recovery.lua consults when the pull gate has parked the bot and it must
       classify what is already in its bags: what to use, and which bar it refills.

WHY A TOOL: the table is data, not logic, and hand-editing it is how it drifts. Regenerate
       instead of patching, so the next reader can tell where every id came from.

SOURCE (on this PC, TBC-scoped):
  C:/newbot/PublicGithubs/tbc/assets/item_data/all_item_tooltips.csv
      Columns ItemID, URL_String, JSON_String. URL_String is a tbc.wowhead.com tooltip request
      and JSON_String is that request's answer: {"name","quality","icon","tooltip"}. The row is
      NOT quoted like a conventional CSV -- the JSON is written raw into the third field and the
      quotes inside it are backslash-escaped -- so the parse is "split at the first two commas,
      json.loads the rest". csv.DictReader fails on these rows; a quoted field would have been
      the other way to write it, but changing the parser would not fix the file.

RULE: an item is food or drink when its tooltip carries a Use: line that restores
      "health over" or "mana over" a duration AND says "Must remain seated" -- the pair every
      sitting consumable carries (the seated clause is what separates an eat/drink item from a
      restorative with a different use text). kind is which of the two the Use line restores;
      the corpus has no TBC item restoring both in one use, so the two are exclusive here.
      min_level is the tooltip's "Requires Level", defaulting to 1 when absent.

EXCLUDED, and why:
  * names matching deprecated / deptecated / test / [DNT] -- cut content that ships in the
    corpus but cannot be used (the same rule the mount generator applies).
  * names starting "Recipe: " -- cooking recipe PAGES; their tooltips quote the finished dish's
    "Restores ... over" line, which otherwise sneaks them in as food. The dish itself is not
    excluded and stays.
  * names starting "Tome of Conjure" -- the mage spellbook TOMES; their tooltips quote the
    conjured item's drink/food line for the same reason. Conjured food and water themselves are
    NOT excluded: a consumable already in the bags is usable whatever its origin, and a mage's
    own conjured water is exactly what a recovery pause should drink.

Usage:
  python3 EaxAutoQuester/tools/generate_recovery_items.py [--csv PATH] [--check]

  --check   compare the file on disk against a fresh generation and exit non-zero on drift,
            so a stale table is a failing check rather than a silent gap.
"""

import argparse
import io
import json
import os
import re
import sys

DEFAULT_CSV = "C:/newbot/PublicGithubs/tbc/assets/item_data/all_item_tooltips.csv"
DEFAULT_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "..", "shared", "recovery_items_sylvanas.lua")

HEALTH_OVER = re.compile(r"Restores\s+[\d,\.]+\s+health over", re.IGNORECASE)
MANA_OVER = re.compile(r"Restores\s+[\d,\.]+\s+mana over", re.IGNORECASE)
SEATED = re.compile(r"Must remain seated", re.IGNORECASE)
USE_KW = re.compile(r"Use:", re.IGNORECASE)
REQUIRES_LEVEL = re.compile(r"Requires Level\s+(\d+)", re.IGNORECASE)
HTML_COMMENT = re.compile(r"<!--.*?-->")
DEAD_NAME = re.compile(r"deprecated|deptecated|test|\[dnt\]", re.IGNORECASE)
RECIPE_NAME = re.compile(r"^Recipe:\s", re.IGNORECASE)
TOME_NAME = re.compile(r"^Tome of Conjure", re.IGNORECASE)


def parse_rows(path):
    """Yield (item_id, name, tooltip) for every row the corpus can parse."""
    with io.open(path, encoding="utf-8", errors="ignore") as f:
        for line in f:
            if line.startswith("ItemID,"):
                continue
            parts = line.split(",", 2)
            if len(parts) < 3:
                continue
            try:
                item_id = int(parts[0])
                data = json.loads(parts[2])
            except (ValueError, json.JSONDecodeError):
                continue
            name = data.get("name") or ""
            tooltip = data.get("tooltip") or ""
            if item_id and name and tooltip:
                yield item_id, name, tooltip


def classify(name, tooltip):
    """(kind, min_level) for a sitting consumable, or None when the row is not one."""
    if DEAD_NAME.search(name) or RECIPE_NAME.match(name) or TOME_NAME.match(name):
        return None
    if not (USE_KW.search(tooltip) and SEATED.search(tooltip)):
        return None
    is_food = bool(HEALTH_OVER.search(tooltip))
    is_drink = bool(MANA_OVER.search(tooltip))
    if is_food == is_drink:      # neither, or the corpus never has both in one use
        return None
    plain = HTML_COMMENT.sub("", tooltip)
    m = REQUIRES_LEVEL.search(plain)
    return ("food" if is_food else "drink"), (int(m.group(1)) if m else 1)


def build(csv_path):
    """Return {item_id: (name, kind, min_level)} sorted by id."""
    out = {}
    for item_id, name, tooltip in parse_rows(csv_path):
        c = classify(name, tooltip)
        if c:
            out[item_id] = (name, c[0], c[1])
    return out


def render(items):
    lines = [
        "-- recovery_items_sylvanas.lua -- TBC food/drink ITEM ids, for classifying what is",
        "-- already in the player's bags when the pull gate has parked the bot to recover.",
        "-- WHAT:  { [item_id] = { name = \"Item Name\", kind = \"food\"|\"drink\", min_level = N } }.",
        "-- WHEN:  read by shared/recovery.lua; generated, never hand-edited -- see",
        "--        EaxAutoQuester/tools/generate_recovery_items.py (run with --check for drift).",
        "-- SOURCE: PublicGithubs/tbc/assets/item_data/all_item_tooltips.csv -- tbc.wowhead.com",
        "--         tooltip answers, one JSON object per row.",
        "-- RULE:  a Use: line restoring health or mana over a duration AND \"Must remain seated\".",
        "--        Excluded: cut content (deprecated/test/[DNT]), cooking recipe PAGES and mage",
        "--        conjure TOMES (their tooltips quote the dish's or water's restore line).",
        "--        Conjured food and water are INCLUDED: what is in the bags is usable, and a",
        "--        mage's own conjured water is exactly what a recovery pause should drink.",
        "-- SAFETY: data only -- no requires, no calls, no state. An id here can only ever be",
        "--         matched against an item ALREADY in the bags, so a stale entry is inert.",
        "-- COUNT: %d ids as of 2026-09-23." % len(items),
        "",
        "return {",
    ]
    for item_id in sorted(items):
        name, kind, min_level = items[item_id]
        lines.append('    [%d] = { name = "%s", kind = "%s", min_level = %d },'
                     % (item_id, name.replace('"', '\\"'), kind, min_level))
    lines.append("}")
    lines.append("")
    return "\n".join(lines).replace("\n", "\r\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--csv", default=DEFAULT_CSV)
    ap.add_argument("--check", action="store_true",
                    help="fail when the file on disk differs from a fresh generation")
    args = ap.parse_args()

    if not os.path.exists(args.csv):
        print("corpus not found: %s" % args.csv, file=sys.stderr)
        return 2

    rendered = render(build(args.csv))

    if args.check:
        with io.open(DEFAULT_OUT, encoding="utf-8", newline="") as f:
            on_disk = f.read()
        if on_disk != rendered:
            print("DRIFT: %s does not match a fresh generation -- regenerate it" % DEFAULT_OUT,
                  file=sys.stderr)
            return 1
        print("OK %s matches the corpus (%d ids)" % (DEFAULT_OUT, rendered.count("min_level") and
                                                     len(build(args.csv))))
        return 0

    with io.open(DEFAULT_OUT, "w", encoding="utf-8", newline="") as f:
        f.write(rendered)
    print("wrote %s (%d ids)" % (DEFAULT_OUT, len(build(args.csv))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
