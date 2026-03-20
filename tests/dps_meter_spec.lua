local dps_meter = require("eax_shared/dps_meter")

local function run_with_core_time(times, fn)
    local original_core = _G.core
    local index = 0
    _G.core = {
        time = function()
            index = index + 1
            return times[index] or times[#times] or 0
        end,
    }

    local ok, err = pcall(fn)
    _G.core = original_core
    if not ok then
        error(err)
    end
end

local function assert_number(v, name)
    assert(type(v) == "number", name .. " should be number")
end

local function assert_snapshot_shape(snapshot)
    assert(type(snapshot) == "table", "snapshot should be table")
    assert_number(snapshot.damage_total, "damage_total")
    assert_number(snapshot.healing_total, "healing_total")
    assert_number(snapshot.duration_s, "duration_s")
    assert_number(snapshot.dps, "dps")
    assert_number(snapshot.hps, "hps")
    assert_number(snapshot.threat_total, "threat_total")
    assert_number(snapshot.tps, "tps")
    assert_number(snapshot.sample_count, "sample_count")
    assert_number(snapshot.reactive_event_count, "reactive_event_count")
    assert_number(snapshot.noop_unsupported_count, "noop_unsupported_count")
    assert_number(snapshot.unsafe_skip_count, "unsafe_skip_count")
    assert_number(snapshot.fail_safe_tick_count, "fail_safe_tick_count")
    assert(type(snapshot.in_combat) == "boolean", "in_combat should be boolean")
    assert(type(snapshot.reactive_action) == "string", "reactive_action should be string")
    assert(type(snapshot.action_id) == "string", "action_id should be string")
    assert(type(snapshot.reason_code) == "string", "reason_code should be string")
    assert(type(snapshot.context_fail_safe) == "boolean", "context_fail_safe should be boolean")
end

-- Test 1: damage/healing accumulate during one combat window.
dps_meter.reset()
dps_meter.on_combat_start()
dps_meter.on_damage(200)
dps_meter.on_damage(300)
dps_meter.on_heal(150)
local combat_snapshot = dps_meter.get_snapshot()
assert(combat_snapshot.damage_total == 500, "damage should accumulate")
assert(combat_snapshot.healing_total == 150, "healing should accumulate")

-- Test 2: reactive telemetry is exposed on idle, combat, and post-combat snapshots.
dps_meter.set_reactive_state({
    reactive_action = "interrupt_control",
    action_id = "interrupt_control",
    reason_code = "INTERRUPT_DANGER",
    context_fail_safe = false,
})
combat_snapshot = dps_meter.get_snapshot()
assert_snapshot_shape(combat_snapshot)
assert(combat_snapshot.reactive_action == "interrupt_control", "combat reactive_action should persist")
assert(combat_snapshot.reason_code == "INTERRUPT_DANGER", "combat reason_code should persist")

-- Test 3: ending combat stores final snapshot and exits combat state without losing telemetry.
dps_meter.on_combat_end()
local post_combat_snapshot = dps_meter.get_snapshot()
assert(post_combat_snapshot.in_combat == false, "should exit combat")
assert(post_combat_snapshot.damage_total == 500, "final damage should persist")
assert(post_combat_snapshot.healing_total == 150, "final healing should persist")
assert(post_combat_snapshot.reactive_action == "none", "post-combat reactive_action should clear")
assert(post_combat_snapshot.reason_code == "NO_ACTION", "post-combat reason_code should clear")

-- Test 4: empty state returns a zeroed snapshot with default telemetry.
dps_meter.reset()
local idle_snapshot = dps_meter.get_snapshot()
assert_snapshot_shape(idle_snapshot)
assert(idle_snapshot.damage_total == 0, "idle damage should be zero")
assert(idle_snapshot.healing_total == 0, "idle healing should be zero")
assert(idle_snapshot.duration_s == 0, "idle duration should be zero")
assert(idle_snapshot.dps == 0, "idle dps should be zero")
assert(idle_snapshot.hps == 0, "idle hps should be zero")
assert(idle_snapshot.in_combat == false, "idle in_combat should be false")
assert(idle_snapshot.reactive_action == "none", "idle reactive_action should default to none")
assert(idle_snapshot.reason_code == "NO_ACTION", "idle reason_code should default to NO_ACTION")
assert(idle_snapshot.context_fail_safe == false, "idle fail-safe should default false")

-- Test 5: threat sampling computes tps and new counters reset cleanly.
run_with_core_time({ 0, 5, 10, 10 }, function()
    dps_meter.reset()
    dps_meter.on_combat_start()
    dps_meter.record_threat_sample(0.20)
    dps_meter.record_threat_sample(0.55)
    dps_meter.record_threat_sample(0.75)
    local sampled_snapshot = dps_meter.get_snapshot()
    assert(sampled_snapshot.threat_total > 0, "positive threat deltas should accumulate")
    assert(sampled_snapshot.sample_count == 3, "each threat sample should increment sample_count")
    dps_meter.on_combat_end()
    local ended_snapshot = dps_meter.get_snapshot()
    assert(ended_snapshot.tps > 0, "positive threat over non-zero duration should produce tps")
    dps_meter.reset()
    local cleared_snapshot = dps_meter.get_snapshot()
    assert(cleared_snapshot.threat_total == 0, "reset should clear threat_total")
    assert(cleared_snapshot.tps == 0, "reset should clear tps")
    assert(cleared_snapshot.sample_count == 0, "reset should clear sample_count")
    assert(cleared_snapshot.reactive_event_count == 0, "reset should clear reactive_event_count")
    assert(cleared_snapshot.noop_unsupported_count == 0, "reset should clear noop_unsupported_count")
    assert(cleared_snapshot.unsafe_skip_count == 0, "reset should clear unsafe_skip_count")
    assert(cleared_snapshot.fail_safe_tick_count == 0, "reset should clear fail_safe_tick_count")
end)

print("dps_meter_spec: ok")
