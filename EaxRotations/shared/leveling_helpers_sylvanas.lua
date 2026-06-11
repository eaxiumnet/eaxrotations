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

--- Check if a spell_action is ready to cast.
---@param spell_action table|nil
---@return boolean
function M.spell_ready(spell_action)
    if not spell_action then return false end
    local ok, result = pcall(function() return spell_action:is_ready() and spell_action:get_cooldown_remaining() == 0 end)
    return ok and result or false
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

return M
