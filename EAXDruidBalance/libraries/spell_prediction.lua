-- EAX Druid Balance | Spell Prediction Module
-- Hurricane AoE positioning and enemy counting

local spell_prediction = {}

-- Try to load common spell_prediction module if available
local sp_module = nil
local ok, mod = pcall(function() return require("common/modules/spell_prediction") end)
if ok and mod then
    sp_module = mod
end

-- Static cache tables (reuse pattern)
local _cached_position = { x = 0, y = 0, z = 0 }
local _cached_enemies = { n = 0 }
local _cache_timestamp = 0
local _cache_ttl = 0.5  -- 500ms cache TTL

-- Hurricane spell constants
local HURRICANE_RADIUS = 10  -- 10 yard radius
local HURRICANE_RADIUS_SQ = HURRICANE_RADIUS * HURRICANE_RADIUS

-- Hot-path API caching
local _core_time = core.time
local _get_visible_objects = core.object_manager.get_all_objects

---Calculate squared distance between two positions
---@param pos1 table {x, y, z}
---@param pos2 table {x, y, z}
---@return number squared distance
local function dist_squared_pos(pos1, pos2)
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    local dz = pos1.z - pos2.z
    return dx * dx + dy * dy + dz * dz
end

---Calculate squared distance between player and object
---@param me table player object
---@param obj table target object
---@return number squared distance
local function dist_squared_obj(me, obj)
    local ok_m, me_pos = pcall(function() return me:get_position() end)
    local ok_o, obj_pos = pcall(function() return obj:get_position() end)
    if not ok_m or not ok_o or not me_pos or not obj_pos then return math.huge end
    local dx = me_pos.x - obj_pos.x
    local dy = me_pos.y - obj_pos.y
    local dz = me_pos.z - obj_pos.z
    return dx * dx + dy * dy + dz * dz
end

---Count enemies within radius of a position
---@param me table player object
---@param position table {x, y, z}
---@param radius number radius in yards
---@return number count of enemies
function spell_prediction.count_enemies_in_radius(me, position, radius)
    if not me or not position then return 0 end
    
    local radius_sq = radius * radius
    local count = 0
    
    -- Clear static enemy cache
    _cached_enemies.n = 0
    
    local objects = _get_visible_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() then
            if me:can_attack(obj) then
                local ok, obj_pos = pcall(function() return obj:get_position() end)
                if ok and obj_pos then
                    local dist_sq = dist_squared_pos(position, obj_pos)
                    if dist_sq <= radius_sq then
                        count = count + 1
                        -- Cache enemy for potential use
                        _cached_enemies.n = _cached_enemies.n + 1
                        _cached_enemies[_cached_enemies.n] = obj
                    end
                end
            end
        end
    end
    
    return count
end

---Get the best position to cast Hurricane for maximum enemy hits
---Uses target position as anchor and checks for optimal clustering
---@param me table player object
---@param target table primary target object
---@param min_targets number minimum targets required (default 3)
---@return table|nil {x, y, z} or nil if not enough targets
function spell_prediction.get_best_hurricane_position(me, target, min_targets)
    if not me or not target then return nil end
    
    min_targets = min_targets or 3
    
    local now = _core_time()
    
    -- Check cache validity
    if (now - _cache_timestamp) < _cache_ttl then
        -- Return cached position if valid
        if _cached_position.x ~= 0 or _cached_position.y ~= 0 then
            return { x = _cached_position.x, y = _cached_position.y, z = _cached_position.z }
        end
    end
    
    local ok, target_pos = pcall(function() return target:get_position() end)
    if not ok or not target_pos then return nil end
    
    -- Count enemies at target position
    local count_at_target = spell_prediction.count_enemies_in_radius(me, target_pos, HURRICANE_RADIUS)
    
    if count_at_target >= min_targets then
        -- Target position is good enough
        _cached_position.x = target_pos.x
        _cached_position.y = target_pos.y
        _cached_position.z = target_pos.z
        _cache_timestamp = now
        return { x = target_pos.x, y = target_pos.y, z = target_pos.z }
    end
    
    -- Try to find a better position by checking enemy clusters
    local objects = _get_visible_objects()
    local best_position = nil
    local best_count = count_at_target
    
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() then
            if me:can_attack(obj) then
                local ok, obj_pos = pcall(function() return obj:get_position() end)
                if ok and obj_pos then
                    -- Only check if within reasonable range of player
                    local dist_to_me_sq = dist_squared_obj(me, obj)
                    if dist_to_me_sq <= 900 then  -- 30 yards max cast range squared
                        local count = spell_prediction.count_enemies_in_radius(me, obj_pos, HURRICANE_RADIUS)
                        if count > best_count then
                            best_count = count
                            best_position = obj_pos
                        end
                    end
                end
            end
        end
    end
    
    if best_position and best_count >= min_targets then
        _cached_position.x = best_position.x
        _cached_position.y = best_position.y
        _cached_position.z = best_position.z
        _cache_timestamp = now
        return { x = best_position.x, y = best_position.y, z = best_position.z }
    end
    
    return nil
end

---Determine if Hurricane should be cast based on target clustering
---@param me table player object
---@param target table primary target object
---@param min_targets number minimum targets required (default 3)
---@return boolean true if Hurricane should be cast
function spell_prediction.should_cast_hurricane(me, target, min_targets)
    if not me or not target then return false end
    
    min_targets = min_targets or 3
    
    local position = spell_prediction.get_best_hurricane_position(me, target, min_targets)
    if not position then return false end
    
    local count = spell_prediction.count_enemies_in_radius(me, position, HURRICANE_RADIUS)
    return count >= min_targets
end

---Clear the position cache (call when combat ends or on zone change)
function spell_prediction.clear_cache()
    _cached_position.x = 0
    _cached_position.y = 0
    _cached_position.z = 0
    _cache_timestamp = 0
    _cached_enemies.n = 0
end

---Get the cached enemy list from last count operation
---@return table array of enemy objects (use .n for count)
function spell_prediction.get_cached_enemies()
    return _cached_enemies
end

---Get Hurricane radius constants
---@return number radius in yards
---@return number radius squared (for distance comparisons)
function spell_prediction.get_hurricane_radius()
    return HURRICANE_RADIUS, HURRICANE_RADIUS_SQ
end

return spell_prediction
