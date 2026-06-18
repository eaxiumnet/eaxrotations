# Implementation Plan: EaxAutoQuester

**Created:** 2026-06-11
**API Surface:** `api/core.lua`, `api/common/izi_sdk.lua`, `api/third_party/sentinel_nav.lua`, `api/common/utility/`
**Docs References:** `apidocs/pages/dev/api/quests.md`, `apidocs/pages/dev/api/addons.md`, `apidocs/pages/dev/api/game-ui.md`, `apidocs/pages/dev/examples/navmesh-playground.md`

## Overview

A standalone autonomous questing plugin (`EaxAutoQuester/`) that follows Zygor Guides step-by-step with Questie objective awareness. Navigates via SentinelNavClient, handles the full quest lifecycle (accept → do objectives → turn in), and provides quality-of-life automation (loot, vendor, repair, training, gossip).

The plugin is **independent of EaxRotations** — combat rotations are handled separately by EaxRotations spec files.

---

## API Integration

| Function | Source | Purpose |
|----------|--------|---------|
| `core.addons.zygor.*` | `api/core.lua` | Zygor guide data (current step, waypoints, objectives, goals) |
| `core.addons.questie.*` | `api/core.lua` | Questie objective NPC/object positions |
| `_G.SentinelNavClient.client` | `api/third_party/sentinel_nav.lua` | Pathfinding + navigation to waypoints |
| `core.quests.*` | `api/core.lua` | Quest lifecycle: accept/complete/gossip/log/train |
| `core.game_ui.*` | `api/core.lua` | Loot window, vendor info, gossip frame, map |
| `core.input.*` | `api/core.lua` | Interact, loot, target, use object, repair, buy, pet |
| `core.inventory.*` | `api/core.lua` | Bag contents, gold, repair cost |
| `core.object_manager.*` | `api/core.lua` | Local player, visible objects, party frames |
| `izi.me()` | `api/common/izi_sdk.lua` | Local player convenience |
| `izi.get_cursor_world_pos()` / `izi.map_to_world()` | `api/common/izi_sdk.lua` | Coordinate conversion |
| `core.menu.*` | `api/core.lua` | Plugin configuration UI |

---

## Files to Create

| File | Purpose | APIs Used |
|------|---------|-----------|
| `EaxAutoQuester/main.lua` | Entry point: register callbacks, init subsystems | `core.register_on_pre_tick_callback`, `core.register_on_render_callback` |
| `EaxAutoQuester/quest_state.lua` | State machine: IDLE → NAV → INTERACT → DO_ACTION → WAITING | `core.time()` |
| `EaxAutoQuester/navigation.lua` | SentinelNavClient integration: move, stop, state tracking | `_G.SentinelNavClient.client`, vec3 |
| `EaxAutoQuester/zygor_reader.lua` | Read Zygor current step, waypoints, objectives, goals | `core.addons.zygor.*` |
| `EaxAutoQuester/questie_reader.lua` | Read Questie objective NPC IDs, locations | `core.addons.questie.*` |
| `EaxAutoQuester/quest_interaction.lua` | Accept, complete, gossip, turn-in, trainer logic | `core.quests.*` |
| `EaxAutoQuester/npc_manager.lua` | NPC/object detection and targeting | `core.object_manager.*`, `core.input.*` |
| `EaxAutoQuester/loot_manager.lua` | Auto-loot: open loot, take items/gold, close | `core.game_ui.*`, `core.input.loot_item()` |
| `EaxAutoQuester/vendor_manager.lua` | Auto-repair, auto-sell, buy quest items | `core.inventory.*`, `core.game_ui.get_vendor_item_info()` |
| `EaxAutoQuester/trainer_manager.lua` | Auto-train at class trainers | `core.quests.get_num_trainer_services()`, `buy_trainer_service()` |
| `EaxAutoQuester/menu.lua` | Plugin config UI: enable/disable, debug, filters | `core.menu.*` |
| `EaxAutoQuester/combat_helper.lua` | Non-rotation helpers: target tagging, quest item use | `core.input.set_target()`, `core.object_manager` |
| `EaxAutoQuester/utils.lua` | Shared utilities: distance, logging, throttle | `core.time()`, `core.log()` |

---

## Architecture

```
on_update() (every tick)
  │
  └─► quest_state.update()
        │
        ├─► IDLE ──► Read Zygor step
        │               │ No step? ──► WAITING (recheck 3s)
        │               │ Has step:
        │               │ ──► UI frame open? ──► INTERACT
        │               │ ──► Goal at position? ──► DO_ACTION
        │               │ ──► Otherwise ──► get waypoint ──► NAV
        │
        ├─► NAV ──► SentinelNavClient.move_to(target)
        │               │ Arrived ──► IDLE (re-evaluate)
        │               │ Failed ──► retry (3x max) ──► IDLE
        │               │ Stuck ──► pause 2s ──► retry
        │
        ├─► INTERACT ──► Handle UI frame
        │               ├─► Gossip/Quest ──► turn-in / accept / gossip option
        │               ├─► Vendor ──► sell junk → repair → buy → close
        │               ├─► Trainer ──► buy affordable spells
        │               ├─► Loot ──► take all → close
        │               └─► Done ──► IDLE
        │
        ├─► DO_ACTION ──► Execute goal
        │               ├─► "loot"/"click"/"use" ──► interact_with_object()
        │               ├─► "kill" ──► target nearest enemy
        │               ├─► "talk"/"gossip" ──► talk to NPC
        │               ├─► "area" ──► wait at location
        │               └─► Done ──► IDLE
        │
        └─► WAITING ──► Recheck Zygor step every 3s
```

---

## Task List

### Wave 1: Foundation (Start Immediately)

- [x] 1. **Project structure + entry point**
  - **File:** `EaxAutoQuester/main.lua`
  - **API Used:** `core.register_on_pre_tick_callback`, `core.register_on_render_callback`, `core.register_on_render_menu_callback`
  - **Wait, Should I also check?** Nothing yet — skeleton file
  - **Acceptance:**
    - Plugin loads without errors (`luac -p` passes)
    - Registers 3 callbacks (update, render, menu)
    - Menu shows "EaxAutoQuester" tree node
  - **Verify:** `luac -p EaxAutoQuester/main.lua`

- [x] 2. **Utils module**
  - **File:** `EaxAutoQuester/utils.lua`
  - **API Used:** `core.time()`, `core.log()`
  - **Acceptance:**
    - `squared_distance(a, b)` — squared 3D distance
    - `vec3_to_string(v)` — "(x, y, z)"
    - `throttle(name, interval)` — rate limiter
    - `log(msg)` / `debug_log(msg)` — logging wrappers
    - Static table reuse (Pattern 4), squared distance (Pattern 3)
  - **Verify:** `luac -p EaxAutoQuester/utils.lua`

- [x] 3. **Plugin configuration menu**
  - **File:** `EaxAutoQuester/menu.lua`
  - **API Used:** `core.menu.checkbox()`, `core.menu.tree_node()`, `core.menu.combobox()`, `core.menu.slider_int()`, `core.menu.keybind()`
  - **Acceptance:**
    - Checkboxes: Enable, Auto-loot, Auto-repair, Auto-vendor, Auto-train, Debug, Auto-accept, Auto-turnin
    - Combobox: Vendor sell threshold
    - Slider: Interaction range, Nav tolerance
    - All nil-guarded (Pattern 1)
    - Settings exposed via `menu.get(key, fallback)` pattern
  - **Verify:** `luac -p EaxAutoQuester/menu.lua`

### Wave 2: Zygor + Questie Readers (Parallel)

- [x] 4. **Zygor guide reader**
  - **File:** `EaxAutoQuester/zygor_reader.lua`
  - **API Used:** `core.addons.zygor.*`
  - **Acceptance:**
    - `get_current_step_info()` → step num, is_complete, goals[]
    - `get_current_waypoint_world()` → vec3 (converts map coords via `izi.map_to_world()`)
    - `get_current_objectives()` → parsed objective IDs
    - `get_sticky_goals()` → sticky step goals
    - Returns nil gracefully if Zygor not loaded
    - All nil-guarded
  - **Verify:** `luac -p EaxAutoQuester/zygor_reader.lua`

- [x] 5. **Questie reader**
  - **File:** `EaxAutoQuester/questie_reader.lua`
  - **API Used:** `core.addons.questie.*`
  - **Acceptance:**
    - `get_quest_npc_positions()` → { npc_id, name, position }[]
    - 2s throttle on cache refresh
    - Returns empty if Questie not loaded
  - **Verify:** `luac -p EaxAutoQuester/questie_reader.lua`

### Wave 2: Navigation (Parallel)

- [x] 6. **SentinelNavClient navigation**
  - **File:** `EaxAutoQuester/navigation.lua`
  - **API Used:** `_G.SentinelNavClient.client:*`
  - **Acceptance:**
    - `navigate_to(vec3, callback)` — starts movement
    - `stop()` — cancels navigation
    - `is_navigating()` → boolean
    - State tracking: IDLE, NAVIGATING, ARRIVED, FAILED, STUCK
    - Arrived callback fires on arrival
    - 3s stuck timeout with auto-stop
    - Fallback to `simple_movement` if Sentinel unavailable
  - **Verify:** `luac -p EaxAutoQuester/navigation.lua`

### Wave 3: World Interaction (Depends on Utils)

- [x] 7. **NPC / object manager**
  - **File:** `EaxAutoQuester/npc_manager.lua`
  - **API Used:** `core.object_manager.*`, `game_object.*`
  - **Acceptance:**
    - `find_nearest_npc(ids[], range)` — by NPC ID
    - `find_interactable_objects(name_filter)` — by name
    - `find_quest_npcs()` — Questie + Zygor goals
    - `get_nearest_enemy(range)` — for kill goals
    - Capped at 50 objects, squared distance, static table reuse
  - **Verify:** `luac -p EaxAutoQuester/npc_manager.lua`

- [x] 8. **Quest interaction (gossip, accept, complete, trainer)**
  - **File:** `EaxAutoQuester/quest_interaction.lua`
  - **API Used:** `core.quests.*`, `core.game_ui.*`
  - **Acceptance:**
    - `handle_gossip()` → detect gossip frame → turn-in first → accept → gossip option
    - `handle_quest_detail()` → accept or complete
    - `accept_all_available()` → iterate gossip available quests
    - `turn_in_completable()` → iterate gossip active quests
    - `select_best_reward()` → choice with max vendor value
    - `handle_trainer()` → buy affordable spells
    - Returns action taken
  - **Verify:** `luac -p EaxAutoQuester/quest_interaction.lua`

- [x] 9. **Loot manager**
  - **File:** `EaxAutoQuester/loot_manager.lua`
  - **API Used:** `core.game_ui.*`, `core.input.loot_item()`, `close_loot()`
  - **Acceptance:**
    - `try_loot()` → if loot window open, loot all items
    - Gold first, then items
    - Close when done
    - 0.5s cooldown
  - **Verify:** `luac -p EaxAutoQuester/loot_manager.lua`

- [x] 10. **Vendor + repair manager**
  - **File:** `EaxAutoQuester/vendor_manager.lua`
  - **API Used:** `core.inventory.*`, `core.game_ui.get_vendor_item_info()`, `core.input.repair_all_items()`, `buy_item()`
  - **Acceptance:**
    - `handle_vendor()` → repair, sell junk, buy quest items
    - `should_repair()` → check repair cost > 0
    - `should_sell_junk()` → grey items in bags
  - **Verify:** `luac -p EaxAutoQuester/vendor_manager.lua`

- [x] 11. **Combat helper (non-rotation)**
  - **File:** `EaxAutoQuester/combat_helper.lua`
  - **API Used:** `core.input.set_target()`, `core.object_manager.*`
  - **Acceptance:**
    - `target_and_tag_nearest()` → set target for EaxRotations
    - `is_current_target_valid()` → alive, enemy, in range check
    - `use_quest_item_on_target(item_id)` → use quest item
    - No rotation API usage
  - **Verify:** `luac -p EaxAutoQuester/combat_helper.lua`

### Wave 4: State Machine + Integration

- [x] 12. **Quest state machine**
  - **Files:** `EaxAutoQuester/quest_state.lua` (+ update `main.lua`)
  - **API Used:** All sub-modules
  - **Acceptance:**
    - **IDLE**: Read Zygor step → no step → WAITING; frame open → INTERACT; immediate goal → DO_ACTION; else → NAV
    - **NAV**: Navigate to waypoint → arrived → IDLE; failed 3x → log → IDLE; stuck → pause → retry
    - **INTERACT**: Delegate to quest_interaction → frame closed → IDLE
    - **DO_ACTION**: Execute goal type → action done → IDLE
    - **WAITING**: Recheck Zygor every 3s → IDLE
    - All state fields nil-guarded (Pattern 4)
    - Debug logging on state transitions when enabled
    - Runs once per tick (no busy loops)
  - **Verify:** `luac -p EaxAutoQuester/quest_state.lua`

### Wave FINAL: Validation

- [x] F1. **Syntax validation**
  - **Verify:** `Get-ChildItem -Path EaxAutoQuester -Recurse -Filter '*.lua' | ForEach-Object { luac -p $_.FullName }` — all pass
- [x] F2. **Structure validation**
  - **Verify:** All 12 files exist, all LSP diagnostics zero errors
- [x] F3. **Logic audit**
  - **Verify:** No unguarded menu/widget access (Pattern 1), no sqrt distance (Pattern 3), static table reuse (Pattern 4), no banned APIs

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| SentinelNavClient unavailable | Cannot navigate | Fallback to `simple_movement`, log warning |
| Zygor not installed | No guide data | Graceful degradation: WAITING state + message |
| Questie not installed | No objective locations | Use Zygor data only |
| Frame timing (gossip/quest) | Missed interaction | Poll every tick, retry loop |
| EaxRotations handles combat separately | Kill goals incomplete | Tag + wait; user must have rotation enabled |
| Coord conversion fails | Wrong nav destination | Fallback to nearest known NPC position |

---

## Commit Strategy

One commit per Wave:
```
feat(auto-quest): Wave 1 - foundation (main, utils, menu)
feat(auto-quest): Wave 2 - readers + navigation
feat(auto-quest): Wave 3 - world interaction modules
feat(auto-quest): Wave 4 - state machine integration
feat(auto-quest): final validation
```
