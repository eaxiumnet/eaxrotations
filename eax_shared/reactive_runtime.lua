local combat_context = require("eax_shared/combat_context")
local dps_meter = require("eax_shared/dps_meter")
local reactive_engine = require("eax_shared/reactive_engine")

local reactive_runtime = {}

local function load_health_prediction()
    local ok, module = pcall(require, "health_prediction")
    if ok then
        return module
    end

    local chunk = loadfile(".api/common/modules/health_prediction.lua")
    if type(chunk) == "function" then
        local chunk_ok, fallback = pcall(chunk)
        if chunk_ok then
            return fallback
        end
    end

    return nil
end

local DEFAULT_ACTIONS = {
    life_save_self = function(ctx)
        if ctx.self.hp_pct > 0 and ctx.self.hp_pct <= 0.35 then
            return { action_id = "life_save_self" }
        end
    end,
    life_save_ally = function(ctx)
        if ctx.party.any_ally_critical then
            return { action_id = "life_save_ally" }
        end
    end,
    interrupt_control = function(ctx)
        if ctx.target.exists
            and (ctx.target.is_casting or ctx.target.is_channeling)
            and ctx.target.interruptible then
            return { action_id = "interrupt_control" }
        end
    end,
    anti_overheal = function(ctx)
        if ctx.self.incoming_heal_pct >= 0.50 and ctx.self.hp_pct >= 0.85 then
            return { action_id = "anti_overheal" }
        end
    end,
    anti_aggro = function(ctx)
        if ctx.self.threat_pct >= 0.90 and not ctx.self.is_tank then
            return { action_id = "anti_aggro" }
        end
    end,
    throughput_resume = function(ctx)
        if ctx.meta.fail_safe ~= true then
            return { action_id = "throughput_resume", hold_until_s = 0 }
        end
    end,
}

reactive_runtime.DEFAULT_ACTIONS = DEFAULT_ACTIONS

function reactive_runtime.update_tick(me, target, deps)
    deps = deps or {}

    local ctx = combat_context.build(me, target, nil, {
        health_prediction = load_health_prediction(),
        encounter_manager = deps.encounter_manager,
        party_reader = deps.party_reader,
        now_s = deps.now_s,
    })

    local result = reactive_engine.try_handle(ctx, {
        state = deps.state,
        actions = DEFAULT_ACTIONS,
    })

    dps_meter.set_reactive_state({
        reactive_action = result.action_id or "none",
        action_id = result.action_id or "none",
        reason_code = result.reason_code or "NO_ACTION",
        context_fail_safe = ctx.meta.fail_safe == true,
    })

    return ctx, result
end

return reactive_runtime
