#!/usr/bin/env python3
"""Generate EaxAutoQuester/object_spawns/ from the cMaNGOS tbc-db game-object tables.

WHAT:  writes the quest game-object spawn index the sweep consults when a goal's id names an
       object rather than a creature:  EaxAutoQuester/object_spawns/chunk_NNN.lua  (by_entry, the
       same shape EaxAutoQuester/npc_spawns uses) and EaxAutoQuester/object_spawns/manifest.lua.

WHY A TOOL: the index is data, and a hand-edited data file drifts silently. The creature index it
       sits beside was cut by hand once; this is the same job with a recorded source, a recorded
       filter and a check mode, so the next reader can tell where every coordinate came from and
       whether the file on disk still matches the source.

WHY IT MATTERS: a Zygor goal's `targetid` for an interactable is a gameobject_template entry, and
       a creature index cannot describe it. With no coordinates for "Ogre Remains", the sweep had
       nothing to walk to and fell back to the guide's waypoints — 108yd and 113yd legs and never a
       click (live, step 7). Naming the objective is the capability neither open pixel bot has.

SOURCE (either form, both TBC-scoped cMaNGOS tbc-db):
  --sql PATH       a SQL dump carrying CREATE TABLE / INSERT for `gameobject` and
                   `gameobject_template` (e.g. TBCDB_1.10.0_ReturnOfTheVengeance.sql, the same
                   dump EaxAutoQuester/npc_spawns was generated from). Column order is READ from
                   the CREATE TABLE when present, so a fork that adds a column cannot silently
                   shift every coordinate; the documented cMaNGOS order is the fallback and a
                   warning says so.
  --csv-dir DIR    the same two tables as CSV with headers (gameobject.csv,
                   gameobject_template.csv) for anyone who has them in a database rather than a
                   dump. Header names are matched case-insensitively.

RULE: an entry is kept when its gameobject_template `type` is in DEFAULT_TYPES, or when its name is
      listed by a repeatable --names option, or always under --all. The default set is the
      interactables a quest asks for — doors, buttons, quest objects, chests, spellcasters — and
      deliberately leaves out nodes (ore, herbs, veins), which are the bulk of the table. A build
      that needs nodes can opt in with --types or --all. Duplicate spawn rows collapse onto a
      --dedup grid.
      Every count the filter and the dedup changed is PRINTED: this is a size/precision trade and it
      is measured, not guessed.

OUTPUT IS BUILD DATA: the chunks and the manifest are gitignored (see .gitignore) and the accessor
       EaxAutoQuester/object_spawns.lua ships without them. With no data the accessor answers nil
       and the sweep behaves exactly as it did before this index existed — that is the contract,
       and tests/test_object_spawns.lua pins it.

Usage:
  python3 EaxAutoQuester/tools/generate_object_spawns.py --sql TBCDB_1.10.0_ReturnOfTheVengeance.sql
  python3 EaxAutoQuester/tools/generate_object_spawns.py --csv-dir out/csv --types 2,3,4
  python3 EaxAutoQuester/tools/generate_object_spawns.py --sql DB.sql --check
  python3 EaxAutoQuester/tools/generate_object_spawns.py --self-test
"""

import argparse
import csv
import os
import re
import sys

CHUNK_SIZE = 2000

# cMaNGOS gameobject_template.type, the values a quester interacts with rather than gathers.
# door=0, button=1, quest=2, chest=3, spellcaster=5. node=4 (ore/herb/vein) is the bulk and is out
# by default; --types 0,1,2,3,4,5 or --all brings it back.
DEFAULT_TYPES = (0, 1, 2, 3, 5)

# Documented cMaNGOS column order, used only when the dump has no CREATE TABLE to read.
GAMEOBJECT_COLUMNS = [
    "guid", "id", "map", "position_x", "position_y", "position_z", "orientation",
    "rotation0", "rotation1", "rotation2", "rotation3", "state", "AnimationInProgress",
    "spawntimesecs", "spawndist", "phase", "phasemask",
]
TEMPLATE_COLUMNS = [
    "entry", "type", "displayId", "name", "faction", "flags", "size", "data0", "data1",
    "data2", "data3", "data4", "data5", "data6", "data7", "data8", "data9", "data10",
    "data11", "data12", "data13", "data14", "data15", "data16", "data17", "data18",
    "dynamicflags", "dynflags", "questItem1", "questItem2", "questItem3", "questItem4",
    "questItem5", "questItem6",
]

CREATE_TABLE_RE = re.compile(
    r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?`?(\w+)`?\s*\((.*?)\)\s*(?:ENGINE|;)",
    re.IGNORECASE | re.DOTALL)
COLUMN_RE = re.compile(r"^\s*`(\w+)`")
INSERT_RE = re.compile(
    r"(?:INSERT|REPLACE)\s+(?:IGNORE\s+)?INTO\s+`?(\w+)`?\s+VALUES\s*", re.IGNORECASE)


# ----------------------------------------------------------------------------
# SQL tokenising
# ----------------------------------------------------------------------------

def split_values(text, start):
    """Yield the rows of a VALUES list, starting just after its opening keyword.

    Quote-aware, because a name can contain a comma, an escaped quote, or a semicolon
    ("Camp; Camp", "Baron's..."), and a regex over the raw text gets all three wrong. Stops at the
    first semicolon outside a string, which is the statement's end.
    """
    i = start
    n = len(text)
    field = []
    row = None
    quote = None
    escaped = False
    while i < n:
        ch = text[i]
        if quote:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == quote:
                # The closing quote ends the string and is not part of the value.
                quote = None
                i += 1
                continue
            field.append(ch)
            i += 1
            continue
        if ch in ("'", '"'):
            quote = ch
            i += 1
            continue
        if ch == "(":
            row = []
            field = []
            i += 1
            continue
        if ch == ")":
            if row is not None:
                row.append("".join(field).strip())
                yield row
            row = None
            field = []
            i += 1
            continue
        if ch == ",":
            if row is not None:
                row.append("".join(field).strip())
            field = []
            i += 1
            continue
        if ch == ";":
            return
        if row is not None:
            field.append(ch)
        i += 1


def unquote(value):
    """Turn a VALUES field into a plain string: strip the quotes, undo the backslash escapes."""
    value = value.strip()
    if len(value) >= 2 and value[0] in ("'", '"') and value[-1] == value[0]:
        value = value[1:-1]
    return value.replace("\\'", "'").replace('\\"', '"').replace("\\\\", "\\").replace("\\n", "\n")


def read_column_order(sql_text, table, fallback):
    """Column order from the CREATE TABLE, or the documented fallback (and say which was used)."""
    for match in CREATE_TABLE_RE.finditer(sql_text):
        if match.group(1).lower() != table:
            continue
        columns = []
        for line in match.group(2).split(","):
            # A column line starts with a backticked name; PRIMARY KEY / KEY / INDEX lines do not.
            column = COLUMN_RE.match(line)
            if column:
                columns.append(column.group(1).lower())
        if columns:
            return columns, None
    return list(fallback), ("no CREATE TABLE for `%s` in the dump; using the documented cMaNGOS "
                          "column order — if this dump adds a column, the coordinates will be "
                          "wrong" % table)


def iter_sql_rows(sql_text, table, columns):
    """Every row of `table` in a SQL dump, as a dict keyed by column name."""
    wanted = set(columns)
    for match in INSERT_RE.finditer(sql_text):
        if match.group(1).lower() != table:
            continue
        for row in split_values(sql_text, match.end()):
            if len(row) < len(columns):
                continue
            record = {}
            for index, name in enumerate(columns):
                if name in wanted:
                    record[name] = unquote(row[index])
            yield record


def to_int(value, default=0):
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return default


def to_float(value, default=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


# ----------------------------------------------------------------------------
# Reading the source, either form
# ----------------------------------------------------------------------------

def read_templates(sql_text=None, csv_dir=None):
    """entry -> {"name": str, "type": int} for every gameobject_template row."""
    templates = {}
    if sql_text is not None:
        columns, warning = read_column_order(sql_text, "gameobject_template", TEMPLATE_COLUMNS)
        if warning:
            print("WARN: " + warning, file=sys.stderr)
        for row in iter_sql_rows(sql_text, "gameobject_template", columns):
            entry = to_int(row.get("entry"), 0)
            if entry > 0:
                templates[entry] = {"name": row.get("name", ""), "type": to_int(row.get("type"), -1)}
        return templates

    path = os.path.join(csv_dir, "gameobject_template.csv")
    with open(path, newline="", encoding="utf-8", errors="ignore") as handle:
        for row in csv.DictReader(handle):
            lowered = {k.lower(): v for k, v in row.items() if k}
            entry = to_int(lowered.get("entry"), 0)
            if entry > 0:
                templates[entry] = {"name": lowered.get("name", ""),
                                    "type": to_int(lowered.get("type"), -1)}
    return templates


def read_spawns(sql_text=None, csv_dir=None):
    """entry -> list of (map_id, x, y, z), the raw rows before any filtering."""
    spawns = {}
    if sql_text is not None:
        columns, warning = read_column_order(sql_text, "gameobject", GAMEOBJECT_COLUMNS)
        if warning:
            print("WARN: " + warning, file=sys.stderr)
        for row in iter_sql_rows(sql_text, "gameobject", columns):
            entry = to_int(row.get("id"), 0)
            if entry <= 0:
                continue
            spawns.setdefault(entry, []).append((
                to_int(row.get("map")),
                to_float(row.get("position_x")),
                to_float(row.get("position_y")),
                to_float(row.get("position_z")),
            ))
        return spawns

    path = os.path.join(csv_dir, "gameobject.csv")
    with open(path, newline="", encoding="utf-8", errors="ignore") as handle:
        for row in csv.DictReader(handle):
            lowered = {k.lower(): v for k, v in row.items() if k}
            entry = to_int(lowered.get("id"), 0)
            if entry <= 0:
                continue
            spawns.setdefault(entry, []).append((
                to_int(lowered.get("map")),
                to_float(lowered.get("position_x")),
                to_float(lowered.get("position_y")),
                to_float(lowered.get("position_z")),
            ))
    return spawns


# ----------------------------------------------------------------------------
# Filtering and rendering
# ----------------------------------------------------------------------------

def build_index(templates, spawns, types, names, dedup):
    """entry -> (name, [points]) after the type/name filter and the dedup grid.

    Returns the index plus the counts the trade cost, because a filter that quietly drops 95% of
    the table is a decision the next reader has to be able to see.
    """
    keep = set(types) if types is not None else None
    extra_names = set(n.strip().lower() for n in names if n.strip())
    index = {}
    dropped_type = 0
    rows_in = 0
    rows_kept = 0
    deduped = 0
    unnamed = 0

    for entry in sorted(spawns):
        points = spawns[entry]
        rows_in += len(points)
        template = templates.get(entry)
        name = (template or {}).get("name", "")
        if not name:
            unnamed += 1
        kind = (template or {}).get("type", -1)
        if keep is not None and kind not in keep and name.strip().lower() not in extra_names:
            dropped_type += 1
            continue

        cells = set()
        kept = []
        for point in sorted(set(points)):
            if dedup and dedup > 0:
                cell = (point[0], int(point[1] // dedup), int(point[2] // dedup))
                if cell in cells:
                    deduped += 1
                    continue
                cells.add(cell)
            kept.append(point)
            rows_kept += 1
        if kept:
            index[entry] = (name or ("object %d" % entry), kept)

    return index, {
        "entries": len(index),
        "rows_in": rows_in,
        "rows_kept": rows_kept,
        "rows_deduped": deduped,
        "entries_dropped_by_type": dropped_type,
        "entries_without_name": unnamed,
    }


def render_chunk(index, chunk_idx, entries, source):
    """One chunk file, in the shape EaxAutoQuester/npc_spawns/chunk_NNN.lua already uses."""
    first = entries[0] if entries else 0
    last = entries[-1] if entries else 0
    lines = [
        "-- Object Spawn Chunk %d: entries %d - %d" % (chunk_idx, first, last),
        "-- %d entries from %s" % (len(entries), source),
        "-- Generated by tools/generate_object_spawns.py - do not edit by hand.",
        "local M = {}",
        "M.by_entry = {",
    ]
    for entry in entries:
        name, points = index[entry]
        lines.append('  ["%d"] = {' % entry)
        lines.append('    name = "%s",' % name.replace('"', '\\"'))
        lines.append("    maps = {")
        for map_id, x, y, z in points:
            lines.append("      { map_id = %d, x = %.4f, y = %.4f, z = %.4f }," % (map_id, x, y, z))
        lines.append("    },")
        lines.append("  },")
    lines.append("}")
    lines.append("return M")
    return "\n".join(lines) + "\n"


def render_manifest(chunk_count, entry_count, source, stats):
    return (
        "-- Generated by tools/generate_object_spawns.py - do not edit by hand.\n"
        "-- %d entries across %d chunk(s) from %s\n"
        "-- rows: %d in, %d kept, %d collapsed onto the dedup grid\n"
        "return {\n"
        "    chunk_count = %d,\n"
        "    entry_count = %d,\n"
        '    generated_from = "%s",\n'
        "}\n" % (entry_count, chunk_count, source, stats["rows_in"], stats["rows_kept"],
                 stats["rows_deduped"], chunk_count, entry_count, source.replace('"', '\\"'))
    )


def render_all(index, source):
    """Every output file as {relative_path: text}, in a deterministic order."""
    entries = sorted(index)
    files = {}
    chunks = [entries[i:i + CHUNK_SIZE] for i in range(0, len(entries), CHUNK_SIZE)] or [[]]
    for chunk_idx, chunk_entries in enumerate(chunks):
        name = "object_spawns/chunk_%03d.lua" % chunk_idx
        files[name] = render_chunk(index, chunk_idx, chunk_entries, source)
    files["object_spawns/manifest.lua"] = render_manifest(
        len(chunks), len(entries), source,
        {"rows_in": 0, "rows_kept": 0, "rows_deduped": 0})
    return files, len(chunks)


# ----------------------------------------------------------------------------
# Self-test: the parser and the renderer, on an embedded mini-dump. No files, no network.
# ----------------------------------------------------------------------------

SELF_TEST_DUMP = """
CREATE TABLE `gameobject_template` (
  `entry` int(10) unsigned NOT NULL DEFAULT '0',
  `type` int(10) unsigned NOT NULL DEFAULT '0',
  `displayId` int(10) unsigned NOT NULL DEFAULT '0',
  `name` char(100) NOT NULL DEFAULT '',
  PRIMARY KEY (`entry`)
) ENGINE=MyISAM;

CREATE TABLE `gameobject` (
  `guid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `id` int(10) unsigned NOT NULL DEFAULT '0',
  `map` smallint(5) unsigned NOT NULL DEFAULT '0',
  `position_x` float NOT NULL DEFAULT '0',
  `position_y` float NOT NULL DEFAULT '0',
  `position_z` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`)
) ENGINE=MyISAM;

INSERT INTO `gameobject_template` VALUES
(233818,2,679,'Ogre Remains',0),
(190000,3,680,'Ogre Remains Cache',0),
(4,4,1,'Copper Vein',0);

INSERT INTO `gameobject` VALUES
(1,233818,0,-4000.5000,1200.2500,145.0000),
(2,233818,0,-4000.6000,1200.3000,145.1000),
(3,190000,0,-4100.0000,1300.0000,147.0000),
(4,4,0,-4200.0000,1400.0000,149.0000);
"""

SELF_TEST_TRICKY_DUMP = """
CREATE TABLE `gameobject_template` (
  `entry` int(10) unsigned NOT NULL DEFAULT '0',
  `type` int(10) unsigned NOT NULL DEFAULT '0',
  `name` char(100) NOT NULL DEFAULT ''
) ENGINE=MyISAM;

CREATE TABLE `gameobject` (
  `guid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `id` int(10) unsigned NOT NULL DEFAULT '0',
  `map` smallint(5) unsigned NOT NULL DEFAULT '0',
  `position_x` float NOT NULL DEFAULT '0',
  `position_y` float NOT NULL DEFAULT '0',
  `position_z` float NOT NULL DEFAULT '0'
) ENGINE=MyISAM;

INSERT INTO `gameobject_template` VALUES (7,2,'Baron\\'s Camp; Camp, East');
INSERT INTO `gameobject` VALUES (1,7,0,1.0,2.0,3.0);
"""


def self_test():
    failures = []

    def check(condition, message):
        if not condition:
            failures.append(message)

    templates = read_templates(sql_text=SELF_TEST_DUMP)
    spawns = read_spawns(sql_text=SELF_TEST_DUMP)
    check(len(templates) == 3, "template rows: expected 3, got %d" % len(templates))
    check(templates[233818]["name"] == "Ogre Remains", "template name lost its row")
    check(templates[233818]["type"] == 2, "template type misread")
    check(len(spawns[233818]) == 2, "spawn rows: expected 2 for 233818, got %d" % len(spawns[233818]))

    index, stats = build_index(templates, spawns, DEFAULT_TYPES, [], 2.0)
    check(stats["entries"] == 2, "the type filter must keep quest=2 and chest=3, drop node=4")
    check(233818 in index, "the quest object must be in the index")
    check(4 not in index, "a node (ore) must be out by default")
    # Two spawn rows 0.1yd apart collapse onto one 2yd cell. Which row survives is the sorted
    # first, so the property pinned is "a real row, once" — not which of the two it was.
    check(len(index[233818][1]) == 1, "the dedup grid must collapse the near-identical rows")
    check(index[233818][1][0] in set(spawns[233818]),
          "the surviving row must be one of the source rows, not a computed average")
    check(stats["rows_deduped"] == 1, "the collapsed row must be counted, not silently dropped")

    files, chunks = render_all(index, "self-test")
    check(chunks == 1, "expected one chunk, got %d" % chunks)
    body = files["object_spawns/chunk_000.lua"]
    check('["233818"]' in body, "the entry key must be rendered")
    check('name = "Ogre Remains"' in body, "the name must be rendered")
    kept = index[233818][1][0]
    check("x = %.4f, y = %.4f, z = %.4f" % (kept[1], kept[2], kept[3]) in body,
          "the coordinate must be rendered as written, to four decimals")
    check("entry_count = 2" in files["object_spawns/manifest.lua"], "the manifest must count entries")

    # A name carrying an apostrophe, a comma and a semicolon must survive tokenising.
    tricky_templates = read_templates(sql_text=SELF_TEST_TRICKY_DUMP)
    tricky_spawns = read_spawns(sql_text=SELF_TEST_TRICKY_DUMP)
    check(tricky_templates[7]["name"] == "Baron's Camp; Camp, East",
          "a quoted name with an apostrophe, a semicolon and a comma misparsed: %r"
          % tricky_templates.get(7, {}).get("name"))
    check(len(tricky_spawns[7]) == 1, "the statement must not have been cut at the semicolon")

    # Column order is read from the dump, not assumed: a fork that adds a column must still yield
    # the right coordinates, and a row too short to fill the declared columns is not guessed at.
    reordered = """
CREATE TABLE `gameobject` (
  `owner` int(10) unsigned NOT NULL DEFAULT '0',
  `guid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `id` int(10) unsigned NOT NULL DEFAULT '0',
  `map` smallint(5) unsigned NOT NULL DEFAULT '0',
  `position_x` float NOT NULL DEFAULT '0',
  `position_y` float NOT NULL DEFAULT '0',
  `position_z` float NOT NULL DEFAULT '0'
) ENGINE=MyISAM;
INSERT INTO `gameobject` VALUES (0,1,233818,0,-4000.5000,1200.2500,145.0000);
INSERT INTO `gameobject` VALUES (0,2,233818);
"""
    reordered_spawns = read_spawns(sql_text=reordered)
    check(reordered_spawns[233818][0] == (0, -4000.5, 1200.25, 145.0),
          "a leading extra column must not shift the coordinates: %r"
          % (reordered_spawns[233818][0],))
    check(len(reordered_spawns[233818]) == 1,
          "a row shorter than the declared columns must be skipped, not padded with zeros")

    if failures:
        for failure in failures:
            print("  FAIL: " + failure, file=sys.stderr)
        return 1
    print("  generate_object_spawns self-test PASS")
    return 0


# ----------------------------------------------------------------------------
# Entry point
# ----------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--sql", help="cMaNGOS SQL dump carrying the two game-object tables")
    parser.add_argument("--csv-dir", help="directory with gameobject.csv and gameobject_template.csv")
    parser.add_argument("--out", default=None,
                        help="output root (default: EaxAutoQuester/)")
    parser.add_argument("--types", default=None,
                        help="comma-separated gameobject_template.type values to keep "
                             "(default: %s)" % ",".join(str(t) for t in DEFAULT_TYPES))
    parser.add_argument("--all", action="store_true", help="keep every entry, whatever its type")
    parser.add_argument("--names", action="append", default=[],
                        help="extra world names to keep whatever their type; repeatable")
    parser.add_argument("--dedup", type=float, default=2.0,
                        help="collapse spawn rows within this many yards (default: 2; 0 disables)")
    parser.add_argument("--check", action="store_true",
                        help="compare the files on disk with a fresh generation; non-zero on drift")
    parser.add_argument("--self-test", action="store_true",
                        help="run the parser and renderer on an embedded dump, touching no files")
    args = parser.parse_args()

    if args.self_test:
        return self_test()
    if not args.sql and not args.csv_dir:
        parser.error("one of --sql or --csv-dir is required (or use --self-test)")

    out_root = args.out or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    source = os.path.basename(args.sql) if args.sql else os.path.basename(args.csv_dir)

    sql_text = None
    if args.sql:
        with open(args.sql, encoding="utf-8", errors="ignore") as handle:
            sql_text = handle.read()

    types = None if args.all else (
        [int(t) for t in args.types.split(",") if t.strip()] if args.types
        else list(DEFAULT_TYPES))

    templates = read_templates(sql_text=sql_text, csv_dir=args.csv_dir)
    spawns = read_spawns(sql_text=sql_text, csv_dir=args.csv_dir)
    index, stats = build_index(templates, spawns, types, args.names, args.dedup)
    files, chunks = render_all(index, source)
    files["object_spawns/manifest.lua"] = render_manifest(
        chunks, stats["entries"], source, stats)

    print("entries kept:   %d of %d template rows" % (stats["entries"], len(templates)))
    print("spawn rows:     %d in, %d kept, %d collapsed at %gyd"
          % (stats["rows_in"], stats["rows_kept"], stats["rows_deduped"], args.dedup))
    print("dropped by type:%d   entries with no name: %d"
          % (stats["entries_dropped_by_type"], stats["entries_without_name"]))
    print("chunks:         %d" % chunks)

    drift = []
    for relative, text in sorted(files.items()):
        path = os.path.join(out_root, relative)
        on_disk = None
        if os.path.exists(path):
            with open(path, encoding="utf-8") as handle:
                on_disk = handle.read()
        if args.check:
            if on_disk != text:
                drift.append(relative)
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
        print("wrote %s (%d bytes)" % (relative, len(text)))

    if args.check:
        if drift:
            print("DRIFT: the index on disk differs from a fresh generation: %s"
                  % ", ".join(drift), file=sys.stderr)
            return 1
        print("index on disk matches a fresh generation")
    return 0


if __name__ == "__main__":
    sys.exit(main())
