local ok, tank_recovery = pcall(require, "eax_shared/tank_recovery")

assert(ok, "tank_recovery module should load")

local function make_snapshot(overrides)
    local snapshot = {
        self = {
            hp_pct = 0.78,
            incoming_damage_pct_2s = 0.12,
            incoming_heal_pct = 0.00,
        },
        party = {
            group_collapse_risk = 0.18,
            threat_instability = 0.72,
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
    local result = tank_recovery.select_recovery_target(nil, {
        snapshot = make_snapshot(),
        candidates = {
            {
                guid = "melee-on-dps",
                victim_role = "damager",
                dangerous_caster = false,
                interruptible = false,
                cast_progress_pct = 0.00,
            },
            {
                guid = "caster-on-healer",
                victim_role = "healer",
                dangerous_caster = true,
                interruptible = true,
                cast_progress_pct = 0.68,
            },
        },
    })

    assert(result, "threat_instability windows should pick a recovery target")
    assert(result.guid == "caster-on-healer", "tank recovery should prefer the highest-danger hostile on the healer")
end

do
    local pressure_rising = tank_recovery.should_prioritize_defensive(make_snapshot({
        self = {
            hp_pct = 0.44,
            incoming_damage_pct_2s = 0.24,
        },
    }))
    local self_death_imminent = tank_recovery.should_prioritize_defensive(make_snapshot({
        self = {
            hp_pct = 0.18,
            incoming_damage_pct_2s = 0.42,
        },
    }))

    assert(pressure_rising == false, "recoverable pressure should still allow peel before personals")
    assert(self_death_imminent == true, "self_death_imminent pressure should prioritize defensives")
end

do
    local stable_window = tank_recovery.select_recovery_target(nil, {
        snapshot = make_snapshot({
            self = {
                hp_pct = 0.84,
                incoming_damage_pct_2s = 0.08,
            },
            party = {
                group_collapse_risk = 0.10,
                threat_instability = 0.10,
            },
        }),
        candidates = {
            {
                guid = "noise-target",
                victim_role = "damager",
                dangerous_caster = false,
                interruptible = false,
                cast_progress_pct = 0.00,
            },
        },
    })

    assert(stable_window == nil, "stable aggro windows should not trigger recovery spam")
end

print("tank_role_behavior_spec: ok")
