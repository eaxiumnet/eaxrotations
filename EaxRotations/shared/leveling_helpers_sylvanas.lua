-- leveling_helpers_sylvanas.lua -- small helpers (range, face, form) reused across leveling specs.
-- WHAT:   small helpers (range, face, form) reused across leveling specs
-- WHEN:   called every frame by every leveling spec
-- WHY:    extracts duplicated 70-line helper block from each leveling_sylvanas.lua
-- SAFETY: all functions nil-guarded; pure helpers, no on_update side-effects
-- DECISION: consumed by specs via require(); no on_update side-effects.

-- Shared helper functions for leveling rotations.
-- Extracted from duplicated boilerplate across 10 leveling files.
-- Each function matches the exact implementation found in the leveling files.

local core = _G.core or {}
local NS = _G.EaxRotations or {}

local M = {}

--- Check if the player has any of the given buff IDs.
---@param buff_ids number|number[]
---@return boolean
function M.has_buff(buff_ids)
    if not buff_ids then return false end
    local me = (NS.GetPlayer and NS.GetPlayer()) or (NS.get_local_player and NS.get_local_player()) or nil
    if not me then return false end
    local ids = type(buff_ids) == "table" and buff_ids or { buff_ids }
    if NS.buff_up then
        local ok, result = pcall(NS.buff_up, me, ids)
        return ok and result
    end
    return false
end

--- Check if a spell_action or spell id-array is ready to cast.
---@param spell_action table|nil
---@return boolean
function M.spell_ready(spell_action)
    if not spell_action then return false end

    if type(spell_action.is_ready) == "function"
        and type(spell_action.get_cooldown_remaining) == "function" then
        local ok, result = pcall(function()
            return spell_action:is_ready()
                and spell_action:get_cooldown_remaining() == 0
        end)
        return ok and result or false
    end

    local NS = _G.EaxRotations or {}
    if type(NS.spell_ready) == "function" then
        local ok, result = pcall(NS.spell_ready, spell_action)
        if ok and result ~= nil then return result == true end
        return false
    end

    return false
end

--- Try to cast a spell action.
---@param spell_action table|nil
---@param target table|nil
---@param label string|nil
---@param opts table|nil
---@return boolean
function M.try_cast(spell_action, target, label, opts)
    if not spell_action then return false end
    if not NS.try_cast then return false end
    local ok, result = pcall(NS.try_cast, spell_action, target, label or "", opts)
    return ok and result == true
end

--- Get the local player unit (for buff/debuff aura checks).
---@return table|nil
function M.get_player()
    return (NS.GetPlayer and NS.GetPlayer()) or (NS.get_local_player and NS.get_local_player()) or nil
end

--- Extract player level from a context table, with safe fallbacks.
---@param context table|nil
---@param fallback number|nil
---@return number
function M.level_from_context(context, fallback)
    if context then
        local lvl = context.level or context.player_level
        if type(lvl) == "number" and lvl > 0 then return lvl end
    end
    return fallback or 70
end

--- Classic Era (1.15) level from context — default **60**, not 70 (TBC cap).
--- Use in all `*_vanilla.lua` paths so missing context does not look like TBC 70.
---@param context table|nil
---@return number
function M.vanilla_level_from_context(context)
    return M.level_from_context(context, 60)
end

--- Scale a threshold linearly with level, clamped to [floor, cap].
---@param level number
---@param base number
---@param per_level number
---@param floor_val number
---@param cap_val number
---@return number
function M.level_scaled_threshold(level, base, per_level, floor_val, cap_val)
    local threshold = base + (level * per_level)
    if threshold < floor_val then threshold = floor_val end
    if threshold > cap_val then threshold = cap_val end
    return threshold
end

--- Return true if Mangle (Cat) can be expected at the given level.
---@param level number|nil
---@return boolean
function M.has_mangle_cat(level)
    return (level or 70) >= 50
end

--- Return true if the player is below the level where endgame debuff dependencies make sense.
---@param level number|nil
---@return boolean
function M.is_low_level(level)
    return (level or 70) < 50
end

--- Return true when the given target is casting an interruptible spell.
--- Nil-guarded: safe to call every frame with a possibly-nil unit.
---@param target table|nil
---@return boolean
function M.should_interrupt(target)
    if not target then return false end
    -- Detect an active cast/channel using the common wrapper first, then raw API.
    local ok, casting = pcall(function()
        if target.is_casting then return target:is_casting() end
        if target.is_casting_spell then return target:is_casting_spell() end
        if target.is_channelling_spell then return target:is_channelling_spell() end
        return false
    end)
    if not ok or not casting then return false end
    -- Respect interruptibility when the API exposes it; assume interruptible otherwise.
    if NS.is_interruptible then
        local ok_i, interruptible = pcall(NS.is_interruptible, target)
        if ok_i and interruptible ~= nil then return interruptible == true end
    end
    local ok_r, interruptible = pcall(function()
        if target.is_active_spell_interruptable then return target:is_active_spell_interruptable() end
        return true
    end)
    if not ok_r or interruptible == nil then return true end
    return interruptible == true
end

--- Return true when the player's mana is low enough to warrant recovery
--- (drink / wand / mana-return abilities). Reads the nil-guarded state field.
---@param state table|nil
---@param threshold number|nil percentage below which recovery is needed (default 20)
---@return boolean
function M.needs_mana_recovery(state, threshold)
    if not state then return false end
    local mana = state.mana_pct
    if type(mana) ~= "number" then return false end
    return mana < (threshold or 20)
end

return M
