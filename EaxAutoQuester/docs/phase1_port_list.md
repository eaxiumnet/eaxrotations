# Phase 1 port list — monolith → `quest_state/*`

**Date:** 2026-09-19
**Source of truth for the port:** `quest_state_sylvanas.lua` (1,823 lines, the LIVE machine
until this phase), compared function-by-function against `quest_state/*` (the machine the 12
suites cover). Line references are the monolith's, as deleted in the final commit of this phase.

The diff ran in both directions. The modular machine is **ahead** on most capabilities
(death/corpse via `death_tracker` + `dead_state`, `quest_blacklist`, `progress_tracker`,
respawn waits, `goal_resolver`, `object_scanner`, `static_popup`, `flight_path`,
`service_gossip`, `mount_manager`, `quest_log_manager`, `corpse_loot`, anti-detection,
force-vendor, nav waypoint/mesh fallbacks, Z-adjusted retries) — those are **superseded**, not
ported. What follows is only what the monolith did and the modular machine did not.

## Ported (one commit each)

| # | Capability | Monolith ref | Modular target | Why it matters live |
|---|---|---|---|---|
| 1 | **Objective-first scan** — before walking to the step waypoint, scan for the goal's named interactable within 50 yd (plural→singular variants); in range (≤5 yd) skip NAV entirely, otherwise NAV straight to the object | §state_idle ~440-508 | `idle_state.run` | The comment records the failure it fixes: navigating to a ~0 yd destination spins `IDLE→NAV→ARRIVED→IDLE` forever because SentinelNavClient resolves instantly, and the objective-first block re-fires every tick. Directly affects gathering-node goals ("Bundles of Wood"). |
| 2 | **Kill-goal hold** — with a kill goal and an already-valid target (50 yd), stay in IDLE so the rotation fights instead of re-tagging | §state_idle ~530-537 | `idle_state.run` | Re-tagging every cycle thrashes the target and can pull extra mobs. |
| 3 | **Respect the post-action pause** before re-entering DO_ACTION | §state_idle ~575-590 | `idle_state.run` | The modular path *zeroed* `_action_pause_timer` at the decision point, so the 0.5 s pacing DO_ACTION sets was never actually applied. |
| 4 | **STUCK escalation** — retry 1: jump; retry 2: jump + a random left/right turn tap, before the 2 s backoff | §state_nav ~735-752 | `nav_state.run` | The modular STUCK branch only paused; a character wedged on geometry never freed itself. |
| 5 | **Arrival settle pause** — 1.5 s before IDLE re-evaluates, so the NPC/object has rendered | §state_nav ~712-716 | `nav_state.run` | Arriving and immediately re-evaluating can miss the freshly-spawned NPC. |
| 6 | **En-route pre-tag** — every 1.5 s while navigating out of combat, tag/interact the current goal's quest NPC | §state_nav ~651-680 | `nav_state.run` | Starts the fight on arrival instead of after a target scan. |
| 7 | **Anti-cheat random jump** — every 10-25 s while navigating | §state_nav ~683-686 | `nav_state.run` | `anti_detection_sylvanas` has delay/jitter/proximity but no movement action; this was the only idle-motion humanizer. |
| 8 | **Kill preference** — prefer the goal's quest NPC id (50 yd) over any nearest enemy, and skip re-tag when the current target is still valid | §execute_goal_action kill ~898-935 | `do_action_state` kill branch | Recorded on the monolith: "Prefer quest-specific mob by NPC ID (e.g. Elder Stranglethorn Tiger over generic tiger)". Killing the generic mob does not advance the quest. |
| 9 | **Talk escalation ladder** — after the quest-NPC-id lookup: goal-name match via `find_interactable_objects`, then `find_nearest_quest_unit`, then a proximity fallback (any non-player, non-dead unit within 30 yd, name match preferred) | §execute_goal_action talk ~1000-1360 | `do_action_state` talk branch | The modular talk branch had only the id lookup at 20 yd. NPCs with no Questie/Zygor id ("Marshal Dughan"-class goals) were unreachable, which is what the monolith's four extra fallbacks existed for. |
| 10 | **Progressive action pacing** — repeated identical action types back off 0.5 → 2.0 s with ±10 % jitter; talk/gossip uses a 0.3 s pause then re-checks the frame | §state_do_action ~1672-1695 | `do_action_state.run` (+2 `shared` fields) | Pacing is the anti-spam/anti-loop guard; the modular path used a flat 0.5 s. |

## Superseded — deliberately NOT ported

| Monolith behaviour | Modular replacement |
|---|---|
| Inline death/ghost recovery (corpse run, 45 yd enemy scan, release spirit) | `dead_state.run` + `death_tracker` (records deaths, resets on rez, 15 yd enemy scan, ≤1 enemy to res, forced-res timeout) and the coordinator's death-loop → hearth + blacklist |
| Brute-force area scan + 5-attempt give-up + permanent block | `do_action_state` area brute force with `object_scanner`, `AREA_FAIL_BLOCK`, plus `quest_blacklist.record_failure` / `abandon_quest` and `progress_tracker` blacklisting |
| `waypoint_fixer` Z fix (1 call site) | Same module used at three call sites (idle waypoint, idle flight/inn, area spawn) with an extra "destination Z is 0 → player Z" sanity check |
| `render_debug` overlay + `stop_navigation` | Equivalent implementations in `coordinator.lua` (plus `nav.dismount()` on hard stop) |
| "Respawn wait" was absent from the monolith entirely | `_respawn_wait_until` / `_respawn_last_scan` in the modular idle + do_action |

## Flagged decisions (behaviour the port list does NOT name, so it is unchanged)

1. **Gather-quest mana pause** — in the monolith this is `if false then … end` dead code with a
   comment explaining why it was disabled: waiting for mana blocked gathering quests ("Bundle of
   Wood" nodes) that do not require mana. The modular `idle_state` has the same check disabled for
   the same class of reason. Not re-enabled; the documented decision carries over verbatim.
2. **Low-HP pause** — the monolith waits below `min_hp` (default 80 %); the modular machine
   disables it under `if false and ctx.me` with a *different, later* rationale: the user reported
   the HP check prevented the bot from fighting and dying naturally, and the top-of-function death
   check now owns the 0 % case. Two live paths disagreed here; the modular (later, test-covered)
   decision wins and is preserved. **If the low-HP pause should return, it is a one-line change
   and should be its own commit with a scenario test.**
3. **Waypoint re-navigate threshold** differs (monolith 25 yd, modular 40 yd). Left as the modular
   value: the monolith's 25 yd was paired with its objective-first loop work, and tightening it
   without live validation risks new thrash.

## End state

`main.lua` requires only `quest_state/coordinator`; `quest_state_sylvanas.lua` is deleted; a
regression suite asserts exactly one state owner exists and that `main.lua` does not reference the
removed monolith.

### How the end state is enforced

`tests/test_state_machine_ownership.lua` fails if the fork returns. It asserts, against the
checked-out sources and the live `package.loaded` table:

1. `main.lua` loads `quest_state/coordinator` and never names the retired loader;
2. the retired loader does not exist on disk and is referenced by no plugin file or suite;
3. exactly one file under `quest_state/` owns the shared state table (`coordinator.lua`),
   every handler keeps the `function M.run(shared, ctx)` dispatch contract, and only the
   coordinator defines `update()` / `stop_navigation()`;
4. no suite loads a plugin module through a path-prefixed identity — the suites and
   production share one module table per file, so a suite cannot pass against a copy.

Item 4 is the one that matters most in practice: before this phase, suites loaded
`EaxAutoQuester/quest_state/idle_state` while the coordinator loaded `quest_state/idle_state`.
Same file, two tables — so a stub or an assertion in a suite touched nothing the live machine
used. Both spellings now resolve to one identity, and the runtime half of item 4 pins it.

### Retired behaviour

The monolith's inline death/ghost recovery, brute-force area scan + permanent block,
`waypoint_fixer` Z-fix call site, `render_debug` overlay, `stop_navigation`, respawn wait,
blacklist/abandon, combat/loot wiring and gather-quest mana pause were all **superseded** by
modular equivalents (see the tables above) before it was reduced to a pass-through and deleted.
