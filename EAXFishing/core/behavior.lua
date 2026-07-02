-- =============================================================================
-- Core/Behavior Module - Humanizer and behavior profiles
-- Uses APISurface for timestamp operations
-- =============================================================================

local Math = require("utils/math")
local APISurface = require("core/api_surface")

local M = {}

-- Behavior archetype definitions
local BEHAVIOR_ARCHETYPES = {
    {
        id = "steady",
        tempo = 1.00,
        break_scale = 1.00,
        reaction = 1.00,
        loot = 1.00,
        look = 1.00,
        recovery = 1.00,
    },
    {
        id = "patient",
        tempo = 1.08,
        break_scale = 1.14,
        reaction = 1.07,
        loot = 1.10,
        look = 1.12,
        recovery = 1.08,
    },
    {
        id = "brisk",
        tempo = 0.94,
        break_scale = 0.92,
        reaction = 0.95,
        loot = 0.94,
        look = 0.92,
        recovery = 0.95,
    },
    {
        id = "wandering",
        tempo = 1.03,
        break_scale = 1.06,
        reaction = 1.02,
        loot = 1.08,
        look = 1.18,
        recovery = 1.05,
    },
}

--- Pick a random behavior archetype
-- @return table archetype
function M.pick_archetype()
    local idx = math.random(1, #BEHAVIOR_ARCHETYPES)
    return BEHAVIOR_ARCHETYPES[idx]
end

--- Roll a new behavior profile
-- @param now number current time
-- @return table behavior profile
function M.roll_profile(now)
    local archetype = M.pick_archetype()
    local phase_start = now
    
    return {
        archetype = archetype,
        phase_start = phase_start,
    }
end

--- Ensure a behavior profile exists, re-rolling every 15-25 minutes for varied behaviour
-- @param state table state object with profile subtable
-- @param now number current time
-- @return table behavior profile
function M.ensure_profile(state, now)
    local profile = state.profile.behavior
    if not profile then
        profile = M.roll_profile(now)
        state.profile.behavior = profile
        state.profile.next_reroll = now + (900 + math.random(0, 600)) -- 15-25 min
        return profile
    end

    -- Re-roll periodically so behaviour is not identical across long sessions
    local next_reroll = state.profile.next_reroll or 0
    if now >= next_reroll then
        profile = M.roll_profile(now)
        state.profile.behavior = profile
        state.profile.next_reroll = now + (900 + math.random(0, 600))
    end

    return profile
end

--- Get a randomised delay scaled by the current behavior profile
-- @param state table
-- @param now number
-- @param min_ms number minimum ms
-- @param max_ms number maximum ms
-- @param channel string behavior channel (tempo, reaction, loot, recovery...)
-- @return number delay in seconds
function M.scaled_delay(state, now, min_ms, max_ms, channel)
    local base_ms = math.random(math.min(min_ms, max_ms), math.max(min_ms, max_ms))
    local scale = M.get_scale(state, now, channel or "tempo")
    return (base_ms * scale) / 1000.0
end

--- Get current behavior phase
-- @param profile table behavior profile
-- @param now number current time
-- @return string phase name
function M.get_phase(profile, now)
    local elapsed = now - profile.phase_start
    
    if elapsed < 60 then
        return "warmup"
    elseif elapsed < 180 then
        return "early"
    elseif elapsed < 420 then
        return "mid"
    elseif elapsed < 900 then
        return "late"
    else
        return "endurance"
    end
end

--- Get archetype scale for a channel
-- @param profile table behavior profile
-- @param channel string (tempo, break, reaction, loot, look, recovery)
-- @return number scale
function M.get_archetype_scale(profile, channel)
    local archetype = profile.archetype
    return archetype and archetype[channel] or 1.0
end

--- Get phase scale for a channel
-- @param phase string phase name
-- @param channel string
-- @return number scale
function M.get_phase_scale(phase, channel)
    local phase_scales = {
        warmup = { tempo = 1.15, break_scale = 1.0, reaction = 1.0, loot = 1.0, look = 1.0, recovery = 1.2 },
        early = { tempo = 1.05, break_scale = 1.0, reaction = 1.0, loot = 1.0, look = 1.0, recovery = 1.1 },
        mid = { tempo = 1.0, break_scale = 1.0, reaction = 1.0, loot = 1.0, look = 1.0, recovery = 1.0 },
        late = { tempo = 0.95, break_scale = 0.95, reaction = 1.0, loot = 1.0, look = 1.0, recovery = 0.95 },
        endurance = { tempo = 0.88, break_scale = 0.85, reaction = 0.95, loot = 0.95, look = 0.95, recovery = 0.9 },
    }
    
    local scales = phase_scales[phase]
    return scales and scales[channel] or 1.0
end

--- Get behavior drift (random variance)
-- @param now number current time
-- @param channel string
-- @return number drift factor
function M.get_drift(now, channel)
    -- Deterministic drift based on time and channel
    local seed = now * 1000 + string.byte(channel, 1)
    local rand = (math.sin(seed) * 43758.5453) % 1.0
    return 1.0 + (rand - 0.5) * 0.1
end

--- Get combined behavior scale for a channel
-- @param state table state object
-- @param now number current time
-- @param channel string
-- @return number combined scale
function M.get_scale(state, now, channel)
    local profile = state.profile.behavior
    if not profile then
        return 1.0
    end
    
    local phase = M.get_phase(profile, now)
    local archetype_scale = M.get_archetype_scale(profile, channel)
    local phase_scale = M.get_phase_scale(phase, channel)
    local drift = M.get_drift(now, channel)
    
    return archetype_scale * phase_scale * drift
end

--- Check if ultra safe mode is enabled
-- @param config table
-- @return boolean
function M.is_ultra_safe_mode(config)
    return config.menu.ultra_safe_mode and config.menu.ultra_safe_mode:get_state() or false
end

--- Check if humanizer is active
-- Uses humanizer_enabled as master gate
-- @param config table
-- @return boolean
function M.is_humanizer_active(config)
    -- humanizer_enabled is the master gate
    if config.menu.humanizer_enabled and type(config.menu.humanizer_enabled.get_state) == "function" then
        return config.menu.humanizer_enabled:get_state()
    end
    -- Fallback to random_delay for backwards compatibility
    if config.menu.random_delay and type(config.menu.random_delay.get_state) == "function" then
        return config.menu.random_delay:get_state()
    end
    return false
end

--- Check if an optional humanizer feature is enabled
-- @param menu_item table?
-- @param default boolean default if nil
-- @return boolean
function M.is_optional_feature(menu_item, default)
    if not menu_item then
        return default
    end
    if type(menu_item.get_state) == "function" then
        return menu_item:get_state()
    end
    return default
end

--- Get delay multiplier (currently fixed at 1.0)
-- @param config table
-- @return number multiplier
function M.get_delay_multiplier(config)
    -- delay_multiplier menu item not implemented - returns fixed 1.0
    return 1.0
end

--- Apply random wait based on humanizer settings
-- @param ctx table context
-- @param min number minimum seconds
-- @param max number? maximum seconds (defaults to min)
function M.apply_random_wait(ctx, min, max)
    max = max or min
    local now = APISurface.now()
    local config = ctx.deps.config
    
    if M.is_humanizer_active(config) then
        local min_ms, max_ms = Math.get_ordered_ms_range(
            config.menu.cast_delay_min_ms,
            config.menu.cast_delay_max_ms,
            math.floor(min * 1000),
            math.floor(max * 1000)
        )
        local profile_scale = M.get_scale(ctx.state, now, "recovery")
        local delay = (math.random(min_ms, max_ms) / 1000) * M.get_delay_multiplier(config) * profile_scale
        ctx.state.fishing.next_cast_time = now + delay
    else
        ctx.state.fishing.next_cast_time = now + min
    end
end

return M
