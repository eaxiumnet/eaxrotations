# Searching for an objective instead of waiting on one spot

Live evidence (2026-09-21, priest, Lesser Rock Elementals): twelve consecutive minutes of

```
IDLE: waiting for respawn (Lesser Rock Elementals)
```

with the player stationary, and the wait re-arming after each 60s expiry because a corpse of the
same name was still underfoot. The bot was not waiting for a respawn — it was waiting at one
corpse.

## Why the old wait could not see anything

The respawn wait's only sensor was `npc_manager.get_nearest_enemy(50, …)`, fired from wherever the
last kill happened, plus a name probe limited to the same 50yd. The mob's own spawn points are not
within 50yd of each other: `Lesser Rock Elementals` has **18 spawn points spread over ~250yd** in
the shipped cMaNGOS index (`EaxAutoQuester/npc_spawns.lua`). So a respawn anywhere but the player's
feet was invisible by construction, and "wait" meant "stand still until the timer expires, then
stand still again".

Answering "the new ones spawn behind me and at other spawn points" therefore needs two things that
did not exist: a **detector that asks about this goal's mobs by name** (not just any enemy within
50yd), and a **walk** that covers the spawn points.

## `shared/spawn_patrol.lua`

`next_point(shared, ctx, goal)` returns the point to walk to next, or `nil` to stand still. It is
the single owner of "where do I look for the mobs this goal names".

- **Candidates** are the goal mob's own spawn points from the local spawn index. The goal's target
  string is resolved through `shared/goal_names.lua` (plural → singular) against
  `npc_spawns.find_npc_ids_by_name`, or used directly when the goal already carries an NPC id.
  Points are filtered to the current map and to 400yd of the player, with the nearest point beyond
  that kept as a single candidate so a mob whose camp is far away still produces a leg toward it.
  A mob with nothing in the index falls back to **the Zygor step's own path**
  (`ctx.zygor.get_step_waypoints_world`) — the areas the guide itself walks through for this step,
  which is what covers quest objects, unusual names, and a checkout with no spawn data.
- **A sweep** is: nearest unsearched point → walk it → at 10yd it counts as searched → next. A
  point the bot is already standing on counts as searched *at choice time*, so the first leg of a
  wait is never a walk to where the bot already is (and a single-spawn objective correctly answers
  "nothing to walk to" — the 5s name probe watches that spot).
- **When every point has been searched** the list is rebuilt around the player's current position,
  so arriving at the camp widens the search to the rest of it instead of freezing the candidate set
  that was chosen from 400yd away — and the search keeps moving instead of ending on whatever point
  it happened to finish on. A rebuild walks the whole spawn index, so it is throttled to one every
  5s rather than one per tick.
- **A leg in flight is published once every 1.5s**, not every tick: the states hand the walk to the
  client and the client owns it from there, and a fresh instruction per frame restarts the path.
- **A point that cannot be reached costs one leg**: if the player has not moved 5yd in 15s the point
  is marked searched and the sweep moves on. An unreachable spawn coordinate (inside geometry, off
  the navmesh) must not wedge the search.
- **Z** is fixed with `waypoint_fixer_sylvanas.fix_z`, once per point, the same way every other
  destination producer in the plugin does it.
- **The pull gate's hold outranks the search.** A search leg walks toward a camp, which is exactly
  what the gate decided not to do; while the hold is armed the retreat is the destination and the
  search waits (`shared/pull_safety.lua`).

## Detection

`idle_state`'s respawn wait now asks two questions, in one throttled 5s scan:

1. **Is this goal's mob here?** `find_interactable_objects` over the goal's expanded names, within
   50yd, ignoring corpses — so a fresh spawn is seen even if the enemy probe's filters disagree
   about a unit that has just appeared.
2. **Is any enemy here?** The old 50yd `get_nearest_enemy` probe, unchanged, for a hostile the
   goal's names do not cover.

The wait logs once per scan instead of once per tick (it was four lines a second for minutes).

## Tests

`tests/test_spawn_patrol.lua` (P1–P15) pins the search rules against the **real** spawn index, with
the fixer stubbed: candidates come from the mob's spawn points nearest-first with the fix-up applied
once (P1), standing on a point advances the sweep (P2), an unreachable point costs one leg (P3), the
gate's hold outranks a leg (P4), a goal with nothing to search is latched (P5), the guide's
waypoints are the fallback (P6), another map's spawn points are never walked to (P7), a new goal is
a new search (P8), the index is asked once per goal rather than per tick (P9), a completed sweep
rebuilds on a 5s throttle rather than per tick (P10), and a leg in flight is published once per
1.5s (P11), the search is scoped to the goal's own id (P12). The guide's step waypoints join the
candidates on every goal, not only when the index resolves nothing — a kill mob with one or two
nearby spawns paces them forever while the guide's objective path is never walked (P13); a waypoint
standing on a spawn coordinate merges into one candidate, the spawn's terrain Z winning the tie
(P14); with no step waypoints the list is index-only, as before (P15).

`tests/test_respawn_wait.lua` (S6–S10) runs the wait end to end through `idle_state`: it walks the
mob's spawn points instead of parking (S6), a searched point advances the search (S7), the gate's
hold outranks it and the retreat is walked out (S8), a live goal target ends the wait while a
corpse of the same name does not (S9), and the scan logs once per scan (S10).

## Not verified without the client

The battery stops at the hand-off: the point is produced, terrain-fixed and published as the nav
destination, but whether `SentinelNavClient` accepts and reaches it is the client's answer. In game
the signal is `SPAWN PATROL: searching spawn point N/M (Xyd)` followed by a normal arrival and a
`sweep N complete — re-scanning …` once the camp has been covered; the failure signal is
`SPAWN PATROL: spawn point N unreachable — trying another` repeating for every point, which would
mean the navmesh does not reach the spawn coordinates the index carries.
