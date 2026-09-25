# Quest-object coordinates — naming an objective and going to it

What: `EaxAutoQuester/object_spawns.lua` plus the generated `EaxAutoQuester/object_spawns/` index, so a
goal whose id is a **game object** resolves to the coordinates that object spawns at.

Why: a Zygor goal carries one id field and two namespaces can live in it. A kill goal's id is a
`creature_template` entry, and `EaxAutoQuester/npc_spawns/` (cut from the same cMaNGOS database) knows
those. An interactable objective's id is a `gameobject_template` entry, and nothing in the plugin
knew one. So the sweep for "Ogre Remains" had no candidates at all and fell back to the step's
waypoints — 108yd and 113yd legs, `spawn point 2 unreachable`, and not one click (live, step 7; see
`quest_object_objectives.md` for that runbook).

This is the capability neither open pixel bot has. They find things by reading nameplate and corpse
pixels off the screen; we are told the objective's name and entry and can ask where that entry
spawns.

## What ships, and what is build data

| Path | Tracked | What it is |
|---|---|---|
| `EaxAutoQuester/object_spawns.lua` | yes | the accessor: the two questions the sweep asks of an index |
| `EaxAutoQuester/tools/generate_object_spawns.py` | yes | the generator, with `--self-test` and `--check` |
| `EaxAutoQuester/object_spawns/chunk_NNN.lua` | **no** | generated spawn rows, 2000 entries per chunk |
| `EaxAutoQuester/object_spawns/manifest.lua` | **no** | generated: chunk count, entry count, source name |

**No data is a normal state, not an error.** With no manifest the accessor reports
`available == false` and every answer is `nil` or `{}`; the sweep then builds the candidate list it
always did — the step's waypoints — and the bot behaves exactly as it did before this index existed.
Nothing invents a destination, and nothing fails loudly for a table it was never given. That
contract is pinned by `tests/test_object_spawns.lua` **O1**, which runs before any fixture exists on
purpose, and by `tests/test_spawn_patrol.lua` **P19**.

## Generating the index

Either source works, both cMaNGOS tbc-db:

```bash
# a SQL dump carrying CREATE TABLE / INSERT for `gameobject` and `gameobject_template`
python EaxAutoQuester/tools/generate_object_spawns.py --sql TBCDB_1.10.0_ReturnOfTheVengeance.sql

# the same two tables as CSV (headers: gameobject.csv, gameobject_template.csv)
python EaxAutoQuester/tools/generate_object_spawns.py --csv-dir out/csv
```

Column order is read from the dump's `CREATE TABLE`, so a fork that adds a column cannot silently
shift every coordinate; a row too short to fill its declared columns is skipped rather than padded.
Values are tokenised quote-aware, because a world name can carry an apostrophe, a comma or a
semicolon (`Baron's Camp; Camp, East`).

Useful flags:

| Flag | What it does |
|---|---|
| `--types 2,3` | keep only these `gameobject_template.type` values (default `0,1,2,3,5`) |
| `--types 0,1,2,3,4,5` | brings nodes (ore, herb, vein) back in |
| `--names "Ogre Remains"` | keep a named entry whatever its type; repeatable |
| `--all` | keep every entry, whatever its type |
| `--dedup 2.0` | collapse spawn rows within N yards (default 2; `0` disables) |
| `--check` | compare the files on disk with a fresh generation; non-zero on drift |
| `--self-test` | run the parser and renderer on an embedded dump; touches no files |

The default type set is the interactables a quest asks for — doors, buttons, quest objects, chests,
spellcasters — and deliberately leaves out `node`, which is the bulk of the table. Every count the
filter and the dedup changed is printed, because "this file holds 2% of the table" is a decision the
next reader has to be able to see:

```
entries kept:   2 of 3 template rows
spawn rows:     4 in, 2 kept, 1 collapsed at 2yd
dropped by type:1   entries with no name: 0
chunks:         1
```

## How the sweep uses it

`shared/spawn_patrol.lua` asks **both** indexes and merges what comes back, for ids and for names.
The precedence that decides where the bot actually walks:

1. **The objective is visible** → `do_action_state`'s name path approaches and uses it (AQ-P3-1).
2. **Otherwise** → the sweep walks the objective's own spawn points, nearest unsearched first
   (AQ-P4-1), with the step's waypoints joining them as they always have.
3. **Otherwise** → the step's waypoints alone, which is the no-data state and the original behaviour.

One id can legitimately exist in both namespaces, so both answers are kept: `P21` pins that a
creature camp and an object sharing an entry number produce one merged candidate list.

## Tests

`tests/test_object_spawns.lua` — **O1** the no-data contract; **O2/O3** entries resolve to their
rows and unknown/empty/nil answer `nil`; **O4/O5** an exact name beats a lookalike and a partial
name is the fallback; **O6** the name answer is cached and rebuildable; **O7** a manifest naming an
absent chunk answers `nil` without raising; **O8** a broad name is capped at 32 entries.

`tests/test_spawn_patrol.lua` — **P19** no data, unchanged behaviour; **P20** an objective game's
entry resolves to the coordinates it spawns at; **P21** one id in two namespaces merges both sets;
**P22** a name-only objective resolves through the object name index.

`tools/generate_object_spawns.py --self-test` — the SQL tokeniser (quoted names carrying an
apostrophe, a comma and a semicolon), the column-order read (an extra leading column does not shift
the coordinates), the type filter, the dedup grid, and the rendered output.

## Not verified without the client

The index says where an entry spawns; the client says whether that object is loaded and what it is
called right now. A stale spawn row, an object that only appears under a condition, or a guide whose
entry is from a different client build all show up the same way in game — the sweep walks to the
coordinates and finds nothing there. What to look for is in `quest_object_objectives.md`: the object
line means it is in sight, the sweep line means it went looking, and neither line repeating at the
same coordinates means the coordinates are wrong, not the search.
