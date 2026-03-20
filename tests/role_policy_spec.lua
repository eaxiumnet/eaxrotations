local role_policy = require("eax_shared/role_policy")

local function make_ctx(overrides)
    local ctx = {
        meta = {
            fail_safe = false,
            now_s = 42,
        },
        self = {
            hp_pct = 0.92,
            incoming_heal_pct = 0,
            incoming_damage_2s = 0,
            incoming_damage_pct_2s = 0,
            threat_pct = 0.10,
            role = "damager",
            is_tank = false,
        },
        target = {
            exists = true,
            is_casting = false,
            is_channeling = false,
            interruptible = false,
            cast_progress_pct = 0,
            victim_role = "damager",
            victim_is_self = false,
        },
        party = {
            lowest_hp_pct = 1,
            any_ally_critical = false,
            members = {},
            tank = nil,
            urgent_ally = nil,
            group_collapse_risk = 0,
        },
        encounter = {
            hold_cooldowns = false,
            burn_phase = false,
            interrupt_priority = false,
            tank_damage_heavy = false,
            raid_aoe_heavy = false,
        },
    }

    if overrides then
        for section, values in pairs(overrides) do
            if type(values) == "table" and type(ctx[section]) == "table" then
                for key, value in pairs(values) do
                    ctx[section][key] = value
                end
            else
                ctx[section] = values
            end
        end
    end

    return ctx
end

do
    local actions = role_policy.build_actions({ role = "healer" })
    local tank = { guid = "tank", hp_pct = 0.31, incoming_heal_pct = 0.04, role = "tank", is_tank = true }
    local ally = { guid = "ally", hp_pct = 0.27, incoming_heal_pct = 0.02, role = "damager", is_tank = false }
    local winner = actions.life_save_ally(make_ctx({
        self = { role = "healer" },
        party = {
            tank = tank,
            urgent_ally = ally,
            members = { tank, ally },
            lowest_hp_pct = 0.27,
            any_ally_critical = false,
            group_collapse_risk = 0.40,
        },
    }))

    assert(winner and winner.action_id == "life_save_ally", "healer policy should trigger life_save_ally")
    assert(winner.target_guid == "tank", "healer policy should save the tank before a non-tank ally")
end

do
    local actions = role_policy.build_actions({ role = "healer" })
    local tank = { guid = "tank", hp_pct = 0.31, incoming_heal_pct = 0.45, role = "tank", is_tank = true }
    local ally = { guid = "ally", hp_pct = 0.24, incoming_heal_pct = 0.00, role = "damager", is_tank = false }
    local winner = actions.life_save_ally(make_ctx({
        self = { role = "healer" },
        party = {
            tank = tank,
            urgent_ally = ally,
            members = { tank, ally },
            lowest_hp_pct = 0.24,
            any_ally_critical = true,
            group_collapse_risk = 0.55,
        },
    }))

    assert(winner and winner.target_guid == "ally", "covered tank policy should move to the next urgent ally")
end

do
    local actions = role_policy.build_actions({ role = "tank" })
    local winner = actions.anti_aggro(make_ctx({
        self = {
            role = "tank",
            is_tank = true,
            hp_pct = 0.62,
            incoming_damage_pct_2s = 0.18,
        },
        party = {
            group_collapse_risk = 0.52,
        },
        target = {
            victim_role = "healer",
            victim_is_self = false,
        },
    }))

    assert(winner and winner.action_id == "anti_aggro", "tank policy should recover aggro before throughput")
end

do
    local actions = role_policy.build_actions({ role = "tank" })
    local self_save = actions.life_save_self(make_ctx({
        self = {
            role = "tank",
            is_tank = true,
            hp_pct = 0.16,
            incoming_damage_pct_2s = 0.42,
        },
        target = {
            victim_role = "healer",
            victim_is_self = false,
        },
    }))

    assert(self_save and self_save.action_id == "life_save_self", "tank self-death should outrank tank policy anti_aggro")
end

do
    local actions = role_policy.build_actions({ role = "damager" })
    local winner = actions.interrupt_control(make_ctx({
        self = { role = "damager" },
        target = {
            exists = true,
            is_casting = true,
            interruptible = true,
            cast_progress_pct = 0.72,
            victim_role = "tank",
            victim_is_self = false,
        },
        encounter = {
            interrupt_priority = true,
        },
    }))

    assert(winner and winner.action_id == "interrupt_control", "interrupt_control should fire for the most dangerous cast")
    assert(winner.urgency_score and winner.urgency_score > 0.90, "interrupt_control should expose deterministic urgency")
end

print("role_policy_spec: ok")
