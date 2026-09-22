#!/usr/bin/env python3
"""Generate EaxAutoQuester/shared/mount_items_sylvanas.lua from the TBC item corpus.

WHAT:  writes { [item_id] = "Item Name" } for every item whose use summons a mount, which is
       what mount_manager_sylvanas.lua consults when it has to judge an item already in the
       player's bags ("is this a mount I can ride?").

WHY A TOOL: the table is data, not logic, and hand-editing it is how it drifts. Regenerate
       instead of patching, so the next reader can tell where every id came from.

SOURCE (on this PC, both TBC-scoped):
  C:/newbot/PublicGithubs/tbc/assets/item_data/all_item_tooltips.csv
      Columns ItemID, URL_String, JSON_String. URL_String is a tbc.wowhead.com tooltip request
      and JSON_String is that request's answer: {"name","quality","icon","tooltip"}. The row is
      NOT quoted like a conventional CSV — the JSON is written raw into the third field and the
      quotes inside it are backslash-escaped — so the parse is "split at the first two commas,
      json.loads the rest". csv.DictReader fails on these rows; a quoted field would have been
      the other way to write it, but changing the parser would not fix the file.
  wowheadScrape/dbc_extract/wowsims.db
      Keept as a cross-check only. Its ItemEffect table carries no rows for classic/TBC mount
      items (every aura-78 item it knows is a modern id above 97000), so it cannot answer this
      question for the era we care about.

RULE: an item is a mount when its tooltip either
        (a) contains "Summons and dismisses"  — the use line every mount item carries, or
        (b) shows "Mount" as its item type     — the type line, which the counting-crystal and
            event-broom mounts carry WITHOUT the use line.
      Drop names containing deprecated / deptecated / test / [DNT], which are cut content the
      client cannot use but which still ship in the tooltip corpus.

Usage:
  python3 EaxAutoQuester/tools/generate_mount_items.py [--csv PATH] [--check]

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
                           "..", "shared", "mount_items_sylvanas.lua")

SUMMONS = "Summons and dismisses"
MOUNT_TYPE = re.compile(r">Mount<")
DEAD_NAME = re.compile(r"deprecated|deptecated|test|\[dnt\]", re.IGNORECASE)
ID_LINE = re.compile(r"^\s*\[(\d+)\]\s*=")


def parse_rows(path):
    """Yield (item_id, name, tooltip) for every row the corpus can parse."""
    with io.open(path, encoding="utf-8", errors="ignore") as f:
        for line in f:
            if line.startswith("ItemID,"):
                continue
            parts = line.rstrip("\n").split(",", 2)
            if len(parts) < 3:
                continue
            try:
                item_id = int(parts[0])
            except ValueError:
                continue
            try:
                obj = json.loads(parts[2])
            except ValueError:
                continue
            if not isinstance(obj, dict):
                continue
            yield item_id, (obj.get("name") or ""), (obj.get("tooltip") or "")


def collect(path):
    """Return {item_id: name} for every mount item, plus counts of what was dropped."""
    mined = {}
    for item_id, name, tooltip in parse_rows(path):
        if SUMMONS in tooltip or MOUNT_TYPE.search(tooltip):
            mined[item_id] = name

    kept, dropped = {}, {}
    for item_id, name in mined.items():
        if DEAD_NAME.search(name):
            dropped[item_id] = name
        else:
            kept[item_id] = name
    return kept, dropped


HEADER = """-- mount_items_sylvanas.lua — TBC mount ITEM ids, for finding a mount in the player's bags.
-- WHAT:  { [item_id] = "Item Name" } for every item whose use summons a mount.
-- WHEN:  Read by mount_manager_sylvanas when a bag item has to be judged: "is this a mount?"
-- WHY:   A mount you are CARRYING is invisible to the spellbook mount list, so "am I carrying
--        a mount?" needs an item list. Generated, never hand-edited: see
--        EaxAutoQuester/tools/generate_mount_items.py (run with --check to detect drift).
-- SOURCE: PublicGithubs/tbc/assets/item_data/all_item_tooltips.csv — tbc.wowhead.com tooltip
--         answers, one JSON object per row.
-- RULE:  tooltip contains "Summons and dismisses", OR the item type line is "Mount" (the
--         counting-crystal and event-broom mounts carry the type without the use line).
--         Names matching deprecated / deptecated / test / [DNT] are dropped: cut content that
--         ships in the corpus but cannot be used. {dropped} ids dropped on that rule.
-- COUNT: {count} ids as of {date}.
-- SAFETY: data only — no requires, no calls, no state. An id here can only ever be matched
--         against an item ALREADY in the bags, so a stale entry is inert: this table can never
--         put a mount in someone's inventory, only recognise one that is already there.
-- LIMITS: the corpus is TBC-scoped, so a mount added only in the 2.5.5 Anniversary client would
--         be missing. The live path prefers the client's own verdict
--         (core.quests.get_item_info(id).item_sub_type == "Mount"); this table is the backstop
--         for a build where that call is unavailable.
"""


def render(kept, dropped, date):
    out = [HEADER.replace("{count}", str(len(kept)))
                 .replace("{dropped}", str(len(dropped)))
                 .replace("{date}", date),
           "\nreturn {\n"]
    for item_id in sorted(kept):
        out.append('    [%d] = %s,\n' % (item_id, json.dumps(kept[item_id], ensure_ascii=False)))
    out.append("}\n")
    return "".join(out)


def ids_on_disk(path):
    found = set()
    with io.open(path, encoding="utf-8") as f:
        for line in f:
            m = ID_LINE.match(line)
            if m:
                found.add(int(m.group(1)))
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default=DEFAULT_CSV)
    ap.add_argument("--out", default=os.path.normpath(DEFAULT_OUT))
    ap.add_argument("--date", default=None, help="stamp for the header (defaults to today)")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    if not os.path.exists(args.csv):
        print("ERROR: corpus not found: %s" % args.csv)
        return 2

    kept, dropped = collect(args.csv)
    if not kept:
        print("ERROR: no mount items matched — the corpus format changed, refusing to write")
        return 2

    date = args.date or __import__("datetime").date.today().isoformat()

    if args.check:
        on_disk = ids_on_disk(args.out)
        missing = sorted(set(kept) - on_disk)
        stale = sorted(on_disk - set(kept))
        if missing or stale:
            print("ERROR: mount item table is out of date")
            if missing:
                print("  missing from the table (%d): %s" % (len(missing), missing[:20]))
            if stale:
                print("  in the table but not a mount now (%d): %s" % (len(stale), stale[:20]))
            return 1
        print("mount item table is in sync (%d ids)" % len(on_disk))
        return 0

    text = render(kept, dropped, date)
    # CRLF, matching the rest of EaxAutoQuester (the repo is CRLF throughout). A bare-LF table
    # would show up as a whole-file rewrite in `git diff`.
    with io.open(args.out, "w", encoding="utf-8", newline="") as f:
        f.write(text.replace("\n", "\r\n"))
    print("wrote %s: %d mount items (%d dropped as cut content)"
          % (args.out, len(kept), len(dropped)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
