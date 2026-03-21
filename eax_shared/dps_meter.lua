local dps_meter = {}

local VALID_ROLE_SIGNALS = {
    tank_save = true,
    triage_save = true,
    group_stabilize = true,
    threat_recovery = true,
    danger_hold = true,
    none = true,
}

local VALID_ROLE_TARGET_KINDS = {
    self = true,
    tank = true,
    ally = true,
    hostile = true,
    none = true,
}

local function normalize_role_signal(value)
    local signal = tostring(value or "none")
    if VALID_ROLE_SIGNALS[signal] then
        return signal
    end
    return "none"
end

local function normalize_role_target_kind(value)
    local kind = tostring(value or "none")
    if VALID_ROLE_TARGET_KINDS[kind] then
        return kind
    end
    return "none"
end

local function now_s()
    if core and core.time then
        local t = core.time()
        if type(t) == "number" then
            return t
        end
    end
    return os.clock()
end

local function zero_snapshot()
    return {
        damage_total = 0,
        healing_total = 0,
        threat_total = 0,
        duration_s = 0,
        dps = 0,
        hps = 0,
        tps = 0,
        sample_count = 0,
        reactive_event_count = 0,
        noop_unsupported_count = 0,
        unsafe_skip_count = 0,
        fail_safe_tick_count = 0,
        in_combat = false,
        reactive_action = "none",
        action_id = "none",
        reason_code = "NO_ACTION",
        reactive_status = "none",
        context_fail_safe = false,
        role_signal = "none",
        role_target_kind = "none",
    }
end

local function zero_reactive_state()
    return {
        reactive_action = "none",
        action_id = "none",
        reason_code = "NO_ACTION",
        reactive_status = "none",
        context_fail_safe = false,
        role_signal = "none",
        role_target_kind = "none",
    }
end

local state = {
    in_combat = false,
    started_at = 0,
    damage_total = 0,
    healing_total = 0,
    threat_total = 0,
    sample_count = 0,
    reactive_event_count = 0,
    noop_unsupported_count = 0,
    unsafe_skip_count = 0,
    fail_safe_tick_count = 0,
    last_threat_pct = 0,
    last_snapshot = zero_snapshot(),
    reactive = zero_reactive_state(),
}

local function as_amount(amount)
    local n = tonumber(amount) or 0
    if n < 0 then
        return 0
    end
    return n
end

local function build_snapshot(damage_total, healing_total, threat_total, sample_count, duration_s, in_combat)
    local safe_duration = tonumber(duration_s) or 0
    local dps = 0
    local hps = 0
    local tps = 0

    if safe_duration >= 0.1 then
        dps = damage_total / safe_duration
        hps = healing_total / safe_duration
        tps = threat_total / safe_duration
    end

    return {
        damage_total = damage_total,
        healing_total = healing_total,
        threat_total = threat_total,
        duration_s = safe_duration,
        dps = dps,
        hps = hps,
        tps = tps,
        sample_count = sample_count,
        reactive_event_count = state.reactive_event_count,
        noop_unsupported_count = state.noop_unsupported_count,
        unsafe_skip_count = state.unsafe_skip_count,
        fail_safe_tick_count = state.fail_safe_tick_count,
        in_combat = in_combat,
        reactive_action = state.reactive.reactive_action,
        action_id = state.reactive.action_id,
        reason_code = state.reactive.reason_code,
        reactive_status = state.reactive.reactive_status,
        context_fail_safe = state.reactive.context_fail_safe,
        role_signal = state.reactive.role_signal,
        role_target_kind = state.reactive.role_target_kind,
    }
end

local function clear_reactive_state()
    state.reactive = zero_reactive_state()
end

function dps_meter.on_combat_start()
    state.in_combat = true
    state.started_at = now_s()
    state.damage_total = 0
    state.healing_total = 0
    state.threat_total = 0
    state.sample_count = 0
    state.reactive_event_count = 0
    state.noop_unsupported_count = 0
    state.unsafe_skip_count = 0
    state.fail_safe_tick_count = 0
    state.last_threat_pct = 0
    clear_reactive_state()
end

function dps_meter.on_damage(amount)
    if not state.in_combat then
        return
    end
    state.damage_total = state.damage_total + as_amount(amount)
end

function dps_meter.on_heal(amount)
    if not state.in_combat then
        return
    end
    state.healing_total = state.healing_total + as_amount(amount)
end

function dps_meter.record_threat_sample(threat_pct, now_override)
    if not state.in_combat then
        return
    end

    local pct = tonumber(threat_pct) or 0
    if pct < 0 then
        pct = 0
    elseif pct > 1 then
        pct = 1
    end

    local delta = pct - state.last_threat_pct
    if delta > 0 then
        state.threat_total = state.threat_total + delta
    end
    state.last_threat_pct = pct
    state.sample_count = state.sample_count + 1
end

function dps_meter.increment_counter(counter_name, amount)
    if type(state[counter_name]) ~= "number" then
        return
    end

    state[counter_name] = state[counter_name] + (tonumber(amount) or 1)
end

function dps_meter.on_combat_end()
    local duration_s = 0
    if state.in_combat then
        duration_s = math.max(0, now_s() - state.started_at)
    end

    state.last_snapshot = build_snapshot(
        state.damage_total,
        state.healing_total,
        state.threat_total,
        state.sample_count,
        duration_s,
        false
    )

    state.in_combat = false
    state.started_at = 0
    state.damage_total = 0
    state.healing_total = 0
    state.threat_total = 0
    state.sample_count = 0
    state.reactive_event_count = 0
    state.noop_unsupported_count = 0
    state.unsafe_skip_count = 0
    state.fail_safe_tick_count = 0
    state.last_threat_pct = 0
    clear_reactive_state()
end

function dps_meter.reset()
    state.in_combat = false
    state.started_at = 0
    state.damage_total = 0
    state.healing_total = 0
    state.threat_total = 0
    state.sample_count = 0
    state.reactive_event_count = 0
    state.noop_unsupported_count = 0
    state.unsafe_skip_count = 0
    state.fail_safe_tick_count = 0
    state.last_threat_pct = 0
    state.last_snapshot = zero_snapshot()
    clear_reactive_state()
end

function dps_meter.set_reactive_state(payload)
    payload = payload or {}
    state.reactive = {
        reactive_action = tostring(payload.reactive_action or payload.action_id or "none"),
        action_id = tostring(payload.action_id or payload.reactive_action or "none"),
        reason_code = tostring(payload.reason_code or "NO_ACTION"),
        reactive_status = tostring(payload.reactive_status or "none"),
        context_fail_safe = payload.context_fail_safe == true,
        role_signal = normalize_role_signal(payload.role_signal),
        role_target_kind = normalize_role_target_kind(payload.role_target_kind),
    }
end

function dps_meter.get_snapshot()
    if state.in_combat then
        local duration_s = math.max(0, now_s() - state.started_at)
        return build_snapshot(state.damage_total, state.healing_total, state.threat_total, state.sample_count, duration_s, true)
    end

    return {
        damage_total = state.last_snapshot.damage_total,
        healing_total = state.last_snapshot.healing_total,
        threat_total = state.last_snapshot.threat_total,
        duration_s = state.last_snapshot.duration_s,
        dps = state.last_snapshot.dps,
        hps = state.last_snapshot.hps,
        tps = state.last_snapshot.tps,
        sample_count = state.last_snapshot.sample_count,
        reactive_event_count = state.last_snapshot.reactive_event_count,
        noop_unsupported_count = state.last_snapshot.noop_unsupported_count,
        unsafe_skip_count = state.last_snapshot.unsafe_skip_count,
        fail_safe_tick_count = state.last_snapshot.fail_safe_tick_count,
        in_combat = false,
        reactive_action = state.reactive.reactive_action,
        action_id = state.reactive.action_id,
        reason_code = state.reactive.reason_code,
        reactive_status = state.reactive.reactive_status,
        context_fail_safe = state.reactive.context_fail_safe,
        role_signal = state.reactive.role_signal,
        role_target_kind = state.reactive.role_target_kind,
    }
end

return dps_meter
