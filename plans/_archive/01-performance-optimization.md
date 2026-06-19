# Plan: Performance Optimization — Reduce Lua/Game Impact

**Problem**: EaxRotations runs at 100% Lua impact and 2200% gameimpact. The rotation dispatcher runs every single frame (~60fps) with no frame-skip throttling, doing a massive `build_context()` + schema widget sync + strategy dispatch every 16ms.

**Root Cause**: `core.register_on_update_callback` fires every frame (docs: "on each frame update"). There is zero frame-skip throttling anywhere in the codebase. `build_context()` is ~420 lines of per-frame work calling dozens of engine APIs, many multiple times.

---

## Phase 0: Documentation Discovery (COMPLETE)

### Sources Consulted
- `apidocs/pages/dev/api/core.md` — `register_on_update_callback` fires every frame; `cpu_time()` returns ns; `game_time()` returns ms since game start
- `main_sylvanas.lua:354-778` — `build_context()` full source
- `main.lua:703-850` — `on_update()` full source
- `main.lua:564-584` — `sync_quick_toggles()` and `sync_playstyle_control()` source
- `main.lua:767-796` — schema widget sync loop source
- `core_sylvanas.lua` — existing throttling patterns (settings cache, pvp_zone 5s, visible 100ms, party_ally 100ms)

### Allowed APIs
- `core.register_on_update_callback(fn)` — fires every frame, no rate control
- `core.cpu_time()` — ns precision for profiling
- `core.game_time()` — ms since game start
- `core.time()` — seconds since injection
- `core.delta_time()` — ms since last frame

### Existing Throttling Patterns (follow these)
| Pattern | File | Interval |
|---------|------|----------|
| `throttled_enemies()` | main_sylvanas.lua:281-293 | 100ms |
| `_cached_tank_alive` | main_sylvanas.lua:534-577 | 500ms |
| `NS.is_pvp_zone()` | core_sylvanas.lua:3948-3959 | 5s |
| `NS.get_setting()` cache | core_sylvanas.lua:1205 | TTL-based |
| `visible` enemies | core_sylvanas.lua:4469 | 100ms |
| `party_ally` | core_sylvanas.lua:4676 | 100ms |
| `schema_widget_last_values` | main.lua:780 | value-change |

### Anti-patterns to Avoid
- Do NOT use `os.clock()` or `os.time()` — banned in Sylvanas sandbox
- Do NOT add `math.random()` for jitter — deterministic only
- Do NOT remove existing throttles (they prevent API spam)
- Do NOT cache `GetPartyMembers()` result across frames without invalidation (party composition can change)

---

## Phase 1: Frame-Skip Throttling in `main.lua`

### What
Add a frame counter to `on_update()` that skips the full rotation dispatch on most frames, only running the lightweight menu sync every frame.

### Where
`main.lua` — the `on_update()` function at line 703.

### Implementation

```lua
-- At module level, near other local state (around line 181):
local _frame_counter = 0
local ROTATION_FRAME_SKIP = 3  -- Run rotation every 3rd frame (~20 ticks/sec at 60fps)

-- In on_update(), wrap the rotation call (around line 844):
_frame_counter = _frame_counter + 1
if _frame_counter >= ROTATION_FRAME_SKIP then
    _frame_counter = 0
    if framework_main and framework_main.on_rotation_update then
        local success, err = pcall(framework_main.on_rotation_update)
        if not success then
            core.log_error("[EaxRotations] Rotation error: " .. tostring(err))
        end
    end
end
```

The menu sync (quick toggles, playstyle, schema widgets) still runs every frame — these are lightweight reads from menu widget memory, not engine API calls.

### Verification
- `luac -p main.lua` passes
- Rotation still fires, just at ~20Hz instead of 60Hz
- No change to rotation behavior (GCD is 1.5s, 20Hz is plenty)

### Anti-pattern Guards
- Do NOT skip the menu sync — settings must respond instantly to user input
- Do NOT use a time-based throttle (e.g. "run every 50ms") — frame-based is simpler and avoids timer drift
- Keep `_frame_counter` as a local, not a global

---

## Phase 2: Cache `GetPartyMembers()` Once Per Frame in `build_context()`

### What
`GetPartyMembers()` is called 4 times per frame in `build_context()` (lines 541, 558, 646, 682). Each call is an engine-level party scan. Cache the result once at the top of the group-related section and reuse it.

### Where
`main_sylvanas.lua` — `build_context()` function.

### Implementation
Replace the 4 separate `NS.GetPartyMembers()` calls with a single cached reference:

```lua
-- After line 531 (_context.is_solo = not _context.is_group), add:
local _party_members = nil
if _context.is_group then
    _party_members = NS.GetPartyMembers and NS.GetPartyMembers() or nil
end
```

Then replace:
- Line 541: `local party = NS.GetPartyMembers and NS.GetPartyMembers() or nil` → `local party = _party_members`
- Line 558: same → `local party = _party_members`
- Line 646: `local party = NS.GetPartyMembers and NS.GetPartyMembers() or nil` → `local party = _party_members`
- Line 682: same → `local party = _party_members`

### Verification
- `luac -p main_sylvanas.lua` passes
- All 4 party iteration blocks still work identically
- Party member changes are reflected next frame (acceptable)

### Anti-pattern Guards
- Do NOT cache across frames — party composition can change mid-frame (player leaves group)
- Do NOT hoist the cache outside `build_context()` — it must be fresh each frame

---

## Phase 3: Cache `throttled_enemies()` Once Per Frame in `build_context()`

### What
`throttled_enemies()` is called 3-4 times per frame (lines 397→296, 639, 667, 707). While it has a 100ms internal cache, calling it repeatedly still has overhead (function call, cache check, table return). Cache the result once.

### Where
`main_sylvanas.lua` — `build_context()` function.

### Implementation
```lua
-- After line 397 (local count = throttled_enemies_count()), add:
local _enemies_cache = throttled_enemies()
```

Then replace:
- Line 639: `_context.enemies = throttled_enemies() or {}` → `_context.enemies = _enemies_cache or {}`
- Line 667: `local enemies = throttled_enemies()` → `local enemies = _enemies_cache`
- Line 707: `local enemies = throttled_enemies()` → `local enemies = _enemies_cache`

### Verification
- `luac -p main_sylvanas.lua` passes
- All enemy iteration blocks work identically

### Anti-pattern Guards
- Do NOT remove the 100ms internal throttle in `throttled_enemies()` — it's still needed for the `GetEnemiesInRange` API call
- Do NOT cache enemies across frames

---

## Phase 4: Throttle Schema Widget Sync to Every N Frames

### What
The schema widget sync loop (main.lua:767-796) iterates all widgets every frame calling `widget.sync()` which does 1-3 `pcall()`s each. With 30-60 widgets, that's 30-180 pcall()s per frame. Throttle to match the rotation frame skip.

### Where
`main.lua` — the schema widget sync loop at line 767.

### Implementation
```lua
-- Change line 767 from:
for key, widget in pairs(schema_widgets) do
-- To:
if _frame_counter == 0 then  -- Only sync widgets when rotation runs
    for key, widget in pairs(schema_widgets) do
        -- ... existing sync code ...
    end
end
```

The `_frame_counter` variable is already incremented in Phase 1. When `_frame_counter == 0`, the rotation is about to run, so sync widgets just before it.

### Verification
- `luac -p main.lua` passes
- Settings still sync, just at 20Hz instead of 60Hz (user can't perceive the difference)

### Anti-pattern Guards
- Do NOT skip `sync_quick_toggles()` and `sync_playstyle_control()` — these must run every frame for responsive keybinds
- Only throttle the schema widget loop (settings that change rarely)

---

## Phase 5: Reduce `safe()` pcall Overhead for Known-Good APIs

### What
Every API call in `build_context()` goes through `safe()` which wraps in `pcall()`. For APIs that are known to exist (cached at module load), this is redundant overhead. Cache the function references at module load and call them directly.

### Where
`main_sylvanas.lua` — module-level caching (top of file, around lines 1-55).

### Implementation
Add cached references for the most frequently called APIs:

```lua
-- Near existing module-level locals (around line 55):
local _time_now = NS.time_now
local _game_time_ms = NS.game_time_ms
local _unit_health_pct = NS.unit_health_pct
local _mana_pct = NS.mana_pct
local _power_current = NS.power_current
local _buff_up = NS.buff_up
local _debuff_remains = NS.debuff_remains
local _debuff_up = NS.debuff_up
local _unit_alive = NS.unit_alive
local _get_party_members = NS.GetPartyMembers
local _get_focus = NS.GetFocus
local _get_pet = NS.GetPet
local _get_player_stance = NS.get_player_stance
local _is_hostile_unit = NS.is_hostile_unit
local _is_pvp_zone = NS.is_pvp_zone
local _is_in_party = NS.is_in_party
local _player_control_locked = NS.player_control_locked
local _has_breakable_cc_nearby = NS.has_breakable_cc_nearby
local _get_debuff_stacks = NS.get_debuff_stacks
local _same_unit = NS.same_unit
local _gcd_remains = NS.gcd_remains
local _get_setting = NS.get_setting
```

Then replace all `NS.xxx()` calls in `build_context()` with the cached `_xxx()` versions.

### Verification
- `luac -p main_sylvanas.lua` passes
- All tests pass (they mock NS functions, not local aliases — need to verify)

### Anti-pattern Guards
- Do NOT cache APIs that may not exist at load time (e.g., optional modules loaded via pcall)
- Do NOT cache `NS.safe_field` — it's a nil-guard pattern, not an API call
- Keep the `NS.xxx and NS.xxx()` nil-guard pattern for APIs that may be nil at runtime

---

## Phase 6: Verification

### Checklist
1. `luac -p` on all modified files (main.lua, main_sylvanas.lua)
2. `lua EaxRotations/tests/run_rotation_tests.lua` — all 111 rotation suites pass
3. `lua EaxRotations/tests/run_leveling_tests.lua` — all 11 leveling suites pass
4. Grep for any remaining `NS.GetPartyMembers()` calls in `build_context()` — should be 0 after Phase 2
5. Grep for any remaining `throttled_enemies()` calls in `build_context()` — should be 1 after Phase 3
6. Verify `_frame_counter` is used correctly (starts at 0, increments, resets at threshold)

### Expected Impact
- **Frame-skip (Phase 1)**: 3x reduction in rotation execution → ~33% Lua impact, ~733% gameimpact
- **Party cache (Phase 2)**: 4x reduction in party scans → significant in raids
- **Enemy cache (Phase 3)**: 3-4x reduction in enemy list fetches → moderate improvement
- **Widget sync throttle (Phase 4)**: 3x reduction in widget sync → moderate improvement
- **API caching (Phase 5)**: Eliminates pcall overhead for ~20 hot-path APIs → small but cumulative

Combined target: ~30-40% Lua impact, ~700-800% gameimpact (down from 100%/2200%).

---

## Execution Order

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
```

Each phase is independent except Phase 4 depends on `_frame_counter` from Phase 1. Phases 2, 3, and 5 can be done in parallel after Phase 1.
