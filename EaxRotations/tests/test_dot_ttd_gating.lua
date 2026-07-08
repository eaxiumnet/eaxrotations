-- test_dot_ttd_gating.lua -- DoT time-to-death resource gating tests.
-- WHAT:  DoT time-to-death resource gating tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Validates time-to-death gating to avoid clipping DoTs on short-lived targets.
-- SAFETY: Uses synthetic TTD values.

-- Test: DoT TTD Gating shared module.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false, assert_eq
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
end
setup_asserts()

_G.EaxRotations = { log = function() end }
local DotTTD = dofile("EaxRotations/shared/dot_ttd_gating_sylvanas.lua")
assert_true(DotTTD ~= nil, "module should load")

-- should_skip_dot: nil/unknown ttd -> never skip
assert_false(DotTTD.should_skip_dot(nil, 15, 0.5), "nil ttd -> don't skip")
assert_false(DotTTD.should_skip_dot(0, 15, 0.5), "zero ttd -> don't skip")

-- ttd longer than dot*threshold -> don't skip
assert_false(DotTTD.should_skip_dot(10, 15, 0.5), "ttd 10 >= dot*0.5 (7.5) -> don't skip")

-- ttd shorter than dot*threshold -> skip
assert_true(DotTTD.should_skip_dot(5, 15, 0.5), "ttd 5 < dot*0.5 (7.5) -> skip")

-- threshold 0 -> never skip
assert_false(DotTTD.should_skip_dot(1, 15, 0), "threshold 0 -> never skip")

-- full duration short
assert_true(DotTTD.should_skip_dot(2, 18, 0.5), "ttd 2 < 9 -> skip")
assert_false(DotTTD.should_skip_dot(10, 18, 0.5), "ttd 10 >= 9 -> don't skip")

-- context wrapper
assert_false(DotTTD.should_skip_dot_from_context(nil, 15, 0.5), "nil context -> don't skip")
assert_false(DotTTD.should_skip_dot_from_context({ ttd_known = false, ttd = 5 }, 15, 0.5), "ttd not known -> don't skip")
assert_true(DotTTD.should_skip_dot_from_context({ ttd_known = true, ttd = 5 }, 15, 0.5), "known short ttd -> skip")

-- duration constants present
assert_true(DotTTD.DOT_DURATIONS.vampiric_touch > 0, "VT duration should be > 0")
assert_true(DotTTD.DOT_DURATIONS.shadow_word_pain > 0, "SWP duration should be > 0")
assert_true(DotTTD.DOT_DURATIONS.corruption > 0, "Corruption duration should be > 0")

print("PASS test_dot_ttd_gating")
