local reactive_engine = require("eax_shared/reactive_engine")

local function make_ctx(overrides)
    local ctx = {
        meta = {
            now_s = 10,
            valid = true,
            fail_safe = false,
        },
        self = {
            hp_pct = 1,
            incoming_heal_pct = 0,
            incoming_damage_2s = 0,
            threat_pct = 0,
            role = "damager",
            is_tank = false,
        },
        target = {
            exists = true,
            hp_pct = 1,
            is_casting = false,
            is_channeling = false,
            spell_id = 0,
            interruptible = false,
        },
        party = {
            lowest_hp_pct = 1,
            any_ally_critical = false,
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

local function make_deps()
    local calls = {}
    return {
        calls = calls,
        actions = {
            life_save_self = function(ctx)
                calls[#calls + 1] = "life_save_self"
                return ctx.self.hp_pct <= 0.20 and { action_id = "self_panic_button" } or nil
            end,
            life_save_ally = function(ctx)
                calls[#calls + 1] = "life_save_ally"
                return ctx.party.any_ally_critical and { action_id = "ally_emergency" } or nil
            end,
            interrupt_control = function(ctx)
                calls[#calls + 1] = "interrupt_control"
                return ctx.target.is_casting and ctx.target.interruptible and { action_id = "kick" } or nil
            end,
            anti_overheal = function(ctx)
                calls[#calls + 1] = "anti_overheal"
                return ctx.self.incoming_heal_pct >= 0.60 and { action_id = "cancel_heal" } or nil
            end,
            anti_aggro = function(ctx)
                calls[#calls + 1] = "anti_aggro"
                return ctx.self.threat_pct >= 0.90 and { action_id = "drop_threat" } or nil
            end,
            throughput_resume = function(ctx)
                calls[#calls + 1] = "throughput_resume"
                return ctx.encounter.burn_phase and { action_id = "resume_burst" } or nil
            end,
        },
    }
end

do
    local deps = make_deps()
    local result = reactive_engine.try_handle(make_ctx({
        self = { hp_pct = 0.15, incoming_heal_pct = 0.80, threat_pct = 0.95 },
        party = { any_ally_critical = true },
        target = { is_casting = true, interruptible = true },
        encounter = { burn_phase = true },
    }), deps)

    assert(result.acted == true, "highest-priority branch should act")
    assert(result.reason_code == "LIFE_SAVE_SELF", "life-save self should win first")
    assert(result.action_id == "self_panic_button", "winner should surface its action id")
    assert(#deps.calls == 1, "engine should stop after first winning branch")
    assert(deps.calls[1] == "life_save_self", "engine should evaluate in fixed order")
end

do
    local deps = make_deps()
    local no_action = reactive_engine.try_handle(make_ctx(), deps)

    assert(no_action.acted == false, "idle result should not act")
    assert(no_action.reason_code == "NO_ACTION", "idle result should use NO_ACTION")
    assert(type(no_action.action_id) == "string", "idle result should still include action_id")

    local fail_safe = reactive_engine.try_handle(make_ctx({
        meta = { fail_safe = true, now_s = 22 },
    }), make_deps())
    assert(fail_safe.reason_code == "FAIL_SAFE_HOLD", "fail-safe snapshot should hold")
    assert(fail_safe.action_id == "none", "fail-safe hold should use placeholder action id")
end

print("reactive_engine_spec: ok")
