-- What: AQ-P2-5 contract for the retired EaxAutoQuester anti-detection surface.
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`.
-- Why: The former module exported dead randomization/timing members and called an undocumented
--       `core.input.turn`; the production loop must not retain a camera action that never worked.
-- Safety: This suite drives the real coordinator tick and only supplies a turn counter; it adds
--       no movement, evasion, randomization, or timing fixture.

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local ad = require("anti_detection_sylvanas")

-- S1 — the retired members stay retired. Keeping a dead member here would make the module
-- look active again and would preserve the allocation/caller ambiguity this pass closes.
local retired_members = {
    "random_delay",
    "maybe_camera_jitter",
    "jitter_destination",
    "action_delay",
    "react_to_nearby_player",
    "varied_tick_interval",
    "check_player_proximity",
}
for i = 1, #retired_members do
    local member = retired_members[i]
    assert(ad[member] == nil,
        "S1 FAIL: retired anti-detection member is still exported: " .. member)
end
assert(next(ad) == nil, "S1 FAIL: anti-detection compatibility shim retained live members")
print("  S1 PASS: dead anti-detection members are removed")

-- S2 — the real coordinator tick no longer loads or invokes the retired camera surface.
-- `core.input.turn` is deliberately counted even though it is not a supported Sylvanas API:
-- a regression to the old block would be observable here without adding a new API fixture.
local coordinator = require("quest_state/coordinator")
local turn_calls = 0
core.input.turn = function() turn_calls = turn_calls + 1 end
mock.reset()
mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
mock.set_time(1.0)
for i = 1, 5 do
    mock.set_time(1.0 + i * 0.05)
    coordinator.update()
end
assert(turn_calls == 0,
    "S2 FAIL: real coordinator tick called the retired turn path " .. tostring(turn_calls) .. " time(s)")
assert(coordinator._test_context().anti_detection == nil,
    "S2 FAIL: retired anti-detection module is still carried on the production tick context")
print("  S2 PASS: real coordinator tick has no retired camera/anti-detection action")

print("PASS test_anti_detection")
os.exit(0)
