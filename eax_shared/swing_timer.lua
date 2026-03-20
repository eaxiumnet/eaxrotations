-- swing_timer.lua  |  Melee Swing Timing & Safe Queue Check  |  TBC Classic
-- Tracks main-hand and off-hand swing timers to prevent Slam clip and Auto Shot clip.
-- Affected specs: Arms/Fury Warrior (Slam), Beast/MM/Survival Hunter (Auto Shot)

local swing_timer = {}

local state = {
    mh_speed = 0,
    oh_speed = 0,
    mh_next = 0,
    oh_next = 0,
    last_update = 0,
    ranged_speed = 0,
    ranged_next = 0,
}

local function update(me)
    if not me then return end
    local now = core and core.time and core.time() or 0
    if now - state.last_update < 0.05 then return end
    state.last_update = now

    local ok_mh_speed = pcall(function() return me:get_attack_time() end)
    local ok_oh_speed = pcall(function() return me:get_offhand_attack_time() end)

    state.mh_speed = (ok_mh_speed and type(ok_mh_speed) == "number" and ok_mh_speed > 0) and ok_mh_speed or 0
    state.oh_speed = (ok_oh_speed and type(ok_oh_speed) == "number" and ok_oh_speed > 0) and ok_oh_speed or 0

    if me.get_auto_attack_timer_ms then
        local ok_mh = pcall(function() return me:get_auto_attack_timer_ms() end)
        state.mh_next = (ok_mh and type(ok_mh) == "number") and ok_mh / 1000 or 0
    else
        state.mh_next = 0
    end

    if me.get_offhand_auto_attack_timer_ms then
        local ok_oh = pcall(function() return me:get_offhand_auto_attack_timer_ms() end)
        state.oh_next = (ok_oh and type(ok_oh) == "number") and ok_oh / 1000 or 0
    else
        state.oh_next = 0
    end
end

function swing_timer.update(me)
    update(me)
end

function swing_timer.get_time_to_swing(me)
    update(me)
    if state.mh_next <= 0.001 then return 0 end
    return math.max(0, state.mh_next)
end

function swing_timer.get_next_swing_time(me)
    update(me)
    return state.mh_next
end

function swing_timer.is_swing_safe(me, safety_buffer_s)
    update(me)
    safety_buffer_s = safety_buffer_s or 0.1
    return state.mh_next <= 0.001 or state.mh_next >= safety_buffer_s
end

function swing_timer.is_swing_imminent(me, threshold_s)
    update(me)
    threshold_s = threshold_s or 0.2
    return state.mh_next > 0.001 and state.mh_next <= threshold_s
end

function swing_timer.get_offhand_time_to_swing(me)
    update(me)
    if state.oh_next <= 0.001 then return 0 end
    return math.max(0, state.oh_next)
end

function swing_timer.get_offhand_next_swing_time(me)
    update(me)
    return state.oh_next
end

function swing_timer.get_mh_speed(me)
    update(me)
    return state.mh_speed
end

function swing_timer.get_oh_speed(me)
    update(me)
    return state.oh_speed
end

function swing_timer.can_cast_before_swing(me, cast_time_s, safety_buffer_s)
    update(me)
    safety_buffer_s = safety_buffer_s or 0.1
    local time_to_swing = swing_timer.get_time_to_swing(me)
    return time_to_swing <= 0.001 or time_to_swing >= (cast_time_s + safety_buffer_s)
end

return swing_timer
