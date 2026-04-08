-- libraries/context_builder.lua
-- Shared rotation context builder for EAX tanking specs
-- Builds context once per frame to reduce redundant API calls

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local context_builder = {}

-- Cached values from last build
local _cached_context = nil
local _last_build_time = 0
local _CACHE_DURATION = 0.016  -- ~1 frame at 60fps

---Build rotation context (call once per frame)
---@param me game_object Player unit
---@param target game_object|nil Current target
---@param menu table Menu/settings module
---@return table context The built context
function context_builder.build(me, target, menu)
    local now = core.time()
    
    -- Return cached context if built this frame
    if _cached_context and (now - _last_build_time) < _CACHE_DURATION then
        return _cached_context
    end
    
    local ctx = {}
    
    -- === PLAYER STATE ===
    ctx.me = me
    ctx.hp = me:get_health_percentage()
    ctx.max_hp = me:get_max_health()
    ctx.in_combat = me:is_in_combat()
    
    -- Resource (rage/mana)
    local power_type = 0
    if me.get_power_type then
        local ok, pt = pcall(function() return me:get_power_type() end)
        if ok then power_type = pt end
    end
    ctx.power_type = power_type
    if power_type == 1 then  -- Rage
        if me.get_power then
            local ok, r = pcall(function() return me:get_power(1) end)
            if ok then ctx.rage = r else ctx.rage = 0 end
        else
            ctx.rage = 0
        end
    elseif power_type == 0 then  -- Mana
        if me.get_power then
            local ok, m = pcall(function() return me:get_power(0) end)
            if ok then 
                ctx.mana = m
                if me.get_max_power then
                    local ok2, max_m = pcall(function() return me:get_max_power(0) end)
                    if ok2 and max_m > 0 then
                        ctx.mana_pct = ctx.mana / max_m
                    else
                        ctx.mana_pct = 0
                    end
                else
                    ctx.mana_pct = 0
                end
            else
                ctx.mana = 0
                ctx.mana_pct = 0
            end
        else
            ctx.mana = 0
            ctx.mana_pct = 0
        end
    end
    
    -- Stance/Form detection
    ctx.stance = nil
    ctx.form = nil
    if me.has_aura then
        -- Check warrior stances
        if me:has_aura(2457) then ctx.stance = "battle"
        elseif me:has_aura(71) then ctx.stance = "defensive"
        elseif me:has_aura(2458) then ctx.stance = "berserker"
        end
        -- Check druid forms
        if me:has_aura(5487) then ctx.form = "bear"
        elseif me:has_aura(9634) then ctx.form = "dire_bear"
        elseif me:has_aura(768) then ctx.form = "cat"
        end
    end
    
    -- === TARGET STATE ===
    ctx.target = target
    ctx.has_target = target and target:is_valid() and not target:is_dead()
    
    if ctx.has_target then
        ctx.target_hp = target:get_health_percentage()
        ctx.target_max_hp = target:get_max_health()
        ctx.in_melee_range = context_builder._is_melee_range(me, target)
        ctx.target_is_player = target:is_player()
        ctx.target_classification = target:get_classification()
        ctx.target_is_casting = false
        if target.is_casting then
            local ok, casting = pcall(function() return target:is_casting() end)
            if ok then ctx.target_is_casting = casting end
        end
        
        -- Threat data (if available)
        if target.get_threat_situation then
            local ok, threat_data = pcall(function() return target:get_threat_situation(me) end)
            if ok and threat_data then
                ctx.threat_pct = threat_data.threat_percent or 0
                ctx.threat_status = threat_data.status or 0
            else
                ctx.threat_pct = 0
                ctx.threat_status = 0
            end
        else
            -- Fallback: check target's target
            local target_target = target:get_target()
            if target_target and target_target:is_valid() then
                if target_target == me then
                    ctx.threat_status = 3  -- Securely tanking
                else
                    ctx.threat_status = 1  -- Have threat but not tanking
                end
            else
                ctx.threat_status = 0  -- Loose mob
            end
            ctx.threat_pct = 0
        end
        
        -- Debuff tracking (using buff_manager)
        ctx.debuffs = {}
        ctx.buffs = {}
    end
    
    -- === COMBAT CONTEXT ===
    ctx.enemy_count = 0
    ctx.enemies = {}
    ctx.melee_enemies = 0
    
    local objects = core.object_manager.get_visible_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() then
            if me:can_attack(obj) then
                ctx.enemy_count = ctx.enemy_count + 1
                table.insert(ctx.enemies, obj)
                
                local dist_sq = context_builder._dist_squared(me, obj)
                if dist_sq <= 25 then  -- 5 yards squared (melee range)
                    ctx.melee_enemies = ctx.melee_enemies + 1
                end
            end
        end
    end
    
    -- Party/raid context
    ctx.party_size = 0
    ctx.party_members = {}
    for i = 1, 4 do
        local member = nil
        if me.get_party_member then
            local ok, m = pcall(function() return me:get_party_member(i) end)
            if ok then member = m end
        end
        if member and member:is_valid() then
            ctx.party_size = ctx.party_size + 1
            table.insert(ctx.party_members, member)
        end
    end
    
    -- === SETTINGS CACHE ===
    ctx.settings = {}
    if menu then
        -- Cache commonly accessed menu values
        local settings_map = {
            "use_last_stand", "use_shield_wall", "use_shield_block",
            "use_taunt", "use_challenging_shout", "use_thunder_clap",
            "use_demo_shout", "use_holy_shield", "use_righteous_defense",
            "use_growl", "use_challenging_roar", "use_barkskin",
        }
        for _, setting_name in ipairs(settings_map) do
            if menu[setting_name] and menu[setting_name].get_state then
                local ok, val = pcall(function() return menu[setting_name]:get_state() end)
                if ok then ctx.settings[setting_name] = val end
            end
        end
        
        -- HP thresholds
        local threshold_map = {
            last_stand_hp = "use_last_stand",
            shield_wall_hp = "use_shield_wall",
            barkskin_hp = "use_barkskin",
            frenzied_regen_hp = "use_frenzied_regen",
        }
        for threshold_name, toggle_name in pairs(threshold_map) do
            if menu[threshold_name] and menu[threshold_name].get then
                local ok, val = pcall(function() return menu[threshold_name]:get() end)
                if ok then ctx.settings[threshold_name] = val end
            end
        end
    end
    
    -- === TIME ===
    ctx.time = now
    ctx.combat_time = 0
    -- Track combat start time if available in caller
    
    -- Cache and return
    _cached_context = ctx
    _last_build_time = now
    return ctx
end

---Clear the cached context (call on zone change, etc.)
function context_builder.clear_cache()
    _cached_context = nil
    _last_build_time = 0
end

---Check if in melee range (squared distance check)
---@param me game_object
---@param target game_object
---@return boolean
function context_builder._is_melee_range(me, target)
    local dist_sq = context_builder._dist_squared(me, target)
    return dist_sq <= 25  -- 5 yards squared
end

---Calculate squared distance between two units
---@param a game_object
---@param b game_object
---@return number squared_distance
function context_builder._dist_squared(a, b)
    if not a or not b then return math.huge end
    local a_pos = a:get_position()
    local b_pos = b:get_position()
    if not a_pos or not b_pos then return math.huge end
    
    local dx = a_pos.x - b_pos.x
    local dy = a_pos.y - b_pos.y
    local dz = a_pos.z - b_pos.z
    return dx * dx + dy * dy + dz * dz
end

---Get debuff data for a target
---@param target game_object
---@param debuff_ids table Array of spell IDs
---@return table|nil debuff_data
function context_builder.get_debuff_data(target, debuff_ids)
    if not target or not target:is_valid() then return nil end
    return buff_manager:get_debuff_data(target, debuff_ids)
end

---Get buff data for a unit
---@param unit game_object
---@param buff_ids table Array of spell IDs
---@return table|nil buff_data
function context_builder.get_buff_data(unit, buff_ids)
    if not unit or not unit:is_valid() then return nil end
    return buff_manager:get_buff_data(unit, buff_ids)
end

---Count enemies within radius
---@param me game_object
---@param radius number Radius in yards
---@return number count
function context_builder.count_enemies_in_radius(me, radius)
    local radius_sq = radius * radius
    local count = 0
    local objects = core.object_manager.get_visible_objects()
    
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() then
            if me:can_attack(obj) then
                local dist_sq = context_builder._dist_squared(me, obj)
                if dist_sq <= radius_sq then
                    count = count + 1
                end
            end
        end
    end
    
    return count
end

---Get enemies classified by type
---@param me game_object
---@param radius number
---@return table counts {bosses, elites, trash}
function context_builder.count_enemies_by_class(me, radius)
    local radius_sq = radius * radius
    local counts = {bosses = 0, elites = 0, trash = 0}
    local objects = core.object_manager.get_visible_objects()
    
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() then
            if me:can_attack(obj) then
                local dist_sq = context_builder._dist_squared(me, obj)
                if dist_sq <= radius_sq then
                    local classification = obj:get_classification()
                    if classification == "worldboss" then
                        counts.bosses = counts.bosses + 1
                    elseif classification == "elite" or classification == "rareelite" then
                        counts.elites = counts.elites + 1
                    else
                        counts.trash = counts.trash + 1
                    end
                end
            end
        end
    end
    
    return counts
end

return context_builder
