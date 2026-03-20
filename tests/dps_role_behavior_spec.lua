local ok, dps_risk = pcall(require, "eax_shared/dps_risk")

assert(ok, "dps risk helper should load")

local function make_snapshot(overrides)
    local snapshot = {
        self = {
            hp_pct = 0.92,
            incoming_damage_pct_2s = 0.05,
            threat_pct = 0.25,
        },
        target = {
            exists = true,
            hp_pct = 0.84,
            time_to_die_s = 30,
        },
        party = {
            group_collapse_risk = 0.10,
        },
        encounter = {
            dangerous_control_window = false,
            interrupt_priority = false,
        },
    }

    if overrides then
        for section, values in pairs(overrides) do
            if type(values) == "table" and type(snapshot[section]) == "table" then
                for key, value in pairs(values) do
                    snapshot[section][key] = value
                end
            else
                snapshot[section] = values
            end
        end
    end

    return snapshot
end

do
    local hold_for_danger_window = dps_risk.should_hold_offense(make_snapshot({
        self = {
            incoming_damage_pct_2s = 0.34,
            threat_pct = 0.82,
        },
    }))
    assert(hold_for_danger_window == true, "danger window should hold offense")

    local hold_for_wipe_risk_control = dps_risk.should_hold_offense(make_snapshot({
        encounter = {
            dangerous_control_window = true,
            interrupt_priority = true,
        },
    }))
    assert(hold_for_wipe_risk_control == true, "wipe-risk control window should hold offense")

    local keep_sending_when_safe = dps_risk.should_hold_offense(make_snapshot())
    assert(keep_sending_when_safe == false, "safe throughput should not hold offense")
end

do
    local drop_for_high_threat = dps_risk.should_drop_threat(make_snapshot({
        self = {
            threat_pct = 0.91,
            incoming_damage_pct_2s = 0.12,
        },
    }))
    assert(drop_for_high_threat == true, "true threat windows should drop threat")

    local drop_for_rising_pressure = dps_risk.should_drop_threat(make_snapshot({
        self = {
            threat_pct = 0.83,
            incoming_damage_pct_2s = 0.31,
        },
    }))
    assert(drop_for_rising_pressure == true, "danger window plus threat should drop threat")

    local routine_safe_throughput = dps_risk.should_drop_threat(make_snapshot({
        self = {
            threat_pct = 0.72,
            incoming_damage_pct_2s = 0.08,
        },
    }))
    assert(routine_safe_throughput == false, "safe routine throughput should not drop threat")
end

do
    local abort_danger_window = dps_risk.should_abort_commit(
        make_snapshot({
            self = {
                incoming_damage_pct_2s = 0.37,
                threat_pct = 0.86,
            },
            party = {
                group_collapse_risk = 0.46,
            },
        }),
        {
            kind = "cast",
            progress_pct = 0.18,
            remaining_s = 1.7,
            projected_damage_pct = 0.06,
        }
    )
    assert(abort_danger_window == true, "danger window cast should abort commit")

    local finish_marginally_risky_commit = dps_risk.should_abort_commit(
        make_snapshot({
            self = {
                incoming_damage_pct_2s = 0.20,
                threat_pct = 0.55,
            },
        }),
        {
            kind = "cast",
            progress_pct = 0.84,
            remaining_s = 0.3,
            projected_damage_pct = 0.18,
        }
    )
    assert(finish_marginally_risky_commit == false, "safe or already-committed casts should finish")
end

print("dps_role_behavior_spec: ok")
