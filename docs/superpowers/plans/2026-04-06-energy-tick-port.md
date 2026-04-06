# Energy Tick Tracking Port to EAX*Flux Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the energy tick tracking system from Flux AIO Cat (GGL platform) to EAX*Flux Druid Feral (Project Sylvanas API), eliminating the naive 1-second cooldown and enabling tick-aware powershifting.

**Architecture:** Add frame-level energy tick detection to EAX*Flux that tracks energy increases, filters out Furor/Wolfshead energy from form shifts, and delays powershifts when a tick is imminent (within 0.4s). This prevents the rapid shift-unshift loop and optimizes energy economy.

**Tech Stack:** Lua, Project Sylvanas API (`core.time()`, `me:get_power(3)`, `utils.has_buff()`), IZI SDK for casting

---

## Current State Analysis

**Flux AIO (source) has:**
- `energy_tick` tracker object (lines 107-168 in `flux/rotation/source/aio/druid/cat.lua`)
- Wolfshead Helm auto-detection (lines 87-104)
- `time_until_next_tick()` calculation based on 2.0s intervals
- `should_delay_shift()` check returning true when tick < 0.4s away
- Tick optimization: prefers Mangle over Shred in dead-zone energy ranges
- Dynamic spell cost reading via `GetSpellPowerCost()`

**EAX*Flux (target) has:**
- Naive 1-second cooldown between powershifts (`SHIFT_COOLDOWN = 1.0`)
- No tick tracking at all
- No Wolfshead detection
- No tick-aware decision making
- Static energy thresholds (hardcoded values)

---

## File Structure

**Files to Modify:**
- `EAXDruidFeral_Flux/libraries/utils.lua` - Add energy tick tracker module
- `EAXDruidFeral_Flux/main.lua` - Integrate tick tracking into rotation loop, replace naive cooldown
- `EAXDruidFeral_Flux/libraries/menu.lua` - Add `cat_tick_optimization` setting
- `EAXDruidFeral_Flux/libraries/spells.lua` - Add Wolfshead item ID constant

---

## Task 1: Energy Tick Tracker Module

**Files:**
- Create: `EAXDruidFeral_Flux/libraries/energy_tick.lua`
- Test: Verify by checking log output with debug mode enabled

### Step 1: Create the energy tick tracker module

```lua
-- energy_tick.lua | Energy tick tracking for EAX*Flux Feral Druid
-- Tracks 2-second energy ticks and filters out Furor/Wolfshead energy from shifts

local utils = require("libraries/utils")
local spells = require("libraries/spells")

-- Hot-path local caching
local _core_time = core.time

-- Constants
local ENERGY_TICK_INTERVAL = 2.0           -- Energy ticks every 2 seconds in TBC
local SHIFT_ENERGY_IGNORE_WINDOW = 0.6     -- Ignore energy increases within 0.6s of a shift
local TICK_WAIT_THRESHOLD = 0.4            -- Wait for tick if arriving within this window
local WOLFSHEAD_HELM_ID = 8345             -- Wolfshead Helm item ID
local INVSLOT_HEAD = 1                     -- Head slot inventory index
local EQUIPMENT_CHECK_INTERVAL = 2.0       -- Cache Wolfshead check for 2 seconds

-- State
local state = {
    -- Tick tracking
    last_energy = 0,
    last_tick_time = 0,
    confident = false,          -- True once we've detected at least one tick
    last_shift_time = 0,

    -- Wolfshead caching
    wolfshead_cache = {
        equipped = false,
        last_check = 0
    }
}

local energy_tick = {}

---Check if Wolfshead Helm is equipped (with caching)
---@return boolean
function energy_tick.is_wolfshead_equipped()
    local now = _core_time()
    if now - state.wolfshead_cache.last_check < EQUIPMENT_CHECK_INTERVAL then
        return state.wolfshead_cache.equipped
    end

    local head_item = core.inventory and core.inventory.get_inventory_item_id("player", INVSLOT_HEAD)
    state.wolfshead_cache.equipped = (head_item == WOLFSHEAD_HELM_ID)
    state.wolfshead_cache.last_check = now
    return state.wolfshead_cache.equipped
end

---Record that a form shift just occurred
---Call this BEFORE casting Cat Form for powershifting
function energy_tick.on_shift()
    state.last_shift_time = _core_time()
end

---Update the tick tracker each frame
---@param current_energy number Current player energy
---@param in_cat_form boolean Whether player is in cat form
function energy_tick.update(current_energy, in_cat_form)
    -- Only track in Cat form
    if not in_cat_form then
        state.last_energy = 0
        state.confident = false
        return
    end

    local now = _core_time()
    local delta = current_energy - state.last_energy

    -- Detect energy tick: positive increase, not from a recent form shift
    -- Ticks are 20 energy; filter out Furor (40) + Wolfshead (20) by checking shift window
    if delta > 0 and delta <= 25 and
       (now - state.last_shift_time) > SHIFT_ENERGY_IGNORE_WINDOW then
        state.last_tick_time = now
        state.confident = true
    end

    state.last_energy = current_energy
end

---Get time until next energy tick (seconds)
---@return number Estimated seconds until next tick (1.0 if unknown)
function energy_tick.time_until_next_tick()
    if not state.confident or state.last_tick_time == 0 then
        return 1.0  -- Default to 1s when uncertain
    end
    local elapsed = _core_time() - state.last_tick_time
    local remaining = ENERGY_TICK_INTERVAL - (elapsed % ENERGY_TICK_INTERVAL)
    return remaining
end

---Check if powershifting should be delayed for an imminent energy tick
---@return boolean True if a tick is arriving soon and we should wait
function energy_tick.should_delay_shift()
    if not state.confident then
        return false  -- Don't delay if we haven't detected a tick yet
    end
    return energy_tick.time_until_next_tick() <= TICK_WAIT_THRESHOLD
end

---Check if we're in the tick optimization range (prefer Mangle over Shred)
---@param energy number Current energy
---@param mangle_cost number Energy cost of Mangle
---@param shred_cost number Energy cost of Shred
---@return boolean
function energy_tick.should_prefer_mangle(energy, mangle_cost, shred_cost)
    -- At these energy levels, Shred leaves you too low to act after the tick, but Mangle doesn't
    -- Formula: lower = 2*mangle_cost - 20, upper = mangle_cost + shred_cost - 21
    local low = 2 * mangle_cost - 20
    local high = mangle_cost + shred_cost - 21

    return energy >= low and energy <= high
       and state.confident
       and energy_tick.time_until_next_tick() < 1.0
end

---Reset tick confidence (call when entering cat form after being in another form)
function energy_tick.reset_confidence()
    state.confident = false
    state.last_tick_time = 0
end

---Get debug info for logging
---@return table Debug state info
function energy_tick.get_debug_info()
    return {
        confident = state.confident,
        last_tick_time = state.last_tick_time,
        time_until_next = energy_tick.time_until_next_tick(),
        should_delay = energy_tick.should_delay_shift(),
        wolfshead = energy_tick.is_wolfshead_equipped(),
        last_shift = state.last_shift_time
    }
end

return energy_tick
```

### Step 2: Add energy_tick to libraries that need it

Modify `EAXDruidFeral_Flux/libraries/utils.lua` to expose the energy_tick module:

```lua
-- At the top of utils.lua, add:
local energy_tick = require("libraries/energy_tick")

-- At the bottom of utils.lua, add to the returned table:
function utils.get_energy_tick_tracker()
    return energy_tick
end
```

### Step 3: Run test to verify module loads

Run the rotation and check that the module loads without errors:

```lua
-- Add temporary test to main.lua on_update:
if utils.throttle("tick_test", 5.0) then
    local et = utils.get_energy_tick_tracker()
    core.log(string.format("[Tick Test] Confident=%s, TimeUntil=%.2f",
        tostring(et.confident), et.time_until_next_tick()))
end
```

Expected: Module loads without errors, confident=false initially, time_until_next_tick=1.0

### Step 4: Commit

```bash
git add EAXDruidFeral_Flux/libraries/energy_tick.lua
git add EAXDruidFeral_Flux/libraries/utils.lua
git commit -m "feat(energy): add energy tick tracker module"
```

---

## Task 2: Integrate Tick Tracking into Main Rotation

**Files:**
- Modify: `EAXDruidFeral_Flux/main.lua`
- Test: Verify powershifts respect tick timing

### Step 1: Import energy_tick in main.lua

Add at the top of `main.lua`:

```lua
-- Add this after other requires:
local energy_tick = require("libraries/energy_tick")
```

### Step 2: Update resolve() to read dynamic spell costs

Modify the `resolve()` function in `main.lua` to read actual spell costs:

```lua
-- Add to rt state:
spell_costs = {
    shred = 42,
    mangle = 40,
    rake = 35,
    rip = 30,
    ferocious_bite = 35,
    ravage = 60,
    tigers_fury = 30,
}

-- Add to resolve() function:
-- Read actual spell costs from API if available
local function get_spell_cost(spell_id, fallback)
    if not spell_id then return fallback end
    -- Project Sylvanas API: try to get cost from spell book
    if core.spell_book and core.spell_book.get_spell_power_cost then
        local cost = core.spell_book.get_spell_power_cost(spell_id)
        if cost and cost > 0 then return cost end
    end
    return fallback
end

rt.spell_costs.shred = get_spell_cost(rt.shred_id, 42)
rt.spell_costs.mangle = get_spell_cost(rt.mangle_cat_id, 40)
rt.spell_costs.rake = get_spell_cost(rt.rake_id, 35)
rt.spell_costs.rip = get_spell_cost(rt.rip_id, 30)
rt.spell_costs.ferocious_bite = get_spell_cost(rt.ferocious_bite_id, 35)
rt.spell_costs.ravage = get_spell_cost(rt.ravage_id, 60)
rt.spell_costs.tigers_fury = get_spell_cost(rt.tigers_fury_id, 30)
```

### Step 3: Update on_update to call tick tracker

Add in `on_update()` after getting player state:

```lua
local function on_update()
    resolve()
    local me = get_me()
    if not me or me:is_dead() then return end

    -- Update energy tick tracker
    local current_energy = energy(me)
    local in_cat_form = utils.has_buff(me, spells.BUFF_CAT_FORM)
    energy_tick.update(current_energy, in_cat_form)

    -- Rest of existing on_update logic...
end
```

### Step 4: Rewrite try_powershift with tick awareness

Replace the naive `try_powershift` function:

```lua
local function try_powershift(me)
    if not (menu.auto_powershift and menu.auto_powershift:is_checked()) then return false end
    if not rt.cat_form_id then return false end

    -- Must BE in cat form to powershift
    if not utils.has_buff(me, spells.BUFF_CAT_FORM) then return false end

    local min_mana = ((menu.powershift_min_mana and menu.powershift_min_mana:get()) or 25) / 100
    if utils.mana_pct(me) < min_mana then return false end

    -- Only powershift when energy is LOW (not > 20)
    local e = energy(me)
    if e > 20 then return false end

    -- NEW: Check if we should delay for an imminent energy tick
    if energy_tick.should_delay_shift() then
        if utils.throttle("powershift_delay_debug", 2.0) then
            utils.log_debug(menu, string.format("Powershift delayed - tick in %.2fs", energy_tick.time_until_next_tick()))
        end
        return false
    end

    -- NEW: Use Wolfshead detection for energy calculation
    local has_wolfshead = energy_tick.is_wolfshead_equipped()
    local furor_energy = 40  -- Base Furor energy
    local wolfshead_bonus = has_wolfshead and 20 or 0
    local energy_after_shift = furor_energy + wolfshead_bonus

    -- Only shift if we gain meaningful energy
    if energy_after_shift <= e then
        if utils.throttle("powershift_no_gain", 3.0) then
            utils.log_debug(menu, "Powershift skipped - no energy gain")
        end
        return false
    end

    -- Check we can cast (GCD available)
    if not utils.can_cast_self(rt.cat_form_id, me) then return false end

    -- Record shift time for tick tracker BEFORE casting
    energy_tick.on_shift()

    if utils.cast_self(rt.cat_form_id, me) then
        rt.last_powershift_time = _core_time()
        utils.log_debug(menu, string.format("Powershift: %d -> %d energy (Wolfshead: %s)",
            e, energy_after_shift, tostring(has_wolfshead)))
        return true
    end
    return false
end
```

### Step 5: Add tick optimization to try_shred

Add tick-aware Mangle preference in `try_shred`:

```lua
local function try_shred(me, t)
    if not (menu.use_shred and menu.use_shred:is_checked()) then return false end
    if not rt.shred_id then return false end
    if combo_points(me) >= 5 then return false end

    local e = energy(me)
    local shred_cost = rt.spell_costs.shred
    local mangle_cost = rt.spell_costs.mangle

    -- NEW: Tick optimization - prefer Mangle over Shred in dead-zone energy
    -- when a tick is imminent (avoids dead GCD after tick)
    if menu.cat_tick_optimization and menu.cat_tick_optimization:is_checked() then
        if energy_tick.should_prefer_mangle(e, mangle_cost, shred_cost) then
            if utils.throttle("tick_opt_debug", 2.0) then
                utils.log_debug(menu, string.format("Tick opt: preferring Mangle over Shred (energy=%d, tick in %.2fs)",
                    e, energy_tick.time_until_next_tick()))
            end
            return false  -- Let Mangle take priority
        end
    end

    if e < shred_cost then return false end
    if not utils.can_cast_hostile(rt.shred_id, me, t) then return false end
    if utils.cast_target(rt.shred_id, me, t) then
        utils.log_debug(menu, "Shred")
        return true
    end
    return false
end
```

### Step 6: Add debug logging for tick state

Add periodic debug output in `do_rotation`:

```lua
-- Add at start of do_rotation:
if utils.throttle("energy_tick_debug", 3.0) and menu.debug and menu.debug:is_checked() then
    local tick_info = energy_tick.get_debug_info()
    core.log(string.format(
        "|cFF00FF00[Tick Debug]|r confident=%s time_until=%.2fs delay=%s wolfshead=%s",
        tostring(tick_info.confident),
        tick_info.time_until_next,
        tostring(tick_info.should_delay),
        tostring(tick_info.wolfshead)
    ))
end
```

### Step 7: Commit

```bash
git add EAXDruidFeral_Flux/main.lua
git commit -m "feat(energy): integrate tick tracking into powershift and shred logic"
```

---

## Task 3: Add Menu Settings for Tick Optimization

**Files:**
- Modify: `EAXDruidFeral_Flux/libraries/menu.lua`
- Test: Verify settings appear in UI and toggle correctly

### Step 1: Add tick optimization setting to MENU_DEF

In `menu.lua`, add to the Rotation category:

```lua
{
    name = "Rotation",
    settings = {
        -- ... existing settings ...
        { key = "cat_tick_optimization", type = "checkbox", label = "Tick Optimization", default = true, tooltip = "Prefer Mangle over Shred when a tick is imminent to avoid dead GCDs" },
    }
}
```

### Step 2: Expose the setting proxy

Add after other proxies:

```lua
menu.cat_tick_optimization = create_proxy("cat_tick_optimization", true)
```

### Step 3: Commit

```bash
git add EAXDruidFeral_Flux/libraries/menu.lua
git commit -m "feat(ui): add tick optimization setting to menu"
```

---

## Task 4: Add Wolfshead Item ID to Spells

**Files:**
- Modify: `EAXDruidFeral_Flux/libraries/spells.lua`

### Step 1: Add item constants

Add at the end of `spells.lua`:

```lua
-- -- Items -------------------------------------------------------------------
spells.WOLFSHEAD_HELM_ID = 8345
```

### Step 2: Commit

```bash
git add EAXDruidFeral_Flux/libraries/spells.lua
git commit -m "feat(data): add Wolfshead Helm item ID constant"
```

---

## Task 5: Testing & Validation

**Manual Testing Checklist:**

### Step 1: Verify tick detection works

Enter cat form in combat and observe debug output:

```lua
-- Expected behavior:
-- 1. Initially: confident=false, time_until_next_tick=1.0
-- 2. After first tick detected: confident=true, time_until_next_tick cycles 0-2.0
-- 3. When powershifting: time_until_next_tick should not decrease immediately after shift
```

### Step 2: Verify powershift delay works

When energy < 20 and a tick is within 0.4s:
- Powershift should NOT occur
- Debug message: "Powershift delayed - tick in X.XXs"
- After tick arrives, powershift should proceed normally

### Step 3: Verify Wolfshead detection works

With Wolfshead equipped:
- Debug should show wolfshead=true
- Powershift should show "40 -> 60 energy" (40 Furor + 20 Wolfshead)

Without Wolfshead:
- Debug should show wolfshead=false
- Powershift should show "40 -> 40 energy"

### Step 4: Verify tick optimization works

With tick optimization enabled and energy in dead zone (60-61 without 2pT6, 50-56 with 2pT6):
- When tick is imminent (<1s), Shred should be skipped
- Mangle should be preferred in that window
- Debug: "Tick opt: preferring Mangle over Shred"

### Step 5: Regression test

Verify these behaviors still work:
- Normal rotation priority (Prowl -> Ravage -> DoTs -> Finishers -> Builders)
- Tiger's Fury usage
- Faerie Fire maintenance
- Rake/Rip DoT refreshes
- Ferocious Bite at 5 CP

---

## Summary of Changes

**New Files:**
- `EAXDruidFeral_Flux/libraries/energy_tick.lua` - Core tick tracking module

**Modified Files:**
- `EAXDruidFeral_Flux/libraries/utils.lua` - Expose energy_tick tracker
- `EAXDruidFeral_Flux/main.lua` - Integrate tick tracking, rewrite powershift logic
- `EAXDruidFeral_Flux/libraries/menu.lua` - Add tick optimization setting
- `EAXDruidFeral_Flux/libraries/spells.lua` - Add Wolfshead item ID

**Key Behavior Changes:**
1. Powershifts now wait for imminent energy ticks (prevents shift-unshift loops)
2. Wolfshead Helm is auto-detected (no manual configuration needed)
3. Tick optimization can prefer Mangle over Shred in dead-zone energy
4. Naive 1-second cooldown replaced with intelligent tick-aware logic

---

## Verification Before Completion

Before claiming this is complete:
1. Run combat scenario and verify no rapid powershift loops occur
2. Verify debug output shows tick detection working (confident=true after first tick)
3. Verify powershift is delayed when tick < 0.4s away
4. Check that Wolfshead detection is correct (equip/unequip helmet)
5. Confirm rotation still functions normally (no regressions)

