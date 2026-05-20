-- ============================================================================
-- Shared Helper: Aspect Manager (Hunter)
-- ============================================================================
-- Pattern: Aspect priorities are Hawk (DPS) > Viper (mana regen).
--   - Switch to Viper when mana drops below viper_start threshold
--   - Switch back to Hawk when mana recovers above viper_end threshold
--   - Hysteresis prevents rapid aspect flip-flopping
--
-- TBC Aspect spell IDs:
--   Aspect of the Hawk: 13165, 14318, 14319, 14320, 14321, 14322, 25296, 27044 (rank 8 TBC)
--   Aspect of the Viper: 34074 (TBC-only, single rank)
--   Aspect of the Cheetah: 5118
--   Aspect of the Pack: 13159
--   Aspect of the Monkey: 13163
--   Aspect of the Beast: 13161
-- ============================================================================
-- NOTE: Aspect of the Hawk rank 1 is 13165. Aspect of the Beast is 13161.
-- The Hawk rank chain uses IDs 13165, 14318, 14319, 14320, 14321,
-- 14322, 25296, 27044 (TBC). Viper is 34074 (TBC-only).
-- ============================================================================

local M = {}
local _G = _G
local NS = _G.EaxRotations

-- Aspect of the Hawk spell IDs by rank (newest first, TBC rank 8 = 27044)
local HAWK_IDS = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }

-- Aspect of the Viper spell ID (TBC-only, single rank)
local VIPER_ID = 34074

-- Aspect of the Cheetah spell ID (single rank)
local CHEETAH_ID = 5118

-- Aspect of the Pack spell ID (single rank)
local PACK_ID = 13159

-- Aspect of the Monkey spell ID (single rank)
local MONKEY_ID = 13163

-- Aspect of the Beast spell ID (single rank)
local BEAST_ID = 13161

-- All aspect IDs for "any aspect active" check
local ALL_ASPECT_IDS = {}
for _, id in ipairs(HAWK_IDS) do ALL_ASPECT_IDS[id] = true end
ALL_ASPECT_IDS[VIPER_ID] = true
ALL_ASPECT_IDS[CHEETAH_ID] = true
ALL_ASPECT_IDS[PACK_ID] = true
ALL_ASPECT_IDS[MONKEY_ID] = true
ALL_ASPECT_IDS[BEAST_ID] = true

--- Check if player currently has Aspect of the Hawk active.
-- @return boolean - true if Hawk aspect buff is present
function M.has_hawk()
    if not NS or not NS.has_player_buff then return false end
    for _, id in ipairs(HAWK_IDS) do
        if NS.has_player_buff(id) then return true end
    end
    return false
end

--- Check if player currently has Aspect of the Viper active.
-- @return boolean - true if Viper aspect buff is present
function M.has_viper()
    if not NS or not NS.has_player_buff then return false end
    return NS.has_player_buff(VIPER_ID) == true
end

--- Check if player has any aspect active.
-- @return boolean - true if any aspect buff is present
function M.has_any_aspect()
    if not NS or not NS.has_player_buff then return false end
    for id, _ in pairs(ALL_ASPECT_IDS) do
        if NS.has_player_buff(id) then return true end
    end
    return false
end

--- Determine the recommended aspect based on mana state (with hysteresis).
-- @param context table - Rotation context with mana_pct, settings
-- @return string - "hawk", "viper", or "none"
function M.recommended_aspect(context)
    if not context or not context.settings then return "hawk" end

    local settings = context.settings
    local mana_pct = context.mana_pct or 100

    -- If both aspect swaps disabled, skip
    if settings.aspect_hawk == false and settings.aspect_viper == false then
        return "none"
    end

    -- Hysteresis thresholds to prevent rapid swapping
    -- viper_start: switch TO Viper when mana drops below this (default 10%)
    -- viper_end: switch BACK to Hawk when mana recovers above this (default 30%)
    local viper_start = settings.mana_viper_start or 10
    local viper_end = settings.mana_viper_end or 30

    -- Currently in Viper: stay until mana recovers above viper_end
    if M.has_viper() then
        if mana_pct >= viper_end then
            return "hawk"
        end
        return "viper"
    end

    -- Not in Viper: switch to Viper if mana drops below viper_start
    if settings.aspect_viper ~= false and mana_pct < viper_start then
        return "viper"
    end

    -- Default: Hawk for DPS
    if settings.aspect_hawk ~= false then
        return "hawk"
    end

    return "none"
end

--- Attempt to swap to the recommended aspect based on current mana.
-- @param context table - Rotation context with me, target, settings
-- @return boolean - true if aspect swap was attempted
function M.try_swap_aspect(context)
    if not context or not context.settings then return false end
    if not context.me then return false end

    -- Don't swap while mounted
    if context.is_mounted then return false end

    local recommended = M.recommended_aspect(context)
    if recommended == "none" then return false end

    -- Already in the correct aspect
    if recommended == "hawk" and M.has_hawk() then return false end
    if recommended == "viper" and M.has_viper() then return false end

    -- Resolve and cast the recommended aspect
    if recommended == "hawk" then
        if not NS or not NS.is_spell_learned then return false end
        for _, id in ipairs(HAWK_IDS) do
            if NS.is_spell_learned(id) then
                if NS.try_cast then
                    return NS.try_cast(id, context.me, "[HUNTER] Aspect of the Hawk", { skip_range = true, target = "self" })
                end
            end
        end
    elseif recommended == "viper" then
        if not NS or not NS.is_spell_learned then return false end
        if NS.is_spell_learned(VIPER_ID) then
            if NS.try_cast then
                return NS.try_cast(VIPER_ID, context.me, "[HUNTER] Aspect of the Viper", { skip_range = true, target = "self" })
            end
        end
    end

    return false
end

--- OOC aspect management: switch to Cheetah for travel, Viper for mana regen.
-- @param context table - Rotation context
-- @return boolean - true if aspect was swapped
function M.try_ooc_aspect(context)
    if not context or not context.settings then return false end
    if context.in_combat then return false end
    if context.is_mounted then return false end

    local mana_pct = context.mana_pct or 100
    local viper_start = context.settings.mana_viper_start or 10

    -- Low mana: switch to Viper for regen
    if mana_pct < viper_start and not M.has_viper() then
        if NS and NS.is_spell_learned and NS.is_spell_learned(VIPER_ID) then
            if NS.try_cast then
                return NS.try_cast(VIPER_ID, context.me, "[HUNTER/OOC] Aspect of the Viper", { skip_range = true })
            end
        end
    end

    -- Mana OK and not in Hawk: switch to Hawk for DPS readiness
    if mana_pct >= viper_start and not M.has_hawk() and not M.has_viper() then
        if context.settings.aspect_hawk ~= false then
            if NS and NS.is_spell_learned then
                for _, id in ipairs(HAWK_IDS) do
                    if NS.is_spell_learned(id) then
                        if NS.try_cast then
                            return NS.try_cast(id, context.me, "[HUNTER/OOC] Aspect of the Hawk", { skip_range = true })
                        end
                    end
                end
            end
        end
    end

    return false
end

--- Middleware strategy for Aspect of the Hawk (in combat DPS aspect).
-- Returns a strategy table suitable for NS.register_class_middleware.
-- @param SPELLS table - Hunter spell table (must contain AspectOfTheHawk)
-- @return table - Strategy entry
function M.hawk_middleware_strategy(SPELLS)
    local spell = SPELLS and SPELLS.AspectOfTheHawk
    if not spell then return nil end
    return {
        name = "AspectHawk",
        matches = function(context)
            if context.settings.aspect_hawk == false then return false end
            -- Skip if already in Hawk
            if M.has_hawk() then return false end
            -- Skip if we should be in Viper (low mana)
            local recommended = M.recommended_aspect(context)
            if recommended ~= "hawk" then return false end
            -- Skip if mounted
            if context.is_mounted then return false end
            return NS.action_matches(context, {
                name = "AspectHawk",
                spell = spell,
                target = "self",
                skip_range = true,
                kind = "buff",
                setting = "aspect_hawk",
            })
        end,
        execute = function(context)
            return NS.action_execute(context, {
                name = "AspectHawk",
                spell = spell,
                target = "self",
                skip_range = true,
                kind = "buff",
            }, "[HUNTER]")
        end,
    }
end

--- Middleware strategy for Aspect of the Viper (mana regen).
-- Returns a strategy table suitable for NS.register_class_middleware.
-- @param SPELLS table - Hunter spell table (must contain AspectOfTheViper)
-- @return table - Strategy entry
function M.viper_middleware_strategy(SPELLS)
    local spell = SPELLS and SPELLS.AspectOfTheViper
    if not spell then return nil end
    return {
        name = "AspectViper",
        matches = function(context)
            if context.settings.aspect_viper == false then return false end
            -- Skip if already in Viper
            if M.has_viper() then return false end
            -- Only match when mana is low enough for Viper
            local recommended = M.recommended_aspect(context)
            if recommended ~= "viper" then return false end
            -- Skip if mounted
            if context.is_mounted then return false end
            return NS.action_matches(context, {
                name = "AspectViper",
                spell = spell,
                target = "self",
                skip_range = true,
                kind = "buff",
                setting = "aspect_viper",
            })
        end,
        execute = function(context)
            return NS.action_execute(context, {
                name = "AspectViper",
                spell = spell,
                target = "self",
                skip_range = true,
                kind = "buff",
            }, "[HUNTER]")
        end,
    }
end

-- Register with EaxRotations namespace if available
if _G.EaxRotations then
    _G.EaxRotations.AspectManager = M
end

return M
