local dps_meter = require("eax_shared/dps_meter")

local function with_stub_modules(overrides, fn)
    local originals = {}
    for name, module in pairs(overrides) do
        originals[name] = package.loaded[name]
        package.loaded[name] = module
    end

    local ok, result = pcall(fn)

    for name, module in pairs(originals) do
        package.loaded[name] = module
    end

    if not ok then
        error(result)
    end

    return result
end

local function make_unit(id)
    return {
        id = id,
        is_valid = function() return true end,
        is_dead = function() return false end,
        get_guid = function(self) return self.id end,
    }
end

local function load_runtime(stubs)
    local chunk, err = loadfile("eax_shared/reactive_runtime.lua")
    assert(chunk, "expected eax_shared/reactive_runtime.lua to exist: " .. tostring(err))

    return with_stub_modules(stubs, function()
        package.loaded["eax_shared/reactive_runtime"] = nil
        local reactive_runtime = chunk("eax_shared.reactive_runtime")
        assert(type(reactive_runtime) == "table", "reactive_runtime should return module table")
        assert(type(reactive_runtime.update_tick) == "function", "update_tick must be defined")
        return reactive_runtime
    end)
end

local function run_with_core(core_stub, fn)
    local original_core = _G.core
    _G.core = core_stub
    local ok, err = pcall(fn)
    _G.core = original_core
    if not ok then
        error(err)
    end
end

local function make_adapter(overrides)
    local adapter = {
        spec = "TestSpec",
        actions = {
            life_save_self = { noop = "unsupported" },
            life_save_ally = { noop = "unsupported" },
            interrupt_control = { noop = "unsupported" },
            anti_overheal = { noop = "unsupported" },
            anti_aggro = { noop = "unsupported" },
            throughput_resume = { noop = "unsupported" },
        },
    }

    overrides = overrides or {}
    for key, value in pairs(overrides) do
        if key == "actions" then
            for action_name, action_value in pairs(value) do
                adapter.actions[action_name] = action_value
            end
        else
            adapter[key] = value
        end
    end

    return adapter
end

local function base_context()
    return {
        meta = { fail_safe = false, now_s = 42 },
        self = { hp_pct = 0.25, incoming_heal_pct = 0, threat_pct = 0.2, is_tank = false },
        target = { exists = true, is_casting = true, is_channeling = false, interruptible = true },
        party = { any_ally_critical = false },
    }
end

local function assert_snapshot(action_id, reason_code, reactive_status)
    local snapshot = dps_meter.get_snapshot()
    assert(snapshot.reactive_action == action_id, "reactive_action should mirror winning action_id")
    assert(snapshot.reason_code == reason_code, "reason_code should persist to benchmark snapshot")
    assert(snapshot.reactive_status == reactive_status, "reactive_status should persist to benchmark snapshot")
end

local current_target = make_unit("current-target")
local urgent_target = make_unit("urgent-target")

local common_stubs = {
    ["eax_shared/combat_context"] = {
        build = function(me, target, spec_meta, deps)
            assert(me == "me", "me should be forwarded")
            assert(target == current_target, "target should be forwarded")
            assert(spec_meta == nil, "spec_meta should stay nil")
            assert(type(deps) == "table", "combat deps should be table")
            assert(type(deps.health_prediction) == "table", "health_prediction should be loaded")
            return base_context()
        end,
    },
    ["eax_shared/reactive_engine"] = {
        try_handle = function(ctx, deps)
            assert(ctx.self.hp_pct == 0.25, "runtime should pass built context")
            assert(type(deps.state) == "table", "runtime should forward state")
            return {
                acted = true,
                reason_code = "INTERRUPT_DANGER",
                action_id = "interrupt_control",
                hold_until_s = 42.5,
            }
        end,
    },
    ["health_prediction"] = {
        get_incoming_damage = function() return 0 end,
        get_role_id = function() return 2 end,
        is_tank = function() return false end,
    },
}

run_with_core({
    input = {
        set_target = function(unit)
            assert(unit == urgent_target or unit == current_target, "set_target should use resolved targets")
            return true
        end,
    },
}, function()
    local handled_calls = 0
    local reactive_runtime = load_runtime(common_stubs)
    dps_meter.reset()

    local ctx, result = reactive_runtime.update_tick("me", current_target, {
        state = {},
        adapter = make_adapter({
            actions = {
                interrupt_control = {
                    handler = function(action_ctx, action_deps)
                        handled_calls = handled_calls + 1
                        assert(action_ctx == ctx, "handler should receive the built context")
                        assert(action_deps.adapter.spec == "TestSpec", "handler should receive adapter deps")
                        return true
                    end,
                },
            },
            resolve_target = function(action_id)
                assert(action_id == "interrupt_control", "resolve_target should receive winning action id")
                return urgent_target
            end,
        }),
    })

    assert(type(ctx) == "table", "update_tick should return ctx")
    assert(type(result) == "table", "update_tick should return result")
    assert(result.action_id == "interrupt_control", "interrupt_control should become action_id")
    assert(result.reactive_status == "handled", "handled adapter executions should be marked")
    assert(handled_calls == 1, "real handler should execute exactly once")
    assert_snapshot("interrupt_control", "INTERRUPT_DANGER", "handled")
end)

run_with_core({
    input = {
        set_target = function()
            error("set_target should not be called for unsupported actions")
        end,
    },
}, function()
    local reactive_runtime = load_runtime(common_stubs)
    dps_meter.reset()

    local _, result = reactive_runtime.update_tick("me", current_target, {
        state = {},
        adapter = make_adapter(),
    })

    assert(result.reactive_status == "noop_unsupported", "explicit noop branches should report noop_unsupported")
    assert_snapshot("interrupt_control", "INTERRUPT_DANGER", "noop_unsupported")
end)

run_with_core({
    input = {
        set_target = function()
            error("unsafe retarget should not call set_target")
        end,
    },
}, function()
    local handler_called = false
    local unsafe_target = {
        is_valid = function() return false end,
        is_dead = function() return false end,
    }

    local reactive_runtime = load_runtime(common_stubs)
    dps_meter.reset()

    local _, result = reactive_runtime.update_tick("me", current_target, {
        state = {},
        adapter = make_adapter({
            actions = {
                interrupt_control = {
                    handler = function()
                        handler_called = true
                        return true
                    end,
                },
            },
            resolve_target = function()
                return unsafe_target
            end,
        }),
    })

    assert(result.reactive_status == "skipped_unsafe", "unsafe retargets should report skipped_unsafe")
    assert(handler_called == false, "unsafe retargets should not execute the handler")
    assert_snapshot("interrupt_control", "INTERRUPT_DANGER", "skipped_unsafe")
end)

print("reactive_runtime_spec: ok")
