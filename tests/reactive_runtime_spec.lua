local dps_meter = require("eax_shared/dps_meter")

local function with_stub_modules(overrides, fn)
    local originals = {}
    for name, module in pairs(overrides) do
        originals[name] = package.loaded[name]
        package.loaded[name] = module
    end

    local ok, err = pcall(fn)

    for name, module in pairs(originals) do
        package.loaded[name] = module
    end

    if not ok then
        error(err)
    end
end

local chunk, err = loadfile("eax_shared/reactive_runtime.lua")
assert(chunk, "expected eax_shared/reactive_runtime.lua to exist: " .. tostring(err))

with_stub_modules({
    ["eax_shared/combat_context"] = {
        build = function(me, target, spec_meta, deps)
            assert(me == "me", "me should be forwarded")
            assert(target == "target", "target should be forwarded")
            assert(spec_meta == nil, "spec_meta should stay nil")
            assert(type(deps) == "table", "combat deps should be table")
            assert(type(deps.health_prediction) == "table", "health_prediction should be loaded")
            return {
                meta = { fail_safe = false, now_s = 42 },
                self = { hp_pct = 0.25, incoming_heal_pct = 0, threat_pct = 0.2, is_tank = false },
                target = { exists = false, is_casting = false, is_channeling = false, interruptible = false },
                party = { any_ally_critical = false },
            }
        end,
    },
    ["eax_shared/reactive_engine"] = {
        try_handle = function(ctx, deps)
            assert(ctx.self.hp_pct == 0.25, "runtime should pass built context")
            assert(type(deps.state) == "table", "runtime should forward state")
            assert(type(deps.actions.life_save_self) == "function", "life_save_self handler should exist")
            assert(type(deps.actions.interrupt_control) == "function", "interrupt_control handler should exist")

            local chosen = deps.actions.life_save_self(ctx, deps)
            assert(chosen and chosen.action_id == "life_save_self", "life_save_self should win when hp is critical")

            return {
                acted = true,
                reason_code = "LIFE_SAVE_SELF",
                action_id = "life_save_self",
                hold_until_s = 42.5,
            }
        end,
    },
    ["health_prediction"] = {
        get_incoming_damage = function() return 0 end,
        get_role_id = function() return 2 end,
        is_tank = function() return false end,
    },
}, function()
    package.loaded["eax_shared/reactive_runtime"] = nil
    local reactive_runtime = chunk("eax_shared.reactive_runtime")
    assert(type(reactive_runtime) == "table", "reactive_runtime should return module table")
    assert(type(reactive_runtime.update_tick) == "function", "update_tick must be defined")

    dps_meter.reset()
    local ctx, result = reactive_runtime.update_tick("me", "target", {
        state = {},
        now_s = function() return 42 end,
    })

    assert(type(ctx) == "table", "update_tick should return ctx")
    assert(type(result) == "table", "update_tick should return result")
    assert(result.action_id == "life_save_self", "life_save_self should become action_id")

    local snapshot = dps_meter.get_snapshot()
    assert(snapshot.reactive_action == result.action_id, "reactive_action should mirror winning action_id")
    assert(snapshot.reason_code == result.reason_code, "reason_code should persist to benchmark snapshot")
end)

print("reactive_runtime_spec: ok")
