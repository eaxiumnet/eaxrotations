-- libraries/smart_defensive.lua
-- Smart defensive cooldown management for EAX tanking specs
-- Uses combat_forecast for predictive mitigation

---@type combat_forecast
local combat_forecast = require("combat_forecast")

local smart_defensive = {}

-- Constants
smart_defensive.BURST_PREDICTION_WINDOW = 3  -- seconds
smart_defensive.MULTI_TARGET_THRESHOLD = 3   -- enemies for lenient thresholds
smart_defensive.MITIGATION_LOOKUP = {
    -- Warrior stances
    defensive = 0.10,  -- 10% damage reduction
    battle = 0,
    berserker = 0,
    -- Druid forms (no built-in mitigation from form alone)
    bear = 0,
    dire_bear = 0,
    -- Paladin (no stance mitigation)
}

---Predict if burst damage is incoming
---Uses combat_forecast to analyze incoming damage trends
---@param me game_object
---@param window_seconds number Prediction window (default 3s)
---@return boolean is_burst_incoming
---@return number predicted_damage
---@return number incoming_dps
function smart_defensive.predict_burst(me, window_seconds)
    if not me or not me:is_valid() then return false, 0, 0 end
    
    window_seconds = window_seconds or smart_defensive.BURST_PREDICTION_WINDOW
    
    -- Get combat forecast
    local ok, forecast = pcall(function() 
        return combat_forecast:get_forecast_single(me, true) 
    end)
    
    if not ok or not forecast then 
        return false, 0, 0 
    end
    
    local incoming_dps = forecast.incoming_dps or 0
    local time_to_die = forecast.time_to_die or 999
    
    -- Get current mitigation
    local mitigation = smart_defensive.get_current_mitigation(me)
    
    -- Predict damage in window
    local predicted_damage = incoming_dps * window_seconds * (1 - mitigation)
    local hp = me:get_health()
    local max_hp = me:get_max_health()
    local hp_pct = (hp / max_hp) * 100
    
    -- Check if predicted damage would be dangerous
    local damage_pct = (predicted_damage / max_hp) * 100
    
    -- Burst detection criteria:
    -- 1. High incoming DPS relative to health pool
    -- 2. Short time to die
    -- 3. Predicted damage would drop us below critical threshold
    local is_burst = false
    
    if incoming_dps > 0 then
        -- Condition 1: Predicted damage significant (>15% of max HP in window)
        if damage_pct > 15 then
            is_burst = true
        end
        
        -- Condition 2: Time to die is short (< 5 seconds)
        if time_to_die < 5 then
            is_burst = true
        end
        
        -- Condition 3: Would drop below 25% HP
        if hp_pct - damage_pct < 25 then
            is_burst = true
        end
    end
    
    return is_burst, predicted_damage, incoming_dps
end

---Get current damage mitigation from stances/buffs
---@param me game_object
---@return number mitigation_percentage (0.0 - 1.0)
function smart_defensive.get_current_mitigation(me)
    if not me or not me:is_valid() then return 0 end
    
    local mitigation = 0
    
    -- Check for defensive stance (Warrior)
    if me.has_aura then
        if me:has_aura(71) then  -- Defensive Stance
            mitigation = mitigation + 0.10  -- 10% DR
        end
    end
    
    -- Check for Shield Block buff (Warrior)
    if me.has_aura then
        if me:has_aura(2565) then  -- Shield Block
            mitigation = mitigation + 0.20  -- Estimated 20% from blocking
        end
    end
    
    return mitigation
end

---Count nearby enemies
---@param me game_object
---@param radius number Radius in yards (default 10)
---@return number count
function smart_defensive.count_nearby_enemies(me, radius)
    if not me or not me:is_valid() then return 0 end
    
    radius = radius or 10
    local radius_sq = radius * radius
    local count = 0
    
    local my_pos = me:get_position()
    if not my_pos then return 0 end
    
    local objects = core.object_manager.get_visible_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() then
            if me:can_attack(obj) then
                local obj_pos = obj:get_position()
                if obj_pos then
                    local dx = obj_pos.x - my_pos.x
                    local dy = obj_pos.y - my_pos.y
                    local dz = obj_pos.z - my_pos.z
                    local dist_sq = dx*dx + dy*dy + dz*dz
                    
                    if dist_sq <= radius_sq then
                        count = count + 1
                    end
                end
            end
        end
    end
    
    return count
end

---Should use defensive cooldown?
---Enhanced logic with predictive mitigation and multi-target awareness
---@param me game_object
---@param defensive_type string ("last_stand", "shield_wall", "barkskin", "frenzied_regen", etc.)
---@param ctx table Context from context_builder
---@param settings table Settings with thresholds
---@return boolean should_use
---@return string|nil reason
function smart_defensive.should_use(me, defensive_type, ctx, settings)
    if not me or not me:is_valid() then return false, "invalid_player" end
    
    local hp_pct = me:get_health_percentage()
    local base_threshold = settings[defensive_type .. "_hp"] or 25
    
    -- Basic HP threshold check
    if hp_pct > base_threshold then
        return false, "hp_above_threshold"
    end
    
    -- Predictive: check if burst is incoming
    local burst_incoming, predicted_dmg, incoming_dps = smart_defensive.predict_burst(me)
    
    if burst_incoming then
        -- Use defensively BEFORE the damage
        return true, "burst_predicted"
    end
    
    -- Multi-target adjustment
    local enemy_count = ctx.enemy_count or smart_defensive.count_nearby_enemies(me, 10)
    if enemy_count >= smart_defensive.MULTI_TARGET_THRESHOLD then
        -- More lenient with multiple targets
        if hp_pct < base_threshold + 10 then
            return true, "multi_target"
        end
    end
    
    -- Check if already buffed with similar effect
    if smart_defensive.has_similar_buff(me, defensive_type) then
        return false, "already_buffed"
    end
    
    -- Check Forbearance (Paladin)
    if defensive_type == "divine_shield" or defensive_type == "lay_on_hands" then
        if me.has_aura and me:has_aura(25771) then  -- Forbearance
            return false, "forbearance"
        end
    end
    
    -- Stance checks for Warrior
    if defensive_type == "shield_wall" then
        -- Shield Wall requires Defensive Stance
        local in_defensive = false
        if me.has_aura then
            in_defensive = me:has_aura(71)  -- Defensive Stance
        end
        if not in_defensive then
            return false, "wrong_stance"
        end
    end
    
    -- Standard HP threshold trigger
    return hp_pct <= base_threshold, "hp_threshold"
end

---Check if player already has a similar defensive buff
---@param me game_object
---@param defensive_type string
---@return boolean has_similar
function smart_defensive.has_similar_buff(me, defensive_type)
    if not me or not me:is_valid() then return false end
    if not me.has_aura then return false end
    
    -- Last Stand check
    if defensive_type == "last_stand" then
        return me:has_aura(12975)  -- Last Stand buff
    end
    
    -- Shield Wall check
    if defensive_type == "shield_wall" then
        return me:has_aura(871)  -- Shield Wall buff
    end
    
    -- Barkskin check
    if defensive_type == "barkskin" then
        return me:has_aura(22812)  -- Barkskin buff
    end
    
    -- Frenzied Regeneration check
    if defensive_type == "frenzied_regen" then
        return me:has_aura(22842)  -- Frenzied Regeneration buff
    end
    
    -- Divine Shield check
    if defensive_type == "divine_shield" then
        return me:has_aura(642)  -- Divine Shield
    end
    
    return false
end

---Get recommended defensive action
---Evaluates all available defensives and returns the best one to use
---@param me game_object
---@param ctx table Context
---@param available_defensives table Array of {type, spell_id, priority}
---@param settings table Settings
---@return string|nil best_defensive
---@return number|nil spell_id
---@return string|nil reason
function smart_defensive.get_recommended_defensive(me, ctx, available_defensives, settings)
    if not me or not me:is_valid() then return nil, nil, "invalid_player" end
    
    local hp_pct = me:get_health_percentage()
    local enemy_count = ctx.enemy_count or smart_defensive.count_nearby_enemies(me, 10)
    
    -- Sort by priority
    local sorted = {}
    for _, def in ipairs(available_defensives) do
        table.insert(sorted, def)
    end
    table.sort(sorted, function(a, b) return (a.priority or 0) > (b.priority or 0) end)
    
    -- Check each defensive in priority order
    for _, def in ipairs(sorted) do
        local should_use, reason = smart_defensive.should_use(me, def.type, ctx, settings)
        if should_use then
            return def.type, def.spell_id, reason
        end
    end
    
    return nil, nil, "none_needed"
end

---PvP: Should switch to defensive stance when kiting?
---@param me game_object
---@param ctx table Context
---@param settings table
---@return boolean should_switch
function smart_defensive.should_defensive_stance_pvp(me, ctx, settings)
    if not me or not me:is_valid() then return false end
    if not ctx.is_pvp then return false end
    
    -- Check if enabled in settings
    local enabled = settings.pvp_defensive_stance_at_range
    if not enabled then return false end
    
    -- Only when not in melee range
    if ctx.in_melee_range then return false end
    
    -- Check current stance
    local in_defensive = false
    if me.has_aura then
        in_defensive = me:has_aura(71)  -- Defensive Stance
    end
    if in_defensive then return false end
    
    -- Only when Intercept is on cooldown (can't gap close)
    local intercept_cd = smart_defensive.get_spell_cooldown(20252)  -- Intercept
    if intercept_cd <= 0 then return false end
    
    return true
end

---Helper to get spell cooldown
---@param spell_id number
---@return number cooldown_remaining
function smart_defensive.get_spell_cooldown(spell_id)
    if not spell_id then return 0 end
    local ok, cd = pcall(function() 
        return core.spell_book.get_spell_cooldown(spell_id) 
    end)
    if ok then return cd end
    return 0
end

---Get defensive status summary
---@param me game_object
---@param ctx table
---@return table status
function smart_defensive.get_status(me, ctx)
    local burst, predicted, dps = smart_defensive.predict_burst(me)
    local enemy_count = smart_defensive.count_nearby_enemies(me, 10)
    local mitigation = smart_defensive.get_current_mitigation(me)
    
    return {
        hp_pct = me:get_health_percentage(),
        burst_predicted = burst,
        predicted_damage = predicted,
        incoming_dps = dps,
        enemy_count = enemy_count,
        mitigation = mitigation,
    }
end

return smart_defensive
