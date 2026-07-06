-- aspect_manager_sylvanas.lua — Dynamic Aspect switching for Hunters (TBC 2.5.5).
-- WHAT:  Auto-switch between Hawk (DPS), Viper (mana), Cheetah (OOC).
-- WHEN:  All Hunter specs (used by MM/Survival spec files; BM uses middleware).
-- WHY:   Never go OOM, never waste GCD on manual aspect.
-- SAFETY: nil-guarded; only suggests switches when not already in correct aspect.
-- DECISION: Hawk/Viper/Cheetah auto-switch; pure state machine driven by mana%.

local NS = _G.EaxRotations
if not NS then return {} end

local M = {}

--- Should we switch to Aspect of the Hawk?
-- Wowsims-aligned: exit Viper at 25% (was viper_threshold + 10).
--
-- @param state               table  Hunter state table
-- @param viper_exit_threshold number Mana % above which Hawk is desired (default 25)
-- @return boolean
function M.should_hawk(state, viper_exit_threshold)
    viper_exit_threshold = viper_exit_threshold or 25
    if not state then return false end
    if state.has_aspect_hawk then return false end
    -- Don't switch from Viper to Hawk until mana has recovered
    if state.has_aspect_viper then
        if (state.mana_pct or 100) <= viper_exit_threshold then return false end
    end
    return true
end

--- Should we switch to Aspect of the Viper?
-- Wowsims-aligned: enter Viper at 5% (was 20).
--
-- @param state               table  Hunter state table
-- @param viper_threshold     number Mana % below which Viper is desired (default 5)
-- @return boolean
function M.should_viper(state, viper_threshold)
    viper_threshold = viper_threshold or 5
    if not state then return false end
    if state.has_aspect_viper then return false end
    if (state.mana_pct or 100) > viper_threshold then return false end
    return true
end

--- Should we switch to Aspect of the Cheetah?
-- Out of combat, no enemies nearby, not mounted.
--
-- @param state               table  Hunter state table
-- @param context             table  Rotation context
-- @return boolean
function M.should_cheetah(state, context)
    if not state then return false end
    if state.has_cheetah then return false end
    if state.in_combat then return false end
    if state.is_mounted then return false end
    -- Only if no valid enemy target nearby
    if context and context.has_valid_enemy_target then return false end
    -- Only if enemy count is low (no nearby threats)
    if (state.enemy_count or 0) > 0 then return false end
    return true
end

--- Determine the recommended aspect for current state.
-- Returns "hawk", "viper", "cheetah", or nil (no change needed).
--
-- @param state               table  Hunter state table
-- @param context             table  Rotation context
-- @param viper_threshold     number Mana % below which Viper is desired (default 20)
-- @return string|nil
function M.recommend_aspect(state, context, viper_threshold)
    viper_threshold = viper_threshold or 20
    if M.should_viper(state, viper_threshold) then return "viper" end
    if M.should_hawk(state, viper_threshold) then return "hawk" end
    if M.should_cheetah(state, context) then return "cheetah" end
    return nil
end

--- Legacy compatibility: try OOC aspect (Cheetah/Hawk swap).
-- Does nothing and returns false by default; reserved for middleware use.
-- @param context table
-- @return boolean
function M.try_ooc_aspect(context)
    return false
end

--- Legacy compatibility: try in-combat aspect swap (Hawk/Viper).
-- Does nothing and returns false by default; reserved for middleware use.
-- @param context table
-- @return boolean
function M.try_swap_aspect(context)
    return false
end

--- Middleware strategy: switch to Aspect of the Viper when mana is low.
-- Returns a strategy table entry for use in a middleware strategies array.
-- @param spells table  SPELLS table from the spec file
-- @return table        { name, matches, execute }
function M.viper_middleware_strategy(spells)
    return {
        name = "AspectOfTheViper",
        matches = function(context)
            if not context.in_combat then return false end
            local settings = context.settings or {}
            if settings.auto_aspect == false then return false end
            local me = context.me
            if not me then return false end
            if NS.buff_up and NS.buff_up(me, { 34074 }) then return false end
            local mana_pct = context.mana_pct or (me.get_mana_percentage and me:get_mana_percentage()) or 100
            local threshold = settings.viper_mana_threshold or 20
            if mana_pct > threshold then return false end
            return NS.spell_ready and NS.spell_ready(spells.AspectOfTheViper, me, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast(spells.AspectOfTheViper, context.me, "[HUNTER] Aspect of the Viper", { skip_range = true })
        end,
    }
end

--- Middleware strategy: switch to Aspect of the Hawk when mana recovers.
-- Returns a strategy table entry for use in a middleware strategies array.
-- @param spells table  SPELLS table from the spec file
-- @return table        { name, matches, execute }
function M.hawk_middleware_strategy(spells)
    local ASPECT_HAWK_IDS = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }
    return {
        name = "AspectOfTheHawk",
        matches = function(context)
            if not context.in_combat then return false end
            local settings = context.settings or {}
            if settings.auto_aspect == false then return false end
            local me = context.me
            if not me then return false end
            if NS.buff_up and NS.buff_up(me, ASPECT_HAWK_IDS) then return false end
            local mana_pct = context.mana_pct or (me.get_mana_percentage and me:get_mana_percentage()) or 100
            local threshold = (settings.viper_mana_threshold or 20) + 10
            if mana_pct <= threshold then return false end
            return NS.spell_ready and NS.spell_ready(spells.AspectOfTheHawk, me, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast(spells.AspectOfTheHawk, context.me, "[HUNTER] Aspect of the Hawk", { skip_range = true })
        end,
    }
end

if NS then
    NS.AspectManager = M
end

return M
