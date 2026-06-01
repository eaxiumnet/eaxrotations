-- ============================================================================
-- CC Immunity Helper
-- ============================================================================
-- What:  Shared helper that prevents wasted CC/utility spells by checking
--        PvP immunity (is_cc_immune) and PvE NPC susceptibility (cc_data_helper).
-- When:  Loaded optionally by spec files that cast CC on enemies.
-- Why:   Specs previously cast CC blindly; bosses/NPCs can be immune.
-- Safety: All checks are nil-safe and optional; falls through to "not immune"
--         if helpers are unavailable. Does NOT block interrupts.
-- Decision: Uses pcall to load cc_data_helper; exposes NS.CCImmunity.
-- ============================================================================

local M = {}

local NS = _G.EaxRotations
if not NS then return M end

-- Load cc_data_helper once at module init (optional)
local _cc_ok, cc_data = pcall(require, "common/utility/cc_data_helper")

-- Cache is_cc_immune method name for safe access
local _is_cc_immune = "is_cc_immune"

-- ============================================================================
-- Core: Check if target is immune to a CC type
-- ============================================================================
-- target:   game_object to check
-- cc_type:  cc_data_helper.CC.* constant (e.g. cc_data_helper.CC.Stun)
-- Returns:  true if target is known-immune, false otherwise (safe default)
-- ============================================================================
function M.is_immune(target, cc_type)
    if not target then return false end

    -- PvP path: IZI is_cc_immune (catches PvP trinket, Ice Block, etc.)
    if target[_is_cc_immune] then
        local ok, immune = pcall(target[_is_cc_immune], target)
        if ok and immune then return true end
    end

    -- PvE path: cc_data_helper NPC database
    if _cc_ok and cc_data and cc_type then
        local get_id = target.get_npc_id
        if get_id then
            local ok, npc_id = pcall(get_id, target)
            if ok and type(npc_id) == "number" and npc_id > 0 then
                local ok2, susceptible = pcall(cc_data.is_susceptible, cc_data, npc_id, cc_type)
                if ok2 and susceptible == false then return true end
            end
        end
    end

    return false
end

-- ============================================================================
-- Convenience: Fear immunity (Psychic Scream, Howl of Terror, Intimidating Shout)
-- ============================================================================
function M.is_fear_immune(target)
    if not target then return false end
    if target[_is_cc_immune] then
        local ok, immune = pcall(target[_is_cc_immune], target)
        if ok and immune then return true end
    end
    if _cc_ok and cc_data then
        local get_id = target.get_npc_id
        if get_id then
            local ok, npc_id = pcall(get_id, target)
            if ok and type(npc_id) == "number" and npc_id > 0 then
                local ok2, sus = pcall(cc_data.is_fearable, cc_data, npc_id)
                if ok2 and sus == false then return true end
            end
        end
    end
    return false
end

-- ============================================================================
-- Convenience: Stun immunity (Hammer of Justice, Kidney Shot, Cheap Shot, Bash)
-- ============================================================================
function M.is_stun_immune(target)
    if not target then return false end
    if target[_is_cc_immune] then
        local ok, immune = pcall(target[_is_cc_immune], target)
        if ok and immune then return true end
    end
    if _cc_ok and cc_data then
        local get_id = target.get_npc_id
        if get_id then
            local ok, npc_id = pcall(get_id, target)
            if ok and type(npc_id) == "number" and npc_id > 0 then
                local ok2, sus = pcall(cc_data.is_stunnable, cc_data, npc_id)
                if ok2 and sus == false then return true end
            end
        end
    end
    return false
end

-- ============================================================================
-- Convenience: Root immunity (Entangling Roots, Frost Nova)
-- ============================================================================
function M.is_root_immune(target)
    if not target then return false end
    if target[_is_cc_immune] then
        local ok, immune = pcall(target[_is_cc_immune], target)
        if ok and immune then return true end
    end
    if _cc_ok and cc_data then
        local get_id = target.get_npc_id
        if get_id then
            local ok, npc_id = pcall(get_id, target)
            if ok and type(npc_id) == "number" and npc_id > 0 then
                local ok2, sus = pcall(cc_data.is_rootable, cc_data, npc_id)
                if ok2 and sus == false then return true end
            end
        end
    end
    return false
end

-- ============================================================================
-- Convenience: Polymorph immunity (includes creature type check)
-- Polymorph only works on Humanoid, Beast, Critter.
-- target_obj: the game_object (needed for creature type check)
-- ============================================================================
function M.is_polymorph_immune(target_obj)
    if not target_obj then return false end
    if target_obj[_is_cc_immune] then
        local ok, immune = pcall(target_obj[_is_cc_immune], target_obj)
        if ok and immune then return true end
    end
    if _cc_ok and cc_data then
        local get_id = target_obj.get_npc_id
        if get_id then
            local ok, npc_id = pcall(get_id, target_obj)
            if ok and type(npc_id) == "number" and npc_id > 0 then
                -- Pass target_obj for creature type check
                local ok2, sus = pcall(cc_data.is_polymorphable, cc_data, npc_id, target_obj)
                if ok2 and sus == false then return true end
            end
        end
    end
    return false
end

-- ============================================================================
-- Convenience: Sap immunity (includes creature type check)
-- Sap only works on Humanoid, Beast, Demon, Dragonkin (while stealthed).
-- ============================================================================
function M.is_sap_immune(target_obj)
    if not target_obj then return false end
    if target_obj[_is_cc_immune] then
        local ok, immune = pcall(target_obj[_is_cc_immune], target_obj)
        if ok and immune then return true end
    end
    if _cc_ok and cc_data then
        local get_id = target_obj.get_npc_id
        if get_id then
            local ok, npc_id = pcall(get_id, target_obj)
            if ok and type(npc_id) == "number" and npc_id > 0 then
                local ok2, sus = pcall(cc_data.is_sappable, cc_data, npc_id, target_obj)
                if ok2 and sus == false then return true end
            end
        end
    end
    return false
end

-- ============================================================================
-- Convenience: Silence immunity (for interrupt-like silence effects)
-- NOTE: This is for CC silence, NOT for interrupt checks. Interruptibility
-- is a separate concept and should not use CC immunity checks.
-- ============================================================================
function M.is_silence_immune(target)
    if not target then return false end
    if target[_is_cc_immune] then
        local ok, immune = pcall(target[_is_cc_immune], target)
        if ok and immune then return true end
    end
    if _cc_ok and cc_data then
        local get_id = target.get_npc_id
        if get_id then
            local ok, npc_id = pcall(get_id, target)
            if ok and type(npc_id) == "number" and npc_id > 0 then
                local ok2, sus = pcall(cc_data.is_silenceable, cc_data, npc_id)
                if ok2 and sus == false then return true end
            end
        end
    end
    return false
end

-- ============================================================================
-- Expose on NS and return
-- ============================================================================
NS.CCImmunity = M
return M
