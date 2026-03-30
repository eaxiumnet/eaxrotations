-- swing_timer.lua  |  Documented swing timing wrapper  |  TBC Classic
-- Uses common/utility/auto_attack_helper and documented game_object methods only.

---@type auto_attack_helper|nil
local auto_attack = nil
do
    local ok, helper = pcall(require, "common/utility/auto_attack_helper")
    if ok and helper then
        auto_attack = helper
    end
end

local swing_timer = {}

local state = {
    mh_speed = 0,
    oh_speed = 0,
    mh_next = 0,
    oh_next = 0,
    last_swing = 0,
    last_update = 0,
}

local UPDATE_INTERVAL_S = 0.05

local function get_now()
    return (core and core.time and core.time()) or 0
end

local function safe_number(value)
    if type(value) ~= "number" or value ~= value then
        return 0
    end
    return value
end

local function update(me)
    if not me then return end

    local now = get_now()
    if (now - state.last_update) < UPDATE_INTERVAL_S then
        return
    end
    state.last_update = now

    state.mh_speed = 0
    state.oh_speed = 0
    state.mh_next = 0
    state.oh_next = 0
    state.last_swing = 0

    if not auto_attack then
        return
    end

    local last_attack = 0
    local ok_last, last_value = pcall(function()
        return auto_attack:get_last_attack_core_time(me)
    end)
    if ok_last then
        last_attack = safe_number(last_value)
    end

    local next_attack = 0
    local ok_next, next_value = pcall(function()
        return auto_attack:get_next_attack_core_time(me, 1)
    end)
    if ok_next then
        next_attack = safe_number(next_value)
    end

    if last_attack > 0 then
        state.last_swing = last_attack
    end

    if last_attack > 0 and next_attack > last_attack then
        state.mh_speed = next_attack - last_attack
        state.oh_speed = state.mh_speed
    end

    if next_attack > now then
        state.mh_next = next_attack - now
        state.oh_next = state.mh_next
        return
    end

    if last_attack > 0 and state.mh_speed > 0 then
        local predicted_next = (last_attack + state.mh_speed) - now
        if predicted_next > 0 then
            state.mh_next = predicted_next
            state.oh_next = predicted_next
        end
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
    cast_time_s = cast_time_s or 0
    safety_buffer_s = safety_buffer_s or 0.1
    local time_to_swing = swing_timer.get_time_to_swing(me)
    return time_to_swing <= 0.001 or time_to_swing >= (cast_time_s + safety_buffer_s)
end

function swing_timer.get_time_to_swing_ms(me)
    return math.floor((swing_timer.get_time_to_swing(me) * 1000) + 0.5)
end

function swing_timer.can_use_instant_before_swing(me, safety_buffer_s)
    safety_buffer_s = safety_buffer_s or 0.1
    return swing_timer.is_swing_safe(me, safety_buffer_s)
end

function swing_timer.get_time_since_last_swing(me)
    update(me)
    if state.last_swing <= 0 then
        return math.huge
    end
    return math.max(0, get_now() - state.last_swing)
end

function swing_timer.is_in_post_swing_window(me, window_s)
    update(me)
    window_s = window_s or 0.35
    local since_last = swing_timer.get_time_since_last_swing(me)
    if since_last == math.huge then
        return false
    end
    return since_last <= window_s
end

return swing_timer
