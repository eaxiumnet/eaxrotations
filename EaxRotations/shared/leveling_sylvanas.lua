-- Shared Leveling Module.
-- Provides common helpers for per-class leveling rotations:
--   - Context guard (solo/leveling playstyle)
--   - Wand execute (Shoot spell)
--   - Common state builder
--   - Generic strategy helpers
--
-- Usage in per-class leveling_sylvanas.lua:
--   local leveling = require("shared/leveling_sylvanas")
--   local guard = leveling.create_context_guard()
--   leveling.execute_wand(context)

local NS = _G.EaxRotations
if not NS then return nil end

local leveling = {}

-- ============================================================================
-- Constants
-- ============================================================================

--- Shoot/Wand spell ID (learned via wand training, usable by all classes)
leveling.WAND_SPELL_ID = 5019

local EMPTY_SETTINGS = {}

-- ============================================================================
-- Context guard
-- ============================================================================

--- Creates a context guard function that checks if leveling rotation should fire.
--- Returns a function(context) -> boolean
function leveling.create_context_guard()
    return function(context)
        if not context then return false end
        if context.is_solo == true or context.is_leveling == true then return true end
        -- Also allow if user explicitly selected leveling playstyle
        local settings = context.settings or EMPTY_SETTINGS
        return settings.playstyle == "leveling" or settings.active_playstyle == "leveling"
    end
end

-- ============================================================================
-- Wand execute
-- ============================================================================

--- Executes the Shoot/wand spell on the target.
--- @param context table Rotation context
--- @return boolean success
function leveling.execute_wand(context)
    if not context or not context.target then return false end
    if NS.try_cast then
        -- Route Shoot through the central cast guard so wanding respects target,
        -- GCD/cooldown/resource, anti-flicker, and range checks like all spells.
        return NS.try_cast(leveling.WAND_SPELL_ID, context.target, "[LEVELING] Wand") == true
    end
    return false
end

-- ============================================================================
-- Wand match function
-- ============================================================================

--- Creates a wand match function that checks mana threshold and spell readiness.
--- @param threshold_key string Setting key for wand mana threshold (e.g. "leveling_wand_threshold")
--- @param default_threshold number Default threshold if setting not found (default 30)
--- @return function matches(context, state) -> boolean
function leveling.create_wand_matches(threshold_key, default_threshold)
    local threshold = default_threshold or 30
    local key = threshold_key or "leveling_wand_threshold"

    return function(context, state)
        if not context then return false end
        if not state then return false end
        if not context.target then return false end
        if not state.wand_learned then return false end
        if not state.in_combat then return false end
        local mana_pct = state.mana_pct or 100
        local wand_threshold = state.wand_threshold or threshold
        if mana_pct >= wand_threshold then return false end
        return true
    end
end

-- ============================================================================
-- Generic state builder helpers
-- ============================================================================

--- Builds common state fields shared across all classes.
--- Call this from your per-class build_state() and then add class-specific fields.
--- @param context table Rotation context
--- @param state table The per-class state table to populate
--- @return table state (same as input, for chaining)
function leveling.build_common_state(context, state)
    if not context or not state then return state end

    state.in_combat = context.in_combat or false
    state.mana_pct = context.mana_pct or 100
    state.hp = context.hp or 100
    state.enemies = context.enemies_count or 0
    state.target = context.target
    state.is_moving = context.is_moving or false
    state.pet = context.pet

    -- Wand readiness (Shoot spell - wand training)
    local ok, exists = pcall(NS.spell_exists, leveling.WAND_SPELL_ID)
    state.wand_learned = ok and exists or false

    -- Read common settings
    local settings = context.settings or EMPTY_SETTINGS
    state.use_interrupt = settings.use_interrupt ~= false

    return state
end

-- ============================================================================
-- Generic interrupt match helper
-- ============================================================================

--- Creates a generic interrupt match function for a given spell readiness field.
--- @param state_field string Name of the spell readiness field in state (e.g. "counterspell_ready")
--- @return function matches(context, state) -> boolean
function leveling.create_interrupt_matches(state_field)
    return function(context, state)
        if not context then return false end
        if not state then return false end
        if not state.target then return false end
        if not state.use_interrupt then return false end
        if not state[state_field] then return false end
        local ok, casting = pcall(function() return state.target:is_casting() end)
        if not ok or not casting then return false end
        return true
    end
end

-- ============================================================================
-- Generic OOC buff match helper
-- ============================================================================

--- Creates a match function for out-of-combat self buffs.
--- Checks OOC status + buff missing + spell ready.
--- @param state_buff_field string State field indicating if buff is active (e.g. "has_fel_armor")
--- @param state_ready_field string State field indicating if spell is ready (e.g. "fel_armor_ready")
--- @return function matches(context, state) -> boolean
function leveling.create_ooc_buff_matches(state_buff_field, state_ready_field)
    return function(context, state)
        if not context then return false end
        if not state then return false end
        if state.in_combat then return false end
        if state[state_buff_field] then return false end
        if not state[state_ready_field] then return false end
        return true
    end
end

-- ============================================================================
-- Generic DoT refresh helper
-- ============================================================================

--- Checks if a DoT/debuff needs refreshing on the target.
--- @param target userdata Target game object
--- @param debuff_ids table Array of debuff spell IDs
--- @param refresh_time number Refresh threshold in seconds (default 4)
--- @return boolean needs_refresh
function leveling.dot_needs_refresh(target, debuff_ids, refresh_time)
    if not target then return false end
    local ok, remains = pcall(NS.debuff_remains, target, debuff_ids)
    local remaining = (ok and remains) or 0
    return remaining <= (refresh_time or 4)
end

-- ============================================================================
-- Generic AoE match helper
-- ============================================================================

--- Creates an AoE match function that fires when enough enemies are present.
--- @param min_enemies number Minimum enemy count (default 3)
--- @return function matches(context, state) -> boolean
function leveling.create_aoe_matches(min_enemies)
    local threshold = min_enemies or 3
    return function(context, state)
        if not context then return false end
        if not state then return false end
        if not state.target then return false end
        if not state.in_combat then return false end
        if (state.enemies or 0) < threshold then return false end
        if state.is_moving then return false end
        return true
    end
end

return leveling
