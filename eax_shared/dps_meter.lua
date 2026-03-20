local dps_meter = {}

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
        duration_s = 0,
        dps = 0,
        hps = 0,
        in_combat = false,
    }
end

local state = {
    in_combat = false,
    started_at = 0,
    damage_total = 0,
    healing_total = 0,
    last_snapshot = zero_snapshot(),
}

local function as_amount(amount)
    local n = tonumber(amount) or 0
    if n < 0 then
        return 0
    end
    return n
end

local function build_snapshot(damage_total, healing_total, duration_s, in_combat)
    local safe_duration = tonumber(duration_s) or 0
    local dps = 0
    local hps = 0

    if safe_duration >= 0.1 then
        dps = damage_total / safe_duration
        hps = healing_total / safe_duration
    end

    return {
        damage_total = damage_total,
        healing_total = healing_total,
        duration_s = safe_duration,
        dps = dps,
        hps = hps,
        in_combat = in_combat,
    }
end

function dps_meter.on_combat_start()
    state.in_combat = true
    state.started_at = now_s()
    state.damage_total = 0
    state.healing_total = 0
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

function dps_meter.on_combat_end()
    local duration_s = 0
    if state.in_combat then
        duration_s = math.max(0, now_s() - state.started_at)
    end

    state.last_snapshot = build_snapshot(
        state.damage_total,
        state.healing_total,
        duration_s,
        false
    )

    state.in_combat = false
    state.started_at = 0
    state.damage_total = 0
    state.healing_total = 0
end

function dps_meter.reset()
    state.in_combat = false
    state.started_at = 0
    state.damage_total = 0
    state.healing_total = 0
    state.last_snapshot = zero_snapshot()
end

function dps_meter.get_snapshot()
    if state.in_combat then
        local duration_s = math.max(0, now_s() - state.started_at)
        return build_snapshot(state.damage_total, state.healing_total, duration_s, true)
    end

    return {
        damage_total = state.last_snapshot.damage_total,
        healing_total = state.last_snapshot.healing_total,
        duration_s = state.last_snapshot.duration_s,
        dps = state.last_snapshot.dps,
        hps = state.last_snapshot.hps,
        in_combat = false,
    }
end

return dps_meter
