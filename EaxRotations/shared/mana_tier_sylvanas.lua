-- ============================================================================
-- Shared Helper: Mana Conservation Tiers
-- ============================================================================
-- What:   Centralizes mana management into three tiers with configurable
--         thresholds, replacing per-spec mana constants with a unified system.
-- When:   Called by healer specs to determine casting behavior based on mana.
-- Why:    All healer specs independently define mana floors/conserve thresholds.
--         A shared module ensures consistent behavior and easier tuning.
-- Safety: All values nil-guarded with sensible defaults.
--
-- Usage:
--   local mana = NS.ManaTier
--   local tier = mana.get(context)         -- "full"|"conserve"|"emergency"
--   if mana.should_cast(context, 500) then  -- can we afford 500 mana?
--       cast_spell()
--   end
--   local downrank = mana.should_downrank(context)  -- should we use lower rank?
-- ============================================================================

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

-- local math_max = math.max  -- reserved for future use

local M = {}
NS.ManaTier = M

-- ---------------------------------------------------------------------------
-- Configuration: Mana thresholds (percentages)
-- ---------------------------------------------------------------------------
local FULL_THRESHOLD    = 50   -- Above this: full rotation
local CONSERVE_THRESHOLD = 25  -- Above this: conserve mode, below: emergency
local MANA_FLOOR        = 10   -- Never cast non-free spells below this %
local EMERGENCY_FLOOR   = 5    -- Absolute minimum — potions/innervate only

-- Mana cost margin: don't cast if it would leave us below floor
local COST_SAFETY_MARGIN = 5   -- 5% extra mana buffer

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Get the current mana tier based on context.
---@param context table Rotation context with mana_pct or settings
---@return string tier "full"|"conserve"|"emergency"
function M.get(context)
    local mana_pct = 100
    if context then
        -- Try multiple mana sources
        if context.mana_pct then
            mana_pct = context.mana_pct
        elseif context.me then
            mana_pct = NS.mana_pct(context.me) or 100
        end
    end

    if mana_pct > FULL_THRESHOLD then return "full" end
    if mana_pct > CONSERVE_THRESHOLD then return "conserve" end
    return "emergency"
end

--- Check if we should cast a spell with the given mana cost.
---@param context table Rotation context
---@param spell_cost number Mana cost of the spell (0 for free/instant)
---@return boolean can_cast True if we can afford the spell safely
function M.should_cast(context, spell_cost)
    if not spell_cost or spell_cost <= 0 then return true end  -- Free spells always OK

    local mana_pct = 100
    if context then
        if context.mana_pct then
            mana_pct = context.mana_pct
        elseif context.me then
            mana_pct = NS.mana_pct(context.me) or 100
        end
    end

    -- Never cast below emergency floor
    if mana_pct < EMERGENCY_FLOOR then return false end

    -- Check if we're above the floor with safety margin
    return mana_pct > MANA_FLOOR + COST_SAFETY_MARGIN
end

--- Check if we should downrank spells (conserve mode).
---@param context table Rotation context
---@return boolean downrank True if in conserve or emergency mode
function M.should_downrank(context)
    local tier = M.get(context)
    return tier == "conserve" or tier == "emergency"
end

--- Check if we're in emergency-only mode (only instant/cheap heals).
---@param context table Rotation context
---@return boolean emergency True if in emergency mode
function M.is_emergency(context)
    return M.get(context) == "emergency"
end

--- Get the mana percentage from context (convenience).
---@param context table Rotation context
---@return number mana_pct Current mana percentage (0-100)
function M.current_mana_pct(context)
    if context then
        if context.mana_pct then return context.mana_pct end
        if context.me then return NS.mana_pct(context.me) or 100 end
    end
    return 100
end

--- Suggest a spell priority modifier based on mana tier.
-- Returns a multiplier for spell selection: 1.0 = normal, >1.0 = prefer, <1.0 = avoid
---@param context table Rotation context
---@param spell_cost number Mana cost of the spell
---@return number modifier Priority modifier (0.0 to 1.5)
function M.priority_modifier(context, spell_cost)
    local tier = M.get(context)

    if tier == "full" then
        return 1.0  -- Normal priority
    elseif tier == "conserve" then
        -- Prefer cheaper spells
        if not spell_cost or spell_cost <= 0 then return 1.2 end  -- Free spells get a boost
        -- Higher cost = lower priority
        local mana_pct = M.current_mana_pct(context)
        local cost_pct = mana_pct > 0 and (spell_cost / mana_pct * 100) or 999
        if cost_pct < 5 then return 1.0 end   -- Cheap spell, normal priority
        if cost_pct < 10 then return 0.7 end   -- Moderate cost, lower priority
        return 0.3  -- Expensive spell, much lower priority
    else
        -- Emergency: only instant/cheap
        if not spell_cost or spell_cost <= 0 then return 1.5 end  -- Free spells highest priority
        return 0.1  -- Everything else is near-zero priority
    end
end
