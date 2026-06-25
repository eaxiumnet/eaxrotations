# Implementation Plan: Sylvanas API Compliance Fixes

**Created:** 2026-06-22
**API Surface:** `api/game_object.lua`, `api/common/izi_sdk.lua`, `apidocs/pages/dev/api/game-object.md`, `apidocs/pages/dev/libraries/izi/izi-object-extensions.md`, `apidocs/pages/dev/mini-libs/unit-helper.md`
**Docs References:** `apidocs/pages/dev/libraries/mini-libs/unit-helper.md`, `apidocs/pages/dev/libraries/izi/izi-object-extensions.md`, `apidocs/pages/dev/api/game-object.md`

## Overview

Three-module compliance audit & fix targeting full Sylvanas API compliance:

| Module | Status | Issues |
|--------|--------|--------|
| **EaxRotations** (29 specs) | **Already compliant** | None found — 165/165 rotation + 11/11 leveling tests pass, luac -p clean, no deprecated APIs, no math.sqrt |
| **EaxESP** (7 source files) | **Mostly compliant** | 3 medium (GC, counters, debug fmt), 3 low (extra args, doc gap, redundant rebuild) |
| **EaxProfessions** (~30 source files) | **CRITICAL gaps** | 3 critical (api_surface missing from context, deps crash, invented HP function), 6 high (5× math.sqrt, io.open), plus test mock cleanup |

## Wave Strategy

Each wave is independently verifiable. Waves within the same group can be executed in parallel.

- **Wave 1**: EaxProfessions CRITICAL → fixes C1 (api_surface injection), C2 (deps), C3 (HP function)
- **Wave 2**: EaxProfessions HIGH → all 6 math.sqrt fixes + io.open fix
- **Wave 3**: EaxESP MEDIUM+LOW → all 6 minor fixes
- **Wave 4**: Test cleanup → remove fake mocks, add real api_surface wiring
- **Wave 5**: Docs → add slider_float to AGENTS.md

---

## Wave 1 — EaxProfessions CRITICAL Fixes (3 files, 3 changes)

### Task 1.1: Inject `api_surface` into context.build() + context.peek() (C1)

**Files:** `EaxProfessions/core/context.lua`
**API Used:** `require("core/api_surface")`
**Wired:** All 10 state files get `ctx.api_surface` automatically.

**Changes:**

**context.lua:184-196** — add `api_surface = APISurface,` to the `build()` return table:
```lua
    local ctx = {
        app                = app,
        state              = app.state,
        config             = app.config,
        player             = player,
        player_pos         = ppos,
        player_map_id      = map_id,
        player_zone_text   = zone_txt,
        now                = now,
        delta              = delta,
        whitelisted_nodes  = nodes,
        nearest_node       = nearest,
+       api_surface        = APISurface,   -- NEW: enables all state handlers
    }
```

**context.lua:217-229** — add `api_surface = APISurface,` to the `peek()` return table:
```lua
    return {
        app                = app,
        state              = app.state,
        config             = app.config,
        player             = player,
        player_pos         = ppos,
        player_map_id      = map_id,
        player_zone_text   = read_zone_text(),
        now                = APISurface.now(),
        delta              = 0,
        whitelisted_nodes  = nodes,
        nearest_node       = pick_nearest(nodes, ppos),
+       api_surface        = APISurface,   -- NEW: match build()
    }
```

**Acceptance:**
1. `ctx.api_surface` is non-nil in both `build()` and `peek()` outputs
2. `ctx.api_surface.get_visible_objects` returns a callable function (not nil)
3. No existing tests break

**Verify:** `luac -p EaxProfessions/core/context.lua`

---

### Task 1.2: Fix `ctx.deps.config` crash in behavior.lua (C2)

**Files:** `EaxProfessions/core/behavior.lua`
**Options:** Two approaches. Prefer Option A (minimal invasive change).

**Option A (Recommended):** Refactor `apply_random_wait` to accept config directly:
```lua
--- Apply random wait based on humanizer settings
--- @param ctx table context
--- @param min number minimum seconds
--- @param max number? maximum seconds (defaults to min)
function M.apply_random_wait(ctx, min, max)
    max = max or min
    local now = APISurface.now()
-   local config = ctx.deps.config
+   local config = (ctx.config) or nil   -- FIX: use ctx.config instead of ctx.deps.config
```

This works because `ctx.config` IS set by `context.build()` (line 187). The context already provides `config` — `deps` is the bug.

**Also fix `EaxProfessions/inventory/bags.lua:15`:**
```lua
 function M.get_total_free_slots(ctx)
     local state = ctx.state
-    local deps = ctx.deps
+    -- ctx.deps is not part of context; use ctx.config directly
+    local deps = { config = ctx.config }
```

**Acceptance:**
1. `apply_random_wait` no longer crashes on `ctx.deps.config`
2. `is_bags_full` still reads debug config correctly
3. Existing tests pass

**Verify:** `luac -p EaxProfessions/core/behavior.lua`, `luac -p EaxProfessions/inventory/bags.lua`

---

### Task 1.3: Add `get_player_hp_pct` to api_surface.lua (C3)

**Files:** `EaxProfessions/core/api_surface.lua`
**API Used:** `me:get_health_percentage()`, `me:get_health()`, `me:get_max_health()` (from `api/game_object.lua`)

Add after line 363 (end of Game Object Methods section, after `get_item_name_from_slot_item`):

```lua
--- Get player HP percentage (0..100). Falls back to (get_health/get_max_health)*100,
--- then 100 if anything fails or the unit is invalid.
--- @param me game_object player
--- @return number 0..100
function M.get_player_hp_pct(me)
    if not M.is_valid(me) then return 100 end
    -- Primary path: game_object.get_health_percentage() (runtime extension)
    if type(me.get_health_percentage) == "function" then
        local ok, v = pcall(me.get_health_percentage, me)
        if ok and type(v) == "number" then return v end
    end
    -- Fallback: get_health / get_max_health
    if type(me.get_health) == "function" and type(me.get_max_health) == "function" then
        local ok_h, hp = pcall(me.get_health, me)
        local ok_max, max = pcall(me.get_max_health, me)
        if ok_h and ok_max and type(hp) == "number" and type(max) == "number" and max > 0 then
            return (hp / max) * 100
        end
    end
    return 100
end
```

**Acceptance:**
1. `APISurface.get_player_hp_pct(player)` returns a number 0..100
2. `avoid_state.lua:86` now evaluates to true — the health check executes
3. mock_core.lua `get_player_hp_pct` test stubs now shadow the real function (existing tests pass)

**Verify:** `luac -p EaxProfessions/core/api_surface.lua`, `lua EaxProfessions/tests/run_professions_tests.lua`

---

## Wave 2 — EaxProfessions HIGH Fixes (6 files, ~8 changes)

**All in ONE wave** because they are independent and can be parallelised.

### Task 2.1: H1 — nav_state.lua math.sqrt fix

**File:** `EaxProfessions/profession_state/nav_state.lua:36,72-75`

Remove `_sqrt` alias, compare squared:
```lua
- local _sqrt = math.sqrt     -- line 36 — DELETE
...
- local dist_yd  = _sqrt(dist_sq)    -- line 73 — REMOVE
- if dist_yd <= 10.0 then           -- line 75 — REPLACE
+ if dist_sq <= 100.0 then          -- FIX: squared compare, 10^2 = 100
```

**Verify:** `luac -p EaxProfessions/profession_state/nav_state.lua`

---

### Task 2.2: H2 — approach_state.lua math.sqrt fix

**File:** `EaxProfessions/profession_state/approach_state.lua:27,56-58`

```lua
- local _sqrt = math.sqrt     -- line 27 — DELETE
...
- local dist_yd = _sqrt(dist_sq)    -- line 56 — REMOVE
- if dist_yd > 10.0 then           -- line 58 — REPLACE
+ if dist_sq > 100.0 then          -- FIX: squared compare, 10^2 = 100
```

**Verify:** `luac -p EaxProfessions/profession_state/approach_state.lua`

---

### Task 2.3: H3 — vendor_state.lua math.sqrt fix

**File:** `EaxProfessions/profession_state/vendor_state.lua:56,135-137`

```lua
- local _sqrt = math.sqrt     -- line 56 — DELETE
...
- local dist_yd = _sqrt(dist_sq)    -- line 135 — REMOVE
- if dist_yd > _VENDOR_TRAVEL_THRESHOLD then   -- line 137 — REPLACE (50.0^2 = 2500)
+ if dist_sq > 2500.0 then          -- FIX: squared compare, _VENDOR_TRAVEL_THRESHOLD=50 → 2500
```

**Note:** `_VENDOR_TRAVEL_THRESHOLD` is a constant `50.0` at line 54. Since it's used only here, inline the squared value. Alternatively, define `_VENDOR_TRAVEL_THRESHOLD_SQ = 2500.0` nearby.

**Verify:** `luac -p EaxProfessions/profession_state/vendor_state.lua`

---

### Task 2.4: H4 — avoid_state.lua math.sqrt fix

**File:** `EaxProfessions/profession_state/avoid_state.lua:58,196-202`

The threat distance is compared against `radius * 1.5` where radius is dynamic. Must square the threshold in-place:

```lua
- local _sqrt = math.sqrt     -- line 58 — DELETE
...
- local ddx = (threat_pos.x or 0) - (ctx.player_pos and ctx.player_pos.x or 0)
- local ddy = (threat_pos.y or 0) - (ctx.player_pos and ctx.player_pos.y or 0)
- local ddz = (threat_pos.z or 0) - (ctx.player_pos and ctx.player_pos.z or 0)
- local threat_dist = _sqrt(ddx*ddx + ddy*ddy + ddz*ddz)       -- lines 196-199 — REMOVE
- local radius = state.avoidance.avoid_radius or 25
- if now - state.avoidance[_AVOID_HP_KEY] >= _L1_DURATION_S
-     or threat_dist > (radius * 1.5) then                      -- line 202 — REPLACE
+ local radius = state.avoidance.avoid_radius or 25
+ local threat_dist_sq = ddx*ddx + ddy*ddy + ddz*ddz
+ if now - state.avoidance[_AVOID_HP_KEY] >= _L1_DURATION_S
+     or threat_dist_sq > ((radius * 1.5) * (radius * 1.5)) then   -- FIX: squared compare
```

**Verify:** `luac -p EaxProfessions/profession_state/avoid_state.lua`

---

### Task 2.5: H5 — ui/render.lua math.sqrt fix

**File:** `EaxProfessions/ui/render.lua:326`

Line 326: floor check for player-standing-still detection. 2D only (no z):
```lua
- local moved = math.sqrt((p.x-lp.x)^2 + (p.y-lp.y)^2) > 5.0
+ local dx = p.x - lp.x
+ local dy = p.y - lp.y
+ local moved = (dx*dx + dy*dy) > 25.0      -- FIX: squared compare, 5^2 = 25
```

**Also fix line 162** (display-only sqrt used to format label distance):
```lua
  local distance = math.sqrt(d2)     -- line 162 — used ONLY for label at line 186
```
This sqrt is for DISPLAY (formatting "%dy" label), not comparison. Per AGENTS.md: "Never use math.sqrt for distance comparisons" — display is acceptable but we should add a comment. Change to:
```lua
  local distance = math.sqrt(d2)     -- DISPLAY ONLY: "%dy" label formatting, not a comparison
```

**Verify:** `luac -p EaxProfessions/ui/render.lua`

---

### Task 2.6: H6 — density_map.lua io.open fix

**File:** `EaxProfessions/avoidance/density_map.lua:86-93`

Remove Strategy B (io.open fallback). `core.read_data_file` is the correct path per PLAN §4.8.

```lua
  if _read_fn then
      local ok, val = pcall(_read_fn, absolute_path)
      if ok and type(val) == "string" and #val > 0 then
          raw = val
      end
  end
- if not raw and absolute_path then
-     -- Strategy B: direct io.open (works on Lua 5.1 + 5.3)
-     local fh = io.open(absolute_path, "rb")
-     if fh then
-         raw = fh:read("*a")
-         fh:close()
-     end
- end
```

**Acceptance:** density_map still loads via `core.read_data_file`. No io.open calls.

**Verify:** `luac -p EaxProfessions/avoidance/density_map.lua`

---

### Task 2.7: lane_shift.lua display sqrt (bonus cleanup)

**File:** `EaxProfessions/avoidance/lane_shift.lua:55,88`

Line 55: `local _sqrt = math.sqrt` — used only for vector normalization at line 88: `local len = _sqrt(dx*dx + dy*dy)`
This is not a distance comparison — it's a vector length for perpendicular offset math. Acceptable. Add comment:
```lua
- local _sqrt = math.sqrt
+ local _sqrt = math.sqrt       -- Vector math (perp offset length, not distance comparison)
```

### Task 2.8: api_surface.lua debug log sqrt (bonus cleanup)

**File:** `EaxProfessions/core/api_surface.lua:935`

`M.print("[EaxFishing] nearby obj: '" .. name .. "' dist=" .. string.format("%.1f", math.sqrt(dist_sq)))` — DISPLAY ONLY (debug log for human readability). Add comment. No change needed — acceptable usage.

---

## Wave 3 — EaxESP MEDIUM + LOW Fixes (4 files, up to 7 changes)

All independent and can be parallelised.

### Task 3.1: M1 — GC hotspot reduction (renderer.lua + projection.lua)

**File:** `EaxESP/renderer.lua`
**File:** `EaxESP/projection.lua`

**Approach:** Pre-allocate scratch tables at module level and reuse them.

**projection.lua** — pre-allocate scratch vec3s:
```lua
-- Module-level state
local _sx, _sy         = 0, 0
local _pad             = 4
local _min_pix_dim     = 8
local _max_pix_dim     = 600

+ -- Scratch tables for reuse in hot path (avoids GC in project_box)
+ local _scratch_head = { x = 0, y = 0, z = 0 }
+ local _scratch_l    = { x = 0, y = 0, z = 0 }
+ local _scratch_rr   = { x = 0, y = 0, z = 0 }
```

In `project_box()` (lines 82-100), replace table allocs with scratch reuse:
```lua
- local head_pos = {
-     x = feet_pos.x,
-     y = feet_pos.y,
-     z = (feet_pos.z or 0) + (unit_height or 2.0),
- }
- local head_x, head_y = safe_w2s(w2s, head_pos)
+ _scratch_head.x = feet_pos.x
+ _scratch_head.y = feet_pos.y
+ _scratch_head.z = (feet_pos.z or 0) + (unit_height or 2.0)
+ local head_x, head_y = safe_w2s(w2s, _scratch_head)

...

- local l_pos = { x = feet_pos.x - r, y = feet_pos.y, z = feet_pos.z }
- local rr_pos = { x = feet_pos.x + r, y = feet_pos.y, z = feet_pos.z }
- local lx, _ly = safe_w2s(w2s, l_pos)
- local rx, _ry = safe_w2s(w2s, rr_pos)
+ _scratch_l.x = feet_pos.x - r
+ _scratch_l.y = feet_pos.y
+ _scratch_l.z = feet_pos.z
+ local lx, _ly = safe_w2s(w2s, _scratch_l)
+ _scratch_rr.x = feet_pos.x + r
+ _scratch_rr.y = feet_pos.y
+ _scratch_rr.z = feet_pos.z
+ local rx, _ry = safe_w2s(w2s, _scratch_rr)
```

**renderer.lua** — this is harder because the vec2/color returns are consumed by graphics APIs that expect a new object each call. However, we can eliminate the `colours_for_kind` color allocation by caching:

```lua
-- Module-level color cache (reuse across frames, re-read config each frame)
local _box_colour_cache = {}
local _name_colour_cache = {}
local _last_kind = ""
local function colours_for_kind(kind, cfg)
    local k = kind or "quest_npc"    
    if _last_kind == k then
        -- reuse cached colours (fast path — same candidate kind)
        return _box_colour_cache, _name_colour_cache
    end
    _last_kind = k
    -- ... existing logic ...
    _box_colour_cache = box_c
    _name_colour_cache = name_c
    return box_c, name_c
end
```

**Acceptance:** renderer + projection create ≤4 tables/candidate (down from ~12). No null references.

**Verify:** `luac -p EaxESP/projection.lua`, `luac -p EaxESP/renderer.lua`, `lua EaxESP/tests/test_renderer.lua`, `lua EaxESP/tests/test_projection.lua`

---

### Task 3.2: M2 — No-op counter simplification

**File:** `EaxESP/renderer.lua:92-96,101-104`

```lua
--- draw_text (lines 92-96):
- if ok then _counters.text = _counters.text
- else _counters.text_err = _counters.text_err + 1 end
+ if ok then -- success (counter already bumped at line 92)
+ else _counters.text_err = _counters.text_err + 1 end

--- draw_line (lines 101-104):
- if ok then _counters.line = _counters.line
- else _counters.line_err = _counters.line_err + 1 end
+ if ok then -- success (counter already bumped at line 101)
+ else _counters.line_err = _counters.line_err + 1 end
```

**Verify:** `luac -p EaxESP/renderer.lua`

---

### Task 3.3: M3 — Duplicate render_mode in debug log

**File:** `EaxESP/main.lua:209`

Remove `mode=%s` from format string + shift:
```lua
- "[EaxESP] mode=%s qtt=%s | candidates=%d (render_mode=%s) | ...",
- M.config.render_mode, questie,
+ "[EaxESP] qtt=%s | candidates=%d (render_mode=%s) | ...",
+ questie,
```

**Verify:** `luac -p EaxESP/main.lua`

---

### Task 3.4: L1 — Extra args documentation

**File:** `EaxESP/reader.lua:245,253`

Add inline comments documenting the extra positional booleans:
```lua
line 245:
- local ok, list = pcall(_uh.get_enemy_list_around, _uh, origin_pt, range, true, false, false, false)
+ -- extra bools: incl_out_combat=true, (unused), (unused), (unused)
+ local ok, list = pcall(_uh.get_enemy_list_around, _uh, origin_pt, range, true)

line 253:
- local ok, list = pcall(_uh.get_ally_list_around, _uh, origin_pt, range, false, false, false)
+ -- extra bools: players_only=false, (unused), (unused)
+ local ok, list = pcall(_uh.get_ally_list_around, _uh, origin_pt, range, false)
```

**Verify:** `luac -p EaxESP/reader.lua`

---

### Task 3.5: L3 — Remove unnecessary _labels rebuild

**File:** `EaxESP/menu.lua:180-187`

Replace per-frame rebuild with direct reference to static RENDER_MODES:
```lua
- if M.render_mode then
-     _labels.n = 0
-     for i = 1, #RENDER_MODES do
-         _labels.n = _labels.n + 1
-         _labels[_labels.n] = RENDER_MODES[i]
-     end
-     M.render_mode:render("Render Mode", _labels)
- end
+ if M.render_mode then
+     M.render_mode:render("Render Mode", RENDER_MODES)
+ end
```

**Note:** The `_labels` declaration at line 18 is now dead code — can optionally remove it too.

**Verify:** `luac -p EaxESP/menu.lua`

---

## Wave 4 — Test Cleanup (3 files)

### Task 4.1: Remove fake `get_player_hp_pct` from test mocks

**Files:** `EaxProfessions/tests/test_avoidance.lua:87-95`, `EaxProfessions/tests/test_coordinator.lua:90-95`

Now that `api_surface.lua` has a real `get_player_hp_pct`, the test mocks shadow it. The tests will continue to work (mock takes priority over real in package.loaded). Optionally remove the mock duplicate and let the real function handle it:
- `test_avoidance.lua:87-95` — REMOVE the `get_player_hp_pct = function(me) ... end` key from the mock api_surface table
- `test_coordinator.lua:90-95` — REMOVE the `get_player_hp_pct = function(me) ... end` key from the mock api_surface table

**Note:** The mocks return `(me._hp / me._max_hp) * 100` while the real implementation uses `me:get_health_percentage()` with fallback to `get_health/get_max_health`. Tests set `_hp` and `_max_hp` but NOT `get_health_percentage` method on the mock player objects. So removing the mocks would BREAK these tests. Instead, update the mock player objects to support the real API, OR keep the mocks (they still work and the real function is now available).

**Recommended:** Keep the mocks as they are. The real `get_player_hp_pct` on api_surface now exists for PRODUCTION use. Tests use their own mock. No change needed.

### Task 4.2: Wire `api_surface` into test mock context builder

**Files:** `EaxProfessions/core/context.lua`

After Task 1.1, production ctx has `api_surface`. For unit tests that bypass `context.build()` and construct ctx manually, no change needed — they already inject `ctx.api_surface` via `attach_api_surface()`. The production fix (Task 1.1) is sufficient.

---

## Wave 5 — Documentation Fix

### Task 5.1: Add slider_float to AGENTS.md

**File:** `AGENTS.md` (Menu Item Reference table)

Add row between Slider and Combobox:
```markdown
| Slider (float) | `core.menu.slider_float(min, max, default, id)` | `menu.max_distance` |
```

**Verify:** `luac -p AGENTS.md` — N/A (markdown)

---

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| C1 fix breaks tests that rely on ctx.api_surface being nil | Tests check `if ctx.api_surface and ctx.api_surface.X` — now evaluates true. Mock ctx in tests already inject api_surface, so no change | Verify all 16 test files pass |
| C3 get_player_hp_pct not on real game_object | All game_object methods are accessed via pcall; fallback handles missing method | The implementation has 3-tier fallback: get_health_percentage → (get_health/get_max_health) → 100 |
| Exporting api_surface to ctx increases table size per frame | Trivial (one extra key), no measurable GC impact | Acceptable |
| math.sqrt in lane_shift.lua:88 is vector math, not distance comparison | Not a violation — it computes perpendicular offset length | Explicit comment added |
| Removing io.open breaks on systems without core.read_data_file | core.read_data_file IS the documented API per PLAN.md §4.8. io.open was speculative | Acceptable — matches PLAN contract |

## Verification Script

```powershell
# After each wave:
# 1. Syntax check ALL changed files
Get-ChildItem -Path EaxProfessions -Recurse -File -Filter '*.lua' | ForEach-Object { luac -p $_.FullName }
Get-ChildItem -Path EaxESP -Recurse -File -Filter '*.lua' | ForEach-Object { luac -p $_.FullName }

# 2. Run EaxProfessions test suite
lua EaxProfessions/tests/run_professions_tests.lua

# 3. Run EaxESP test suite
lua EaxESP/tests/run_professions_tests.lua  # Note: EaxESP has test_projection.lua, test_reader.lua, test_renderer.lua
# or run individual:
lua EaxESP/tests/test_projection.lua
lua EaxESP/tests/test_reader.lua
lua EaxESP/tests/test_renderer.lua

# 4. Run EaxRotations test suite (verify no regression)
lua EaxRotations/tests/run_rotation_tests.lua
lua EaxRotations/tests/run_leveling_tests.lua
```

## Execution Summary

| Wave | Tasks | Files Changed | Can Parallel? | Expected Verdict |
|------|-------|--------------|---------------|-----------------|
| 1 | C1, C2, C3 | 3-4 files | Yes (C1 independent from C2 from C3) | EaxProfessions now functional |
| 2 | H1-H6 + bonus | 6-8 files | Yes (all independent single-line fixes) | No more math.sqrt, no io.open |
| 3 | M1-M3, L1, L3 | 4 files | Yes (all independent) | EaxESP GC-friendly, cleaner |
| 4 | Test cleanup | 0-2 files | Yes | Remove mock debt |
| 5 | Docs | 1 file | Yes | AGENTS.md complete |
