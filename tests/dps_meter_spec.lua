local dps_meter = require("eax_shared/dps_meter")

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

print("dps_meter_spec: ok")
