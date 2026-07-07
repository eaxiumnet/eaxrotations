# EaxAutoQuester Improvements — Completed 2026-06-25

**Date:** 2026-06-25
**Status:** ✅ COMPLETE
**Tests:** 22/22 EaxAutoQuester + 171/171 EaxRotations + 11/11 Leveling — ALL PASS

---

## What Was Done

### Phase 1: Critical Fixes (3 failing tests → 0 failing)

| # | File | Problem | Fix |
|---|------|---------|-----|
| 1 | `npc_db_sylvanas.lua` | `find_transport_npc()` didn't exist but `coordinator.lua:452` called it | Added `find_transport_npc(type_hint, map_id)` with keyword matching for vendor/repair/flight/inn |
| 2 | `vendor_manager_sylvanas.lua` | `should_sell_junk()` only sold grey (quality=0); test expected aggressive selling when bags full | Reads `_force_vendor_soon` flag; if set, sells up to green (quality=2). Flag cleared in `handle_vendor()` |
| 3 | `loot_manager_sylvanas.lua` | `_force_vendor_soon` was never set by anything | Added `get_bag_fullness_pct()` helper; after `auto_loot_all()`, if bags ≥80% full → sets flag + logs warning |
| 4 | `npc_manager_sylvanas.lua` | `find_nearest_npc()` returned local player unit, causing self-target loop | Added `is_player()` exclusion. Also fixed nil-entry early-break bug in `find_interactable_objects()` and `get_nearest_enemy()` |
| 5 | `quest_interaction_sylvanas.lua` | `is_reward` undefined variable at line ~215 | Removed undefined variable; rewrote `has_rewards` to use `ok_link` result only |
| 6 | `quest_interaction_sylvanas.lua` | Vendor frame detected but `vendor_manager.handle_vendor()` never called | Wired vendor_manager require+handle_vendor call when vendor frame open |
| 7 | `quest_interaction_sylvanas.lua` | No auto-equip reward logic | Added `auto_equip_best_reward()` using `equipment_compare_sylvanas.lua` |
| 8 | `quest_interaction_sylvanas.lua` | No pre-accept-all on turn-in NPCs | Added Priority 0: `accept_all_available()` before turn-in, so new quests are grabbed before leaving |

### Phase 2: New Features

| # | File | Feature | Details |
|---|------|---------|---------|
| 9 | `zygor_reader_sylvanas.lua` | `get_next_waypoint_world()` | Returns step waypoint[2] for lookahead pre-navigation; falls back to `core.addons.zygor.get_next_waypoint()` if available |
| 10 | `navigation_sylvanas.lua` | Escalating stuck recovery | L1: jump+strafe → L2: turn+move → L3: dismount → L4: hearthstone. `_stuck_level` and `_stuck_attempts` tracked per destination |
| 11 | **NEW** `anti_detection_sylvanas.lua` | Human-like behavior | Gaussian random delays, camera jitter (20-60s intervals), path deviation jitter, per-action-type delays, player proximity pause (2-5s), tick-rate variation |

### Phase 3: Test Adjustments

| # | File | Change |
|---|------|--------|
| 12 | `tests/test_do_action_state.lua` | Mocked `npc_db_sylvanas` with predictable spawn for NPC 5500 so S4 doesn't depend on real `creature_spawn_index.json` |

---

## Validation

```bash
luac -p EaxAutoQuester/*.lua EaxAutoQuester/quest_state/*.lua # all pass
lua EaxAutoQuester/tests/run_quester_tests.lua     # 21/21 pass
lua EaxRotations/tests/run_rotation_tests.lua     # 171/171 pass
lua EaxRotations/tests/run_leveling_tests.lua     # 11/11 pass
```

---

## API Integration Phase (questie + zygor + coords_helper wiring)

### Phase 3: New API wiring — fixes underground waypoint bug + adds is_quest_unit

| # | File | Feature | Details |
|---|------|---------|---------|
| 13 | **NEW** `waypoint_fixer_sylvanas.lua` | Terrain-height Z fix | Uses `coords_helper:get_terrain_height(x,y)` to fix z=0 waypoints. `map_to_world_fixed()` wraps coords_helper:map_to_world with Z correction |
| 14 | `zygor_reader_sylvanas.lua` | Z-fix in conversion | Coordinate conversion now chains through `waypoint_fixer.map_to_world_fixed()` first, then izi, then core.game_ui — all paths fix Z |
| 15 | `goal_resolver_sylvanas.lua` | Rewritten 6-stage resolver | Stage 1: Zygor passthrough → Stage 2: NPC DB → Stage 3: Inventory → Stage 4a: **is_quest_unit visible scan** (NEW) → Stage 4b: Questie `get_quest_objectives` + `get_quest_locations` (NEW, Z-fixed) → Stage 5: Unresolved. Uses `core.quests.get_quest_log_title()` for proper quest log scanning |
| 16 | `questie_reader_sylvanas.lua` | Full Questie API surface | `get_quest_objectives(quest_id)` — returns objectives with Z-fixed positions. `get_quest_locations(quest_id)` — returns NPC/object spawn locations with Z-fixed positions. `find_nearest_quest_unit(range)` — scans visible objects for `is_quest_unit()==true` |
| 17 | `npc_manager_sylvanas.lua` | `find_nearest_quest_unit()` | New function using `game_object:is_quest_unit()` — no addon needed, uses engine's own quest flag |
| 18 | `do_action_state.lua` | is_quest_unit fast path | Before Questie fallback, scans for nearest `is_quest_unit` within 80yd. Also fixes Z on NPC DB spawn positions via waypoint_fixer |
| 19 | `idle_state.lua` | Z-fix on waypoint | Every Zygor waypoint gets `fix_z()` applied before distance check |
| 20 | `coordinator.lua` | Anti-detection wired | Camera jitter + player proximity pause injected into the state machine update loop |

## Files Modified (16)

1. `EaxAutoQuester/npc_db_sylvanas.lua`
2. `EaxAutoQuester/vendor_manager_sylvanas.lua`
3. `EaxAutoQuester/loot_manager_sylvanas.lua`
4. `EaxAutoQuester/npc_manager_sylvanas.lua`
5. `EaxAutoQuester/quest_interaction_sylvanas.lua`
6. `EaxAutoQuester/zygor_reader_sylvanas.lua`
7. `EaxAutoQuester/navigation_sylvanas.lua`
8. `EaxAutoQuester/goal_resolver_sylvanas.lua`
9. `EaxAutoQuester/quest_state/idle_state.lua`
10. `EaxAutoQuester/quest_state/do_action_state.lua`
11. `EaxAutoQuester/quest_state/coordinator.lua`
12. `EaxAutoQuester/tests/test_do_action_state.lua`
13. `EaxAutoQuester/tests/run_quester_tests.lua`

## Files Created (3)

14. `EaxAutoQuester/anti_detection_sylvanas.lua`
15. `EaxAutoQuester/waypoint_fixer_sylvanas.lua`
16. `EaxAutoQuester/tests/test_waypoint_fixer.lua`
