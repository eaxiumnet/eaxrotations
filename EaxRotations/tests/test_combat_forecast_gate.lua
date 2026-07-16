-- test_combat_forecast_gate.lua — Unit test for combat_forecast_gate module.
-- WHAT:  proves should_use_long_cd blocks on short fights, allows on long fights.
-- WHEN:  regression gate for combat_forecast integration into spec CD strategies.
-- WHY:   prior bug passed wrong CD value (30 instead of 1800) making gate a no-op.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local test = {}
local M = require("shared/combat_forecast_gate_sylvanas")

-- Unit tests: gate logic directly
function test.test_no_forecast_allows_cast()
    local ctx = { combat_length_forecast = nil }
    assert(M.should_use_long_cd(ctx, 1800) == true, "no forecast should allow cast")
end

function test.test_boss_always_allows()
    local ctx = { combat_length_forecast = 10, target_is_boss = true }
    assert(M.should_use_long_cd(ctx, 1800) == true, "boss should always allow")
end

function test.test_long_cd_blocked_on_short_fight()
    local ctx = { combat_length_forecast = 30, target_is_boss = false }
    assert(M.should_use_long_cd(ctx, 1800) == false, "1800s CD should be blocked when forecast < 60")
end

function test.test_long_cd_allowed_on_long_fight()
    local ctx = { combat_length_forecast = 120, target_is_boss = false }
    assert(M.should_use_long_cd(ctx, 1800) == true, "1800s CD should be allowed when forecast >= 60")
end

function test.test_medium_cd_blocked_on_short_fight()
    local ctx = { combat_length_forecast = 20, target_is_boss = false }
    assert(M.should_use_long_cd(ctx, 120) == false, "120s CD should be blocked when forecast < 45")
end

function test.test_medium_cd_allowed_on_medium_fight()
    local ctx = { combat_length_forecast = 50, target_is_boss = false }
    assert(M.should_use_long_cd(ctx, 120) == true, "120s CD should be allowed when forecast >= 45")
end

function test.test_short_cd_blocked_on_very_short_fight()
    local ctx = { combat_length_forecast = 15, target_is_boss = false }
    assert(M.should_use_long_cd(ctx, 60) == false, "60s CD should be blocked when forecast < 30")
end

function test.test_short_cd_allowed_on_short_fight()
    local ctx = { combat_length_forecast = 40, target_is_boss = false }
    assert(M.should_use_long_cd(ctx, 60) == true, "60s CD should be allowed when forecast >= 30")
end

function test.test_trivial_cd_never_blocked()
    local ctx = { combat_length_forecast = 5, target_is_boss = false }
    assert(M.should_use_long_cd(ctx, 30) == true, "30s CD should never be blocked (below 60s threshold)")
end

function test.test_nil_context_allows()
    assert(M.should_use_long_cd(nil, 1800) == true, "nil context should allow cast")
end

function test.test_boundary_60s_cd_at_29s_forecast()
    local ctx = { combat_length_forecast = 29, target_is_boss = false }
    assert(M.should_use_long_cd(ctx, 60) == false, "60s CD at 29s forecast should be blocked (< 30)")
end

function test.test_boundary_60s_cd_at_30s_forecast()
    local ctx = { combat_length_forecast = 30, target_is_boss = false }
    assert(M.should_use_long_cd(ctx, 60) == true, "60s CD at exactly 30s forecast should be allowed (not < 30)")
end

-- Run all tests
local failures = 0
local passed = 0
for name, fn in pairs(test) do
    local ok, err = pcall(fn)
    if ok then
        print(string.format("  [ PASS ] %s", name))
        passed = passed + 1
    else
        print(string.format("  [ FAIL ] %s: %s", name, err))
        failures = failures + 1
    end
end

print(string.format("\n  combat_forecast_gate: %d passed, %d failed", passed, failures))
if failures > 0 then os.exit(1) end
