# WoW Forever Community Datamine (beta 1.60.1.69893)

> Datamined 2026-09-17 from the Forever beta client (`wow_classic_beta`
> 1.60.1.69893) with `tools/build_forever_database.py`. The client DBC is
> the authoritative source of truth (repo law); Wowhead/tooltips are
> supplementary. Everything below regenerates from a beta install — no
> bytes here are hand-written.

## What lives here

| Artifact (under `wowheadScrape/dbc_extract/forever_community/`) | Shape | Contents |
|---|---|---|
| `index.html` | viewer (offline) | Self-contained Wowhead-style browser: search + class/heal/aoe filters, tooltip cards, rank ladders, talent trees, race table. Double-click to open, no server |
| `forever-datamine-1.60.1.69893.zip` | shareable bundle | The viewer + every file below + the rotation bridge + a generated friend-facing README (the maintainer README you are reading never ships — it references repo paths) under one top folder |
| `forever_datamine.db` | SQLite | Curated `spells`, `spell_effects`, `spell_ranks`, `talents`, `talent_tabs`, `trainer_spells`, `races`, `procs`, `meta` tables + `player_spells` / `heals` views, **plus a verbatim mirror of all 96 world/NPC/item DBC tables** (`AreaTable`, `Map`, `UiMap*`, `Taxi*`, `Creature*`, `Item*`, `SpellPower`, ...) and 4 helper views: `creature_displays`, `zones`, `taxi_nodes`, `item_index` |
| `spells.jsonl` | JSON lines | One object per named spell (31,308 lines): full descriptions included |
| `by_name.json` | JSON map | Exact client name → every spell id carrying it (sorted) |
| `talents.json` | JSON | 27 talent tabs → talents (tier/column/prereq) with rank-spell names + descriptions joined |
| `trainers.json` | JSON | Per class: trainer spell lists (spell, level, skill line, method) |
| `races.json` | JSON | All 58 client races (playable flag, starting level) |
| `procs.json` | JSON | `SpellAuraOptions` proc rows (chance/charges/type) with spell names joined |
| `items.jsonl` | JSON lines | One object per named item (~19k): quality, ilvl, required level, class/subclass, slot, **computed stat values + budget shares**, flavor text, on-use/equip effects (via `ItemXItemEffect`), prices, stack, set id, icon FDID |
| `zones.json` | JSON | `AreaTable` joined to `Map`: every named area with id, map name/type, parent area |
| `points.json` | JSON | Place index: `AreaPOI` + `AreaTrigger` + `TaxiNodes` in one list with world coordinates (x/y/z) and ids |
| `taxi.json` | JSON | Flight network: 100 nodes (name, map, x/y/z) + 328 paths (from/to, ticket cost, waypoint count) |
| `creatures.json` | JSON | Companion-creature catalogue (178 rows) with type/family names, the 27 families, 13 types, and difficulty rows (min/max level) |
| `spell_meta.json` | JSON | Per-spell metadata keyed by id (31k): cast ms, duration ms, effect radius yd, min/max range, target cap, cone degrees, dispel/mechanic/category names, mana cost + power type, interrupt flags |
| `icons.png` + `icons.json` | PNG sprite sheet + JSON index | 4,047 icons decoded straight from the client's BLP textures (items, spells, talents) into a 2048x2048 sheet (32px cells); `icons.json` maps icon file id -> cell |
| `mounts.json` | JSON | All 141 client mounts: name, summon spell (+ name), type/kind, source enum, display ids |
| `viewer3d.html` + `models.js` + `models_index.json` | WebGL viewer + payload | Offline 3D model previews (orbit/zoom, textured, no skeleton): geometry decoded from the client M2+SKIN via wowser, textures via this repo's BLP decoder. Built by `tools/build_forever_models.py`; the payload is a `window.MODELS`/`window.MODELS_INDEX` script so it loads on `file://` |

Bulk files above are **local-only build output** (gitignored, like the rest
of `wowheadScrape/`); the tracked artifacts are the generators
(`tools/build_forever_database.py`, `tools/build_forever_bundle.py`,
`tools/probe_forever_tables.py`), this README, and the rotation bridge
(`EaxRotations/shared/wowhead_data_bridge_spell_index_forever_sylvanas.lua`).

## Quick recipes

SQLite (any `sqlite3` shell):
```sql
.open wowheadScrape/dbc_extract/forever_community/forever_datamine.db
-- All Paladin Holy Strikes, weakest to strongest:
SELECT spell_id, rank_no, level FROM spell_ranks
 WHERE name = 'Holy Strike' AND class = 'Paladin' ORDER BY rank_no;
-- Every direct heal a Resto Shaman can cast:
SELECT id, name, level, cooldown_s FROM heals WHERE class = 'Shaman';
-- Full mechanic text + effects for one spell:
SELECT description FROM spells WHERE id = 11078;
SELECT effect, aura, base_points, targets FROM spell_effects WHERE spell_id = 11078;
-- Paladin Holy talents with their rank spells:
SELECT tier, column_no, spell_rank_ids FROM talents WHERE tab = 'Holy' AND class = 'Paladin';
-- What does a Paladin trainer teach, in level order:
SELECT spell_id, name, level, skill FROM trainer_spells
 WHERE class = 'Paladin' ORDER BY level, spell_id;

-- World / NPC / item mirror (raw DBC tables, original names):
-- Every flight master with coordinates, by map:
SELECT t.Name_lang, t.Pos, m.MapName_lang FROM TaxiNodes t
 LEFT JOIN Map m ON m.ID = t.ContinentID ORDER BY t.ContinentID, t.ID;
-- All zones of a map with their parent area:
SELECT z.id, z.name, z.map, z.parent_id FROM zones z WHERE z.map_id = 0 ORDER BY z.name;
-- Item lookup with class/subclass names and slot string (helper view):
SELECT id, name, quality, ilvl, req_level, class_id, subclass_id, inv_type
 FROM item_index WHERE name LIKE 'Thunderfury%';
-- Set bonuses for one item set:
SELECT s.Name_lang, sp.SpellID, sp.Threshold FROM ItemSet s
 JOIN ItemSetSpell sp ON sp.ItemSetID = s.ID WHERE s.ID = 1;
-- NPC base-health curve by level (client expected values):
SELECT Lvl, CreatureHealth, CreatureAutoAttackDps, CreatureArmor FROM ExpectedStat
 WHERE ExpansionID = -2 ORDER BY Lvl;
-- Creature display → model + run speed:
SELECT * FROM creature_displays WHERE display_id = 7937;
-- Map coordinate rect for a zone (world→map conversion):
SELECT UiMapID, MapID, AreaID, Region FROM UiMapAssignment WHERE AreaID = 14;
```

Python:
```python
import json, sqlite3
db = sqlite3.connect("wowheadScrape/dbc_extract/forever_community/forever_datamine.db")
db.row_factory = sqlite3.Row
row = db.execute("SELECT * FROM spells WHERE id = 20163").fetchone()
print(row["name"], row["description"][:120])
by_name = json.load(open("wowheadScrape/dbc_extract/forever_community/by_name.json"))
print(by_name["Seal of Fury"])  # every id sharing the name
meta = json.load(open("wowheadScrape/dbc_extract/forever_community/spell_meta.json"))
print(meta["133"])  # Fireball: cast/range/mana/...
```

Agent grep recipes (JSONL is one object per line — `rg` friendly):
```
rg '"name": "Holy Strike"' spells.jsonl          # every Holy Strike row
rg '"class": "Shaman".*"aoe": true' spells.jsonl # shaman AoE kit
rg 'Touch of the Grave' spells.jsonl             # racial proc rows
rg '"name": "Thunderfury' items.jsonl            # item lookup by name
rg '"quality": 4.*"req": 60' items.jsonl         # epic level-60 items (rough)
```

Regeneration (needs the beta installed; see `docs/forever/dbc_runbook.md`):
```
dotnet DB2ToSqliteTool.dll -s appsettings.forever_world.json -o wowheadScrape/dbc_extract/wowsims_forever.db
python tools/build_forever_database.py            # rebuild this package
python tools/build_forever_database.py --check    # verify it
python tools/build_forever_icons.py --blp-dir <exported icons> --out-dir wowheadScrape/dbc_extract/forever_community
python tools/build_forever_icons.py --out-dir wowheadScrape/dbc_extract/forever_community --check
python tools/build_forever_bundle.py              # viewer + shareable zip
python tools/build_forever_bundle.py --check      # verify them
python tools/build_forever_models.py              # 3D preview pack (models.js)
python tools/build_forever_models.py --mounts all --items 19019,17182
python tools/build_forever_models.py --check      # verify the 3D pack
```

## Schema reference

`spells`: `id, name, subtext, class, class_set, level, rank, school,
school_mask, cast_idx, gcd_s, cooldown_s, description, aura_description,
is_heal, aoe`, plus `description_rendered` / `aura_description_rendered`:
the client tooltip tokens ($s1/$m1/$d/$t1/$a1/$o1/$x1, $/N;sM,
$@spelldesc\<id\>) substituted with real numbers from the effect tables
(67% of all tokenized descriptions fully resolved; the rest use runtime
expressions `${...}`, `$<var>`, `$?a...` that the client evaluates from
SpellDescriptionVariables/local state and are left verbatim). `cooldown_s`/`gcd_s` are seconds (NULL when the DBC carries
no cooldown row — distinct from 0.0). `description` holds the FULL client
tooltip text including `$s1`/`$m1`-style tokens (client-resolved numbers,
kept verbatim). `rank` is positional per (class, name) ordered by
(level, id) — see quirks.

`spell_effects`: `spell_id, idx, effect, aura, base_points, misc, targets,
trigger_spell, radius, coefficient` (all values verbatim from the DBC).

`spell_ranks`: `spell_id, name, class, rank_no, level` (same ordering as
the `rank` field above, queryable).

`talents` / `talent_tabs`: 432 talents across 27 tabs (9 classes × 3);
`spell_rank_ids` is the raw rank-id array, `prereq` the raw prereq-talent
array. `trainers`: per-class trainer lists joined to skill-line names
(`skill`), required level (`level`), raw acquire `method` + `races` masks.
`races`: all 58 client races with `playable` flag and starting level.
`procs`: `SpellAuraOptions` rows (chance/charges/type/ppm) with spell names
joined. `meta`: client version/build/product, extraction timestamp,
generator, source DB, `dbc_tables` (109).

**World mirror**: every table named in `WORLD_TABLES`
(`tools/build_forever_database.py`) is copied verbatim from
`wowsims_forever.db` under its DBC name — query them exactly as wowdev
documents them. The four helper views: `creature_displays` (display →
model fdid, run/walk speed, collision, scale), `zones` (area → map name),
`taxi_nodes`, `item_index` (item → class/subclass/slot + prices). Array
fields (`Pos`, `StatModifier_bonusStat`, `Flags`, ...) arrive as DBC text
(`[-8888.98,-0.54,94.39]`) alongside the tool's expanded `_0.._N` columns.

**Curated world artifacts**: `items.jsonl` keeps `stats` as
`[stat_id, stat_name, basis_points]` triples (see quirks); `points.json`
types are `poi` / `trigger` / `taxi`; `spell_meta.json` is keyed by spell id
and only carries non-zero fields.

## Known data quirks (read before drawing conclusions)

- **Rank-1 baseline vs rank order.** Rotation code resolves rank ladders by
  lowest spell id, but a few classic ladders number out of order: Holy
  Strike rank 1 is 679@6 (not the 678@12 baseline), Consecration rank 1 is
  26573@20 (not 20116@30). The `rank`/`rank_no` fields here use level
  order and are correct for both.
- **One name, several roles.** Some names cover a talent row, a proc/buff
  row AND a cast row (Arcane Blast 400573 aura vs 400574 nuke;
  Missile Barrage talent 400588 vs proc 400589; Maelstrom talent 408498 vs
  buff 408505; Hot Streak legacy 48108 vs Forever proc 400625). Lanes must
  pick the role-correct id — see the `spell_maxrank_by_name_forever` and
  `spell_buff_by_name_forever` mirrors in the rotation bridge, which encode
  the verified resolutions.
- **Aura names are not in the DBC.** Aura ids (107/108 procs etc.) have no
  name table on the client; proc/buff identification above comes from
  effect shapes + description text, flagged per case in the kit docs.
- **Cooldowns live in two columns.** `RecoveryTime` (most nukes) vs
  `CategoryRecoveryTime` (Holy Shock 10s, Holy Strike 12s, Lava Burst 10s
  all live here); `cooldown_s` in this package uses `RecoveryTime`, so a
  NULL/0.0 there does NOT mean "no cooldown" — check category-gated
  spells in-game.
- **BaseLevel 0/NULL rows** are helper/trigger/aura rows, not castable
  ranks (they sort last in `rank_no` by construction).
- **Hotfixes**: the extractor found hotfix caches for builds 68940/69795
  only; the beta build is 69893, so NO hotfixes applied (matches a fresh
  beta datamine; re-extract after beta patches land).
- **`ItemRandomProperties` extraction crashes** this DB2ToSqlite build on
  the 1.60 client; `ItemRandomSuffix`, `WorldSafeLocs`, `WorldMapArea`,
  `CharStartOutfit`, `SoundEntries` and the `Gt*` game tables are likewise
  absent from this client build (probe-confirmed). Use
  `tools/probe_forever_tables.py` to re-check after a client patch.
- **Item stat values are computed, and validated.** The 1.60 client stores
  stat TYPES + budget SHARES (basis points in `StatPercentEditor`) and
  derives values from `RandPropPoints(ItemLevel)[quality column][slot tier]`.
  `items.jsonl` carries both the computed value and the raw share, using the
  slot-tier mapping calibrated against the 2.5.5 reference client (which
  stores final values): head/chest/legs/2H/robe -> tier 0;
  shoulders/waist/feet/hands -> 1; neck/wrist/finger/back/shield/holdable ->
  2; 1H/main-hand/off-hand -> 3; ranged/thrown -> 4. Spot checks:
  Lionheart Helm -> +18 Str / +28 crit rating / +20 hit rating;
  Thunderfury -> +5 agi / +8 sta / +8 fire res / +9 nature res. Still NOT
  computed: **armor and weapon damage** (their tables do not reproduce
  classic values) and items without `ItemLevel` (shares only). Verify
  anything surprising in-game.
- **3D models are geometry-only.** The pipeline resolves the client model
  chain (item -> `ItemModifiedAppearance` -> `ItemAppearance` ->
  `ItemDisplayInfo`; mount -> `MountXDisplay` -> `CreatureDisplayInfo` ->
  `CreatureModelData`), exports the M2 + `SFID` skin + `TXID` textures,
  parses geometry with wowser (`MD21` container unwrapped first; M2 v272
  vertices are 48-byte structs in the M2, indices in the skin) and decodes
  textures with the BLP decoder here. No skeleton, animations, or geosets:
  weapons and mounts look right, characters would need far more work.
- **Icons come from CASC, not the DBCs.** `Item.IconFileDataID` /
  `SpellMisc.SpellIconFileDataID` are ids; the pixels are BLP textures
  exported with an FDID dumper and decoded by `tools/build_forever_icons.py`
  (DXT1/DXT3/DXT5 + paletted + BGRA; the 1.60 icons are BLP2 whose `type`
  field reads 1 while the payload is DXT -- format is picked by payload
  size + alpha depth). 24 of the 4,071 exported icons decode as all-zero
  bytes: those are the client's encrypted/unreleased placeholders (same
  phenomenon as encrypted TACT content) -- not a decoder failure.
- **Mounts**: `Mount` + `MountXDisplay` (uuid-free join) with the summon
  spell resolved through `SpellName`; `MountType` has no names (the client
  localizes from `Type`), so the artifact carries ids + kind.
- **Item effects come from `ItemXItemEffect`.** `ItemEffect` rows are keyed
  by row id, not item id; the item link lives in `ItemXItemEffect`
  (`ItemID` -> `ItemEffectID`). That is what resolves potions, trinkets and
  procs (Thunderfury -> spell 21992). The old direct `ItemEffect.ID = item`
  join finds nothing on this client.
- **NPC spawns, drop tables and live health do NOT exist in the client.**
  No client DB2 carries spawn points, loot, vendors or per-NPC HP — that
  data lives server-side. What the client DOES ship: the companion-creature
  catalogue (178 rows with names/type/family/displays), 14k displays with
  models, families/types, movement speeds, factions/faction templates
  (hostility masks) and `ExpectedStat` creature-health curves by level
  (`ExpansionID = -2` row: 42 HP @1, 272 @12, 3968 @60 — expected values,
  not server truth). For real spawns/loot the repo's TBC precedent is the
  cMaNGOS world dump (`wowhead_data/lua/npc_db.lua`); no Forever equivalent
  exists yet — a Forever emulator DB would be the source when one appears.
- **Map structure is modern (`UiMap`), not `WorldMap*`.** The 1.60 client
  has no `WorldMapArea`/`WorldMapContinent`/`WorldMapTransforms`; use
  `UiMap` (60 rows) + `UiMapAssignment`, whose `Region` field
  (`[minX,minY,minZ,maxX,maxY,maxZ]`) is the world→map coordinate rect for
  a zone, plus `WorldMapOverlay` (1,081 art overlays) and `AreaPOI` (372
  place markers with world positions).
- **Taxi waypoints are the closest thing to "paths" in the client.**
  `TaxiPathNode` (10,778 rows) gives flight-path waypoints with map + x/y/z;
  boat/zeppelin moved paths live in `TransportAnimation` (1,016 rows) —
  server-side transport schedules are not client data.
- **Multi-school spells** decode all mask bits (`Frostfire Bolt` mask 20 =
  `fire+frost`); single-school rows match the rotation bridge exactly.
