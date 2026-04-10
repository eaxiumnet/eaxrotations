-- libraries/combat_context.lua
-- Combat context builder for EAXPaladinProtection
-- Follows AGENTS.md Pattern 6: 2s throttle, API caching, squared distance, static tables

-- 1. API caching at module load (CRITICAL - never call these in on_update)
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_enemies = core.object_manager.get_enemy_list
local _get_visible_objects = core.object_manager.get_visible_objects

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

-- 2. Static tables for reuse (no garbage allocation)
local _enemy_list = { n = 0 }
local _party_list = { n = 0 }
local _enemies_attacking_me = { n = 0 }

-- 3. Cache variables
local _last_build_time = 0
local _cached_context = nil

-- 4. Squared distance helper (never use math.sqrt for comparisons)
local function dist_squared(a, b)
    if not a or not b then return math.huge end
    local ok_a, a_pos = pcall(function() return a:get_position() end)
    local ok_b, b_pos = pcall(function() return b:get_position() end)
    if not ok_a or not a_pos or not ok_b or not b_pos then return math.huge end
    
    local dx = a_pos.x - b_pos.x
    local dy = a_pos.y - b_pos.y
    local dz = a_pos.z - b_pos.z
    return dx * dx + dy * dy + dz * dz
end

-- 5. Main build function with 2s throttle (AGENTS.md Pattern 6)
local function build(me)
    local now = _core_time()
    
    -- Return cached context if within 2s throttle window
    if _cached_context and (now - _last_build_time) <= 2 then
        return _cached_context
    end
    
    -- Ensure we have a valid player unit
    if not me then
        me = _get_local_player()
        if not me then return nil end
    end
    
    -- Clear static tables (reset count, don't create new tables)
    _enemy_list.n = 0
    _party_list.n = 0
    _enemies_attacking_me.n = 0
    
    -- Build fresh context
    local ctx = {}
    
    -- === PLAYER STATE ===
    ctx.me = me
    local ok_hp, hp = pcall(function() return me:get_health_percentage() end)
    ctx.hp = ok_hp and hp or 100
    local ok_max_hp, max_hp = pcall(function() return me:get_max_health() end)
    ctx.max_hp = ok_max_hp and max_hp or 0
    local ok, in_combat = pcall(function() return me:is_in_combat() end)
    ctx.in_combat = ok and in_combat or false
    
    -- Mana (Paladin resource)
    ctx.mana = 0
    ctx.mana_pct = 0
    if me.get_power then
        local ok_m, m = pcall(function() return me:get_power(0) end)
        if ok_m then
            ctx.mana = m
            if me.get_max_power then
                local ok_max, max_m = pcall(function() return me:get_max_power(0) end)
                if ok_max and max_m > 0 then
                    ctx.mana_pct = m / max_m
                end
            end
        end
    end
    
    -- === THREAT & TANKING DATA (Protection-specific) ===
    ctx.has_aggro = false
    ctx.threat_status = 0
    ctx.threat_pct = 0
    ctx.enemies_attacking_me = 0
    
    -- === ENEMY SCANNING ===
    ctx.enemy_count = 0
    ctx.melee_enemies = 0
    ctx.ranged_enemies = 0
    
    local objects = _get_visible_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj then
            local ok_valid, is_valid = pcall(function() return obj:is_valid() end)
            local ok_unit, is_unit = pcall(function() return obj:is_unit() end)
            local ok_dead, is_dead = pcall(function() return obj:is_dead() end)
            
            if ok_valid and is_valid and ok_unit and is_unit and not (ok_dead and is_dead) then
                local ok_attack, can_attack = pcall(function() return me:can_attack(obj) end)
                
                if ok_attack and can_attack then
                    -- Add to enemy list using static table pattern
                    _enemy_list.n = _enemy_list.n + 1
                    _enemy_list[_enemy_list.n] = obj
                    ctx.enemy_count = ctx.enemy_count + 1
                    
                    -- Squared distance check (5 yards = 25, 8 yards = 64, 10 yards = 100, 30 yards = 900)
                    local dist_sq = dist_squared(me, obj)
                    if dist_sq <= 25 then  -- 5 yards squared (melee range)
                        ctx.melee_enemies = ctx.melee_enemies + 1
                    elseif dist_sq <= 900 then  -- 30 yards squared
                        ctx.ranged_enemies = ctx.ranged_enemies + 1
                    end
                    
                    -- Check if enemy is targeting me (threat detection)
                    local ok_target, target_target = pcall(function() return obj:get_target() end)
                    if ok_target and target_target then
                        local ok_same, is_same = pcall(function() return target_target == me end)
                        if ok_same and is_same then
                            _enemies_attacking_me.n = _enemies_attacking_me.n + 1
                            _enemies_attacking_me[_enemies_attacking_me.n] = obj
                            ctx.enemies_attacking_me = ctx.enemies_attacking_me + 1
                        end
                    end
                    
                    -- Get threat data from current target
                    if obj.get_threat_situation then
                        local ok_threat, threat_data = pcall(function() return obj:get_threat_situation(me) end)
                        if ok_threat and threat_data then
                            ctx.threat_pct = threat_data.threat_percent or 0
                            ctx.threat_status = threat_data.status or 0
                            if ctx.threat_status >= 3 then
                                ctx.has_aggro = true
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Store references to static tables
    ctx.enemies = _enemy_list
    ctx.enemies_attacking_me_list = _enemies_attacking_me
    
    -- === PARTY/RAID CONTEXT ===
    ctx.party_size = 0
    for i = 1, 4 do
        local member = nil
        if me.get_party_member then
            local ok, m = pcall(function() return me:get_party_member(i) end)
            if ok then member = m end
        end
        if member then
            local ok_valid, is_valid = pcall(function() return member:is_valid() end)
            if ok_valid and is_valid then
                _party_list.n = _party_list.n + 1
                _party_list[_party_list.n] = member
                ctx.party_size = ctx.party_size + 1
            end
        end
    end
    ctx.party_members = _party_list
    
    -- === INCOMING DPS ESTIMATE ===
    ctx.incoming_dps = 0
    if ctx.enemies_attacking_me > 0 then
        -- Rough estimate: more enemies attacking = higher incoming DPS
        ctx.incoming_dps = ctx.enemies_attacking_me * 500  -- Base estimate per enemy
    end
    
    -- === TIME ===
    ctx.time = now
    ctx.cache_age = 0  -- Fresh cache
    
    -- Cache and return
    _cached_context = ctx
    _last_build_time = now
    return ctx
end

-- Clear the cached context (call on zone change, combat end, etc.)
local function clear_cache()
    _cached_context = nil
    _last_build_time = 0
end

-- Get cache age in seconds
local function get_cache_age()
    if not _cached_context then return math.huge end
    return _core_time() - _last_build_time
end

-- Check if cache is still valid (within 2s window)
local function is_cache_valid()
    if not _cached_context then return false end
    return (_core_time() - _last_build_time) <= 2
end

-- Count enemies within radius using squared distance
local function count_enemies_in_radius(me, radius)
    local radius_sq = radius * radius
    local count = 0
    local objects = _get_visible_objects()
    
    for i = 1, #objects do
        local obj = objects[i]
        if obj then
            local ok_valid, is_valid = pcall(function() return obj:is_valid() end)
            local ok_unit, is_unit = pcall(function() return obj:is_unit() end)
            local ok_dead, is_dead = pcall(function() return obj:is_dead() end)
            
            if ok_valid and is_valid and ok_unit and is_unit and not (ok_dead and is_dead) then
                local ok_attack, can_attack = pcall(function() return me:can_attack(obj) end)
                if ok_attack and can_attack then
                    local dist_sq = dist_squared(me, obj)
                    if dist_sq <= radius_sq then
                        count = count + 1
                    end
                end
            end
        end
    end
    
    return count
end

-- Get debuff data for a target
local function get_debuff_data(target, debuff_ids)
    if not target then return nil end
    local ok, is_valid = pcall(function() return target:is_valid() end)
    if not ok or not is_valid then return nil end
    return buff_manager:get_debuff_data(target, debuff_ids)
end

-- Get buff data for a unit
local function get_buff_data(unit, buff_ids)
    if not unit then return nil end
    local ok, is_valid = pcall(function() return unit:is_valid() end)
    if not ok or not is_valid then return nil end
    return buff_manager:get_buff_data(unit, buff_ids)
end

-- 6. Export
local combat_context = {
    build = build,
    clear_cache = clear_cache,
    get_cache_age = get_cache_age,
    is_cache_valid = is_cache_valid,
    dist_squared = dist_squared,
    count_enemies_in_radius = count_enemies_in_radius,
    get_debuff_data = get_debuff_data,
    get_buff_data = get_buff_data,
}

return combat_context
