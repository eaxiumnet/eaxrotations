-- energy_tick.lua | Energy tick tracking for EAX* Feral Druid
-- Tracks 2-second energy ticks and filters out Furor/Wolfshead energy from shifts


-- Hot-path local caching
local _core_time = core.time

-- ============================================================================
-- ENERGY COST CONSTANTS (TBC-accurate values)
-- ============================================================================
local ENERGY_COST_RIP = 35
local ENERGY_COST_RAKE = 40
local ENERGY_COST_MANGLE = 40        -- 35 with 2pT6, default to 40
local ENERGY_COST_SHRED = 42
local ENERGY_COST_BITE = 35

-- ============================================================================
-- TICK OPTIMIZATION THRESHOLDS
-- Prefer Mangle over Shred in this energy range when tick is imminent
-- ============================================================================
local TICK_OPT_MANGLE_LOW = 2 * ENERGY_COST_MANGLE - 20      -- 60
local TICK_OPT_MANGLE_HIGH = ENERGY_COST_MANGLE + ENERGY_COST_SHRED - 21  -- 61
local TICK_OPT_THRESHOLD = 1.0  -- seconds until tick to trigger optimization

-- ============================================================================
-- TIMING CONSTANTS
-- ============================================================================
local ENERGY_TICK_INTERVAL = 2.0
local SHIFT_ENERGY_IGNORE_WINDOW = 0.6
local TICK_WAIT_THRESHOLD = 0.4
local EQUIPMENT_CHECK_INTERVAL = 2.0

-- ============================================================================
-- WOLFSHEAD HELM CONSTANTS
-- ============================================================================
local WOLFSHEAD_HELM_ID = 8345
local INVSLOT_HEAD = 1
local FUROR_ENERGY = 40
local WOLFSHEAD_BONUS = 20

-- ============================================================================
-- STATE
-- ============================================================================
local state = {
    last_energy = 0,
    last_tick_time = 0,
    confident = false,
    last_shift_time = 0,
    wolfshead_cache = { equipped = false, last_check = 0 }
}

local energy_tick = {}

-- ============================================================================
-- SPELL ENERGY COST HELPER
-- ============================================================================

--- Get the energy cost of a spell, with fallback for invalid spells
---@param spell table|nil Spell object (from core.spell_book or izi.spell)
---@param fallback number Fallback cost if spell is nil or invalid
---@return number Energy cost
function energy_tick.get_spell_energy_cost(spell, fallback)
    if not spell then return fallback end
    -- Try Sylvanas API: spell:GetSpellPowerCost()
    local cost, power_type = spell:GetSpellPowerCost()
    if cost and cost > 0 and power_type == 3 then
        return cost
    end
    return fallback
end

-- ============================================================================
-- WOLFSHEAD DETECTION
-- ============================================================================

--- Check if Wolfshead Helm is equipped (cached)
---@return boolean True if Wolfshead Helm is equipped
function energy_tick.is_wolfshead_equipped()
    local now = _core_time()
    if now - state.wolfshead_cache.last_check < EQUIPMENT_CHECK_INTERVAL then
        return state.wolfshead_cache.equipped
    end

    -- Try Sylvanas API first, fall back to WoW API
    local head_item = nil
    if core.inventory and core.inventory.get_item_id then
        head_item = core.inventory.get_item_id(INVSLOT_HEAD)
    elseif _G.GetInventoryItemID then
        head_item = _G.GetInventoryItemID("player", INVSLOT_HEAD)
    end

    state.wolfshead_cache.equipped = (head_item == WOLFSHEAD_HELM_ID)
    state.wolfshead_cache.last_check = now
    return state.wolfshead_cache.equipped
end

-- ============================================================================
-- ENERGY AFTER SHIFT CALCULATION
-- ============================================================================

--- Calculate energy available after a powershift (Furor + Wolfshead)
---@return number Energy after shift (40 base, +20 with Wolfshead)
function energy_tick.get_energy_after_shift()
    local bonus = energy_tick.is_wolfshead_equipped() and WOLFSHEAD_BONUS or 0
    return FUROR_ENERGY + bonus
end

-- ============================================================================
-- SHIFT TRACKING
-- ============================================================================

--- Call this when shifting to cat form to ignore Furor/Wolfshead energy
function energy_tick.on_shift()
    state.last_shift_time = _core_time()
end

-- ============================================================================
-- TICK TRACKING
-- ============================================================================

--- Update tick tracking with current energy and form state
---@param current_energy number Current energy value
---@param in_cat_form boolean True if in cat form
function energy_tick.update(current_energy, in_cat_form)
    if not in_cat_form then
        state.last_energy = 0
        state.confident = false
        return
    end

    local now = _core_time()
    local delta = current_energy - state.last_energy

    -- Detect tick: delta > 0 and delta <= 25, outside shift window
    if delta > 0 and delta <= 25 and (now - state.last_shift_time) > SHIFT_ENERGY_IGNORE_WINDOW then
        state.last_tick_time = now
        state.confident = true
    end

    state.last_energy = current_energy
end

--- Get time until next energy tick
---@return number Seconds until next tick (1.0 if not confident)
function energy_tick.time_until_next_tick()
    if not state.confident or state.last_tick_time == 0 then
        return 1.0
    end
    local elapsed = _core_time() - state.last_tick_time
    return ENERGY_TICK_INTERVAL - (elapsed % ENERGY_TICK_INTERVAL)
end

-- ============================================================================
-- DECISION HELPERS
-- ============================================================================

--- Check if we should delay powershift to catch next tick
---@return boolean True if shift should be delayed
function energy_tick.should_delay_shift()
    if not state.confident then return false end
    return energy_tick.time_until_next_tick() <= TICK_WAIT_THRESHOLD
end

--- Check if we should prefer Mangle over Shred due to tick optimization

---@param current_energy number Current energy value
---@return boolean True if Mangle should be preferred over Shred
function energy_tick.should_prefer_mangle(current_energy)
    return current_energy >= TICK_OPT_MANGLE_LOW
       and current_energy <= TICK_OPT_MANGLE_HIGH
       and state.confident
       and energy_tick.time_until_next_tick() < TICK_OPT_THRESHOLD
end

--- Legacy compatibility: should_prefer_mangle with explicit costs
---@param energy number Current energy
---@param mangle_cost number Mangle energy cost (ignored, uses constants)
---@param shred_cost number Shred energy cost (ignored, uses constants)
---@return boolean True if Mangle should be preferred
function energy_tick.should_prefer_mangle_legacy(energy, mangle_cost, shred_cost)
    -- Delegate to new implementation using constants
    return energy_tick.should_prefer_mangle(energy)
end

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

--- Reset tick confidence (call on form changes, combat end, etc.)
function energy_tick.reset_confidence()
    state.confident = false
    state.last_tick_time = 0
end

--- Get debug information for HUD/display
---@return table Debug info table
function energy_tick.get_debug_info()
    return {
        confident = state.confident,
        last_tick_time = state.last_tick_time,
        time_until_next = energy_tick.time_until_next_tick(),
        should_delay = energy_tick.should_delay_shift(),
        wolfshead = energy_tick.is_wolfshead_equipped(),
        last_shift = state.last_shift_time,
        
        tick_opt_low = TICK_OPT_MANGLE_LOW,
        tick_opt_high = TICK_OPT_MANGLE_HIGH,
        energy_after_shift = energy_tick.get_energy_after_shift()
    }
end

-- ============================================================================
-- CONSTANTS EXPORT (for external use)
-- ============================================================================

energy_tick.ENERGY_COST_RIP = ENERGY_COST_RIP
energy_tick.ENERGY_COST_RAKE = ENERGY_COST_RAKE
energy_tick.ENERGY_COST_MANGLE = ENERGY_COST_MANGLE
energy_tick.ENERGY_COST_SHRED = ENERGY_COST_SHRED
energy_tick.ENERGY_COST_BITE = ENERGY_COST_BITE
energy_tick.FUROR_ENERGY = FUROR_ENERGY
energy_tick.WOLFSHEAD_BONUS = WOLFSHEAD_BONUS
energy_tick.TICK_OPT_THRESHOLD = TICK_OPT_THRESHOLD

return energy_tick
