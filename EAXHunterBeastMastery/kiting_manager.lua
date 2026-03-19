-- kiting_manager.lua  |  Smart Kiting System  |  TBC
-- Tracks enemy velocity, pre-emptively kites before melee range

local kiting_manager = {}

local KITING_RANGE = 5           -- yards: start kiting only when enemy is AT melee
local PREDICT_RANGE = 0         -- yards: no pre-emptive kiting (causes too many false positives)
local SAFE_RANGE = 30           -- yards: kite until we're at least this far
local MIN_KITE_RANGE = 4       -- yards: don't kite if enemy is too close to center

local STATE_IDLE = 0
local STATE_KITING = 1
local STATE_REPOSITIONING = 2

kiting_manager.state = STATE_IDLE
kiting_manager.last_target_guid = nil
kiting_manager.target_positions = {}
kiting_manager.target_times = {}
kiting_manager.slowed_until = 0
kiting_manager.last_concussive = 0
kiting_manager.last_wingclip = 0
kiting_manager.last_disengage = 0
kiting_manager.kiting_started = 0
kiting_manager.preemptive_kiting = false

function kiting_manager.init(state_by_spec)
    kiting_manager.state_by_spec = state_by_spec or {}
end

local function get_spec_state(spec_name)
    if not kiting_manager.state_by_spec then
        kiting_manager.state_by_spec = {}
    end
    if not kiting_manager.state_by_spec[spec_name] then
        kiting_manager.state_by_spec[spec_name] = {
            state = STATE_IDLE,
            last_target_guid = nil,
            target_positions = {},
            target_times = {},
            slowed_until = 0,
            last_concussive = 0,
            last_wingclip = 0,
            last_disengage = 0,
            kiting_started = 0,
            preemptive_kiting = false,
        }
    end
    return kiting_manager.state_by_spec[spec_name]
end

local function dist_3d(p1, p2)
    if not p1 or not p2 then return 999 end
    local dx, dy, dz = p1.x - p2.x, p1.y - p2.y, p1.z - p2.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function get_velocity(s, spec_name)
    local st = get_spec_state(spec_name)
    local guid = st.last_target_guid
    if not guid then return 0, 0, 0 end
    local times = st.target_times[guid]
    local positions = st.target_positions[guid]
    if not times or not positions or #times < 2 then return 0, 0, 0 end
    local n = #times
    local dt = times[n] - times[n-1]
    if dt <= 0 then return 0, 0, 0 end
    local vx = (positions[n].x - positions[n-1].x) / dt
    local vy = (positions[n].y - positions[n-1].y) / dt
    local vz = (positions[n].z - positions[n-1].z) / dt
    return vx, vy, vz
end

local function predict_arrival_time(me_pos, target_pos, vx, vy, vz, me_speed)
    if not me_pos or not target_pos then return 999 end
    local dx, dy, dz = me_pos.x - target_pos.x, me_pos.y - target_pos.y, me_pos.z - target_pos.z
    local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
    if dist < 0.1 then return 0 end
    local dot = (vx*dx + vy*dy + vz*dz) / (dist + 0.001)
    if dot >= 0 then return 999 end
    local approach_speed = -dot
    if approach_speed < 0.1 then return 999 end
    return dist / approach_speed
end

function kiting_manager.update(me, target, rt, spells, utils, now, spec_name)
    if not target or not target:is_valid() then
        local st = get_spec_state(spec_name)
        st.state = STATE_IDLE
        st.last_target_guid = nil
        return STATE_IDLE, false
    end

    local me_pos = me:get_position()
    local target_pos = target:get_position()
    if not me_pos or not target_pos then
        local st = get_spec_state(spec_name)
        st.state = STATE_IDLE
        return STATE_IDLE, false
    end

    local ok, guid = pcall(function() return tostring(target:get_guid()) end)
    if not ok or not guid then
        local st = get_spec_state(spec_name)
        st.state = STATE_IDLE
        return STATE_IDLE, false
    end

    local st = get_spec_state(spec_name)

    if st.last_target_guid ~= guid then
        st.target_positions[guid] = {}
        st.target_times[guid] = {}
        st.last_target_guid = guid
        st.state = STATE_IDLE
        st.preemptive_kiting = false
    end

    local positions = st.target_positions[guid]
    local times = st.target_times[guid]
    if not positions then positions = {}; st.target_positions[guid] = positions end
    if not times then times = {}; st.target_times[guid] = times end

    table.insert(positions, target_pos)
    table.insert(times, now)
    if #positions > 10 then
        table.remove(positions, 1)
        table.remove(times, 1)
    end

    local d = dist_3d(me_pos, target_pos)
    local vx, vy, vz = get_velocity(st, spec_name)
    local speed = math.sqrt(vx*vx + vy*vy + vz*vz)
    local arrival_time = predict_arrival_time(me_pos, target_pos, vx, vy, vz, 7.0)

    local enemy_approaching = speed > 0.5 and arrival_time < 2.0
    local should_kite = false
    local preemptive = false

    if d <= KITING_RANGE and d >= MIN_KITE_RANGE then
        should_kite = true
        preemptive = false
    elseif d <= PREDICT_RANGE and d >= MIN_KITE_RANGE and enemy_approaching then
        should_kite = true
        preemptive = true
    end

    if not should_kite and st.state == STATE_KITING then
        if d >= SAFE_RANGE then
            st.state = STATE_IDLE
            st.preemptive_kiting = false
            return STATE_IDLE, false
        end
    end

    if should_kite then
        st.state = STATE_KITING
        st.preemptive_kiting = preemptive
        if st.kiting_started == 0 then
            st.kiting_started = now
        end
        return STATE_KITING, true
    end

    return STATE_IDLE, false
end

function kiting_manager.try_kiting_sequence(me, target, rt, spells, utils, menu, spec_name)
    local st = get_spec_state(spec_name)
    local me_pos = me:get_position()
    local target_pos = target and target:get_position()
    if not me_pos or not target_pos then return false end

    local d = dist_3d(me_pos, target_pos)
    local now = core.time()

    if rt.concussive_shot_id and core.spell_book.get_spell_cooldown(rt.concussive_shot_id) == 0 then
        if not utils.has_debuff(target, spells.DEBUFF_CONCUSSIVE) then
            if utils.can_cast_hostile(rt.concussive_shot_id, me, target) then
                if utils.cast_target(rt.concussive_shot_id, target) then
                    utils.log_debug(menu, "[Kiting] Concussive Shot")
                    return true
                end
            end
        end
    end

    if rt.wing_clip_id and core.spell_book.get_spell_cooldown(rt.wing_clip_id) == 0 then
        if not utils.has_debuff(target, spells.DEBUFF_WING_CLIP) and d <= 5 then
            if utils.can_cast_hostile(rt.wing_clip_id, me, target) then
                if utils.cast_target(rt.wing_clip_id, target) then
                    utils.log_debug(menu, "[Kiting] Wing Clip")
                    return true
                end
            end
        end
    end

    if rt.disengage_id and core.spell_book.get_spell_cooldown(rt.disengage_id) == 0 then
        if (rt.last_disengage_time or 0) == 0 or (now - rt.last_disengage_time) >= 20 then
            if utils.can_cast_self(rt.disengage_id, me) then
                if utils.cast_self(rt.disengage_id, me) then
                    rt.last_disengage_time = now
                    st.slowed_until = now + 2.0
                    utils.log_debug(menu, "[Kiting] Disengage")
                    return true
                end
            end
        end
    end

    -- NOTHING to cast for kiting - don't block the main rotation
    return false
end

function kiting_manager.should_kite_preemptively(me, target, rt, spells, utils, spec_name)
    local st = get_spec_state(spec_name)
    return st.preemptive_kiting == true
end

function kiting_manager.is_kiting(spec_name)
    local st = get_spec_state(spec_name)
    return st.state == STATE_KITING
end

function kiting_manager.reset(spec_name)
    local st = get_spec_state(spec_name)
    st.state = STATE_IDLE
    st.last_target_guid = nil
    st.target_positions = {}
    st.target_times = {}
    st.slowed_until = 0
    st.last_concussive = 0
    st.last_wingclip = 0
    st.last_disengage = 0
    st.kiting_started = 0
    st.preemptive_kiting = false
end

return kiting_manager
