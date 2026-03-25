-- creature_utils.lua
-- Shared helpers for creature-type-gated spell logic.

local creature_utils = {}

local _enums = nil
local function enums()
    if not _enums then
        local ok, e = pcall(require, "common/enums")
        if ok and e then _enums = e end
    end
    return _enums
end

local function get_ct(unit)
    if not unit or not unit.is_valid or not unit:is_valid() then return nil end
    local ok, ct = pcall(function() return unit:get_creature_type() end)
    return ok and ct or nil
end

function creature_utils.is_beast(target)
    local ct = get_ct(target)
    local e = enums(); if not ct or not e then return false end
    return ct == e.creature_type.BEAST
end

return creature_utils
