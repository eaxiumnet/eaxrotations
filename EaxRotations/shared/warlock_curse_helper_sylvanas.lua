-- warlock_curse_helper_sylvanas.lua — Shared curse selection logic for Warlock specs.
-- WHAT:  context-aware curse picker and curse-mode gate helper.
-- WHEN:  consumed by affliction/demonology/destruction_sylvanas.lua.
-- WHY:   eliminates duplicated curse selection logic and ensures consistent
--         behavior across specs (PvP tongues/exhaustion, AoE elements, raid shadow).
-- SAFETY: nil-guarded; no engine dependencies beyond spec_kit.setting.

local spec_kit = require("shared/spec_kit_sylvanas")

local M = {}

--- Check if the current curse mode setting permits a specific curse category.
-- @param curse_mode string  Current warlock_curse_mode value.
-- @param allowed_modes table  List of mode strings that permit the action.
-- @return boolean
function M.curse_mode_allows(curse_mode, allowed_modes)
    if curse_mode == "auto" then return true end
    for _, m in ipairs(allowed_modes) do
        if curse_mode == m then return true end
    end
    return false
end

--- Select which curse to use based on context and user settings.
-- Mirrors the Affliction select_curse() logic and is suitable for all specs.
-- @param context table  Rotation context (is_pvp, is_group, enemy_healer, etc.).
-- @param state table    Built state (enemy_count, etc.).
-- @return string|nil    One of: "agony", "doom", "elements", "shadow",
--                     "tongues", "exhaustion", "recklessness", "weakness", nil.
function M.select_curse(context, state)
    local curse_mode = spec_kit.setting(context, "warlock_curse_mode", "auto")

    -- Explicit mode choices
    if curse_mode == "agony" then
        if context.is_pvp and context.enemy_healer then return "tongues" end
        if context.is_pvp and context.melee_on_you then return "exhaustion" end
        return "agony"
    elseif curse_mode == "shadow" then
        return "shadow"
    elseif curse_mode == "elements" then
        return "elements"
    elseif curse_mode == "doom" then
        return "doom"
    elseif curse_mode == "recklessness" then
        return "recklessness"
    elseif curse_mode == "weakness" then
        return "weakness"
    elseif curse_mode == "none" then
        return nil
    end

    -- Auto mode: context-aware curse selection
    if context.is_pvp then
        if context.enemy_healer then return "tongues" end
        if context.melee_on_you then return "exhaustion" end
    end

    if (state.enemy_count or 0) >= 3 then
        return "elements"
    end

    -- In raids: prefer Shadow for shadow-damage specs, Elements for fire/destro
    if context.is_group then
        local playstyle = context.active_playstyle or "affliction"
        if playstyle == "affliction" or playstyle == "demonology" then
            return "shadow"
        end
        return "elements"
    end

    return "agony"
end

return M
