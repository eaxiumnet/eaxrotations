-- spell_queue_helper_sylvanas.lua -- nil-safe wrapper for direct spell_queue access.
-- WHAT:  exposes queue_spell_target/position with safe fallback to NS.try_cast.
-- WHEN:  called from specs that need explicit priority, fast (off-GCD), or movement flags.
-- WHY:   spell_queue is the preferred backend, but it may be unavailable in tests/stubs.
-- SAFETY: falls back to NS.try_cast / NS.try_cast_position when module is missing.
-- DECISION: keep the module tiny; callers pass raw spell ids and targets.

local NS = _G.EaxRotations
local M = {}

local _sq_ok, _spell_queue = pcall(require, "common/modules/spell_queue")
if not _sq_ok or type(_spell_queue) ~= "table" then _spell_queue = nil end

local function spell_id_from(spell)
    if type(spell) == "number" then return spell end
    if type(spell) == "table" then
        if type(spell.id) == "function" then return spell:id() end
        if type(spell._meta) == "table" and type(spell._meta.id) == "number" then return spell._meta.id end
    end
    return nil
end

function M.queue_spell_target(spell, target, priority, message, allow_movement)
    local id = spell_id_from(spell)
    if not id then return false end
    priority = priority or 1
    if _spell_queue and type(_spell_queue.queue_spell_target) == "function" then
        local ok, result = pcall(_spell_queue.queue_spell_target, _spell_queue, id, target, priority, message, allow_movement == true)
        if ok and result ~= false then return true end
    end
    if NS and NS.try_cast then
        return NS.try_cast(spell, target, message) == true
    end
    return false
end

function M.queue_spell_target_fast(spell, target, priority, message, allow_movement)
    local id = spell_id_from(spell)
    if not id then return false end
    priority = priority or 1
    if _spell_queue and type(_spell_queue.queue_spell_target_fast) == "function" then
        local ok, result = pcall(_spell_queue.queue_spell_target_fast, _spell_queue, id, target, priority, message, allow_movement == true)
        if ok and result ~= false then return true end
    end
    if NS and NS.try_cast then
        return NS.try_cast(spell, target, message, { skip_gcd = true }) == true
    end
    return false
end

function M.queue_spell_position(spell, position, priority, message, allow_movement)
    local id = spell_id_from(spell)
    if not id then return false end
    priority = priority or 1
    if _spell_queue and type(_spell_queue.queue_spell_position) == "function" then
        local ok, result = pcall(_spell_queue.queue_spell_position, _spell_queue, id, position, priority, message, allow_movement == true)
        if ok and result ~= false then return true end
    end
    if NS and NS.try_cast_position then
        return NS.try_cast_position(spell, position, nil, message) == true
    end
    return false
end

return M
