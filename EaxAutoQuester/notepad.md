# Ultrawork Notepad — EaxAutoQuester Mega Overhaul
Started: 2026-06-15

## Plan (exhaustive, atomic)
See TODO list and Plan Agent output.

## Scenarios (the contract)
1. Happy path: Plugin loads, Zygor step active, navigates to waypoint, interacts with NPC, accepts quest, turns in quest, loots, vendors, repairs.
2. Edge: Player dies, plugin pauses and resumes after rez; low HP/mana waits for regen; navigation stuck after 3 retries.
3. Adjacent-surface regression: EaxRotations still works (no breaking changes); all existing tests pass; no AGENTS.md pattern violations.
4. Bug fix: quest_interaction line 215 undefined `is_reward` must be fixed.
5. Performance: object scanning capped at 50, no garbage in tight loops, all API calls cached.
6. Feature: vendor_manager integrated into quest_interaction; quest item usage supported; death handling.

## Now (single step in progress)
Initialize notepad + invoke Plan Agent

## Todo (remaining, ordered)
- Phase 0: Plan Agent creates structured work breakdown
- Phase 1: Fix critical bugs
- Phase 2: Refactor quest_state
- Phase 3: Performance optimization
- Phase 4: Add missing features
- Phase 5: Write tests
- Phase 6: Verify everything

## Findings (non-obvious facts with file:line refs)
- quest_interaction_sylvanas.lua:215 — undefined `is_reward` variable (BUG)
- quest_state_sylvanas.lua:313 — nested `if me then` inside existing `if me then` (redundant)
- quest_state_sylvanas.lua:721 — `math.huge` used in brute-force scan (acceptable but could be improved)
- combat_helper_sylvanas.lua:56 — uses `ipairs` on potentially sparse object list (should use numeric for)
- quest_interaction_sylvanas.lua:399 — vendor frame detected but vendor_manager.handle_vendor NEVER called
- main.lua:69 — keybind toggle only works after first press because `_last_kb_toggle` starts nil
- navigation_sylvanas.lua:144 — `init_sentinel` called every `navigate_to` even if already initialized
- npc_manager_sylvanas.lua:137 — `find_interactable_objects` creates new table every call instead of static reuse
- zygor_reader_sylvanas.lua:90 — `get_current_waypoint_world` can return z=0 if terrain height unavailable
- No tests exist for EaxAutoQuester at all (gap vs EaxRotations which has 111 tests)

## Learnings (patterns / pitfalls for next turn)
- EaxAutoQuester follows AGENTS.md patterns generally well but has gaps in integration between modules.
- The state machine in quest_state is monolithic; needs decomposition for maintainability.
- Vendor/repair integration is half-implemented (manager exists but not wired into interaction flow).
- JSON parser has forward reference (parse_string called before defined) but works due to Lua runtime lookup.

---

# Phase 7 — Autonomy Chapter (started 2026-06-17)

## Goal
Add capabilities that maximise bot autonomy and minimise manual-help triggers, built on top of Phase 1-6's complete plumbing. Vendor/loot/trainer/death are wired. 21/21 baseline tests pass.

## Confirmed API surface (Project Sylvanas runtime)
- `core.quests.abandon_quest()` — core.lua:3379 — Item H ✓
- `core.quests.is_quest_flagged_completed(quest_id)` — quests.md ✓
- `core.quests.is_on_quest(quest_id)` — quests.md ✓
- `core.quests.get_quest_log_title(index)` returns `{title, level, quest_id, is_header, is_complete}` ✓
- `core.addons.zygor.get_next_waypoint()` — addons.md ✓ (next-step API not exposed; lookahead = next waypoint only)
- `core.addons.questie.get_quest_objectives(quest_id)` + `get_quest_locations(quest_id)` — addons.md ✓
- `core.game_ui.get_all_completed_quest_ids()` — core.lua:828 ✓
- `core.inventory.get_num_bag_slots(bag_id)` — core.lua:651 ✓
- `game_object.get_class()`, `get_faction_id()`, `get_race_id()`, `get_level()` — game_object.lua ✓
- `game_object.get_equipped_items()` returns `[{object=game_object, slot_id=integer}]` — game_object.md ✓
- `game_object.is_quest_unit()` — game_object.md ✓ (lets us preemptively scan quest-unit game_objects for resolver)
- **NO `core.taxi` API** — Item F deferred, replace with npc_db transport lookup
- **NO explicit `core.equipment` slot API** — Item E uses get_equipped_items + core.input.use_container_item pattern

## Confirmed existing assets (in-repo)
- `EaxAutoQuester/notepad.md` — this file
- `EaxAutoQuester/plans/overhaul-2026-06-15.md` — Phase 1-6 plan (complete)
- `EaxAutoQuester/safe_api_wrapper.lua` — `probe/call/call_pcall/probe_batch` API
- `EaxAutoQuester/npc_db_sylvanas.lua:52` — `search_npc_by_name(search)` (12,265 cMaNGOS NPCs)
- `EaxAutoQuester/npc_spawns/chunk_NNN.lua` — 7 chunks of spawn data with find_npc_spawn(npc_id, map_id)
- `EaxAutoQuester/questie_reader_sylvanas.lua` — Questie reader (already wired)
- `EaxAutoQuester/zygor_reader_sylvanas.lua` — Zygor reader (basic; needs `get_next_waypoint` + per-goal class/faction)
- Tests: 21/21 in `EaxAutoQuester/tests/` (mock_core.lua with `install()`, `create_player()`, `create_object()`, etc.)
- Test runner pattern: `lua EaxAutoQuester/tests/run_quester_tests.lua`

## Deliverables (8 items, all new modules + small edits)
| # | Module | New/Edit | Priority |
|---|--------|----------|----------|
| A | goal_resolver_sylvanas.lua | NEW | P0 — biggest stall-killer |
| B | zygor_reader_sylvanas.lua | EDIT — add `get_next_waypoint_world()` + per-goal class/faction parser | P0 |
| C | idle_state.lua | EDIT — skip already-completed + class/faction filter | P1 |
| D | vendor_manager_sylvanas.lua | EDIT — bag-full trigger; loot_manager_sylvanas.lua bag-space awareness | P1 |
| E | quest_interaction_sylvanas.lua | EDIT — auto-equip upgrade when reward beats equipped | P2 |
| G | npc_db_sylvanas.lua + idle_state.lua | NEW helper `find_transport_npc(map_id)` | P2 |
| H | do_action_state.lua + quest_interaction_sylvanas.lua + new blacklist module | NEW `quest_blacklist_sylvanas.lua` + EDIT | P0 (failure-path) |
| I | quest_interaction_sylvanas.lua | EDIT — pre-accept all available on turn-in-NPC | P1 |

## Scenarios (contract)
1. **A — Happy path**: Zygor step says "Talk to Milly Osworth" with no npc_id. Goal resolver looks up name via npc_db, finds spawn, NAVs there, interacts. ✓
2. **A — Edge**: Goal name not in npc_db. Resolver falls back to Questie get_quest_locations + context scan. After 4 retries, abandon quest (H).
3. **B — Lookahead**: Step complete → next waypoint from `zygor.get_next_waypoint_world()` pre-NAV'd in waiting state, 200ms gap.
4. **C — Class filter**: Quest log contains pre-completed quest → skipped.
5. **D — Bag full**: All 4 bags ≥80% → sell junk immediately.
6. **E — Equip upgrade**: Quest reward ilvl > equipped slot → equip on accept.
7. **G — Portal**: Sub-zone step at "Rut'theran Village" → NPC DB lookup of "Rut'theran" flight master.
8. **H — Abandon**: 5 failed area attempts on broken quest → core.quests.abandon_quest() + log + step advances.
9. **I — Pre-accept**: NPC has 2 gossip quests → both accepted before leaving.
10. **Regression**: All 21 existing tests still pass.

## Now
Spawn Plan agent to produce work breakdown + parallel graph. Then execute wave-by-wave.


