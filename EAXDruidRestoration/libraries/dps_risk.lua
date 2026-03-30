local dps_risk = {}

local function clamp01(value)
    local n = tonumber(value) or 0
    if n < 0 then
        return 0
    end
    if n > 1 then
        return 1
    end
    return n
end

local function section(snapshot, key)
    local value = (snapshot or {})[key]
    if type(value) == "table" then
        return value
    end
    return {}
end

local function damage_pct(snapshot)
    return clamp01(section(snapshot, "self").incoming_damage_pct_2s)
end

local function threat_pct(snapshot)
    return clamp01(section(snapshot, "self").threat_pct)
end

local function collapse_risk(snapshot)
    return clamp01(section(snapshot, "party").group_collapse_risk)
end

local function target_unstable(snapshot, opts)
    local target = section(snapshot, "target")
    local unstable_ttd_s = tonumber((opts or {}).unstable_ttd_s) or 10
    local target_hp = clamp01(target.hp_pct)
    local ttd_s = tonumber(target.time_to_die_s) or math.huge

    return target.exists == false
        or ttd_s <= unstable_ttd_s
        or target_hp <= 0.10
end

local function dangerous_control_window(snapshot)
    local encounter = section(snapshot, "encounter")
    return encounter.dangerous_control_window == true
        or encounter.interrupt_priority == true
end

function dps_risk.should_hold_offense(snapshot, opts)
    opts = opts or {}

    if damage_pct(snapshot) >= (tonumber(opts.hold_damage_pct) or 0.30) then
        return true
    end

    if threat_pct(snapshot) >= (tonumber(opts.hold_threat_pct) or 0.85) then
        return true
    end

    if dangerous_control_window(snapshot) then
        return true
    end

    if target_unstable(snapshot, opts) then
        return true
    end

    return false
end

function dps_risk.should_drop_threat(snapshot, opts)
    opts = opts or {}

    if threat_pct(snapshot) >= (tonumber(opts.drop_threat_pct) or 0.90) then
        return true
    end

    return threat_pct(snapshot) >= (tonumber(opts.pressure_threat_pct) or 0.80)
        and damage_pct(snapshot) >= (tonumber(opts.pressure_damage_pct) or 0.30)
end

function dps_risk.should_abort_commit(snapshot, cast_state, opts)
    opts = opts or {}
    cast_state = cast_state or {}

    local progress_pct = clamp01(cast_state.progress_pct)
    local remaining_s = tonumber(cast_state.remaining_s) or 0
    local projected_damage_pct = clamp01(cast_state.projected_damage_pct)
    local rising_danger = damage_pct(snapshot) >= (tonumber(opts.abort_damage_pct) or 0.30)
        and threat_pct(snapshot) >= (tonumber(opts.abort_threat_pct) or 0.80)
    local chaos_window = collapse_risk(snapshot) >= (tonumber(opts.abort_collapse_risk) or 0.40)
        or dangerous_control_window(snapshot)
    local low_commit_value = projected_damage_pct <= (tonumber(opts.abort_damage_value_pct) or 0.10)
        and remaining_s >= (tonumber(opts.abort_remaining_s) or 0.75)

    if not rising_danger and not chaos_window then
        return false
    end

    if progress_pct >= (tonumber(opts.finish_progress_pct) or 0.70) then
        return false
    end

    return low_commit_value
end

return dps_risk
