-- libraries/force_commands.lua
-- Force command system for burst/defensive mode activation
-- Note: Project Sylvanas does not support slash commands (/eax burst)
-- Use menu toggles, keybinds, or programmatic triggers instead

local force_commands = {
    flags = {
        burst = 0,      -- Timestamp when burst expires
        defensive = 0,  -- Timestamp when defensive expires
    },
    DURATION = 3.0,
}

-- Cache hot-path APIs at load
local _core_time = core.time
local _core_log = core.log

-- ============================================================================
-- PUBLIC API
-- ============================================================================

---Initialize the force commands system
---Call once from main.lua during plugin load
---Note: Chat commands not supported by Project Sylvanas API
function force_commands:init()
    -- No chat API available in Project Sylvanas
    -- Use menu toggles or keybinds to trigger burst/defensive modes
end

---Check if burst mode is currently active
---@return boolean is_active
function force_commands:is_burst_active()
    return _core_time() < self.flags.burst
end

---Check if defensive mode is currently active
---@return boolean is_active
function force_commands:is_defensive_active()
    return _core_time() < self.flags.defensive
end

---Check if should bypass normal checks for a spell
---Usage: if force_commands:should_bypass(true, false) then ... end
---@param is_burst_spell boolean Whether the spell is a burst/offensive CD
---@param is_defensive_spell boolean Whether the spell is a defensive CD
---@return boolean should_bypass
function force_commands:should_bypass(is_burst_spell, is_defensive_spell)
    -- Return true if burst flag active and spell is burst
    if is_burst_spell and self:is_burst_active() then
        return true
    end
    
    -- Return true if defensive flag active and spell is defensive
    if is_defensive_spell and self:is_defensive_active() then
        return true
    end
    
    return false
end

---Get remaining time for a flag (for UI display)
---@param flag_name string "burst" or "defensive"
---@return number seconds_remaining
function force_commands:get_remaining(flag_name)
    local expiry = self.flags[flag_name]
    if not expiry then return 0 end
    
    local remaining = expiry - _core_time()
    return remaining > 0 and remaining or 0
end

---Manually set burst flag (for programmatic use)
---@param duration number|nil Optional custom duration (defaults to DURATION)
function force_commands:set_burst(duration)
    duration = duration or self.DURATION
    self.flags.burst = _core_time() + duration
    _core_log("[EAX] Burst mode activated for " .. duration .. " seconds")
end

---Manually set defensive flag (for programmatic use)
---@param duration number|nil Optional custom duration (defaults to DURATION)
function force_commands:set_defensive(duration)
    duration = duration or self.DURATION
    self.flags.defensive = _core_time() + duration
    _core_log("[EAX] Defensive mode activated for " .. duration .. " seconds")
end

---Clear burst flag immediately
function force_commands:clear_burst()
    self.flags.burst = 0
end

---Clear defensive flag immediately
function force_commands:clear_defensive()
    self.flags.defensive = 0
end

return force_commands
