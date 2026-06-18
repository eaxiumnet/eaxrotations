# EaxAutoQuester Optimization & Development Plan

**Status:** Ready for review  
**Phases:** 6 (0–5)  
**Total Tasks:** 14  
**Estimated Effort:** ~25 atomic commits across 12+ files  

---

## Table of Contents

1. [Context & Architecture Summary](#1-context--architecture-summary)
2. [Task Dependency Graph](#2-task-dependency-graph)
3. [Phase 1: Infrastructure](#3-phase-1-infrastructure)
4. [Phase 2: Performance](#4-phase-2-performance)
5. [Phase 3: Features](#5-phase-3-features)
6. [Phase 4: Code Quality](#6-phase-4-code-quality)
7. [Phase 5: Testing](#7-phase-5-testing)
8. [Phase 6: Verification](#8-phase-6-verification)
9. [Commit Strategy](#9-commit-strategy)
10. [Clarifying Questions](#10-clarifying-questions)

---

## 1. Context & Architecture Summary

**EaxAutoQuester** is a Lua-based WoW TBC Classic auto-questing plugin for Project Sylvanas.

### State Machine Flow
```
IDLE → NAV → INTERACT → DO_ACTION → WAITING → DEAD
```

### Key Files
| File | Role | Lines |
|------|------|-------|
| `main.lua` | Entry point, menu/keybind, pre_tick/render callbacks | ~120 |
| `quest_state/coordinator.lua` | State machine dispatcher, shared state, context builder | ~348 |
| `quest_state/idle_state.lua` | IDLE: frame detection, goal evaluation, corpse loot, death check | ~592 |
| `quest_state/nav_state.lua` | NAV: navigation wrapper, arrival/failure/stuck handling | ~180 |
| `quest_state/interact_state.lua` | INTERACT: gossip/quest/trainer/vendor frame handling | ~120 |
| `quest_state/do_action_state.lua` | DO_ACTION: goal execution (loot, kill, talk, area) | **682** |
| `quest_state/waiting_state.lua` | WAITING: step completion, progress detection | ~90 |
| `quest_state/dead_state.lua` | DEAD: corpse run, resurrection, ghost form | ~160 |
| `navigation_sylvanas.lua` | SentinelNav + simple_movement fallback, stuck detection | ~397 |
| `npc_manager_sylvanas.lua` | Object scanning, NPC finding, enemy targeting | **319** |
| `combat_helper_sylvanas.lua` | Target tagging, quest item usage | ~140 |
| `loot_manager_sylvanas.lua` | Auto-loot, close loot | ~180 |
| `vendor_manager_sylvanas.lua` | Repair, sell junk, buy items | **212** |
| `quest_interaction_sylvanas.lua` | Gossip/quest/trainer/vendor frame automation | ~320 |
| `zygor_reader_sylvanas.lua` | Zygor guide data access | ~200 |
| `questie_reader_sylvanas.lua` | Questie addon data access | ~100 |
| `npc_db_sylvanas.lua` | NPC spawn DB lookup | ~150 |
| `object_scanner.lua` | **CACHED object scan** (currently **UNUSED**) | 196 |
| `safe_api_wrapper.lua` | **Probe-once API wrapper** (currently **UNUSED**) | 126 |
| `json_loader.lua` | JSON parser (forward reference bug) | 194 |
| `menu_sylvanas.lua` | UI configuration (vendor_threshold combobox exists) | 199 |
| `utils_sylvanas.lua` | Shared utilities | ~180 |

### Test Files (20 total)
```
test_idle_state.lua, test_dead_state.lua, test_do_action_state.lua,
test_coordinator.lua, test_npc_manager.lua, test_npc_db.lua,
test_loot_manager.lua, test_combat_helper.lua, test_waiting_state.lua,
test_nav_state.lua, test_integration_death_flow.lua, test_json_loader.lua,
test_integration_vendor_flow.lua, test_integration_quest_flow.lua,
test_interact_state.lua, test_vendor_manager.lua, test_utils_sylvanas.lua,
test_runner_lib.lua, run_quester_tests.lua, mock_core.lua
```

### Critical Issues Found
1. **object_scanner.lua UNUSED** — 7 call sites across 6 files call `get_visible_objects()` directly, causing 5–8 duplicate scans per tick.
2. **safe_api_wrapper.lua UNUSED** — All modules use raw `pcall` on every API call; ~15–20% overhead on hot paths.
3. **npc_manager expensive debug logging** — `find_nearest_npc` second loop (lines 124–143) iterates ALL objects for detailed logging on EVERY call, regardless of debug flag.
4. **vendor_manager ignores menu setting** — Menu has `vendor_threshold` combobox (1=Grey, 2=White, 3=Green, 4=Blue) but `vendor_manager` hardcodes `QUALITY_GREY = 1`.
5. **json_loader forward reference** — `parse_string` called in `parse_value` (lines 46, 95) before defined (line 114).
6. **idle_state duplicate corpse loot** — Lines 204–268 and 521–578 are nearly identical corpse-loot logic blocks.
7. **do_action_state monolithic** — 682 lines, should be decomposed into focused handlers.

---

## 2. Task Dependency Graph

```
Wave 1 (Start immediately — no dependencies):
  ├─ 1. Fix json_loader forward reference
  ├─ 2. Integrate object_scanner into coordinator
  ├─ 3. Integrate safe_api into coordinator
  ├─ 4. Fix npc_manager debug logging
  ├─ 5. Fix vendor_manager threshold
  ├─ 6. Extract idle_state corpse loot helper
  ├─ 7. Decompose do_action_state
  └─ 10. Add mount support to navigation

Wave 2 (After Wave 1):
  ├─ 8. Adopt object_scanner in all state/helper files      ← depends on 2
  ├─ 9. Adopt safe_api in state files                         ← depends on 3
  ├─ 11. Implement stuck escalation ladder                   ← depends on 10
  └─ 12. Implement death zone tracker

Wave 3 (After Wave 2):
  ├─ 13. Write new unit tests & integration tests            ← depends on 1–12
  └─ 14. Run full regression suite & syntax checks           ← depends on 13
```

**Critical Path:** Task 2 → Task 8 → Task 13 → Task 14  
**Estimated Parallel Speedup:** ~35% vs. fully sequential.

---

## 3. Phase 1: Infrastructure

### Task 1: Fix json_loader forward reference
- **File:** `EaxAutoQuester/json_loader.lua`
- **What:** `parse_string` is called inside `parse_value` (lines 46, 95) before it is defined (line 114). Move `parse_string` definition to line ~28 (before `parse_value`).
- **Risk:** None — pure reordering, no logic change.
- **Test:** `lua EaxAutoQuester/tests/test_json_loader.lua` must pass.
- **Commit:** `fix(json_loader): move parse_string before parse_value to eliminate forward reference`

### Task 2: Integrate object_scanner into coordinator
- **File:** `EaxAutoQuester/quest_state/coordinator.lua`
- **What:**
  1. `local object_scanner = require("object_scanner")` at load.
  2. In `M.update()`, top: `object_scanner.invalidate()`.
  3. In `build_context()`, add `object_scanner = object_scanner` to returned context.
- **Why:** Single cached scan per tick, shared by all state handlers.
- **Test:** `test_coordinator.lua` — mock scanner, assert `invalidate()` called per tick.
- **Commit:** `feat(coordinator): integrate object_scanner for single-scan-per-tick`

### Task 3: Integrate safe_api_wrapper into coordinator
- **File:** `EaxAutoQuester/quest_state/coordinator.lua`
- **What:**
  1. `local safe_api = require("safe_api_wrapper")` at load.
  2. Probe batch of framework APIs:
     - `get_local_player`, `get_loot_item_count`, `get_vendor_item_count`, `is_gossip_frame_shown`
     - `get_num_trainer_services`, `set_target`, `look_at`, `loot_object`, `close_loot`
     - `interact_with_object`, `use_object`
  3. Add `safe_api = safe_api, probed = _probed` to `build_context()` return.
- **Why:** Eliminates per-frame pcall overhead for singleton APIs (~25 hot-path calls).
- **Test:** `test_coordinator.lua` — verify probed handles are present and functional.
- **Commit:** `feat(coordinator): integrate safe_api_wrapper for hot-path API probes`

---

## 4. Phase 2: Performance

### Task 4: Fix npc_manager expensive debug logging
- **File:** `EaxAutoQuester/npc_manager_sylvanas.lua`
- **What:**
  1. Add `debug_mode` as optional parameter to `find_nearest_npc(ids, range, debug_mode)` and `get_nearest_enemy(range, debug_mode)`.
  2. Wrap the second loop (lines 124–143, detailed per-object logging) in `if debug_mode then ... end`.
  3. Update callers (coordinator/state files) to pass `shared._debug` or `menu.get("debug")`.
- **Why:** Prevents iterating all ~100 visible objects every call when debug is off.
- **Test:** `test_npc_manager.lua` — mock 200 objects, call with `debug_mode=false`, assert no `core.log` calls and fast return.
- **Commit:** `fix(npc_manager): gate expensive debug logging loop behind debug_mode param`

### Task 5: Fix vendor_manager to respect vendor_threshold menu setting
- **File:** `EaxAutoQuester/vendor_manager_sylvanas.lua`
- **What:**
  1. Replace hardcoded `QUALITY_GREY = 1` with dynamic helper:
     ```lua
     local function get_threshold_quality()
         local menu = _G.EaxAutoQuester and _G.EaxAutoQuester.menu
         local idx = menu and menu.get("vendor_threshold") or 1
         return math.min(math.max(idx, 1), 4)
     end
     ```
  2. Update `should_sell_junk` and `sell_junk` to compare `info.quality <= get_threshold_quality()`.
- **Why:** Menu combobox was present but ignored.
- **Test:** `test_vendor_manager.lua` — mock menu index 2 (White), create quality 1 and 2 items, assert only quality 1 sold.
- **Commit:** `fix(vendor_manager): respect vendor_threshold menu setting instead of hardcoding grey`

### Task 6: Extract idle_state duplicate corpse loot logic
- **File:** `EaxAutoQuester/quest_state/idle_state.lua`
- **What:**
  1. Extract `local function try_loot_nearest_corpse(shared, ctx, max_nav_dist_sq)`:
     - Checks loot window/cooldown.
     - Scans for nearest dead non-player unit via `ctx.object_scanner` (after Task 2).
     - Within 9 dist_sq: `look_at`, `set_target`, `loot_object` → returns `"IDLE"`.
     - Within `max_nav_dist_sq` (400): sets `shared._nav_destination` → returns `"NAV"`.
     - Else returns `nil`.
  2. Replace both original blocks (lines 204–268 and 521–578) with:
     ```lua
     local loot_result = try_loot_nearest_corpse(shared, ctx, 400)
     if loot_result then return loot_result end
     ```
- **Risk:** Must preserve semantic equivalence (block 1 is after goal evaluation, block 2 is after "no uncompleted goal"). Ensure return paths match.
- **Test:** Characterization test in `test_idle_state.lua` — mock corpses at 5yd and 15yd, pin current behavior, refactor, verify GREEN.
- **Commit:** `refactor(idle_state): extract try_loot_nearest_corpse to eliminate duplicate logic`

### Task 7: Decompose do_action_state monolith
- **File:** `EaxAutoQuester/quest_state/do_action_state.lua` (+ optional new file)
- **What:**
  1. Keep `M.run` as dispatcher (~50 lines).
  2. Extract handlers (same file or `do_action_handlers.lua`):
     - `handle_loot_click_use(shared, ctx, goal)` — lines ~27–73
     - `handle_kill(shared, ctx, goal)` — lines ~75–114
     - `handle_talk_gossip(shared, ctx, goal)` — lines ~116–130
     - `handle_area(shared, ctx, goal)` — lines ~132–602 (delegates to sub-handlers)
  3. Decompose `handle_area` further into private helpers:
     - `area_try_questie_fallback(shared, ctx, npc, goal)` — Questie NPC search
     - `area_try_npc_db_lookup(shared, ctx, goal)` — NPC DB spawn navigation
     - `area_try_name_targeting(shared, ctx, npc, goal)` — Name-based object search
     - `area_try_enemy_scan(shared, ctx, npc, goal)` — Enemy name matching & attack
     - `area_try_brute_force(shared, ctx, npc, goal)` — Final 25yd brute-force interact
     - `area_enemy_fallback(shared, ctx, npc)` — Fallback enemy tag
  4. Each helper returns `true` if action taken, `false` if not.
  5. `handle_area` calls helpers in priority order and returns on first success.
- **Target:** `do_action_state.lua` ≤ 150 lines; each handler ≤ 120 lines.
- **Test:** Characterization tests first (cover each action_type), refactor, keep GREEN. Add isolated handler unit tests.
- **Commit:** `refactor(do_action_state): decompose execute_goal_action into focused handlers`

---

## 5. Phase 3: Features

### Task 10: Add mount support to navigation
- **File:** `EaxAutoQuester/navigation_sylvanas.lua`
- **What:**
  1. Add `local _mounted = false` state.
  2. Add `M.try_mount()`:
     ```lua
     function M.try_mount()
         local ok, mounted = pcall(core.input.mount)
         if ok and mounted then _mounted = true end
     end
     ```
  3. Add `M.dismount()`:
     ```lua
     function M.dismount()
         if _mounted then
             pcall(core.input.dismount)
             _mounted = false
         end
     end
     ```
  4. In `M.navigate_to()`, if destination distance from player > 1600 dist_sq (40yd), call `M.try_mount()` before starting nav.
  5. In `stop_internal()`, `on_sentinel_arrived`, and combat override in coordinator, call `M.dismount()`.
- **Test:** `test_nav_state.lua` (or new `test_navigation_mount.lua`) — mock `core.input.mount` and `core.input.dismount`, verify mount called when distance > 40yd, dismount on arrival.
- **Commit:** `feat(navigation): add mount support for long-distance travel`

### Task 11: Implement stuck detection escalation ladder
- **File:** `EaxAutoQuester/navigation_sylvanas.lua`
- **What:**
  1. Replace single `_stuck_timer` with `_stuck_level` (0–3) and `_stuck_start_time`.
  2. Escalation levels:
     | Level | Time | Action |
     |-------|------|--------|
     | 0 | 2s | Jump/strafe (if `core.input.jump()` available) |
     | 1 | 3s | Stop and recalculate path (`M.navigate_to(_destination, _arrived_cb)`) |
     | 2 | 6s | Attempt hearthstone (scan bags for item 6948, use `core.input.use_container_item`) |
     | 3 | 9s | Fire callback with `"stuck_escalated"`, stop nav, log critical warning |
  3. If jump/strafe APIs are unavailable (see Clarifying Questions), skip Level 1.
  4. Update `M.update()` stuck block (lines 325–363) to implement ladder.
- **Test:** New `test_navigation_stuck.lua` — mock time advancing 1s per tick, assert correct level transitions and actions.
- **Commit:** `feat(navigation): implement stuck detection escalation ladder`

### Task 12: Implement death zone tracking and blacklist
- **File:** New `EaxAutoQuester/death_tracker_sylvanas.lua`, update `coordinator.lua`
- **What:**
  1. New module `death_tracker_sylvanas.lua`:
     ```lua
     local deaths = {} -- keyed by map_id
     local function record_death(map_id)
         deaths[map_id] = (deaths[map_id] or 0) + 1
         return deaths[map_id]
     end
     local function get_death_count(map_id) return deaths[map_id] or 0 end
     local function should_blacklist(map_id) return get_death_count(map_id) >= 3 end
     local function reset_zone(map_id) deaths[map_id] = nil end
     ```
  2. In `coordinator.lua`, when entering DEAD state or when `dead_state` detects death, call `record_death(map_id)`.
  3. If `should_blacklist(map_id)`, transition to WAITING with warning log, or trigger hearth via navigation.
  4. Auto-reset on successful quest turn-in (hook into `interact_state` or `zygor_reader` step completion).
- **Test:** `test_death_tracker.lua` — mock `core.get_map_id`, verify counting, threshold, blacklist flag.
- **Commit:** `feat(death_tracker): add zone death tracking and blacklist after 3 deaths`

---

## 6. Phase 4: Code Quality (Cross-File Adoption)

### Task 8: Adopt object_scanner in all state/helper files
- **Files:** `idle_state.lua`, `do_action_state.lua`, `dead_state.lua`, `npc_manager_sylvanas.lua`, `combat_helper_sylvanas.lua`, `loot_manager_sylvanas.lua`
- **What:** Replace all raw `pcall(core.object_manager.get_visible_objects())` with `ctx.object_scanner` methods:
  - Use `ctx.object_scanner.get_visible_objects()` for direct access.
  - Use `ctx.object_scanner.scan(filter_fn, 50)` for filtered scans.
  - Use `ctx.object_scanner.find_nearest(filter_fn, range)` for nearest-match searches.
- **Special attention:**
  - `combat_helper_sylvanas.lua` line 49 has a **bare unprotected call** to `_get_visible_objects()` — crash risk if API errors. **This must be fixed first.**
  - `npc_manager.lua`: refactor internal functions to accept `scanner` param or read from global. Remove internal `_get_visible_objs` caching.
- **Grep verification:** After completion, `grep -rn "get_visible_objects" EaxAutoQuester/` must only match:
  - `object_scanner.lua` (the cache itself)
  - `coordinator.lua` (probe site)
  - `safe_api_wrapper.lua` (irrelevant, but may match)
- **Test:** For each file, test that no raw `get_visible_objects` is called (mock to assert call count = 1 per tick from scanner).
- **Commit:** `perf(state-files): adopt object_scanner in idle/do/dead/npc/combat/loot modules`

### Task 9: Adopt safe_api in state files for framework APIs
- **Files:** `idle_state.lua`, `do_action_state.lua`, `interact_state.lua`, `dead_state.lua`, `loot_manager_sylvanas.lua`, `quest_interaction_sylvanas.lua`
- **What:** Replace raw `pcall(core.game_ui.*)`, `pcall(core.quests.*)`, `pcall(core.input.*)` with fast-path calls:
  ```lua
  -- Before:
  local ok, result = pcall(core.input.set_target, target)
  -- After:
  local result = ctx.safe_api.call(ctx.probed.set_target, target)
  ```
- **Boundaries:** Keep per-object method pcalls (`obj:is_unit()`, `obj:get_position()`, etc.) as-is — `safe_api` cannot probe instance methods.
- **Grep verification:** After completion, raw `pcall(core.input.set_target)` and `pcall(core.game_ui.get_loot_item_count)` eliminated from state files.
- **Test:** For each state file, mock `ctx.probed` and assert fast-path calls are made without pcall overhead.
- **Commit:** `perf(state-files): adopt safe_api fast-path for framework-level singleton APIs`

---

## 7. Phase 5: Testing

### Task 13: Write new unit tests and update integration tests
- **Files:** `EaxAutoQuester/tests/test_object_scanner.lua`, `test_safe_api_wrapper.lua`, `test_navigation_mount.lua`, `test_navigation_stuck.lua`, `test_death_tracker.lua`, plus updates to existing tests.
- **What:**
  1. **test_object_scanner.lua** — Cache invalidation, `scan()`, `find_nearest()`, `count()`, error fallback (pcall failure returns empty table).
  2. **test_safe_api_wrapper.lua** — `probe()` success/failure, `call()` fast path, `call_pcall()` fallback, `wrap()` auto-switch, `probe_batch()`.
  3. **test_navigation_mount.lua** — Mount triggers on >40yd travel, dismount on arrival/combat/stop.
  4. **test_navigation_stuck.lua** — Escalation ladder simulation: mock time ticks, assert level transitions at 2s/3s/6s/9s, hearth attempt, final stop.
  5. **test_death_tracker.lua** — Zone counting, threshold=3, blacklist flag, reset.
  6. **Update existing tests:**
     - `test_coordinator.lua` — verify scanner invalidation and probed handles in context.
     - `test_idle_state.lua` — verify extracted `try_loot_nearest_corpse` helper.
     - `test_do_action_state.lua` — verify decomposed handlers still produce same transitions.
     - `test_npc_manager.lua` — verify debug-gated logging.
     - `test_vendor_manager.lua` — verify threshold quality mapping.
- **Target:** 20+ new test assertions covering all new behavior.
- **Commit:** `test(all): add unit tests for scanner, safe_api, mount, stuck, death tracker`

---

## 8. Phase 6: Verification

### Task 14: Run full regression suite and syntax checks
- **What:** Final verification gate before declaring completion.
- **Steps:**
  1. Syntax check all Lua files:
     ```powershell
     Get-ChildItem -Path EaxAutoQuester -Recurse -File -Filter '*.lua' |
         ForEach-Object { luac -p $_.FullName }
     ```
     → Must return zero errors.
  2. Run full test suite:
     ```powershell
     lua EaxAutoQuester/tests/run_quester_tests.lua
     ```
     → Must report all tests passing.
  3. Verify no raw scans remain:
     ```powershell
     grep -rn "pcall(core.object_manager.get_visible_objects)" EaxAutoQuester/
     ```
     → Should only match `object_scanner.lua` and coordinator probe site.
  4. Verify no raw framework pcalls remain in state files:
     ```powershell
     grep -rn "pcall(core.input.set_target)" EaxAutoQuester/quest_state/
     grep -rn "pcall(core.game_ui.get_loot_item_count)" EaxAutoQuester/quest_state/
     ```
     → Should return empty.
  5. Verify vendor threshold fixed:
     ```powershell
     grep -rn "QUALITY_GREY" EaxAutoQuester/vendor_manager_sylvanas.lua
     ```
     → Should not match hardcoded constant.
  6. Verify npc_manager logging fixed:
     ```powershell
     grep -A5 "find_nearest_npc" EaxAutoQuester/npc_manager_sylvanas.lua | grep "id_matches"
     ```
     → Should show debug_mode gating.
- **Commit:** `chore(verification): luac -p + full regression suite pass`

---

## 9. Commit Strategy

**Branch:** `feat/autoquester-optimization`

**Atomic commits — one per task:**
```
fix(json_loader): move parse_string before parse_value to eliminate forward reference
feat(coordinator): integrate object_scanner for single-scan-per-tick
feat(coordinator): integrate safe_api_wrapper for hot-path API probes
fix(npc_manager): gate expensive debug logging loop behind debug_mode param
fix(vendor_manager): respect vendor_threshold menu setting instead of hardcoding grey
refactor(idle_state): extract try_loot_nearest_corpse to eliminate duplicate logic
refactor(do_action_state): decompose execute_goal_action into focused handlers
perf(state-files): adopt object_scanner in idle/do/dead/npc/combat/loot modules
perf(state-files): adopt safe_api fast-path for framework-level singleton APIs
feat(navigation): add mount support for long-distance travel
feat(navigation): implement stuck detection escalation ladder
feat(death_tracker): add zone death tracking and blacklist after 3 deaths
test(all): add unit tests for scanner, safe_api, mount, stuck, death tracker
chore(verification): luac -p + full regression suite pass
```

**Pre-commit hook for each task:**
```powershell
# 1. Syntax check changed files
luac -p <file>
# 2. Run affected tests
lua EaxAutoQuester/tests/test_<module>.lua
# 3. Run full suite (before final push)
lua EaxAutoQuester/tests/run_quester_tests.lua
```

---

## 10. Clarifying Questions

Before execution begins, please confirm the following:

### Q1: Item quality mapping
The menu combobox index is 1=Grey, 2=White, 3=Green, 4=Blue. The current hardcoded constant is `QUALITY_GREY = 1`. **Does `core.quests.get_item_info(info.quality)` return 0 for grey (standard WoW) or 1 for grey?** This determines whether the mapping is `threshold_quality = menu_index` or `threshold_quality = menu_index - 1`.

### Q2: Jump/strafe APIs
The available API list mentions `core.input.mount, dismount, look_at, set_target, interact_with_object, use_object, loot_object` but no `jump` or `strafe`. **Are `core.input.jump()` or `core.input.move(strafe_x, strafe_y)` or similar movement APIs available?**

- If **yes**: Stuck ladder Level 0 will include jump/strafe.
- If **no**: Stuck ladder will start at Level 1 (recalc path at 3s).

### Q3: Hearthstone detection
For stuck ladder Level 2 (hearth at 6s), the plan assumes scanning bags for item ID 6948 and using `core.input.use_container_item`. **Is there a direct `core.input.hearth()` API, or should we scan bags and use the item?**

> **If you confirm these, I will lock the plan and begin execution. If no response, I will proceed with the safer/agnostic defaults (assume 0=grey, no jump API, bag-scan hearth).**
