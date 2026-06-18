# Implementation Plan: Rake PvE Builder + Claw Fallback

**Created:** 2026-06-12
**API Surface:** `NS.setting_bool`, `NS.setting_number`, `NS.debuff_remains`, `NS.spell_ready`, `NS.try_cast`, `NS.log`
**Docs References:** AGENTS.md Pattern 1 (menu nil guards), Pattern 7 (spell resolution caching), Pattern 9 (file requires)

## Overview

Port Rake PvE builder (`rake_pve_matches`) and Claw fallback (`claw_fallback_matches`) from the old feral rotation logic into `cat_sylvanas.lua`. These fill two gaps: Rake as a CP builder during PvE (not just PvP), and Claw as an energy dump when Shred is unavailable (not behind target).

## Key Discrepancy Note

- **RAKE_COST** = 35 in `cat_sylvanas.lua` (already defined). User wants 35. Match.
- **Claw spell data** in `class_sylvanas.lua` says `power_cost=40`, but **leveling code uses 45** and **user specifies 45**. Use `CLAW_COST = 45` per user spec.
- **RAKE_REFRESH_WINDOW** = 3.0 (already defined). User's `cat_rake_refresh_seconds` slider (default 3) maps to same concept but as user-configurable value.

## Current Priority Flow (ACTIONS table, lines 728-759)

```
... → MangleDebuff → MangleBuilder → ... → ShredOmen → Shred → MangleFiller → RakePvP → FaerieFireFeral
```

## Desired Priority Flow

```
... → MangleDebuff → RakePvE → MangleBuilder → ... → ShredOmen → Shred → MangleFiller → ClawFallback → RakePvP → FaerieFireFeral
```

## Files to Touch

| File | Change | Verify |
|------|--------|--------|
| `EaxRotations/classes/druid/schema_sylvanas.lua` | Add 2 cat settings | `luac -p` |
| `EaxRotations/classes/druid/cat_sylvanas.lua` | Add 2 match functions + ACTIONS entries + CLAW_COST + debug log update | `luac -p`, rotation tests, leveling tests |
| `EaxRotations/tests/test_cat_custom_matches.lua` | Add RakePvE + ClawFallback tests (optional enhancement) | `luac -p` |

## Task List

### Task 1: schema_sylvanas.lua — Add 2 new cat settings

**File:** `EaxRotations/classes/druid/schema_sylvanas.lua`
**Location:** Lines 57-58 (after `cat_energy_pooling`, before closing brace of cat section)

**Changes:**
1. Add `cat_use_rake` checkbox (default true) — line after `cat_energy_pooling`
2. Add `cat_rake_refresh_seconds` slider (min=1, max=10, default=3) — line after `cat_use_rake`

**Setting entries:**
```lua
{ key = "cat_use_rake", type = "checkbox", label = "Use Rake (PvE)", default = true, description = "Use Rake as a CP builder when target will live long enough for the bleed" },
{ key = "cat_rake_refresh_seconds", type = "slider", label = "Rake Refresh Seconds", min = 1, max = 10, default = 3, description = "Refresh Rake when remaining duration is at or below this value" },
```

**Acceptance:**
- Settings appear in cat menu section
- Default values: cat_use_rake=true, cat_rake_refresh_seconds=3

**Verify:** `luac -p EaxRotations/classes/druid/schema_sylvanas.lua`

---

### Task 2: cat_sylvanas.lua — Add CLAW_COST constant

**File:** `EaxRotations/classes/druid/cat_sylvanas.lua`
**Location:** After line 30 (`local RAKE_COST = 35`), add:
```lua
local CLAW_COST = 45
```

**Rationale:** Consistent with leveling_sylvanas.lua (uses 45) and user spec. Class data says 40 but all existing code uses 45.

**Verify:** `luac -p EaxRotations/classes/druid/cat_sylvanas.lua`

---

### Task 3: cat_sylvanas.lua — Add `rake_pve_matches()` function

**File:** `EaxRotations/classes/druid/cat_sylvanas.lua`
**Location:** After `mangle_debuff_matches()` (ends line 522), before `rip_matches()` (starts line 524)

**Function:**
```lua
local function rake_pve_matches(context, action)
    local state = build_state(context)
    if not state.target then return false end
    if NS.setting_bool(state.settings, "cat_use_rake", true) == false then return false end
    if (state.combo_points or 0) >= 5 then return false end
    if state.target_ttd > 0 and state.target_ttd < MIN_RAKE_TTD then return false end
    if state.rake_remains > (NS.setting_number(state.settings, "cat_rake_refresh_seconds", 3) or 3) then return false end
    if should_wait_for_tick(state, RAKE_COST) then return false end
    return true
end
```

**Logic:** Setting gate → CP < 5 (no waste) → TTD > 6s (bleed worth it) → Refresh when remains <= refresh_seconds → Energy check via should_wait_for_tick → Uses RAKE_COST=35

**Note:** Does NOT require `is_behind` (unlike vanilla Rake). Rake is usable from any angle.

**Acceptance:**
- Returns false when `cat_use_rake = false` in settings
- Returns false when CP >= 5
- Returns false when TTD < 6
- Returns true when all gates pass
- Does not depend on `is_behind` position

**Verify:** `luac -p EaxRotations/classes/druid/cat_sylvanas.lua`

---

### Task 4: cat_sylvanas.lua — Add `claw_fallback_matches()` function

**File:** `EaxRotations/classes/druid/cat_sylvanas.lua`
**Location:** After `mangle_filler_matches()` (ends line 672), before `tigers_fury_matches()` (starts line 674)

**Function:**
```lua
local function claw_fallback_matches(context, action)
    local state = build_state(context)
    if not state.target then return false end
    if state.is_behind then return false end
    if (state.combo_points or 0) >= 5 then return false end
    if not state.target or not state.target.is_alive then
        if state.target_ttd <= 0 then return false end
    end
    if (state.energy or 0) < CLAW_COST then return false end
    if state.mangle_remains <= 0 then return false end
    if should_wait_for_tick(state, CLAW_COST) then return false end
    return true
end
```

**Logic:** Target exists → NOT behind (Shred unavailable) → CP < 5 → Target alive (TTD > 0) → Energy >= CLAW_COST (45) → Mangle debuff up (otherwise Mangle first) → Energy tick check

**Acceptance:**
- Returns false when behind target (should use Shred)
- Returns false when CP >= 5
- Returns false when mangle debuff is down (should Mangle first)
- Returns false when energy < CLAW_COST
- Returns true when all gates pass

**Verify:** `luac -p EaxRotations/classes/druid/cat_sylvanas.lua`

---

### Task 5: cat_sylvanas.lua — Add ACTIONS table entries + reorder

**File:** `EaxRotations/classes/druid/cat_sylvanas.lua`
**Location:** ACTIONS table (lines 728-759)

**Changes:**

1. **Insert RakePvE** after MangleDebuff (line 747), before MangleBuilder (line 748):
```lua
    { name = "RakePvE", spell = SPELLS.Rake, required_form = "cat", min_energy = RAKE_COST, matches = rake_pve_matches },
```

2. **Insert ClawFallback** after MangleFiller (line 756), before RakePvP (line 757):
```lua
    { name = "ClawFallback", spell = SPELLS.Claw, required_form = "cat", min_energy = CLAW_COST, matches = claw_fallback_matches },
```

**Resulting ACTIONS order (after insertion):**
```
... MangleDebuff → RakePvE → MangleBuilder → ... ShredOmen → Shred → MangleFiller → ClawFallback → RakePvP → FaerieFireFeral
```

**Acceptance:**
- `find_strategy("RakePvE")` resolves in test file
- `find_strategy("ClawFallback")` resolves in test file
- Actions appear in correct priority position

**Verify:** `luac -p EaxRotations/classes/druid/cat_sylvanas.lua`

---

### Task 6: cat_sylvanas.lua — Update debug log to show cat_use_rake

**File:** `EaxRotations/classes/druid/cat_sylvanas.lua`
**Location:** Line 444 (debug log)

**Change:** Append `" use_rake=" .. tostring(NS.setting_bool(settings, "cat_use_rake", true))` to the log string.

**Before (line 444):**
```lua
NS.log("[EaxRotations:CAT] cp=" .. tostring(state.combo_points) .. " energy=" .. tostring(state.energy) .. " range=" .. tostring(math.floor(state.target_range)) .. " stance=" .. tostring(state.stance or context.stance or "?") .. " behind=" .. tostring(state.is_behind) .. " rake=" .. tostring(math.floor(state.rake_remains)) .. " rip=" .. tostring(math.floor(state.rip_remains)) .. " mangle=" .. tostring(math.floor(state.mangle_remains)) .. " ff=" .. tostring(math.floor(state.faerie_fire_remains)) .. " stealth=" .. tostring(state.is_stealthed) .. " pvp=" .. tostring(state.is_pvp) .. " target_p=" .. tostring(state.is_player_target) .. " pool=" .. tostring(state.pooling))
```

**After:** Append `" use_rake=" .. tostring(NS.setting_bool(settings, "cat_use_rake", true))`

**Acceptance:** Debug log includes `use_rake=true` or `use_rake=false`

**Verify:** Visual inspection of debug log string

---

### Task 7: cat_sylvanas.lua — Update registration message

**File:** `EaxRotations/classes/druid/cat_sylvanas.lua`
**Location:** Line 794

**Change:** Update from `"(cat-v7: Rip>Mangle>Shred, TF-opener, noRake, pcall-bm)"` to `"(cat-v8: Rip>Mangle>RakePvE>Shred>ClawFallback, TF-opener, pcall-bm)"`

**Acceptance:** Registration message reflects new version

---

### Task 8: Update test file (bonus — new tests for RakePvE + ClawFallback)

**File:** `EaxRotations/tests/test_cat_custom_matches.lua`

**Changes:**
1. Add test section for `rake_pve_matches` strategy:
   - Setting disabled → no match
   - CP >= 5 → no match
   - TTD < 6 → no match
   - Rake remains > refresh seconds → no match
   - All gates pass → match

2. Add test section for `claw_fallback_matches` strategy:
   - Behind target → no match (should use Shred)
   - CP >= 5 → no match
   - Energy < 45 → no match
   - Mangle debuff down → no match
   - All gates pass → match

**Acceptance:** All new test assertions pass

**Note:** This task is optional for MVP but recommended. If skipped, verify existing tests still pass.

---

### Task 9: Full Validation

**Verify:**
1. `luac -p EaxRotations/classes/druid/schema_sylvanas.lua` — exit 0
2. `luac -p EaxRotations/classes/druid/cat_sylvanas.lua` — exit 0
3. `luac -p EaxRotations/tests/test_cat_custom_matches.lua` (if modified) — exit 0
4. `lua EaxRotations/tests/run_rotation_tests.lua` — all 95+ suites pass
5. `lua EaxRotations/tests/run_leveling_tests.lua` — all 11 suites pass
6. `lsp_diagnostics` on all changed files — 0 errors

---

### Task 10: Git Commit

- Commit with conventional commit format
- Scope: druid(cat)
- Description: Add Rake PvE builder + Claw fallback

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| `rake_pve_matches` conflicts with `rake_pvp_matches` | PvE Rake could override PvP Rake in PvP scenarios | PvE Rake has `cat_use_rake` check + no `is_player_target` gate; PvP Rake prioritizes `is_player_target`. Order ensures PvE before PvP in the actions table. |
| Claw not learned at level | False match, waste | `spell_ready(SPELLS.Claw, state.target)` in the action table handles this via `NS.spell_ready`. |
| TTD unknown value | Rake might fire on short-lived target | Gate with `state.target_ttd > 0 and state.target_ttd < MIN_RAKE_TTD`. If TTD unknown (0/999), Rake is allowed. |
| `should_wait_for_tick(state, RAKE_COST)` with nil state | Nil error | Already guarded: `should_wait_for_tick` checks `state.energy or 0` |
| ClawFallback activates when NOT behind but Shred still usable (clearcasting) | Suboptimal choice | ShredOmen (clearcasting) is higher priority and will match first. ClawFallback is last resort. |
