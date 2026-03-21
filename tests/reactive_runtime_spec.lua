local dps_meter = require("eax_shared/dps_meter")

local function run_with_core_time(core_stub, fn)
    local original_core = _G.core
    _G.core = core_stub
    local ok, err = pcall(fn)
    _G.core = original_core
    if not ok then
        error(err)
    end
end

local function assert_counter(snapshot, key, expected)
    assert(snapshot[key] == expected, key .. " should be " .. tostring(expected) .. ", got " .. tostring(snapshot[key]))
end

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

local run_with_core = run_with_core_time

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
        self = {
            hp_pct = 0.25,
            incoming_heal_pct = 0,
            incoming_damage_pct_2s = 0,
            threat_pct = 0.2,
            role = "damager",
            is_tank = false,
        },
        target = {
            exists = true,
            is_casting = true,
            is_channeling = false,
            interruptible = true,
            cast_progress_pct = 0,
            victim_role = "damager",
            victim_is_self = false,
        },
        party = {
            any_ally_critical = false,
            group_collapse_risk = 0,
            members = {},
            tank = nil,
            urgent_ally = nil,
        },
        encounter = {
            interrupt_priority = false,
            tank_damage_heavy = false,
        },
    }
end

local function merge_context(base, overrides)
    local merged = {}
    for section, values in pairs(base) do
        if type(values) == "table" then
            merged[section] = {}
            for key, value in pairs(values) do
                merged[section][key] = value
            end
        else
            merged[section] = values
        end
    end

    for section, values in pairs(overrides or {}) do
        if type(values) == "table" and type(merged[section]) == "table" then
            for key, value in pairs(values) do
                merged[section][key] = value
            end
        else
            merged[section] = values
        end
    end

    return merged
end

local function assert_snapshot(action_id, reason_code, reactive_status)
    local snapshot = dps_meter.get_snapshot()
    assert(snapshot.reactive_action == action_id, "reactive_action should mirror winning action_id")
    assert(snapshot.reason_code == reason_code, "reason_code should persist to benchmark snapshot")
    assert(snapshot.reactive_status == reactive_status, "reactive_status should persist to benchmark snapshot")
end

local current_target = make_unit("current-target")
local urgent_target = make_unit("urgent-target")
local tank_target = make_unit("tank-target")
local ally_target = make_unit("ally-target")

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
            assert(type(ctx.self) == "table", "runtime should pass built context")
            assert(type(ctx.self.hp_pct) == "number", "runtime should preserve self hp_pct")
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
    dps_meter.on_combat_start()

    local ctx, result = reactive_runtime.update_tick("me", current_target, {
        state = {},
        adapter = make_adapter({
            actions = {
                interrupt_control = {
                    handler = function(action_ctx, action_deps)
                        handled_calls = handled_calls + 1
                        assert(action_ctx.self.hp_pct == 0.25, "handler should receive the built context")
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
    local snapshot = dps_meter.get_snapshot()
    assert(snapshot.sample_count == 1, "runtime tick should increment sample_count")
    assert(snapshot.tps == 0, "single tick at zero elapsed time should keep tps at zero")
    assert_counter(snapshot, "reactive_event_count", 1)
    assert_counter(snapshot, "noop_unsupported_count", 0)
    assert_counter(snapshot, "unsafe_skip_count", 0)
    assert_counter(snapshot, "fail_safe_tick_count", 0)
end)

local function load_runtime_with_real_policy(ctx)
    package.loaded["eax_shared/reactive_engine"] = nil
    package.loaded["eax_shared/role_policy"] = nil
    return load_runtime({
        ["eax_shared/combat_context"] = {
            build = function(me, target, spec_meta, deps)
                assert(me == "me", "me should be forwarded")
                assert(target == current_target, "target should be forwarded")
                assert(spec_meta == nil, "spec_meta should stay nil")
                assert(type(deps.health_prediction) == "table", "health_prediction should be loaded")
                return ctx
            end,
        },
        ["health_prediction"] = {
            get_incoming_damage = function() return 0 end,
            get_role_id = function() return 2 end,
            is_tank = function() return false end,
        },
    })
end

local function run_policy_case(case)
    run_with_core({
        input = {
            set_target = function(unit)
                assert(unit == case.expected_target or unit == current_target, "set_target should use the case target")
                return true
            end,
        },
    }, function()
        local handled_calls = 0
        local reactive_runtime = load_runtime_with_real_policy(case.ctx)
        dps_meter.reset()

        local _, result = reactive_runtime.update_tick("me", current_target, {
            state = {},
            adapter = make_adapter({
                actions = {
                    [case.expected_action] = {
                        handler = function(action_ctx, action_deps)
                            handled_calls = handled_calls + 1
                            assert(action_ctx == case.ctx, "handler should receive the policy-built context")
                            assert(action_deps.action_id == case.expected_action, "handler should receive the winning action")
                            return true
                        end,
                    },
                },
                resolve_target = function(action_id, action_ctx)
                    assert(action_id == case.expected_action, "resolve_target should receive the winning action")
                    assert(action_ctx == case.ctx, "resolve_target should receive the built context")
                    return case.expected_target
                end,
            }),
        })

        assert(
            result.action_id == case.expected_action,
            case.name .. " should select the expected action (got " .. tostring(result.action_id) .. ")"
        )
        assert(
            result.reactive_status == "handled",
            case.name .. " should execute the adapter handler (got " .. tostring(result.reactive_status) .. ")"
        )
        assert(handled_calls == 1, case.name .. " should execute exactly one handler")
        assert_snapshot(case.expected_action, case.expected_reason, "handled")
    end)
end

run_policy_case({
    name = "healer tank-first life_save_ally",
    expected_action = "life_save_ally",
    expected_reason = "LIFE_SAVE_ALLY",
    expected_target = tank_target,
    ctx = merge_context(base_context(), {
        self = { role = "healer", hp_pct = 0.88 },
        target = { exists = false, is_casting = false, interruptible = false },
        party = {
            tank = { guid = "tank-target", unit = tank_target, hp_pct = 0.31, incoming_heal_pct = 0.05, role = "tank", is_tank = true },
            urgent_ally = { guid = "ally-target", unit = ally_target, hp_pct = 0.24, incoming_heal_pct = 0.00, role = "damager", is_tank = false },
            members = {},
            group_collapse_risk = 0.55,
        },
    }),
})

run_policy_case({
    name = "tank anti_aggro recovery",
    expected_action = "anti_aggro",
    expected_reason = "ANTI_AGGRO",
    expected_target = urgent_target,
    ctx = merge_context(base_context(), {
        self = { role = "tank", is_tank = true, hp_pct = 0.68, incoming_damage_pct_2s = 0.12 },
        target = { victim_role = "healer", victim_is_self = false, is_casting = false, interruptible = false },
        party = { group_collapse_risk = 0.58 },
    }),
})

run_policy_case({
    name = "dps threat-drop gating",
    expected_action = "anti_aggro",
    expected_reason = "ANTI_AGGRO",
    expected_target = current_target,
    ctx = merge_context(base_context(), {
        self = { role = "damager", hp_pct = 0.74, threat_pct = 0.96, incoming_damage_pct_2s = 0.22 },
        target = { is_casting = false, interruptible = false },
        party = { group_collapse_risk = 0.32 },
    }),
})

run_policy_case({
    name = "dps self-save gating",
    expected_action = "life_save_self",
    expected_reason = "LIFE_SAVE_SELF",
    expected_target = current_target,
    ctx = merge_context(base_context(), {
        self = { role = "damager", hp_pct = 0.18, threat_pct = 0.96, incoming_damage_pct_2s = 0.44 },
        target = { is_casting = false, interruptible = false },
        party = { group_collapse_risk = 0.18 },
    }),
})

run_policy_case({
    name = "urgency-aware interrupt_control",
    expected_action = "interrupt_control",
    expected_reason = "INTERRUPT_DANGER",
    expected_target = urgent_target,
    ctx = merge_context(base_context(), {
        self = { role = "damager", hp_pct = 0.82 },
        target = {
            exists = true,
            is_casting = true,
            interruptible = true,
            cast_progress_pct = 0.72,
            victim_role = "tank",
            victim_is_self = false,
        },
        encounter = { interrupt_priority = true },
        party = { group_collapse_risk = 0.40 },
    }),
})

run_with_core({
    input = {
        set_target = function()
            error("set_target should not be called for unsupported actions")
        end,
    },
}, function()
    local reactive_runtime = load_runtime(common_stubs)
    dps_meter.reset()
    dps_meter.on_combat_start()

    local _, result = reactive_runtime.update_tick("me", current_target, {
        state = {},
        adapter = make_adapter(),
    })

    assert(result.reactive_status == "noop_unsupported", "explicit noop branches should report noop_unsupported")
    assert_snapshot("interrupt_control", "INTERRUPT_DANGER", "noop_unsupported")
    assert_counter(dps_meter.get_snapshot(), "noop_unsupported_count", 1)
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
    dps_meter.on_combat_start()

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
    assert_counter(dps_meter.get_snapshot(), "unsafe_skip_count", 1)
end)

run_with_core({
    time = (function()
        local times = { 0, 5, 10, 10 }
        local index = 0
        return function()
            index = index + 1
            return times[index] or times[#times]
        end
    end)(),
    input = {
        set_target = function(unit)
            assert(unit == current_target, "stable target flow should keep the current target")
            return true
        end,
    },
}, function()
    local threat_values = { 0.10, 0.45, 0.70 }
    local threat_index = 0
    local reactive_runtime = load_runtime({
        ["eax_shared/combat_context"] = {
            build = function()
                threat_index = threat_index + 1
                local ctx = base_context()
                ctx.self.threat_pct = threat_values[threat_index] or threat_values[#threat_values]
                ctx.meta.now_s = threat_index * 5
                ctx.meta.fail_safe = threat_index == 3
                return ctx
            end,
        },
        ["eax_shared/reactive_engine"] = {
            try_handle = function(_, deps)
                local outcomes = {
                    { action_id = "throughput_resume", reason_code = "THROUGHPUT_RESUME" },
                    { action_id = "none", reason_code = "NO_ACTION" },
                    { action_id = "throughput_resume", reason_code = "THROUGHPUT_RESUME" },
                }
                return outcomes[(deps.state.tick_count or 0) + 1] or outcomes[#outcomes]
            end,
        },
        ["health_prediction"] = {
            get_incoming_damage = function() return 0 end,
            get_role_id = function() return 2 end,
            is_tank = function() return false end,
        },
    })

    dps_meter.reset()
    dps_meter.on_combat_start()
    local state = { tick_count = 0 }
    local adapter = make_adapter({
        actions = {
            throughput_resume = {
                handler = function(_, action_deps)
                    action_deps.state.tick_count = action_deps.state.tick_count + 1
                    return true
                end,
            },
        },
    })

    reactive_runtime.update_tick("me", current_target, { state = state, adapter = adapter })
    state.tick_count = 1
    reactive_runtime.update_tick("me", current_target, { state = state, adapter = adapter })
    state.tick_count = 2
    reactive_runtime.update_tick("me", current_target, { state = state, adapter = adapter })

    local snapshot = dps_meter.get_snapshot()
    assert(snapshot.threat_total > 0, "runtime threat samples should accumulate positive deltas")
    assert(snapshot.tps > 0, "runtime threat samples should produce non-zero tps")
    assert_counter(snapshot, "sample_count", 3)
    assert_counter(snapshot, "reactive_event_count", 2)
    assert_counter(snapshot, "fail_safe_tick_count", 1)
end)

print("reactive_runtime_spec: ok")
