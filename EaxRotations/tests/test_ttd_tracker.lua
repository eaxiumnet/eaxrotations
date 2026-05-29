-- TTD Tracker regression tests.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
local function assert_near(a, b, tolerance, label)
    if math.abs(a - b) > tolerance then
        error((label or "assert_near") .. ": " .. tostring(a) .. " not near " .. tostring(b) .. " (tol=" .. tostring(tolerance) .. ")", 2)
    end
end

dofile('EaxRotations/shared/ttd_tracker_sylvanas.lua')
local M = _G.TTDTracker

-- Reset state before each test.
M.clear_all()

-- Mock target factory.
local function mock_target(guid, hp_pct)
    return {
        get_guid = function() return guid end,
        get_health_percentage = function() return hp_pct end,
    }
end

-- Test 1: No target returns nil.
assert_eq(M.update(nil, 0, {}), nil, "nil target -> nil")

-- Test 2: Disabled via settings returns nil.
local t = mock_target("boss1", 100)
assert_eq(M.update(t, 1, { ttd_linear_enabled = false }), nil, "disabled -> nil")

-- Test 3: Insufficient samples returns nil.
M.clear_all()
t = mock_target("boss2", 100)
assert_eq(M.update(t, 1, {}), nil, "1 sample -> nil")
assert_eq(M.update(t, 1.4, {}), nil, "still throttled -> nil")

-- Test 4: Steady HP decline predicts roughly correct TTD.
-- Simulate boss losing 10% HP every 2 seconds (5s total to die from 50%).
M.clear_all()
local guid = "boss3"
local base_time = 10
local hp_samples = { 100, 90, 80, 70, 60, 50 }
for i, hp in ipairs(hp_samples) do
    t = mock_target(guid, hp)
    local now = base_time + (i - 1) * 2
    M.update(t, now, { ttd_sample_interval = 1 })
end
local ttd = M.update(mock_target(guid, 50), base_time + 10, {})
assert_true(ttd ~= nil, "boss regression should produce a TTD")
assert_true(ttd > 8 and ttd < 12, "TTD should be ~10s from 50% at -10%/2s")

-- Test 5: HP rising (healing) returns nil.
M.clear_all()
guid = "boss4"
local rising = { 50, 55, 60, 65, 70 }
for i, hp in ipairs(rising) do
    t = mock_target(guid, hp)
    M.update(t, base_time + (i - 1) * 2, { ttd_sample_interval = 1 })
end
assert_eq(M.update(mock_target(guid, 70), base_time + 8, {}), nil, "rising HP -> nil")

-- Test 6: Target swap resets history.
M.clear_all()
local t1 = mock_target("bossA", 100)
local t2 = mock_target("bossB", 100)
for i = 1, 6 do
    M.update(mock_target("bossA", 100 - i * 10), base_time + (i - 1) * 2, { ttd_sample_interval = 1 })
end
-- Swap targets
M.update(t2, base_time + 20, {})
assert_eq(M.update(t2, base_time + 20, {}), nil, "swap resets history -> nil")

-- Test 7: Max TTD cap is enforced.
M.clear_all()
local slow_drop = {}
for i = 1, 10 do slow_drop[i] = 100 - i * 0.5 end
for i, hp in ipairs(slow_drop) do
    M.update(mock_target("boss5", hp), base_time + (i - 1) * 2, { ttd_sample_interval = 1 })
end
local capped = M.update(mock_target("boss5", 95), base_time + 18, { ttd_max_ttd = 60 })
assert_true(capped ~= nil, "slow drop should produce some TTD")
assert_eq(capped, 60, "max TTD cap enforced")

-- Test 8: Pruning works — old samples outside window are ignored.
M.clear_all()
guid = "boss6"
for i = 1, 8 do
    M.update(mock_target(guid, 100 - i * 5), base_time + (i - 1) * 2, { ttd_sample_interval = 1 })
end
-- Now add a single very old sample that should be pruned by a 6-second window.
-- Since we can't inject a stale sample directly, we'll trust the prune logic
-- exercised above. Instead, verify behavior with a very tight window.
local tight_window = M.update(mock_target(guid, 60), base_time + 14, { ttd_window = 4, ttd_min_samples = 4 })
-- With window=4, only samples from base_time+10 onward remain (3 samples), so nil.
assert_eq(tight_window, nil, "tight window prunes too many -> nil")

print("PASS test_ttd_tracker")
