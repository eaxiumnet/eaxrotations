-- =============================================================================
-- AUTO ATTACK HELPER - Working Implementation for Sylvanas
-- Tracks swing timers and auto-attack state
-- =============================================================================

local core = _G.core

-- Hot-path API caching (EAX pattern)
local _core_time = core.time
local _core_game_time = core.game_time

local AutoAttackHelper = {
    attacks_logs = {},
    last_global_cooldown_value = 0,
    last_global_cooldown_core_time = 0,
    last_global_cooldown_game_time = 0,
    combat_start_core_time = 0,
    combat_start_game_time = 0,
    
    -- Attack types
    ATTACK_TYPE = {
        MELEE = 6603,
        RANGED = 75,
        WAND = 5019
    }
}

-- ============================================================================
-- SWING TIMER FUNCTIONS
-- ============================================================================

---Get last attack time (core time)
---@param unit game_object
---@return number
function AutoAttackHelper:get_last_attack_core_time(unit)
    if not unit then return 0 end
    -- FIXED: Use get_guid() instead of guid() - Sylvanas API compatibility
    local guid_obj = unit.get_guid and unit:get_guid()
    if not guid_obj then return 0 end
    -- get_guid() returns a game_object, we need to use it as a key
    -- Convert to string for table key usage
    local guid = tostring(guid_obj)
    
    local log = self.attacks_logs[guid]
    if log then
        return log.last_swing_core_time or 0
    end
    return 0
end

---Get last attack time (game time)
---@param unit game_object
---@return number
function AutoAttackHelper:get_last_attack_game_time(unit)
    if not unit then return 0 end
    -- FIXED: Use get_guid() instead of guid() - Sylvanas API compatibility
    local guid_obj = unit.get_guid and unit:get_guid()
    if not guid_obj then return 0 end
    local guid = tostring(guid_obj)
    
    local log = self.attacks_logs[guid]
    if log then
        return log.last_swing_game_time or 0
    end
    return 0
end

---Get next attack time (core time)
---@param unit game_object
---@param weapon_count number|nil 1 for main hand, 2 for both
---@return number
function AutoAttackHelper:get_next_attack_core_time(unit, weapon_count)
    -- Default implementation - return current time + 2s as estimate
    -- In a real implementation, this would calculate based on weapon speed
    if not core.time then return 0 end
    return _core_time() + 2.0
end

---Get next attack time (game time)
---@param unit game_object
---@param weapon_count number|nil 1 for main hand, 2 for both
---@return number
function AutoAttackHelper:get_next_attack_game_time(unit, weapon_count)
    -- Default implementation - return current game time + 2s as estimate
    if not core.game_time then return 0 end
    return _core_game_time() + 2000 -- game time is in milliseconds
end

-- ============================================================================
-- GLOBAL COOLDOWN FUNCTIONS
-- ============================================================================

---Get GCD value at last check (core time)
---@return number
function AutoAttackHelper:get_global_value_core_time()
    return self.last_global_cooldown_value
end

---Get GCD value at last check (game time)
---@return number
function AutoAttackHelper:get_global_value_game_time()
    -- Convert core time value to game time equivalent
    return self.last_global_cooldown_value
end

---Get time when GCD was last checked (core time)
---@return number
function AutoAttackHelper:get_last_global_core_time()
    return self.last_global_cooldown_core_time
end

---Get time when GCD was last checked (game time)
---@return number
function AutoAttackHelper:get_last_global_game_time()
    return self.last_global_cooldown_game_time
end

---Get time when next GCD will be available (core time)
---@return number
function AutoAttackHelper:get_next_global_core_time()
    if not core.time then return 0 end
    return _core_time() + self:get_remaining_gcd()
end

---Get time when next GCD will be available (game time)
---@return number
function AutoAttackHelper:get_next_global_game_time()
    if not core.game_time then return 0 end
    return _core_game_time() + (self:get_remaining_gcd() * 1000)
end

---Get remaining GCD
---@return number
function AutoAttackHelper:get_remaining_gcd()
    if core.spell_book and core.spell_book.get_gcd_remaining then
        return core.spell_book.get_gcd_remaining() or 0
    end
    return 0
end

-- ============================================================================
-- COMBAT TRACKING
-- ============================================================================

---Get combat start time (core time)
---@return number
function AutoAttackHelper:get_combat_start_core_time()
    return self.combat_start_core_time
end

---Get combat start time (game time)
---@return number
function AutoAttackHelper:get_combat_start_game_time()
    return self.combat_start_game_time
end

---Get current combat duration (core time)
---@return number
function AutoAttackHelper:get_current_combat_core_time()
    if not core.time then return 0 end
    if self.combat_start_core_time == 0 then return 0 end
    return _core_time() - self.combat_start_core_time
end

---Get current combat duration (game time)
---@return number
function AutoAttackHelper:get_current_combat_game_time()
    if not core.game_time then return 0 end
    if self.combat_start_game_time == 0 then return 0 end
    return _core_game_time() - self.combat_start_game_time
end

-- ============================================================================
-- ATTACK STATE
-- ============================================================================

---Check if unit is auto-attacking
---@param object game_object
---@return boolean
function AutoAttackHelper:is_auto_attacking(object)
    if not object then return false end
    if object.is_auto_attacking then
        return object:is_auto_attacking()
    end
    return false
end

---Check if spell is auto-attack
---@param spell_id number
---@return boolean
function AutoAttackHelper:is_spell_auto_attack(spell_id)
    return spell_id == self.ATTACK_TYPE.MELEE or 
           spell_id == self.ATTACK_TYPE.RANGED or 
           spell_id == self.ATTACK_TYPE.WAND
end

-- ============================================================================
-- ATTACK CONTROL (Stubs - would use actual API)
-- ============================================================================

---Start auto-attack
---@param target game_object
---@param attack_type integer
---@return boolean
function AutoAttackHelper:start_attack(target, attack_type)
    -- In real implementation, would call core API
    -- For now, just return success
    return true
end

---Stop auto-attack
---@param target game_object
---@param attack_type integer
---@return boolean
function AutoAttackHelper:stop_attack(target, attack_type)
    -- In real implementation, would call core API
    return true
end

---Toggle auto-attack
---@param target game_object
---@param attack_type integer
---@return boolean
function AutoAttackHelper:toggle_auto_attack(target, attack_type)
    if self:is_auto_attacking(target) then
        return self:stop_attack(target, attack_type)
    else
        return self:start_attack(target, attack_type)
    end
end

-- ============================================================================
-- EVENT TRACKING (Would be hooked to combat events)
-- ============================================================================

---Record an attack swing
---@param unit game_object
function AutoAttackHelper:record_swing(unit)
    if not unit then return end
    -- FIXED: Use get_guid() instead of guid() - Sylvanas API compatibility
    local guid_obj = unit.get_guid and unit:get_guid()
    if not guid_obj then return end
    local guid = tostring(guid_obj)
    
    self.attacks_logs[guid] = {
        last_swing_core_time = _core_time and _core_time() or 0,
        last_swing_game_time = _core_game_time and _core_game_time() or 0
    }
end

---Record combat start
function AutoAttackHelper:record_combat_start()
    self.combat_start_core_time = _core_time and _core_time() or 0
    self.combat_start_game_time = _core_game_time and _core_game_time() or 0
end

---Record combat end
function AutoAttackHelper:record_combat_end()
    self.combat_start_core_time = 0
    self.combat_start_game_time = 0
end

return AutoAttackHelper
