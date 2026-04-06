--- rotation_context.lua
-- Lazy cache wrapper for rotation decisions
-- Provides faster refresh (~0.10s) than combat_context's general purpose 2s throttle
-- Ensures target-safe combo point tracking for rogue/feral

local combat_context = require("libraries/combat_context")

local rotation_context = {}

local function safe_call(obj, method_name, ...)
    if not obj or type(obj) ~= "table" and type(obj) ~= "userdata" then
        return false, nil
    end
    local fn = obj[method_name]
    if type(fn) ~= "function" then
        return false, nil
    end
    return pcall(fn, obj, ...)
end

local function primitive_value(value)
    local t = type(value)
    if t == "string" or t == "number" then
        return value
    end
    return nil
end

local function safe_guid(obj, method_name)
    local ok, value = safe_call(obj, method_name)
    if not ok then
        return nil
    end
    return primitive_value(value)
end

local function safe_combo_target_guid(me)
    local ok, cp_target = safe_call(me, "get_combo_points_target")
    if not ok or not cp_target then
        return nil
    end
    return safe_guid(cp_target, "get_guid")
end

local function safe_boolean(obj, method_name)
    local ok, value = safe_call(obj, method_name)
    if not ok then
        return nil
    end
    if type(value) == "boolean" then
        return value
    end
    return nil
end

-- Cache validity window for rotation decisions (100ms)
local ROTATION_REFRESH_MS = 100
local ROTATION_REFRESH_S = ROTATION_REFRESH_MS / 1000

--- Create a new rotation context cache
-- @param spec_meta table: spec-specific metadata (important_buffs, important_debuffs, important_procs)
-- @return table: rotation context cache
function rotation_context.new(spec_meta)
    return {
        ctx = nil,
        last_build_s = 0,
        me_guid = nil,
        target_guid = nil,
        combo_target_guid = nil,  -- for rogue/feral
        form = nil,               -- for druid
        stance = nil,             -- for warrior
        dirty = true,
        spec_meta = spec_meta or {},
    }
end

--- Invalidate the cached context (call after cast, target change, form change)
-- @param cache table: rotation context cache
function rotation_context.invalidate(cache)
    if cache then
        cache.dirty = true
    end
end

--- Get rotation context, building only when needed
-- @param cache table: rotation context cache
-- @param me game_object: local player
-- @param target game_object: current target
-- @param deps table: dependencies (now_s, health_prediction, etc.)
-- @return table: combat context snapshot
function rotation_context.get(cache, me, target, deps)
    if not cache then
        return nil
    end

    local now_s = 0
    if deps and type(deps.now_s) == "function" then
        now_s = deps.now_s()
    elseif deps and type(deps.now) == "function" then
        now_s = deps.now()
    end

    local me_guid = safe_guid(me, "get_guid")
    local target_guid = safe_guid(target, "get_guid")
    local combo_target_guid = cache.combo_target_guid
    local current_form = cache.form
    local current_stance = cache.stance

    local me_is_valid = safe_boolean(me, "is_valid")
    local target_is_valid = safe_boolean(target, "is_valid")

    if me_is_valid == false then
        me_guid = nil
        combo_target_guid = nil
        current_form = nil
        current_stance = nil
    else
        combo_target_guid = safe_combo_target_guid(me) or combo_target_guid
        current_form = safe_guid(me, "get_form") or current_form
        current_stance = safe_guid(me, "get_stance") or current_stance
    end

    if target_is_valid == false then
        target_guid = nil
    end

    -- Check if cache is still valid
    local cache_valid = (
        not cache.dirty and
        cache.me_guid == me_guid and
        cache.target_guid == target_guid and
        cache.combo_target_guid == combo_target_guid and
        cache.form == current_form and
        cache.stance == current_stance and
        cache.last_build_s and
        (now_s - cache.last_build_s) < ROTATION_REFRESH_S
    )

    if cache_valid and cache.ctx then
        return cache.ctx
    end

    if me_is_valid == false then
        cache.ctx = nil
        cache.last_build_s = now_s
        cache.me_guid = nil
        cache.target_guid = nil
        cache.combo_target_guid = nil
        cache.form = nil
        cache.stance = nil
        cache.dirty = false
        return nil
    end

    -- Build new context
    local ok_build, ctx = pcall(combat_context.build, me, target, cache.spec_meta, deps)
    if not ok_build then
        ctx = nil
    end

    -- Update cache
    cache.ctx = ctx
    cache.last_build_s = now_s
    cache.me_guid = me_guid
    cache.target_guid = target_guid
    cache.combo_target_guid = combo_target_guid
    cache.form = current_form
    cache.stance = current_stance
    cache.dirty = false

    return ctx
end

--- Simple helper: get just the resources needed for rotation decisions
-- @param cache table: rotation context cache
-- @param me game_object: local player
-- @param target game_object: current target
-- @param deps table: dependencies
-- @return table: subset of context with resources
function rotation_context.get_resources(cache, me, target, deps)
    local ctx = rotation_context.get(cache, me, target, deps)
    if not ctx then
        return nil
    end

    -- Return only the resource fields needed for rotation decisions
    return {
        self = ctx.self,
        target = ctx.target,
        party = ctx.party,
    }
end

return rotation_context
