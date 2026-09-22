# The right mob: identity, not similarity

Reported live: on the guide's step

```
kill Rock Elemental##92+
collect 3 Large Stone Slab##4627 |q 711/1 |goto Badlands 13.40,37.80
```

the bot killed **Lesser** Rock Elementals.

## What drops the item

`wowhead_data/extracted/creature_loot_template.json` (cMaNGOS, creature → item) has item **4627
"Large Stone Slab"** under exactly one creature:

```
entry 92  item 4627  ChanceOrQuestChance -80   comments: Large Stone Slab
```

and `creature_template.json` gives entry 92 the name **"Rock Elemental"** (levels 39–40). The other
mobs that share those two words are different creatures with different drops:

| Entry | Name | Level |
|---|---|---|
| **92** | **Rock Elemental** | 39–40 |
| 2735 | Lesser Rock Elemental | 37–39 |
| 2736 | Greater Rock Elemental | 42–44 |
| 2791 | Enraged Rock Elemental | 42–43 |

The guide distinguishes them the same way — with the `##92` on the step. Killing a Lesser one can
never advance the objective, however long the bot farms.

## Two defects in how the goal was read

**1. The id was thrown away.** The bridge hands the goal over with `npc_id = 0` when it has no
value for that field, and the plugin read it as

```lua
local nid = goal.npc_id or goal.target_id     -- 0 is truthy in Lua
if nid and nid > 0 then goal_npc_id = nid end -- ...so target_id was never consulted
```

`0 or x` is `0`. A goal whose identity lives in `target_id` (or in Zygor's own `targetid`, which is
what `Goal.lua` actually sets for `kill Rock Elemental##92+`, and which a multi-target goal carries
as `targets = { {name, id}, ... }`) therefore arrived at the kill lane as "no id": the lane fell back
to `get_nearest_enemy(50)` and the nearest hostile — a Lesser Rock Elemental — was killed.

**2. Similarity was accepted as identity.** The names a goal stands for were matched with
`lower_name:find(filter, 1, true)` — a substring test — so `"lesser rock elemental"` matched
`"rock elemental"`. The objective scan, the respawn wait and the area lane all took that answer, and
the bot both *walked* to the Lesser ones and declared its objective met among them (and the spawn
search swept their camp).

## The rule now

`shared/objective_match.lua` owns the question "is this unit the goal's objective?":

- **Ids first.** `mob_ids(goal)` reads every spelling the bridge and the addon use — `npc_id`,
  `target_id`, `targetid`, `id`, plus the `{name, id}` pairs in `targets` and `mobs`. `goal_id()`
  is the common single-id case. `is_objective()` compares the unit's own `get_npc_id()` against
  them: an id that is not in the list is **not** the objective, whatever the unit is called.
- **Whole names second**, and only where an id cannot decide — a unit that cannot answer
  `get_npc_id()`, or a goal that carries no id at all (quest objects, name-only goals). Names are
  compared as whole names, case-insensitively, without lowercasing either string.
- **No substring fallback.** `"Lesser Rock Elemental"` is a different mob from `"Rock Elemental"`,
  and the guide names the one that drops the item.

`only(goal, objects)` applies that to the lists the name lookups return (a list that is already all
matches is handed straight back, so the per-tick callers allocate nothing). It is used by

- `idle_state`'s objective scan (is my objective here?) and its respawn wait,
- `do_action_state`'s area lane (which mob to walk to / attack), and
- `spawn_patrol`, which now takes the goal's own ids as the mobs to search for — so the walk goes to
  Rock Elemental camps, and re-scopes when a step changes between two mobs that share a name.

`do_action_state`'s kill lane reads the goal id through `objective_match.goal_id`, so a zero
`npc_id` no longer hides `target_id`.

## Tests

- `tests/test_objective_match.lua` (O1–O6) pins the module on the real entries: the id decides
  (O1), every spelling and multi-target goal (O2), whole-name fallback (O3), units without an id
  (O4), `only()`'s keep/copy rules (O5), and that one goal's ids never leak into another's (O6).
- `tests/test_do_action_state.lua` **S19** (kill lane, the regression: the Lesser one is nearer and
  must not be touched — the goal's own mob is targeted) and **S25** (area lane, no id: the walk goes
  to the goal's mob 45yd away, not the lookalike at 3yd).
- `tests/test_respawn_wait.lua` **S11**: a live Lesser Rock Elemental does not end a wait for
  Rock Elementals; the goal's own mob does.
- `tests/test_idle_state.lua` **P1c**: a lookalike 2yd away is not "my objective" — the state still
  navigates to the goal's mob 40yd out.
- `tests/test_spawn_patrol.lua` **P12**: the search is scoped to the goal's id, uses no name lookup
  when it has one, and re-scopes when the step changes to a different mob behind the same name.

Thirteen mutants (targetid unread, the zero-truthiness idiom restored, the unit id never probed,
substring names, `only()` not filtering, a stale id list, each of the four filters removed, the
spawn search keyed on the name) are all killed by these scenarios.

## Not verified without the client

Which field the runtime bridge actually populates for a `kill` goal is the client's answer, and it
cannot be read offline: the module reads every spelling it could be, so the fix holds either way.
If the mob is still wrong in game, the line to check is `DO_ACTION: kill — targeted quest NPC <id>`
— its `id` should be 92 for this objective (or the id the guide's `##` carries); a
`DO_ACTION: kill — enemy found` line instead means the goal still arrived without an id.
