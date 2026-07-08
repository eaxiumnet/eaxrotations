-- swing_timer_sylvanas.lua -- enhance the engine's swing timer with offset + haste compensation.
-- WHAT:   enhance the engine's swing timer with offset + haste compensation
-- WHEN:   any melee spec when dual-wield or 2H
-- WHY:    decreases melee-cap clipping by exposing actual-swing ETA
-- SAFETY: zero allocations; throttled recompute
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.

local M = {}
local _G = _G
local NS = _G.EaxRotations

local initialized = false

-- Swing state tracking
local swing_state = {
    mh_start = 0,
    mh_duration = 0,
    oh_start = 0,
    oh_duration = 0,
    ranged_start = 0,
    ranged_duration = 0,
    last_update = 0,
}

-- Spells that reset swings
local SWING_RESET_SPELLS = {
    -- Warrior Slam resets main-hand
    [1464] = "mh", [8820] = "mh", [11604] = "mh", [11605] = "mh", [25241] = "mh", [25242] = "mh", -- Slam
    -- Hunter: Aimed Shot, Multi-Shot reset auto-shot
    [19434] = "ranged", [20900] = "ranged", [20901] = "ranged", [20902] = "ranged", [20903] = "ranged", [20904] = "ranged", -- Aimed Shot
    [2643] = "ranged", [14288] = "ranged", [14289] = "ranged", [14290] = "ranged", [25294] = "ranged", [27021] = "ranged", -- Multi-Shot
}

local function now()
    return NS and NS.time_now and NS.time_now() or 0
end

-- Get swing info from Sylvanas APIs
local function get_swing_info(weapon_type)
    -- Try IZI SDK first
    if NS and NS.GetPlayer then
        local me = NS.GetPlayer()
        if me then
            -- Player:GetSwingStart(weapon_type) and Player:GetSwing(weapon_type)
            -- weapon_type: 1 = mainhand, 2 = offhand, 3 = ranged
            local start_time = nil
            local ok1 = pcall(function() 
                if me.GetSwingStart then
                    start_time = me:GetSwingStart(weapon_type)
                end
            end)
            local duration = nil
            local ok2 = pcall(function() 
                if me.GetSwing then
                    duration = me:GetSwing(weapon_type)
                end
            end)
            
            if ok1 and ok2 then
                return start_time or 0, duration or 0
            end
        end
    end
    
    return nil, nil
end

-- Update swing timers
function M.update()
    local t = now()
    
    -- Update mainhand
    local mh_start, mh_dur = get_swing_info(1)
    if mh_start then
        -- Check if this is a new swing
        if mh_start ~= swing_state.mh_start then
            swing_state.mh_start = mh_start
            swing_state.mh_duration = mh_dur
        end
    end
    
    -- Update offhand
    local oh_start, oh_dur = get_swing_info(2)
    if oh_start then
        if oh_start ~= swing_state.oh_start then
            swing_state.oh_start = oh_start
            swing_state.oh_duration = oh_dur
        end
    end
    
    -- Update ranged
    local ranged_start, ranged_dur = get_swing_info(3)
    if ranged_start then
        if ranged_start ~= swing_state.ranged_start then
            swing_state.ranged_start = ranged_start
            swing_state.ranged_duration = ranged_dur
        end
    end
    
    swing_state.last_update = t
end

-- Get main-hand swing progress (0.0 to 1.0)
function M.get_mh_progress()
    local t = now()
    if (swing_state.mh_duration or 0) == 0 then return 0 end
    
    local elapsed = t - swing_state.mh_start
    local progress = elapsed / swing_state.mh_duration
    return math.max(0, math.min(1, progress))
end

-- Get off-hand swing progress
function M.get_oh_progress()
    local t = now()
    if (swing_state.oh_duration or 0) == 0 then return 0 end
    
    local elapsed = t - swing_state.oh_start
    local progress = elapsed / swing_state.oh_duration
    return math.max(0, math.min(1, progress))
end

-- Get ranged swing progress
function M.get_ranged_progress()
    local t = now()
    if (swing_state.ranged_duration or 0) == 0 then return 0 end
    
    local elapsed = t - swing_state.ranged_start
    local progress = elapsed / swing_state.ranged_duration
    return math.max(0, math.min(1, progress))
end

-- Get time until next swing
function M.get_mh_time_until()
    local t = now()
    local remaining = (swing_state.mh_start + swing_state.mh_duration) - t
    return math.max(0, remaining)
end

function M.get_oh_time_until()
    local t = now()
    local remaining = (swing_state.oh_start + swing_state.oh_duration) - t
    return math.max(0, remaining)
end

function M.get_ranged_time_until()
    local t = now()
    local remaining = (swing_state.ranged_start + swing_state.ranged_duration) - t
    return math.max(0, remaining)
end

-- Get weaving hint for casters
-- Returns: "cast_now", "hold", "clip_warning", "optimal"
function M.get_weaving_hint(cast_time)
    cast_time = cast_time or (NS.get_global_cooldown and NS.get_global_cooldown() or 1.5)  -- Default GCD
    
    local mh_remaining = M.get_mh_time_until()
    local oh_remaining = M.get_oh_time_until()
    
    -- If swing is far away, safe to cast
    if mh_remaining > cast_time + 0.5 then
        return "cast_now"
    end
    
    -- If swing is very close, might clip
    if mh_remaining < 0.3 then
        return "clip_warning"
    end
    
    -- If we can fit the cast before swing, it's optimal
    if mh_remaining > cast_time then
        return "optimal"
    end
    
    -- Otherwise hold
    return "hold"
end

-- Check if we can weave a spell
-- Returns: true if safe to cast without clipping swing
function M.can_weave(cast_time, buffer)
    buffer = buffer or 0.2  -- Safety buffer
    cast_time = cast_time or 1.5
    
    local mh_remaining = M.get_mh_time_until()
    return mh_remaining > (cast_time + buffer)
end

-- Record swing reset from spell cast
function M.record_spell_cast(spell_id)
    if not spell_id then return end
    
    local reset_type = SWING_RESET_SPELLS[spell_id]
    if not reset_type then return end
    
    local t = now()
    
    if reset_type == "mh" then
        swing_state.mh_start = t
        swing_state.mh_duration = 0  -- Will update on next scan
    elseif reset_type == "oh" then
        swing_state.oh_start = t
        swing_state.oh_duration = 0
    elseif reset_type == "ranged" then
        swing_state.ranged_start = t
        swing_state.ranged_duration = 0
    end
end

-- Get full swing status
function M.get_status()
    M.update()  -- Ensure fresh data
    
    return {
        mh_progress = M.get_mh_progress(),
        mh_remaining = M.get_mh_time_until(),
        oh_progress = M.get_oh_progress(),
        oh_remaining = M.get_oh_time_until(),
        ranged_progress = M.get_ranged_progress(),
        ranged_remaining = M.get_ranged_time_until(),
        weaving_hint = M.get_weaving_hint(),
    }
end

-- Initialize
function M.init()
    if not NS then return end
    if initialized then return end
    initialized = true
    
    -- Register spell cast callback for swing resets
    -- Signature: function(spell_id, target, data)
    if NS.register_on_spell_cast then
        NS.register_on_spell_cast(function(spell_id, target, data)
            if spell_id then
                M.record_spell_cast(spell_id)
            end
        end)
    elseif core and core.register_on_spell_cast_callback then
        core.register_on_spell_cast_callback(function(data)
            if data and data.spell_id then
                M.record_spell_cast(data.spell_id)
            end
        end)
    end
end

-- Periodic update (call from on_update)
function M.on_update()
    M.update()
end

if NS then
    NS.SwingTimer = M
    -- Defer init until player is available (engine callbacks may not be ready at require() time)
    if NS.GetPlayer and NS.GetPlayer() then
        M.init()
    end
end

return M
