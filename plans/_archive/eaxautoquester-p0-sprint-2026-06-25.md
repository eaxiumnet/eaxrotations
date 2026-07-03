# EaxAutoQuester P0 Sprint — Static Popups, Quest Items

**Date:** 2026-06-25
**Goal:** Fix the 2 biggest stall-killers for autonomous questing
**Status:** COMPLETE

---

## Deliverables

| # | Module | What | Status | Test file |
|---|--------|------|--------|-----------|
| A | `static_popup_sylvanas.lua` | Auto-accept dungeon proposals + battlefield ports | ✅ Done | `test_static_popup.lua` |
| B | `quest_item_manager_sylvanas.lua` | Scan inventory, match items to quest goal text, use item on target/at position | ✅ Done | (tested via integration in `test_do_action_state.lua`) |
| C | Wire A+B into state machine | Static popup in `interact_state.lua`; quest items in `do_action_state.lua` | ✅ Done | existing tests pass |
| D | `flight_path_sylvanas.lua` | Detect taxi frame → find destination → TakeTaxiNode | ❌ Dropped | No taxi/flight path APIs in Project Sylvanas docs |

---

## Completion Checklist

- [x] `luac -p` passes on all 18 changed files
- [x] `lua EaxAutoQuester/tests/run_quester_tests.lua` — 23/23 pass
- [x] `lua EaxRotations/tests/run_leveling_tests.lua` — 11/11 pass
- [x] `lua EaxRotations/tests/run_rotation_tests.lua` — 170/171 pass (1 pre-existing vanilla warlock failure unrelated to this sprint)

---

## Notes
- Flight path automation dropped: no `core.quests.get_taxi_nodes()` or `TakeTaxiNode()` API found in docs or API. Will revisit if API surface expands.
- Static popup handler narrowed to detectable dialogs: dungeon proposals (`has_dungeon_proposal`) and battlefield ports (`get_battlefield_status`). Resurrection/BOP loot require frame-level APIs not exposed.
- Quest item resolution uses inventory scan + name fuzzy-matching against goal text (e.g., "Use Frostwolf Muzzle on a sickly giant" → finds "Frostwolf Muzzle" in bags).
