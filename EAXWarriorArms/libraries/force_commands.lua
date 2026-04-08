-- libraries/force_commands.lua
-- Force command system for /eax burst and /eax def commands
-- Ported from Flux with Sylvanas API compliance

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
-- CHAT EVENT HANDLER
-- ============================================================================
local function on_chat_msg(msg)
    if not msg then return end
    
    -- Parse /eax burst
    if msg:match("^/eax%s+burst") or msg:match("^/eax%s+offensive") then
        force_commands.flags.burst = _core_time() + force_commands.DURATION
        _core_log("[EAX] Burst mode activated for 3 seconds")
        return
    end
    
    -- Parse /eax def
    if msg:match("^/eax%s+def") or msg:match("^/eax%s+defensive") then
        force_commands.flags.defensive = _core_time() + force_commands.DURATION
        _core_log("[EAX] Defensive mode activated for 3 seconds")
        return
    end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

---Initialize the force commands system
---Call once from main.lua during plugin load
function force_commands:init()
    -- Register chat event handler for slash commands
    if core.add_event_callback then
        core.add_event_callback("CHAT_MSG", on_chat_msg)
    end
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
