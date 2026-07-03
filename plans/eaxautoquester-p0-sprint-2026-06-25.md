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
| D | `flight_path_sylvanas.lua` | Detect "Fly to X" steps → NAV to flight master → auto-select destination gossip option | ✅ Done | `test_flight_path.lua` |
| E | Respawn wait in state machine | kill goal with no enemy → 3 min wait, throttled 5s scans, auto-resume on respawn | ✅ Done | `test_respawn_wait.lua` |
| F | Quest log manager | Auto-abandon grey quests when log ≥20 entries; blacklist prevents re-abandon | ✅ Done | `test_quest_log_manager.lua` |
| G | Service gossip handler | Auto-select innkeeper hearth-set, bank, repair from gossip options; NAV to innkeeper when step says "Set Hearth" | ✅ Done | `test_service_gossip.lua` |
| H | Progress tracker | Track kill/loot/area objective progress; blacklist after 5 min with no progress | ✅ Done | `test_progress_tracker.lua` |
| I | Dungeon quest detector | Skip quests requiring dungeon/instance entry (via text patterns + quest log scan); allows if player already inside | ✅ Done | `test_dungeon_detector.lua` |
| J | Mount manager | Auto-mount when destination >50yd; auto-dismount when <15yd; blocked in combat; mount cache; 3s throttle | ✅ Done | `test_mount_manager.lua` |
| K | EaxProfessions crash fix | Nil-guard all menu `:get()` calls in idle_state, approach_state, nav_state (Pattern 1 violations) | ✅ Done | (verified in runtime logs)

---

## Completion Checklist

- [x] `luac -p` passes on all 18 changed files
- [x] `lua EaxAutoQuester/tests/run_quester_tests.lua` — 30/30 pass
- [x] `lua EaxRotations/tests/run_leveling_tests.lua` — 11/11 pass
- [x] `lua EaxRotations/tests/run_rotation_tests.lua` — 171/171 pass

---

## Notes
- Flight path automation uses gossip option matching (no dedicated taxi API needed). The flight master presents destinations as gossip options; we match by name against the Zygor step text.
- Static popup handler narrowed to detectable dialogs: dungeon proposals (`has_dungeon_proposal`) and battlefield ports (`get_battlefield_status`). Resurrection/BOP loot require frame-level APIs not exposed.
- Quest item resolution uses inventory scan + name fuzzy-matching against goal text (e.g., "Use Frostwolf Muzzle on a sickly giant" → finds "Frostwolf Muzzle" in bags).
