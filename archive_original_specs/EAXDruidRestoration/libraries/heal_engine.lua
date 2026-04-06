-- heal_engine.lua
-- Shared healer friend scan with effective HP scoring for Project Sylvanas.

---@type unit_helper
local unit_helper = require("common/utility/unit_helper")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local heal_engine = {}

local ABSORB_SCALAR = 0.25
local SCAN_RANGE = 60.0
local BUILD_INTERVAL = 0.10

heal_engine.friends = {}

local last_build_time = 0
local tank_priority_weight = 0.08

local function clamp01(value)
    local n = tonumber(value) or 0
    if n < 0 then
        return 0
    end
    if n > 1 then
        return 1
    end
    return n
end

local function safe_number(unit, method_name)
    if not unit then
        return 0
    end

    local method = unit[method_name]
    if type(method) ~= "function" then
        return 0
    end

    local ok, value = pcall(method, unit)
    if not ok then
        return 0
    end

    return tonumber(value) or 0
end

local function safe_position(unit)
    if not unit then
        return nil
    end

    local method = unit.get_position
    if type(method) ~= "function" then
        return nil
    end

    local ok, value = pcall(method, unit)
    if ok then
        return value
    end

    return nil
end

function heal_engine.get_raw_hp_pct(unit)
    local max_hp = safe_number(unit, "get_max_health")
    if max_hp <= 0 then
        return 1.0
    end

    return clamp01(safe_number(unit, "get_health") / max_hp)
end

function heal_engine.get_incoming_heal_pct(unit)
    local max_hp = safe_number(unit, "get_max_health")
    if max_hp <= 0 then
        return 0
    end

    return clamp01(safe_number(unit, "get_incoming_heals") / max_hp)
end

function heal_engine.get_effective_hp_pct(unit)
    local max_hp = safe_number(unit, "get_max_health")
    if max_hp <= 0 then
        return 1.0
    end

    local current_hp = safe_number(unit, "get_health")
    local incoming_heals = safe_number(unit, "get_incoming_heals")
    local shields = safe_number(unit, "get_total_shield") * ABSORB_SCALAR
    local heal_absorbs = safe_number(unit, "get_total_heal_absorbs")
    local effective_hp = current_hp + incoming_heals + shields - heal_absorbs

    return clamp01(effective_hp / max_hp)
end

function heal_engine.get_priority_hp_pct(unit, is_tank)
    local effective_hp_pct = heal_engine.get_effective_hp_pct(unit)
    if is_tank then
        return clamp01(effective_hp_pct - tank_priority_weight)
    end
    return effective_hp_pct
end

function heal_engine.make_member(unit, opts)
    if not unit or not unit.is_valid or not unit:is_valid() or unit:is_dead() then
        return nil
    end

    opts = opts or {}
    local is_tank = opts.is_tank == true
    local raw_hp_pct = heal_engine.get_raw_hp_pct(unit)
    local eff_hp_pct = heal_engine.get_effective_hp_pct(unit)
    local priority_hp_pct = heal_engine.get_priority_hp_pct(unit, is_tank)

    return {
        guid = opts.guid,
        unit = unit,
        hp_pct = eff_hp_pct,
        raw_hp_pct = raw_hp_pct,
        eff_hp_pct = eff_hp_pct,
        priority_hp_pct = priority_hp_pct,
        incoming_heal_pct = heal_engine.get_incoming_heal_pct(unit),
        role = opts.role or (is_tank and "tank") or "damager",
        is_tank = is_tank,
    }
end

function heal_engine.make_snapshot(unit, opts)
    opts = opts or {}
    local is_tank = opts.is_tank == true
    return {
        hp_pct = heal_engine.get_effective_hp_pct(unit),
        raw_hp_pct = heal_engine.get_raw_hp_pct(unit),
        eff_hp_pct = heal_engine.get_effective_hp_pct(unit),
        priority_hp_pct = heal_engine.get_priority_hp_pct(unit, is_tank),
        incoming_heal_pct = heal_engine.get_incoming_heal_pct(unit),
        collapse_risk = opts.collapse_risk == true,
        group_count = tonumber(opts.group_count) or 0,
    }
end

local function compare_friends(a, b)
    local a_priority = tonumber(a and a.priority_hp_pct) or 1
    local b_priority = tonumber(b and b.priority_hp_pct) or 1
    if a_priority ~= b_priority then
        return a_priority < b_priority
    end

    local a_effective = tonumber(a and a.eff_hp_pct) or 1
    local b_effective = tonumber(b and b.eff_hp_pct) or 1
    if a_effective ~= b_effective then
        return a_effective < b_effective
    end

    local a_incoming = tonumber(a and a.incoming_heal_pct) or 0
    local b_incoming = tonumber(b and b.incoming_heal_pct) or 0
    return a_incoming < b_incoming
end

function heal_engine.update(me, opts)
    opts = opts or {}

    local now = core.time()
    local build_interval = tonumber(opts.build_interval_s) or BUILD_INTERVAL
    if opts.force ~= true and (now - last_build_time) < build_interval then
        return
    end
    last_build_time = now

    if opts.tank_priority_weight ~= nil then
        tank_priority_weight = (tonumber(opts.tank_priority_weight) or tank_priority_weight)
    end

    local friends = heal_engine.friends
    for i = #friends, 1, -1 do
        friends[i] = nil
    end

    if not me or type(me.get_position) ~= "function" then
        return
    end

    local allies = unit_helper:get_ally_list_around(
        me:get_position(),
        tonumber(opts.scan_range) or SCAN_RANGE,
        true,
        true
    ) or {}

    local count = 0
    for _, ally in ipairs(allies) do
        if ally and ally:is_valid() and not ally:is_dead() then
            local is_tank = unit_helper:is_tank(ally) == true
            local raw_hp_pct = heal_engine.get_raw_hp_pct(ally)
            local incoming_heal_pct = heal_engine.get_incoming_heal_pct(ally)
            local effective_hp_pct = heal_engine.get_effective_hp_pct(ally)
            local priority_hp_pct = heal_engine.get_priority_hp_pct(ally, is_tank)

            count = count + 1
            friends[count] = {
                unit = ally,
                hp_pct = raw_hp_pct,
                raw_hp_pct = raw_hp_pct,
                incoming_heal_pct = incoming_heal_pct,
                eff_hp_pct = effective_hp_pct,
                priority_hp_pct = priority_hp_pct,
                eff_pct = priority_hp_pct,
                is_tank = is_tank,
                role = is_tank and "tank" or "damager",
                pos = safe_position(ally),
            }
        end
    end

    table.sort(friends, compare_friends)
end

function heal_engine.lowest_friend()
    local entry = heal_engine.friends[1]
    return entry and entry.unit or nil
end

function heal_engine.lowest_tank()
    for _, entry in ipairs(heal_engine.friends) do
        if entry.is_tank then
            return entry.unit
        end
    end
    return nil
end

function heal_engine.count_below(threshold)
    threshold = clamp01(threshold or 1)
    local count = 0
    for _, entry in ipairs(heal_engine.friends) do
        if (entry.eff_pct or 1) <= threshold then
            count = count + 1
        else
            break
        end
    end
    return count
end

function heal_engine.size()
    return #heal_engine.friends
end

function heal_engine.get_eff_pct(unit)
    if not unit then
        return 1.0
    end

    for _, entry in ipairs(heal_engine.friends) do
        if entry.unit == unit then
            return entry.eff_pct or 1.0
        end
    end

    return heal_engine.get_priority_hp_pct(unit, unit_helper:is_tank(unit) == true)
end

function heal_engine.find_without_buff(buff_id_table, max_pct, skip_tanks)
    max_pct = clamp01(max_pct or 1.0)
    for _, entry in ipairs(heal_engine.friends) do
        if (entry.eff_pct or 1) > max_pct then
            break
        end

        if not (skip_tanks and entry.is_tank) then
            local data = buff_manager:get_buff_data(entry.unit, buff_id_table)
            if not (data and data.is_active) then
                return entry.unit
            end
        end
    end
    return nil
end

function heal_engine.has_critical(threshold)
    local entry = heal_engine.friends[1]
    return entry ~= nil and (entry.eff_pct or 1) < clamp01(threshold or 0)
end

function heal_engine.cluster_center(n_targets)
    n_targets = n_targets or 3
    local sum_x, sum_y, sum_z, count = 0, 0, 0, 0
    for i, entry in ipairs(heal_engine.friends) do
        if i > n_targets then
            break
        end

        local pos = entry.pos
        if pos then
            sum_x = sum_x + pos.x
            sum_y = sum_y + pos.y
            sum_z = sum_z + pos.z
            count = count + 1
        end
    end

    if count == 0 then
        return nil
    end

    local cx, cy, cz = sum_x / count, sum_y / count, sum_z / count
    local vec3_g = rawget(_G, "vec3")
    if vec3_g and type(vec3_g.new) == "function" then
        local ok, result = pcall(vec3_g.new, cx, cy, cz)
        if ok and result then
            return result
        end
    end

    return { x = cx, y = cy, z = cz }
end

function heal_engine.set_tank_priority(weight_pct)
    tank_priority_weight = (tonumber(weight_pct) or 0) / 100.0
end

-- ============================================================================
-- FLUX ADAPTATION: Damage Prediction and Effective Deficit
-- Proactive healing based on encounter timers and incoming damage prediction
-- ============================================================================

local prediction_cache = {}
local last_prediction_time = 0
local PREDICTION_CACHE_DURATION = 0.5  -- 500ms throttle

--- Estimate incoming damage from BigWigs encounter timers
---@param unit game_object Unit to check
---@param time_horizon_seconds number How far ahead to look (default 3 seconds)
---@return number predicted_damage_pct Predicted damage as HP percentage
local function estimate_damage_from_encounter(unit, time_horizon_seconds)
    if not unit or not unit.is_valid or not unit:is_valid() then
        return 0
    end
    
    local horizon = tonumber(time_horizon_seconds) or 3.0
    local total_damage_pct = 0
    
    -- Try BigWigs API (encounter timer based prediction)
    local ok, bigwigs = pcall(function() return core.addons.bigwigs end)
    if ok and bigwigs and bigwigs.get_bars then
        local bars = bigwigs:get_bars() or {}
        
        for _, bar in ipairs(bars) do
            if bar and bar.remaining and bar.remaining <= horizon then
                -- Check if this ability targets our unit
                local is_targeted = false
                
                -- Common dangerous ability patterns
                local dangerous_patterns = {
                    "damage", "aoe", "raid", "tank", "cleave", "breath",
                    "slash", "strike", "blow", "impact", "explosion"
                }
                
                local bar_text = string.lower(bar.text or "")
                for _, pattern in ipairs(dangerous_patterns) do
                    if string.find(bar_text, pattern, 1, true) then
                        is_targeted = true
                        break
                    end
                end
                
                if is_targeted then
                    -- Estimate damage based on ability type (conservative estimates)
                    local estimated_damage_pct = 15  -- Default 15% HP
                    
                    if string.find(bar_text, "tank", 1, true) or 
                       string.find(bar_text, "breath", 1, true) or
                       string.find(bar_text, "cleave", 1, true) then
                        estimated_damage_pct = 35  -- Tank busters hit hard
                    elseif string.find(bar_text, "aoe", 1, true) or
                           string.find(bar_text, "raid", 1, true) then
                        estimated_damage_pct = 25  -- Raid-wide AoE
                    end
                    
                    -- Scale by urgency (closer = more certain)
                    local urgency_factor = 1.0 - (bar.remaining / horizon)
                    total_damage_pct = total_damage_pct + (estimated_damage_pct * urgency_factor)
                end
            end
        end
    end
    
    return math.min(total_damage_pct, 100)  -- Cap at 100%
end

--- Estimate damage from recent damage patterns (health prediction module)
---@param unit game_object Unit to check
---@param time_horizon_seconds number How far ahead to look
---@return number predicted_damage_pct Predicted damage as HP percentage
local function estimate_damage_from_patterns(unit, time_horizon_seconds)
    if not unit or not unit.is_valid or not unit:is_valid() then
        return 0
    end
    
    -- Try health_prediction module if available
    local ok, hp_module = pcall(require, "common/modules/health_prediction")
    if ok and hp_module and hp_module.predict_damage then
        local horizon = tonumber(time_horizon_seconds) or 3.0
        local damage = hp_module:predict_damage(unit, horizon)
        
        if damage and damage > 0 then
            local max_hp = safe_number(unit, "get_max_health")
            if max_hp > 0 then
                return (damage / max_hp) * 100
            end
        end
    end
    
    return 0
end

--- Predict effective HP deficit incorporating incoming heals and predicted damage
--- Ported from Flux predict_effective_deficit()
---@param unit game_object Unit to analyze
---@param time_horizon_seconds number How far ahead to predict (default 2 seconds for heal cast time)
---@return number deficit_pct Predicted HP deficit (0-1)
---@return number confidence_score 0-1 indicating prediction reliability
function heal_engine.predict_effective_deficit(unit, time_horizon_seconds)
    if not unit or not unit.is_valid or not unit:is_valid() then
        return 0, 0
    end
    
    local horizon = tonumber(time_horizon_seconds) or 2.0
    
    -- Check cache
    local now = core.time()
    local guid = ""
    local ok, val = pcall(function() return unit:get_guid() end)
    if ok and val then guid = tostring(val) end
    
    local cache_key = guid .. "_" .. math.floor(horizon * 10)
    if prediction_cache[cache_key] then
        local cached = prediction_cache[cache_key]
        if (now - cached.timestamp) < PREDICTION_CACHE_DURATION then
            return cached.deficit, cached.confidence
        end
    end
    
    -- Get current effective HP
    local current_eff_hp_pct = heal_engine.get_effective_hp_pct(unit)
    
    -- Predict incoming damage from multiple sources
    local encounter_damage = estimate_damage_from_encounter(unit, horizon)
    local pattern_damage = estimate_damage_from_patterns(unit, horizon)
    
    -- Use highest prediction source
    local predicted_damage = math.max(encounter_damage, pattern_damage)
    
    -- Calculate confidence based on data source
    local confidence = 0.3  -- Base confidence
    if encounter_damage > 0 then
        confidence = 0.8  -- High confidence from encounter timers
    elseif pattern_damage > 0 then
        confidence = 0.5  -- Medium confidence from patterns
    end
    
    -- Calculate predicted effective HP after damage
    local predicted_eff_hp_pct = current_eff_hp_pct - (predicted_damage / 100)
    predicted_eff_hp_pct = clamp01(predicted_eff_hp_pct)
    
    -- Deficit is how much HP we'll need (0 = full, 1 = empty)
    local deficit_pct = 1.0 - predicted_eff_hp_pct
    
    -- Cache result
    prediction_cache[cache_key] = {
        deficit = deficit_pct,
        confidence = confidence,
        timestamp = now
    }
    
    -- Cleanup old cache entries periodically
    if (now - last_prediction_time) > 10 then
        last_prediction_time = now
        for key, entry in pairs(prediction_cache) do
            if (now - entry.timestamp) > 5 then
                prediction_cache[key] = nil
            end
        end
    end
    
    return deficit_pct, confidence
end

--- Get predicted effective HP percentage (convenience wrapper)
---@param unit game_object Unit to analyze
---@param time_horizon_seconds number Prediction window
---@return number predicted_hp_pct 0-1
function heal_engine.get_predicted_hp_pct(unit, time_horizon_seconds)
    local deficit, _ = heal_engine.predict_effective_deficit(unit, time_horizon_seconds)
    return 1.0 - deficit
end

--- Check if unit will need healing within prediction window
---@param unit game_object Unit to check
---@param threshold_pct number HP threshold to trigger (default 0.75)
---@param time_horizon_seconds number Prediction window
---@return boolean will_need_heal
---@return number predicted_hp_pct
function heal_engine.will_need_heal(unit, threshold_pct, time_horizon_seconds)
    local threshold = tonumber(threshold_pct) or 0.75
    local predicted_hp = heal_engine.get_predicted_hp_pct(unit, time_horizon_seconds)
    return predicted_hp < threshold, predicted_hp
end

return heal_engine
