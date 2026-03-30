--[[
    smart_cast_manager.lua
    
    Eax TBC Rotation Framework - Smart Cast Management
    
    Solves common rotation issues:
    1. Repetitive ability spam - intelligent throttling between similar abilities
    2. Sluggish feel - smart GCD detection with cast-time awareness
    3. Stuck feeling - adaptive pending cast timeouts with failure recovery
    
    Usage:
        local scm = require("eax_shared/smart_cast_manager")
        
        -- In your rotation function:
        if not scm.is_gcd_ready(runtime) then return false end
        
        -- Check if we should throttle a specific action
        if scm.should_throttle("moonfire", 0.5) then return false end
        
        -- Mark a cast attempt
        scm.on_cast_attempt(spell_id, "moonfire")
        
        -- Check pending cast status
        if scm.is_pending(spell_id) then return false end
        
        -- On successful cast
        scm.on_cast_success(spell_id, cast_time_s)
        
        -- On cast failure
        scm.on_cast_failure(spell_id)
        
    Configuration:
        scm.configure({
            gcd_base = 1.5,           -- Base TBC GCD (1.5s)
            gcd_min = 1.0,             -- Minimum GCD with max haste
            throttle_default = 0.3,   -- Default throttle between similar abilities
            throttle_dots = 0.1,       -- Throttle for DoT refreshes
            pending_timeout_fast = 0.5, -- Fast ability timeout
            pending_timeout_normal = 2.0, -- Normal ability timeout
            pending_timeout_channel = 3.0, -- Channel ability timeout
            adaptive_recovery = true,  -- Enable adaptive timeout recovery
            success_decay = 0.9,        -- Success rate decay factor
            failure_boost = 1.3,       -- Timeout boost on failure
        })
--]]

local smart_cast_manager = {}

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------
local CONFIG = {
    -- GCD settings (TBC accurate)
    gcd_base = 1.5,              -- Base GCD in seconds
    gcd_min = 1.0,               -- Minimum GCD (with ~27% haste from talents)
    
    -- Throttle settings (seconds between same action)
    throttle_default = 0.3,       -- Default throttle
    throttle_dots = 0.15,         -- DoT refresh throttle (more responsive)
    throttle_filler = 0.2,         -- Filler ability throttle
    throttle_cooldown = 0.1,      -- Cooldown ability throttle
    throttle_aoe = 0.25,           -- AoE ability throttle
    
    -- Pending cast timeout settings
    pending_timeout_fast = 0.5,   -- Instant/fast abilities
    pending_timeout_normal = 1.8,  -- Normal cast abilities
    pending_timeout_long = 2.5,    -- Long cast abilities
    pending_timeout_channel = 3.5, -- Channel abilities
    
    -- Adaptive settings
    adaptive_recovery = true,      -- Adjust timeouts based on success rate
    success_decay = 0.95,         -- Exponential decay for success tracking
    failure_boost = 1.4,          -- Timeout multiplier on failure
    success_reduction = 0.9,       -- Timeout reduction on success
    
    -- Debug
    debug_enabled = false,
}

--------------------------------------------------------------------------------
-- State tracking
--------------------------------------------------------------------------------
local state = {
    -- Last cast timestamps by action category
    last_cast = {},               -- { action_key = timestamp }
    
    -- Pending casts
    pending = {},                 -- { spell_id = { requested_at, timeout_s, action_key } }
    
    -- GCD tracking
    last_gcd_trigger = 0,        -- Timestamp of last GCD-triggering cast
    current_gcd_duration = CONFIG.gcd_base,  -- Current GCD duration
    
    -- Success rate tracking for adaptive timeouts
    cast_stats = {},             -- { spell_id = { successes = n, failures = n, avg_timeout = s } }
    
    -- API references (set during init)
    _core_time = nil,
    _get_gcd = nil,
    _get_spell_cd = nil,
}

--------------------------------------------------------------------------------
-- Utility functions
--------------------------------------------------------------------------------
local function get_time()
    if state._core_time then
        return state._core_time()
    elseif core and core.time then
        return core.time()
    end
    return 0
end

local function get_gcd()
    if state._get_gcd then
        local gcd = state._get_gcd()
        if gcd and gcd > 0 then
            return tonumber(gcd)
        end
    elseif core and core.spell_book and core.spell_book.get_global_cooldown then
        local gcd = core.spell_book.get_global_cooldown()
        if gcd and gcd > 0 then
            return tonumber(gcd)
        end
    end
    return 0
end

--------------------------------------------------------------------------------
-- Core API
--------------------------------------------------------------------------------

--- Initialize the cast manager with API references
function smart_cast_manager.init(api)
    api = api or {}
    state._core_time = api.core_time or core.time
    state._get_gcd = api.get_gcd or (core and core.spell_book and core.spell_book.get_global_cooldown)
    state._get_spell_cd = api.get_spell_cd or (core and core.spell_book and core.spell_book.get_spell_cooldown)
    
    if CONFIG.debug_enabled then
        print("[SmartCastManager] Initialized")
    end
end

--- Configure the cast manager
function smart_cast_manager.configure(options)
    if options.gcd_base then CONFIG.gcd_base = options.gcd_base end
    if options.gcd_min then CONFIG.gcd_min = options.gcd_min end
    if options.throttle_default then CONFIG.throttle_default = options.throttle_default end
    if options.throttle_dots then CONFIG.throttle_dots = options.throttle_dots end
    if options.pending_timeout_fast then CONFIG.pending_timeout_fast = options.pending_timeout_fast end
    if options.pending_timeout_normal then CONFIG.pending_timeout_normal = options.pending_timeout_normal end
    if options.pending_timeout_channel then CONFIG.pending_timeout_channel = options.pending_timeout_channel end
    if options.adaptive_recovery ~= nil then CONFIG.adaptive_recovery = options.adaptive_recovery end
    if options.debug_enabled ~= nil then CONFIG.debug_enabled = options.debug_enabled end
end

--- Check if GCD is ready (smart detection)
function smart_cast_manager.is_gcd_ready()
    local now = get_time()
    local elapsed = now - state.last_gcd_trigger
    local actual_gcd = get_gcd()
    local computed_gcd = state.current_gcd_duration or CONFIG.gcd_base
    if actual_gcd and actual_gcd > 0 then
        computed_gcd = actual_gcd
    end
    local gcd_duration = math.max(CONFIG.gcd_min, computed_gcd)
    return elapsed >= gcd_duration
end

--- Get the remaining GCD time after enforcing the configured minimum floor.
function smart_cast_manager.get_remaining_gcd()
    local elapsed = get_time() - state.last_gcd_trigger
    local actual_gcd = get_gcd()
    local computed_gcd = state.current_gcd_duration or CONFIG.gcd_base
    if actual_gcd and actual_gcd > 0 then
        computed_gcd = actual_gcd
    end
    local gcd_duration = math.max(CONFIG.gcd_min, computed_gcd)
    return math.max(0, gcd_duration - elapsed)
end

--- Backward-compatible alias for remaining GCD time.
function smart_cast_manager.get_gcd_duration()
    return smart_cast_manager.get_remaining_gcd()
end

--- Check if we should throttle a specific action
-- action_key: string identifier for the action (e.g., "moonfire", "wrath", "bloodthirst")
-- category: optional throttle category ("dots", "filler", "cooldown", "aoe", "default")
function smart_cast_manager.should_throttle(action_key, category)
    if not action_key then return false end
    
    -- Get throttle interval based on category
    local throttle_interval
    if category == "dots" then
        throttle_interval = CONFIG.throttle_dots
    elseif category == "filler" then
        throttle_interval = CONFIG.throttle_filler
    elseif category == "cooldown" then
        throttle_interval = CONFIG.throttle_cooldown
    elseif category == "aoe" then
        throttle_interval = CONFIG.throttle_aoe
    else
        throttle_interval = CONFIG.throttle_default
    end
    
    local last_cast = state.last_cast[action_key] or 0
    local now = get_time()
    local elapsed = now - last_cast
    
    return elapsed < throttle_interval
end

--- Get time until an action is off throttle
function smart_cast_manager.get_throttle_remaining(action_key, category)
    if not action_key then return 0 end
    
    local throttle_interval
    if category == "dots" then
        throttle_interval = CONFIG.throttle_dots
    elseif category == "filler" then
        throttle_interval = CONFIG.throttle_filler
    elseif category == "cooldown" then
        throttle_interval = CONFIG.throttle_cooldown
    elseif category == "aoe" then
        throttle_interval = CONFIG.throttle_aoe
    else
        throttle_interval = CONFIG.throttle_default
    end
    
    local last_cast = state.last_cast[action_key] or 0
    local now = get_time()
    local elapsed = now - last_cast
    local remaining = throttle_interval - elapsed
    
    return math.max(0, remaining)
end

--- Called when we attempt to cast (regardless of success)
function smart_cast_manager.on_cast_attempt(spell_id, action_key, options)
    options = options or {}
    local now = get_time()
    
    -- Update last cast timestamp for this action
    if action_key then
        state.last_cast[action_key] = now
    end
    
    -- Mark as pending if it triggers GCD
    if spell_id and (options.triggers_gcd ~= false) then
        -- Determine timeout based on category or cast time
        local timeout
        if options.timeout then
            timeout = options.timeout
        elseif options.category == "fast" or options.category == "instant" then
            timeout = CONFIG.pending_timeout_fast
        elseif options.category == "channel" then
            timeout = CONFIG.pending_timeout_channel
        elseif options.category == "long" then
            timeout = CONFIG.pending_timeout_long
        elseif options.cast_time then
            -- Calculate timeout based on cast time with buffer
            timeout = options.cast_time + 0.5
        else
            timeout = CONFIG.pending_timeout_normal
        end
        
        -- Apply adaptive adjustment if enabled
        if CONFIG.adaptive_recovery and spell_id then
            local stats = state.cast_stats[spell_id]
            if stats and stats.avg_timeout then
                -- Use weighted average of configured and actual timeout
                timeout = (timeout * 0.7) + (stats.avg_timeout * 1.3)
            end
        end
        
        state.pending[spell_id] = {
            requested_at = now,
            timeout_s = timeout,
            action_key = action_key,
            cast_time = options.cast_time or 0,
        }
        
        -- GCD tracking is updated on cast success

    end
end

--- Check if a spell is currently pending
function smart_cast_manager.is_pending(spell_id)
    if not spell_id then return false end
    
    local pending = state.pending[spell_id]
    if not pending then return false end
    
    local now = get_time()
    local elapsed = now - pending.requested_at
    
    -- Check if expired
    if elapsed >= pending.timeout_s then
        state.pending[spell_id] = nil
        return false
    end
    
    -- Check if cooldown is back (spell no longer on cooldown)
    if state._get_spell_cd then
        local cd = state._get_spell_cd(spell_id)
        if cd and cd <= 0 then
            smart_cast_manager.on_cast_success(spell_id)
            return false
        end
    end
    
    return true
end

--- Called on successful cast
function smart_cast_manager.on_cast_success(spell_id, actual_cast_time)
    if not spell_id then return end
    
    local now = get_time()
    local pending = state.pending[spell_id]
    local actual_gcd = get_gcd()
    if actual_gcd and actual_gcd > 0 then
        state.current_gcd_duration = actual_gcd
    else
        state.current_gcd_duration = CONFIG.gcd_base
    end
    state.last_gcd_trigger = now
    
    -- Record success for adaptive timing
    if CONFIG.adaptive_recovery then
        if not state.cast_stats[spell_id] then
            state.cast_stats[spell_id] = { successes = 0, failures = 0, avg_timeout = CONFIG.pending_timeout_normal }
        end
        
        local stats = state.cast_stats[spell_id]
        stats.successes = stats.successes + 1
        
        -- Update average timeout based on actual cast time
        if actual_cast_time then
            local measured_timeout = actual_cast_time + 0.3  -- Small buffer
            stats.avg_timeout = (stats.avg_timeout * CONFIG.success_decay) + (measured_timeout * (1 - CONFIG.success_decay))
        end
        
        -- Reduce timeout if we're consistently successful
        if stats.successes >= 5 then
            local success_rate = stats.successes / (stats.successes + stats.failures)
            if success_rate > 0.9 then
                -- We're very successful, can be more responsive
                stats.avg_timeout = stats.avg_timeout * CONFIG.success_reduction
            end
        end
    end
    
    -- Clear pending
    state.pending[spell_id] = nil
    
    if CONFIG.debug_enabled then
        print(string.format("[SmartCastManager] Cast success: spell=%d, action=%s", spell_id, pending and pending.action_key or "unknown"))
    end
end

--- Called on cast failure (spell rejected by server)
function smart_cast_manager.on_cast_failure(spell_id, reason)
    if not spell_id then return end
    
    local now = get_time()
    
    -- Record failure for adaptive timing
    if CONFIG.adaptive_recovery then
        if not state.cast_stats[spell_id] then
            state.cast_stats[spell_id] = { successes = 0, failures = 0, avg_timeout = CONFIG.pending_timeout_normal }
        end
        
        local stats = state.cast_stats[spell_id]
        stats.failures = stats.failures + 1
        
        -- Increase timeout on failure
        stats.avg_timeout = stats.avg_timeout * CONFIG.failure_boost
        
        -- Cap the timeout to prevent runaway
        stats.avg_timeout = math.min(stats.avg_timeout, CONFIG.pending_timeout_long * 2)
    end
    
    -- Clear pending
    state.pending[spell_id] = nil
    
    if CONFIG.debug_enabled then
        print(string.format("[SmartCastManager] Cast failure: spell=%d, reason=%s", spell_id, reason or "unknown"))
    end
end

--- Force clear a pending cast (e.g., on target death)
function smart_cast_manager.clear_pending(spell_id)
    if spell_id then
        state.pending[spell_id] = nil
    end
end

--- Clear all pending casts
function smart_cast_manager.clear_all_pending()
    state.pending = {}
end

--- Get statistics for an action
function smart_cast_manager.get_stats(action_key)
    local pending_entries = {}
    for spell_id, pending in pairs(state.pending) do
        if not action_key or pending.action_key == action_key then
            local now = get_time()
            local remaining = pending.timeout_s - (now - pending.requested_at)
            table.insert(pending_entries, {
                spell_id = spell_id,
                action_key = pending.action_key,
                remaining_s = math.max(0, remaining),
                timeout_s = pending.timeout_s,
            })
        end
    end
    return pending_entries
end

--- Reset all state (call on combat end)
function smart_cast_manager.reset()
    state.last_cast = {}
    state.pending = {}
    state.last_gcd_trigger = 0
    state.current_gcd_duration = CONFIG.gcd_base
    -- Don't reset cast_stats - we want to maintain adaptive behavior
end

--- Reset all state including adaptive tracking
function smart_cast_manager.full_reset()
    state.last_cast = {}
    state.pending = {}
    state.cast_stats = {}
    state.last_gcd_trigger = 0
    state.current_gcd_duration = CONFIG.gcd_base
end

--- Check if any casts are currently pending
function smart_cast_manager.has_pending()
    for spell_id in pairs(state.pending) do
        if smart_cast_manager.is_pending(spell_id) then
            return true
        end
    end
    return false
end

--- Get time until next pending cast completes
function smart_cast_manager.get_next_ready_time()
    local now = get_time()
    local min_remaining = math.huge
    
    for spell_id in pairs(state.pending) do
        local pending = state.pending[spell_id]
        if pending then
            local remaining = pending.timeout_s - (now - pending.requested_at)
            if remaining < min_remaining then
                min_remaining = remaining
            end
        end
    end
    
    if min_remaining == math.huge then
        return 0
    end
    
    return math.max(0, min_remaining)
end

--------------------------------------------------------------------------------
-- Pre-built throttle helpers for common scenarios
--------------------------------------------------------------------------------

--- Create a throttler for a specific action with custom interval
function smart_cast_manager.create_throttler(action_key, interval_s)
    return function()
        return smart_cast_manager.should_throttle(action_key, "default")
    end
end

--- Group multiple related abilities (only one can cast at a time)
local group_locks = {}

function smart_cast_manager.lock_group(group_name, action_key)
    group_locks[group_name] = {
        action_key = action_key,
        locked_at = get_time(),
    }
    -- Auto-unlock after group-specific timeout
end

function smart_cast_manager.is_group_locked(group_name, exclude_action)
    local lock = group_locks[group_name]
    if not lock then return false end
    
    if lock.action_key == exclude_action then
        return false
    end
    
    local elapsed = get_time() - lock.locked_at
    if elapsed > 0.5 then  -- Lock expires after 500ms
        group_locks[group_name] = nil
        return false
    end
    
    return true
end

--------------------------------------------------------------------------------
-- Diagnostics
--------------------------------------------------------------------------------

function smart_cast_manager.dump_state()
    print("=== Smart Cast Manager State ===")
    print(string.format("GCD Duration: %.2fs", state.current_gcd_duration))
    print(string.format("Last GCD: %.2fs ago", get_time() - state.last_gcd_trigger))
    print("Pending casts:")
    for spell_id, pending in pairs(state.pending) do
        local remaining = pending.timeout_s - (get_time() - pending.requested_at)
        print(string.format("  Spell %d: %s (%.2fs remaining)", spell_id, pending.action_key or "unknown", remaining))
    end
    print("Action throttle timestamps:")
    for action, timestamp in pairs(state.last_cast) do
        print(string.format("  %s: %.2fs ago", action, get_time() - timestamp))
    end
    print("=============================")
end

return smart_cast_manager
