# EAXFishing v2.4.0 — 12 Feature Build

**Started**: 2026-07-05
**Status**: IN PROGRESS

## Goal
Implement all 12 fishing bot features from the roadmap in dependency order.

## Build Order (12 features, ~6 commits)

### Commit 1: Auto-open containers + Mr. Pinchy handler
- `fishing/containers.lua` — open clams, chests, lockboxes between casts
- `fishing/mr_pinchy.lua` — auto-use Mr. Pinchy charges, alert on Crawdad
- Wire both into engine tick (between loot and cook)
- Menu: `auto_open_containers` (default ON), `auto_pinchy` (default ON)
- State: `state.containers` + `state.pinchy`
- HUD: show opened count + pinchy charges remaining

### Commit 2: Auto-sell junk + auto-delete worthless
- `inventory/auto_sell.lua` — sell gray items when vendor window open
- `inventory/auto_delete.lua` — delete user-specified junk when bags full
- Menu: `auto_sell_junk` (default OFF), `auto_delete_junk` (default OFF)
- State: `state.autosell` + `state.autodelete`
- HUD: show items sold/deleted count

### Commit 3: Pool depletion detection + cast reliability telemetry
- Engine: track casts per pool, detect depletion (no catch in N casts)
- Engine: track failed vs successful casts, show success rate in HUD
- State: `state.fishing.casts_at_pool`, `state.fishing.cast_success_count`
- Menu: `pool_depletion_threshold` (default 5)
- HUD: cast success rate + pool depletion status

### Commit 4: Fish-specific targeting + daily quest tracker
- `fishing/quest_tracker.lua` — detect active daily fishing quest, target quest pools
- Pool ranker: filter by target fish when configured
- Menu: `target_fish` (combobox), `auto_quest_fish` (default OFF)
- State: `state.quest`
- HUD: quest progress

### Commit 5: Whisper/AFK responder + auto-hearth
- `core/responder.lua` — auto-respond to whispers with configurable message
- `navigation/hearth.lua` — hearth to inn, vendor, return
- Menu: `auto_respond` (default OFF), `responder_message`, `auto_hearth_full` (default OFF)
- State: `state.responder` + `state.hearth`
- HUD: whispers responded to

### Commit 6: Auto-relog + weather/time awareness
- `core/relog.lua` — detect disconnect, relog, resume
- `core/conditions.lua` — time-of-day fish scheduling
- Menu: `auto_relog` (default OFF), `night_fishing_only` (default OFF)
- State: `state.relog` + `state.conditions`
- HUD: connection status + time window

## Testing
- Each commit: luac -p + run_fishing_tests.lua + 219+13 rotation tests
- Add new test suites for containers, mr_pinchy, auto_sell, quest_tracker
