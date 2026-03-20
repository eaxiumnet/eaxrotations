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

-- Test 2: ending combat stores final snapshot and exits combat state.
dps_meter.on_combat_end()
local post_combat_snapshot = dps_meter.get_snapshot()
assert(post_combat_snapshot.in_combat == false, "should exit combat")
assert(post_combat_snapshot.damage_total == 500, "final damage should persist")
assert(post_combat_snapshot.healing_total == 150, "final healing should persist")

-- Test 3: empty state returns a zeroed snapshot.
dps_meter.reset()
local idle_snapshot = dps_meter.get_snapshot()
assert_snapshot_shape(idle_snapshot)
assert(idle_snapshot.damage_total == 0, "idle damage should be zero")
assert(idle_snapshot.healing_total == 0, "idle healing should be zero")
assert(idle_snapshot.duration_s == 0, "idle duration should be zero")
assert(idle_snapshot.dps == 0, "idle dps should be zero")
assert(idle_snapshot.hps == 0, "idle hps should be zero")
assert(idle_snapshot.in_combat == false, "idle in_combat should be false")

print("dps_meter_spec: ok")
