local function clone_member(member)
    local copy = {}
    for key, value in pairs(member or {}) do
        copy[key] = value
    end
    return copy
end

local function make_member(id, hp_pct, incoming_heal_pct, role, extras)
    local member = {
        guid = id,
        unit = { id = id },
        hp_pct = hp_pct,
        incoming_heal_pct = incoming_heal_pct or 0,
        role = role or "damager",
        is_tank = role == "tank",
    }

    for key, value in pairs(extras or {}) do
        member[key] = value
    end

    return member
end

local function make_units(overrides)
    local tank = make_member("tank", 0.80, 0.00, "tank")
    local ally = make_member("ally", 0.65, 0.00, "damager")
    local mage = make_member("mage", 0.72, 0.00, "damager")
    local units = { tank, ally, mage }

    overrides = overrides or {}
    for index, patch in pairs(overrides) do
        units[index] = clone_member(units[index])
        for key, value in pairs(patch) do
            units[index][key] = value
        end
    end

    return units
end

local healer_triage = require("eax_shared/healer_triage")

do
    local units = make_units({
        [1] = { hp_pct = 0.52, incoming_heal_pct = 0.10 },
        [2] = { hp_pct = 0.21, incoming_heal_pct = 0.05 },
    })
    local winner = healer_triage.select_target(units[2], units, {})

    assert(winner and winner.reason == "tank_save", "tank_save should win while the tank is unstable")
    assert(winner.target_guid == "tank", "tank_save should point at the tank first")
    assert(winner.emergency == true, "tank_save should mark emergency coverage")
end

do
    local units = make_units({
        [1] = { hp_pct = 0.78, incoming_heal_pct = 0.30 },
        [2] = { hp_pct = 0.28, incoming_heal_pct = 0.02 },
        [3] = { hp_pct = 0.33, incoming_heal_pct = 0.33 },
    })
    local winner = healer_triage.select_target(units[2], units, {})

    assert(winner and winner.reason == "triage_save", "stable tank should move triage to the lowest uncovered ally")
    assert(winner.target_guid == "ally", "triage_save should prefer the lowest uncovered ally")
    assert(winner.covered_hold == false, "triage_save should not mark covered_hold")
end

do
    local covered_hold = healer_triage.should_cancel_overheal({
        hp_pct = 0.90,
        incoming_heal_pct = 0.55,
        collapse_risk = false,
    }, {})
    local still_dangerous = healer_triage.should_cancel_overheal({
        hp_pct = 0.64,
        incoming_heal_pct = 0.52,
        collapse_risk = true,
    }, {})

    assert(covered_hold == true, "covered_hold should cancel clearly overhealed casts")
    assert(still_dangerous == false, "dangerous targets must not cancel stabilizing casts")
end

do
    local units = make_units({
        [1] = { hp_pct = 0.54, incoming_heal_pct = 0.05 },
        [2] = { hp_pct = 0.32, incoming_heal_pct = 0.00 },
        [3] = { hp_pct = 0.48, incoming_heal_pct = 0.04 },
    })
    units[4] = make_member("rogue", 0.44, 0.00, "damager")
    local winner = healer_triage.select_target(units[2], units, {})

    assert(winner and winner.reason == "group_stabilize", "group collapse should prefer group_stabilize")
    assert(winner.target_guid == "ally", "group_stabilize should still anchor on the lowest ally target")
    assert(winner.group_count == 4, "group_stabilize should report the injured count")
end

print("healer_role_behavior_spec: ok")
