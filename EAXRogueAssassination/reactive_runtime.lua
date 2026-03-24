local combat_context = require("combat_context")
local dps_meter = require("dps_meter")
local reactive_engine = require("reactive_engine")
local role_policy = require("role_policy")
pcall(function()
    local benchmark = require("tools/dps_benchmark")
    if benchmark and benchmark.install_runtime_capture then
        benchmark.install_runtime_capture()
    end
end)

local reactive_runtime = {}

-- Throttle combat_context.build() to reduce 20+ pcall API calls per frame
-- Context is refreshed every 2 seconds instead of every frame
local CONTEXT_REFRESH = 2.0  -- seconds between context rebuilds
local _last_context_build = 0
local _cached_context = nil

local REQUIRED_BRANCHES = {
    "life_save_self",
    "life_save_ally",
    "interrupt_control",
    "anti_overheal",
    "anti_aggro",
    "throughput_resume",
}

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

local DEFAULT_ACTIONS = role_policy.build_actions()

reactive_runtime.DEFAULT_ACTIONS = DEFAULT_ACTIONS

local function is_valid_unit(unit)
    if type(unit) ~= "table" or type(unit.is_valid) ~= "function" then
        return false
    end

    if not unit:is_valid() then
        return false
    end

    if type(unit.is_dead) == "function" and unit:is_dead() then
        return false
    end

    return true
end

local function unit_guid(unit)
    if not is_valid_unit(unit) or type(unit.get_guid) ~= "function" then
        return nil
    end

    local ok, guid = pcall(function()
        return unit:get_guid()
    end)
    if not ok or guid == nil then
        return nil
    end

    return tostring(guid)
end

local function same_unit(a, b)
    if a == b and a ~= nil then
        return true
    end

    local a_guid = unit_guid(a)
    local b_guid = unit_guid(b)
    if a_guid and b_guid then
        return a_guid == b_guid
    end

    return false
end

local function validate_adapter(adapter)
    if adapter == nil then
        return nil
    end

    assert(type(adapter) == "table", "reactive adapter must be a table")
    assert(type(adapter.actions) == "table", "reactive adapter.actions must be a table")

    for _, action_id in ipairs(REQUIRED_BRANCHES) do
        local entry = adapter.actions[action_id]
        assert(type(entry) == "table", "reactive adapter missing action entry: " .. action_id)
        assert(
            type(entry.handler) == "function" or entry.noop == "unsupported",
            "reactive adapter entry must declare handler or noop=unsupported: " .. action_id
        )
    end

    if adapter.resolve_target ~= nil then
        assert(type(adapter.resolve_target) == "function", "reactive adapter.resolve_target must be a function")
    end

    if adapter.restore_target ~= nil then
        assert(type(adapter.restore_target) == "function", "reactive adapter.restore_target must be a function")
    end

    return adapter
end

local function can_retarget(action_id)
    return action_id ~= "throughput_resume"
end

local function can_restore_now(me)
    if not me then
        return false
    end

    if type(me.is_casting_spell) == "function" and me:is_casting_spell() then
        return false
    end

    if type(me.is_channelling_spell) == "function" and me:is_channelling_spell() then
        return false
    end

    return true
end

local function restore_previous_target(me, target, state, adapter, ctx, deps)
    if type(state) ~= "table" or state.restore_pending ~= true then
        return target
    end

    local previous_target = state.previous_target
    if not is_valid_unit(previous_target) then
        state.previous_target = nil
        state.restore_pending = false
        return target
    end

    if same_unit(previous_target, target) then
        state.restore_pending = false
        return target
    end

    if not can_restore_now(me) then
        return target
    end

    local restored = false
    if adapter and adapter.restore_target then
        restored = adapter.restore_target(previous_target, ctx, deps) == true
    elseif core and core.input and core.input.set_target then
        restored = core.input.set_target(previous_target) == true
    end

    if restored then
        state.restore_pending = false
        return previous_target
    end

    return target
end

local function execute_adapter(me, target, ctx, result, deps, adapter)
    local action_id = result.action_id or "none"
    if action_id == "none" then
        return "none"
    end

    local entry = adapter and adapter.actions and adapter.actions[action_id]
    if type(entry) ~= "table" then
        return "none"
    end

    if entry.noop == "unsupported" then
        return "noop_unsupported"
    end

    local resolved_target = target
    if adapter.resolve_target then
        local candidate = adapter.resolve_target(action_id, ctx, deps)
        if candidate ~= nil then
            resolved_target = candidate
        end
    end

    local retargeted = false
    if resolved_target ~= nil and not same_unit(resolved_target, target) then
        if not can_retarget(action_id) or not is_valid_unit(resolved_target) then
            return "skipped_unsafe"
        end

        if not (core and core.input and core.input.set_target and core.input.set_target(resolved_target) == true) then
            return "skipped_unsafe"
        end

        if type(deps.state) == "table" then
            deps.state.previous_target = target
            deps.state.restore_pending = false
        end
        retargeted = true
    end

    local handled = entry.handler(ctx, {
        me = me,
        adapter = adapter,
        target = resolved_target,
        current_target = target,
        action_id = action_id,
        state = deps.state,
        deps = deps,
    })

    if retargeted and type(deps.state) == "table" then
        if handled == false then
            restore_previous_target(me, resolved_target, deps.state, adapter, ctx, deps)
            deps.state.restore_pending = false
        else
            deps.state.restore_pending = true
        end
    end

    return "handled"
end

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

local function role_telemetry(ctx, result)
    local action_id = (result or {}).action_id or "none"
    local self_ctx = (ctx or {}).self or {}
    local party = (ctx or {}).party or {}
    local target_ctx = (ctx or {}).target or {}
    local role = self_ctx.role or "unknown"

    if action_id == "life_save_self" then
        return "none", "self"
    end

    if action_id == "life_save_ally" and role == "healer" then
        local tank = party.tank or {}
        local group_collapse_risk = clamp01(party.group_collapse_risk)
        if tank.guid and clamp01(tank.hp_pct) <= 0.55 and clamp01(tank.incoming_heal_pct) < 0.25 then
            return "tank_save", "tank"
        end
        if group_collapse_risk >= 0.60 then
            return "group_stabilize", "ally"
        end
        return "triage_save", "ally"
    end

    if action_id == "anti_aggro" and role == "tank" then
        return "threat_recovery", "hostile"
    end

    if action_id == "throughput_resume" and role == "damager" then
        if clamp01(self_ctx.incoming_damage_pct_2s) >= 0.30
            or clamp01(self_ctx.threat_pct) >= 0.85
            or (target_ctx.interrupt_priority == true)
            or ((ctx or {}).encounter or {}).dangerous_control_window == true then
            return "danger_hold", "hostile"
        end
    end

    return "none", "none"
end

function reactive_runtime.update_tick(me, target, deps)
    deps = deps or {}
    local adapter = validate_adapter(deps.adapter)

    target = restore_previous_target(me, target, deps.state, adapter, nil, deps)

    -- Throttle combat_context.build() to every CONTEXT_REFRESH seconds
    -- Eliminates ~20+ pcall API calls per frame (massive CPU savings)
    local now = deps.now_s or (core and core.time and core.time()) or 0
    if (now - _last_context_build) >= CONTEXT_REFRESH then
        _last_context_build = now
        _cached_context = combat_context.build(me, target, nil, {
            health_prediction = load_health_prediction(),
            encounter_manager = deps.encounter_manager,
            party_reader = deps.party_reader,
            now_s = deps.now_s,
        })
    end

    local ctx = _cached_context

    local result = reactive_engine.try_handle(ctx, {
        state = deps.state,
        actions = DEFAULT_ACTIONS,
    })

    local reactive_status = execute_adapter(me, target, ctx, result, deps, adapter)
    result.reactive_status = reactive_status

    -- record_threat_sample owns sample_count increments for each runtime tick.
    dps_meter.record_threat_sample((((ctx or {}).self or {}).threat_pct), (((ctx or {}).meta or {}).now_s))
    if (result.action_id or "none") ~= "none" then
        dps_meter.increment_counter("reactive_event_count")
    end
    if reactive_status == "noop_unsupported" then
        dps_meter.increment_counter("noop_unsupported_count")
    end
    if reactive_status == "skipped_unsafe" then
        dps_meter.increment_counter("unsafe_skip_count")
    end
    if ctx.meta.fail_safe == true then
        dps_meter.increment_counter("fail_safe_tick_count")
    end

    local role_signal, role_target_kind = role_telemetry(ctx, result)
    dps_meter.set_reactive_state({
        spec = deps.spec,
        reactive_action = result.action_id or "none",
        action_id = result.action_id or "none",
        reason_code = result.reason_code or "NO_ACTION",
        reactive_status = reactive_status,
        context_fail_safe = ctx.meta.fail_safe == true,
        role_signal = role_signal,
        role_target_kind = role_target_kind,
    })

    return ctx, result
end

--- Force a rebuild of the combat context on the next update_tick call.
--- Call this when combat state changes significantly (e.g., new target, party change).
function reactive_runtime.invalidate_context()
    _last_context_build = 0
    _cached_context = nil
end

return reactive_runtime
