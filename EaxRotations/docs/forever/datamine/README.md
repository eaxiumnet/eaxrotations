# WoW Forever Community Datamine (beta 1.60.1.69893)

> Datamined 2026-09-17 from the Forever beta client (`wow_classic_beta`
> 1.60.1.69893) with `tools/build_forever_database.py`. The client DBC is
> the authoritative source of truth (repo law); Wowhead/tooltips are
> supplementary. Everything below regenerates from a beta install — no
> bytes here are hand-written.

## What lives here

| Artifact (under `wowheadScrape/dbc_extract/forever_community/`) | Shape | Contents |
|---|---|---|
| `forever_datamine.db` | SQLite | `spells`, `spell_effects`, `spell_ranks`, `talents`, `talent_tabs`, `trainer_spells`, `races`, `procs`, `meta` tables + `player_spells` / `heals` views |
| `spells.jsonl` | JSON lines | One object per named spell (31,308 lines): full descriptions included |
| `by_name.json` | JSON map | Exact client name → every spell id carrying it (sorted) |
| `talents.json` | JSON | 27 talent tabs → talents (tier/column/prereq) with rank-spell names + descriptions joined |
| `trainers.json` | JSON | Per class: trainer spell lists (spell, level, skill line, method) |

Bulk files above are **local-only build output** (gitignored, like the rest
of `wowheadScrape/`); the tracked artifacts are the generator
(`tools/build_forever_database.py`), this README, and the rotation
bridge (`EaxRotations/shared/wowhead_data_bridge_spell_index_forever_sylvanas.lua`).

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
```

Agent grep recipes (JSONL is one object per line — `rg` friendly):
```
rg '"name": "Holy Strike"' spells.jsonl          # every Holy Strike row
rg '"class": "Shaman".*"aoe": true' spells.jsonl # shaman AoE kit
rg 'Touch of the Grave' spells.jsonl             # racial proc rows
```

Regeneration (needs the beta installed; see `docs/forever/dbc_runbook.md`):
```
dotnet DB2ToSqliteTool.dll -s appsettings.forever_full.json -o wowheadScrape/dbc_extract/wowsims_forever.db
python tools/build_forever_database.py            # rebuild this package
python tools/build_forever_database.py --check    # verify it
```

## Schema reference

`spells`: `id, name, subtext, class, class_set, level, rank, school,
school_mask, cast_idx, gcd_s, cooldown_s, description, aura_description,
is_heal, aoe`. `cooldown_s`/`gcd_s` are seconds (NULL when the DBC carries
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
generator, source DB.

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
  the 1.60 client ("File not found in root"); items are out of scope for
  this package until that table resolves — spell/talent/trainer coverage
  is unaffected.
- **AcquireMethod / RaceMasks** are emitted raw (observed methods 0/1/2/3);
  skill lines resolve to names, race bits to `races.playable_bit`.
- **Multi-school spells** decode all mask bits (`Frostfire Bolt` mask 20 =
  `fire+frost`); single-school rows match the rotation bridge exactly.
