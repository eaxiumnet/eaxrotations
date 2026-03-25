--- rotation_context.lua
-- Lazy cache wrapper for rotation decisions
-- Provides faster refresh (~0.10s) than combat_context's general purpose 2s throttle
-- Ensures target-safe combo point tracking for rogue/feral

local combat_context = require("combat_context")

local rotation_context = {}

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
    if not cache or not me then
        return nil
    end

    local now_s = 0
    if deps and type(deps.now_s) == "function" then
        now_s = deps.now_s()
    elseif deps and type(deps.now) == "function" then
        now_s = deps.now()
    end

    -- Get GUIDs for cache key
    local me_guid = nil
    local target_guid = nil
    local combo_target_guid = cache.combo_target_guid
    local current_form = cache.form
    local current_stance = cache.stance

    -- Try to get me GUID
    if me.get_guid then
        local ok, guid = pcall(me.get_guid, me)
        if ok and guid then
            me_guid = guid
        end
    end

    -- Try to get target GUID
    local target_is_valid = false
    if target and target.is_valid then
        local ok_valid, is_valid = pcall(target.is_valid, target)
        target_is_valid = ok_valid and is_valid
    end
    if target_is_valid then
        if target.get_guid then
            local ok, guid = pcall(target.get_guid, target)
            if ok and guid then
                target_guid = guid
            end
        end
    else
        target_guid = nil
    end

    -- Detect combo point target for rogue/feral
    if me.get_combo_points_target then
        local ok, cp_target = pcall(me.get_combo_points_target, me)
        if ok and cp_target and cp_target.get_guid then
            local ok2, cp_guid = pcall(cp_target.get_guid, cp_target)
            if ok2 and cp_guid then
                combo_target_guid = cp_guid
            end
        end
    end

    -- Detect form for druid
    if me.get_form then
        local ok, form = pcall(me.get_form, me)
        if ok and form then
            current_form = form
        end
    end

    -- Detect stance for warrior
    if me.get_stance then
        local ok, stance = pcall(me.get_stance, me)
        if ok and stance then
            current_stance = stance
        end
    end

    -- Check if cache is still valid
    local cache_valid = (
        not cache.dirty and
        cache.me_guid == me_guid and
        cache.target_guid == target_guid and
        cache.combo_target_guid == combo_target_guid and
        cache.form == current_form and
        cache.stance == current_stance and
        (now_s - cache.last_build_s) < ROTATION_REFRESH_S
    )

    if cache_valid and cache.ctx then
        return cache.ctx
    end

    -- Build new context
    local ctx = combat_context.build(me, target, cache.spec_meta, deps)

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
