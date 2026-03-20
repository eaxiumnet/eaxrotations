local cooldown_tracker = require("eax_shared/cooldown_tracker")
local visual_state = require("eax_shared/visual_state")
local dps_meter = require("eax_shared/dps_meter")

local function assert_number(v, name)
    assert(type(v) == "number", name .. " should be number")
end

local function assert_table(v, name)
    assert(type(v) == "table", name .. " should be table")
end

cooldown_tracker.clear()
dps_meter.reset()

-- Test 1: cooldown tracker returns 0 when no spell is set.
assert(cooldown_tracker.seconds_remaining(100) == 0, "seconds_remaining should default to 0")

-- Test 2: visual snapshot includes required fields every time.
local snapshot = visual_state.build_snapshot({
    now_s = 100,
    ttd_seconds = 12.5,
    tracked_auras = {
        { id = 1, name = "Demo", active = true },
    },
})

assert_number(snapshot.dps, "dps")
assert_number(snapshot.hps, "hps")
assert_number(snapshot.cooldown_s, "cooldown_s")
assert_table(snapshot.tracked_auras, "tracked_auras")
assert(snapshot.ttd_s == 12.5, "ttd_s should preserve numeric value")

-- Test 3: unknown TTD normalizes to display-safe sentinel.
local unknown_ttd = visual_state.build_snapshot({
    now_s = 100,
    ttd_seconds = 999,
    tracked_auras = nil,
})

assert(unknown_ttd.ttd_s == "--", "unknown ttd should normalize to --")
assert_table(unknown_ttd.tracked_auras, "tracked_auras should always be table")

print("visual_state_spec: ok")
