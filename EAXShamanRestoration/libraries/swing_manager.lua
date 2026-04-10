-- swing_manager.lua
-- Heroic Strike / Cleave next-swing queue management for Warriors
-- Enhanced with rage prediction, swing timing, and dashboard integration
-- Ported from Flux with Sylvanas API compliance

local swing_manager = {}

-- Cache hot-path APIs at load
local _core_time = core.time
local _is_spell_ready = core.spell_book.is_spell_ready
local _is_spell_already_queued = core.spell_book.is_spell_already_queued
local _cast_spell = core.input.cast_target_spell
local _get_local_player = core.object_manager.get_local_player

-- Constants
local NEXT_SWING_WINDOW = 0.4  -- seconds before swing to queue
local DEFAULT_SWING_THRESHOLD = 0.15  -- seconds for "swing landing soon"
local RAGE_PER_SWING_BASE = 15  -- Base estimated rage per swing
local RAGE_PER_DAMAGE_UNIT = 0.5  -- Rage per point of damage (approximate)
local OFF_HAND_RAGE_PENALTY = 0.5  -- Off-hand generates 50% rage

-- Internal state
local _last_queue_time = 0
local _queued_spell_id = nil

-- Swing timing state
local _swing_state = {
    last_swing_time = 0,
    swing_speed = 2.0,
    offhand_speed = 2.0,
    last_oh_swing_time = 0,
    is_dual_wielding = false,
    haste_percent = 0,
    -- For dashboard integration
    next_swing_time = 0,
    next_oh_swing_time = 0,
    swing_progress = 0,  -- 0.0 to 1.0
    oh_swing_progress = 0,
}

-- Rage prediction state
local _rage_state = {
    last_rage = 0,
    rage_from_last_swing = 0,
    avg_rage_per_swing = RAGE_PER_SWING_BASE,
    swing_count = 0,
    total_rage_from_swings = 0,
}

-- ============================================================================
-- CORE SWING QUEUE FUNCTIONS (Existing - maintained for backward compatibility)
-- ============================================================================

function swing_manager.queue_next_swing(me, heroic_strike_id, cleave_id, rage_threshold, use_cleave, target)
    -- Nil guards
    if not me or not me:is_valid() then
        return false
    end
    
    -- Validate spell IDs
    if not heroic_strike_id then
        return false
    end
    
    -- Check rage threshold
    local ok, rage = pcall(function() return me:get_power_percentage() end)
    if not ok or not rage or rage < (rage_threshold or 50) then
        return false
    end
    
    -- Check if already queued
    if swing_manager.is_queued(heroic_strike_id) then
        return true
    end
    
    if cleave_id and swing_manager.is_queued(cleave_id) then
        return true
    end
    
    -- Determine which spell to cast
    local spell_to_cast = heroic_strike_id
    if use_cleave and cleave_id then
        spell_to_cast = cleave_id
    end
    
    -- Check if spell is ready
    local ready_ok, is_ready = pcall(_is_spell_ready, spell_to_cast)
    if not ready_ok or not is_ready then
        return false
    end
    
    -- Cast the spell (queues for next swing)
    local cast_ok = pcall(_cast_spell, spell_to_cast, target)
    if cast_ok then
        _queued_spell_id = spell_to_cast
        _last_queue_time = _core_time()
        return true
    end
    
    return false
end

function swing_manager.is_queued(spell_id)
    if not spell_id then
        return false
    end
    
    local queued_ok, is_queued = pcall(_is_spell_already_queued, spell_id)
    if queued_ok then
        return is_queued
    end
    
    return false
end

function swing_manager.get_next_swing_time(me)
    -- Nil guards
    if not me or not me:is_valid() then
        return nil
    end
    
    -- Try to use auto_attack_helper if available
    local has_helper, helper = pcall(require, "common/modules/auto_attack_helper")
    if has_helper and helper then
        local swing_ok, next_swing = pcall(helper.get_next_attack_core_time, helper, me, 1)
        if swing_ok and next_swing then
            local current_time = _core_time()
            return next_swing - current_time
        end
    end
    
    -- Fallback: estimate based on weapon speed
    local weapon_ok, main_hand = pcall(me.get_weapon_info, me, 0)  -- 0 = main hand
    if weapon_ok and main_hand and main_hand.speed then
        -- Return estimated swing time (rough approximation)
        return main_hand.speed
    end
    
    return nil
end

function swing_manager.cancel_queue(me, heroic_strike_id, cleave_id)
    -- Nil guards
    if not me or not me:is_valid() then
        return false
    end
    
    local cancelled = false
    
    -- Cancel Heroic Strike if queued
    if heroic_strike_id and swing_manager.is_queued(heroic_strike_id) then
        local cancel_ok = pcall(_cast_spell, heroic_strike_id)
        if cancel_ok then
            cancelled = true
            _queued_spell_id = nil
        end
    end
    
    -- Cancel Cleave if queued
    if cleave_id and swing_manager.is_queued(cleave_id) then
        local cancel_ok = pcall(_cast_spell, cleave_id)
        if cancel_ok then
            cancelled = true
            _queued_spell_id = nil
        end
    end
    
    return cancelled
end

-- ============================================================================
-- NEW: SWING TIMING FUNCTIONS
-- ============================================================================

--- Update swing timing information from player weapon data
-- Call this in your on_update loop to keep swing timing accurate
-- @param me Player game object
function swing_manager:update_swing(me)
    if not me or not me:is_valid() then
        return
    end
    
    local now = _core_time()
    
    -- Get main hand weapon info (0 = main hand)
    local mh_ok, mh_weapon = pcall(me.get_weapon_info, me, 0)
    if mh_ok and mh_weapon then
        _swing_state.swing_speed = mh_weapon.speed or _swing_state.swing_speed
    end
    
    -- Get off-hand weapon info (1 = off hand)
    local oh_ok, oh_weapon = pcall(me.get_weapon_info, me, 1)
    if oh_ok and oh_weapon and oh_weapon.speed then
        _swing_state.offhand_speed = oh_weapon.speed
        _swing_state.is_dual_wielding = true
    else
        _swing_state.is_dual_wielding = false
    end
    
    -- Try to get precise swing timing from auto_attack_helper
    local has_helper, helper = pcall(require, "common/modules/auto_attack_helper")
    if has_helper and helper then
        -- Get next main-hand swing time
        local mh_next_ok, mh_next = pcall(helper.get_next_attack_core_time, helper, me, 1)
        if mh_next_ok and mh_next then
            _swing_state.next_swing_time = mh_next
            -- Calculate progress (0.0 = just started, 1.0 = landing now)
            local time_until = mh_next - now
            if time_until > 0 and _swing_state.swing_speed > 0 then
                _swing_state.swing_progress = 1.0 - (time_until / _swing_state.swing_speed)
                _swing_state.swing_progress = math.max(0, math.min(1, _swing_state.swing_progress))
            else
                _swing_state.swing_progress = 0
            end
        end
        
        -- Get next off-hand swing time (if dual wielding)
        if _swing_state.is_dual_wielding then
            local oh_next_ok, oh_next = pcall(helper.get_next_attack_core_time, helper, me, 2)
            if oh_next_ok and oh_next then
                _swing_state.next_oh_swing_time = oh_next
                local oh_time_until = oh_next - now
                if oh_time_until > 0 and _swing_state.offhand_speed > 0 then
                    _swing_state.oh_swing_progress = 1.0 - (oh_time_until / _swing_state.offhand_speed)
                    _swing_state.oh_swing_progress = math.max(0, math.min(1, _swing_state.oh_swing_progress))
                else
                    _swing_state.oh_swing_progress = 0
                end
            end
        end
    end
end

--- Get time until next main-hand swing
-- @return number Time in seconds until next swing (0 if swing is ready/unknown)
function swing_manager:time_until_next_swing()
    local now = _core_time()
    local next_time = _swing_state.next_swing_time
    
    if next_time > now then
        return next_time - now
    end
    
    -- Fallback: estimate based on last known swing speed
    if _swing_state.swing_speed > 0 then
        return _swing_state.swing_speed
    end
    
    return 0
end

--- Get time until next off-hand swing (for dual-wield rage prediction)
-- @return number Time in seconds until off-hand swing
function swing_manager:time_until_offhand_swing()
    if not _swing_state.is_dual_wielding then
        return nil
    end
    
    local now = _core_time()
    local next_time = _swing_state.next_oh_swing_time
    
    if next_time > now then
        return next_time - now
    end
    
    if _swing_state.offhand_speed > 0 then
        return _swing_state.offhand_speed
    end
    
    return nil
end

--- Check if swing is landing within threshold time
-- Use this to delay abilities that would clip your auto-attack
-- @param threshold number Seconds threshold (default 0.15)
-- @return boolean True if swing landing within threshold
function swing_manager:is_swing_landing_soon(threshold)
    threshold = threshold or DEFAULT_SWING_THRESHOLD
    local time_until = self:time_until_next_swing()
    
    -- If we can't determine swing time, assume it's not landing soon
    if time_until == 0 then
        return false
    end
    
    return time_until > 0 and time_until <= threshold
end

--- Check if off-hand swing is landing soon
-- @param threshold number Seconds threshold (default 0.15)
-- @return boolean True if off-hand swing landing within threshold
function swing_manager:is_offhand_landing_soon(threshold)
    if not _swing_state.is_dual_wielding then
        return false
    end
    
    threshold = threshold or DEFAULT_SWING_THRESHOLD
    local time_until = self:time_until_offhand_swing()
    
    if not time_until or time_until == 0 then
        return false
    end
    
    return time_until > 0 and time_until <= threshold
end

--- Get current swing progress (0.0 to 1.0)
-- Useful for dashboard visualization
-- @return number Progress where 0.0 = start, 1.0 = landing
function swing_manager:get_swing_progress()
    return _swing_state.swing_progress
end

--- Get off-hand swing progress
-- @return number Progress where 0.0 = start, 1.0 = landing (nil if not dual wielding)
function swing_manager:get_offhand_progress()
    if not _swing_state.is_dual_wielding then
        return nil
    end
    return _swing_state.oh_swing_progress
end

--- Get current swing speed (affected by haste)
-- @return number Weapon speed in seconds
function swing_manager:get_swing_speed()
    return _swing_state.swing_speed
end

--- Check if player is dual wielding
-- @return boolean True if off-hand weapon equipped
function swing_manager:is_dual_wielding()
    return _swing_state.is_dual_wielding
end

-- ============================================================================
-- NEW: RAGE PREDICTION FUNCTIONS (Warrior-specific)
-- ============================================================================

--- Predict rage that will be generated from the next main-hand swing
-- Based on weapon damage, haste, and historical averages
-- @param me Player game object
-- @return number Estimated rage from next swing
function swing_manager:predict_rage(me)
    if not me or not me:is_valid() then
        return 0
    end
    
    -- Get weapon info for damage calculation
    local weapon_ok, weapon = pcall(me.get_weapon_info, me, 0)
    if not weapon_ok or not weapon then
        -- Fallback to average if we can't get weapon data
        return _rage_state.avg_rage_per_swing
    end
    
    -- Estimate rage based on weapon damage
    -- TBC rage formula: Rage = (Damage / 274.7) * 27.5 * RageConversionValue
    -- Simplified: roughly 0.5 rage per damage point for main hand
    local avg_damage = ((weapon.min_damage or 0) + (weapon.max_damage or 0)) / 2
    local predicted_rage = avg_damage * RAGE_PER_DAMAGE_UNIT
    
    -- Apply haste adjustments (faster swings = less rage per swing, but more over time)
    if _swing_state.swing_speed < 2.0 then
        -- Hasted swings generate slightly less rage per swing
        predicted_rage = predicted_rage * (0.8 + (0.2 * (_swing_state.swing_speed / 2.0)))
    end
    
    -- Clamp to reasonable bounds
    predicted_rage = math.max(5, math.min(30, predicted_rage))
    
    return predicted_rage
end

--- Predict rage from off-hand swing
-- @param me Player game object
-- @return number Estimated off-hand rage (nil if not dual wielding)
function swing_manager:predict_offhand_rage(me)
    if not me or not me:is_valid() or not _swing_state.is_dual_wielding then
        return nil
    end
    
    local weapon_ok, weapon = pcall(me.get_weapon_info, me, 1)
    if not weapon_ok or not weapon then
        return nil
    end
    
    local avg_damage = ((weapon.min_damage or 0) + (weapon.max_damage or 0)) / 2
    local predicted_rage = avg_damage * RAGE_PER_DAMAGE_UNIT * OFF_HAND_RAGE_PENALTY
    
    -- Clamp
    predicted_rage = math.max(2, math.min(15, predicted_rage))
    
    return predicted_rage
end

--- Get total predicted rage from all pending swings within time window
-- @param me Player game object
-- @param time_window number Seconds to look ahead (default: time until next MH swing)
-- @return number Total predicted rage
function swing_manager:predict_rage_in_window(me, time_window)
    if not me or not me:is_valid() then
        return 0
    end
    
    time_window = time_window or self:time_until_next_swing()
    if time_window <= 0 then
        time_window = _swing_state.swing_speed
    end
    
    local total_rage = 0
    
    -- Main hand rage
    total_rage = total_rage + self:predict_rage(me)
    
    -- Check if off-hand will land within window
    if _swing_state.is_dual_wielding then
        local oh_time = self:time_until_offhand_swing()
        if oh_time and oh_time <= time_window then
            local oh_rage = self:predict_offhand_rage(me)
            if oh_rage then
                total_rage = total_rage + oh_rage
            end
        end
    end
    
    return total_rage
end

--- Get future rage after next swing lands
-- Use this for ability planning - "will I have enough rage after my swing?"
-- @param current_rage number Current rage value
-- @param me Player game object (optional, uses cached if nil)
-- @return number Predicted rage after next swing
function swing_manager:get_future_rage(current_rage, me)
    if not me then
        me = _get_local_player()
    end
    
    if not me or not me:is_valid() then
        return current_rage
    end
    
    -- Ensure current_rage is a number
    current_rage = tonumber(current_rage) or 0
    
    -- Add predicted rage from next swing
    local predicted = self:predict_rage(me)
    local future_rage = current_rage + predicted
    
    -- Clamp to max rage (100 for warriors)
    return math.min(100, future_rage)
end

--- Get future rage after both main-hand and off-hand swings
-- @param current_rage number Current rage value
-- @param me Player game object (optional)
-- @return number Predicted rage after both swings
function swing_manager:get_future_rage_dual_wield(current_rage, me)
    if not me then
        me = _get_local_player()
    end
    
    if not me or not me:is_valid() then
        return current_rage
    end
    
    current_rage = tonumber(current_rage) or 0
    
    -- Add main hand
    local future_rage = current_rage + self:predict_rage(me)
    
    -- Add off-hand if dual wielding
    if _swing_state.is_dual_wielding then
        local oh_rage = self:predict_offhand_rage(me)
        if oh_rage then
            future_rage = future_rage + oh_rage
        end
    end
    
    return math.min(100, future_rage)
end

--- Check if ability should be delayed to avoid clipping next swing
-- Returns true if you should WAIT before casting (swing landing soon)
-- @param ability_rage_cost number Rage cost of ability you want to cast
-- @param current_rage number Current rage
-- @param threshold number Optional threshold for "soon" (default 0.15)
-- @return boolean True if you should delay the ability
function swing_manager:should_delay_for_swing(ability_rage_cost, current_rage, threshold)
    -- If we don't have enough rage anyway, no need to delay
    if current_rage < ability_rage_cost then
        return false
    end
    
    -- Check if swing is landing soon
    if self:is_swing_landing_soon(threshold) then
        -- Check if we'll have enough rage AFTER the swing
        local future_rage = self:get_future_rage(current_rage)
        if future_rage >= ability_rage_cost then
            -- We can afford it after the swing, so delay now to avoid clipping
            return true
        end
    end
    
    return false
end

--- Record actual rage gained from a swing for calibration
-- Call this when you detect rage gain from a swing
-- @param rage_gained number Amount of rage actually gained
function swing_manager:record_rage_gain(rage_gained)
    rage_gained = tonumber(rage_gained) or 0
    
    _rage_state.swing_count = _rage_state.swing_count + 1
    _rage_state.total_rage_from_swings = _rage_state.total_rage_from_swings + rage_gained
    _rage_state.rage_from_last_swing = rage_gained
    
    -- Update rolling average
    if _rage_state.swing_count > 0 then
        _rage_state.avg_rage_per_swing = _rage_state.total_rage_from_swings / _rage_state.swing_count
    end
    
    -- Keep array size manageable (last 50 swings)
    if _rage_state.swing_count > 50 then
        _rage_state.swing_count = 25
        _rage_state.total_rage_from_swings = _rage_state.avg_rage_per_swing * 25
    end
end

--- Get average rage per swing from historical data
-- @return number Average rage generated per swing
function swing_manager:get_avg_rage_per_swing()
    return _rage_state.avg_rage_per_swing
end

-- ============================================================================
-- NEW: DASHBOARD INTEGRATION
-- ============================================================================

--- Get swing data formatted for dashboard display
-- Returns a table with all swing timing info for visualization
-- @return table Swing data for dashboard
function swing_manager:get_dashboard_data()
    return {
        -- Timing
        time_until_swing = self:time_until_next_swing(),
        time_until_offhand = self:time_until_offhand_swing(),
        swing_speed = _swing_state.swing_speed,
        offhand_speed = _swing_state.offhand_speed,
        
        -- Progress (0.0 to 1.0 for bars)
        swing_progress = _swing_state.swing_progress,
        offhand_progress = _swing_state.oh_swing_progress,
        
        -- State
        is_dual_wielding = _swing_state.is_dual_wielding,
        is_swing_landing_soon = self:is_swing_landing_soon(),
        
        -- Rage prediction
        predicted_rage = _rage_state.avg_rage_per_swing,
    }
end

--- Update dashboard swing timer bar
-- Call this from your dashboard update to sync swing display
-- @param dashboard_module table The dashboard module instance
function swing_manager:update_dashboard(dashboard_module)
    if not dashboard_module or not dashboard_module._timer_bars then
        return
    end
    
    local time_until = self:time_until_next_swing()
    
    if time_until > 0 and _swing_state.swing_speed > 0 then
        dashboard_module._timer_bars.swing.active = true
        dashboard_module._timer_bars.swing.remaining = time_until
        dashboard_module._timer_bars.swing.total = _swing_state.swing_speed
    else
        dashboard_module._timer_bars.swing.active = false
        dashboard_module._timer_bars.swing.remaining = 0
    end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Reset all swing tracking state
-- Call this on stance changes, weapon swaps, or when entering combat
function swing_manager:reset()
    _swing_state.last_swing_time = 0
    _swing_state.next_swing_time = 0
    _swing_state.next_oh_swing_time = 0
    _swing_state.swing_progress = 0
    _swing_state.oh_swing_progress = 0
    _queued_spell_id = nil
end

--- Get debug info for troubleshooting
-- @return table Debug information
function swing_manager:get_debug_info()
    return {
        swing_state = _swing_state,
        rage_state = _rage_state,
        queued_spell = _queued_spell_id,
        last_queue_time = _last_queue_time,
    }
end

--- Check if an ability would clip the next auto-attack
-- More detailed version of should_delay_for_swing with reasoning
-- @param cast_time number Cast time of ability (default 0 for instant)
-- @param threshold number Safety buffer in seconds (default 0.15)
-- @return boolean would_clip, number time_until_swing
function swing_manager:would_clip_swing(cast_time, threshold)
    cast_time = cast_time or 0
    threshold = threshold or DEFAULT_SWING_THRESHOLD
    
    local time_until = self:time_until_next_swing()
    
    -- If we don't know when swing is, assume no clipping
    if time_until <= 0 then
        return false, 0
    end
    
    -- Ability would clip if: cast_time > time_until - threshold
    local would_clip = cast_time > (time_until - threshold)
    
    return would_clip, time_until
end

return swing_manager
