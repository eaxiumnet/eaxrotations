-- enemy_count_hysteresis_sylvanas.lua regression test
-- Tests: rapid emergence filtering, drop hold, sustained presence, nil safety

dofile('EaxRotations/shared/enemy_count_hysteresis_sylvanas.lua')
local H = _G.EnemyCountHysteresis

local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": got " .. tostring(a) .. " expected " .. tostring(b), 2) end
end

-- Reset module state before each scenario
local function reset()
    H.reset()
end

-- Scenario 1: Rapid emergence (0->3->0 within 1s) stays at 0
reset()
H.update(0, 0)
H.update(3, 0)      -- rise detected at t=0, hold for 500ms
H.update(0, 100)    -- back to 0 before rise hold expires
assert_eq(H.smoothed_count(), 0, "rapid_emergence_stays_0")

-- Scenario 2: Sustained presence (0->3 held for 600ms) settles to 3
reset()
H.update(0, 0)
H.update(3, 0)
H.update(3, 600)    -- rise hold (500ms) expired
assert_eq(H.smoothed_count(), 3, "sustained_presence_settles")

-- Scenario 3: Drop hold (3->0) keeps 3 for 2000ms
reset()
H.update(3, 0)      -- establish 3
H.update(3, 600)    -- confirm settled
assert_eq(H.smoothed_count(), 3, "drop_hold_baseline")
H.update(0, 1000)   -- drop at t=1000, hold until t=3000
assert_eq(H.smoothed_count(), 3, "drop_hold_keeps_3")
H.update(0, 2500)   -- still in drop hold
assert_eq(H.smoothed_count(), 3, "drop_hold_at_2500")
H.update(0, 3000)   -- drop hold expired
assert_eq(H.smoothed_count(), 0, "drop_hold_expired")

-- Scenario 4: Oscillation (3->0->3->0) stays at 3 during drop window
reset()
H.update(3, 0)
H.update(3, 600)
assert_eq(H.smoothed_count(), 3, "oscillation_baseline")
H.update(0, 1000)   -- drop, hold until 3000
H.update(3, 1500)   -- back to 3 (cancels drop)
H.update(0, 2000)   -- drop again, hold until 4000
H.update(3, 2500)   -- back to 3
assert_eq(H.smoothed_count(), 3, "oscillation_stays_3")

-- Scenario 5: Rising during hold updates pending but doesn't reset timer
reset()
H.update(0, 0)
H.update(3, 0)      -- rise hold until 500, pending=3
H.update(5, 100)    -- higher rise, pending=5, timer still 500
H.update(5, 600)    -- hold expired, should apply pending=5
assert_eq(H.smoothed_count(), 5, "rising_during_hold")

-- Scenario 6: Nil/empty input safety
reset()
assert_eq(H.smoothed_count(), 0, "nil_safety_default")

-- Scenario 7: Concatenated dispatcher round-trip (matches real main_sylvanas.lua pattern)
reset()
H.update(0, 0)                            -- dispatcher line: count=0 in
H.update(3, 100)                          -- adversary appears, rise hold active
H.update(3, 200)                          -- still rising
local s1 = H.smoothed_count()
assert_eq(s1, 0, "round_trip_rise_pending")
H.update(3, 700)                          -- rise hold (500ms) expired
assert_eq(H.smoothed_count(), 3, "round_trip_rise_applied")
H.update(3, 1000)
H.update(0, 1100)                         -- adversary leaves, drop hold active
assert_eq(H.smoothed_count(), 3, "round_trip_drop_pending")
H.update(0, 3500)                         -- drop hold (2000ms) expired
assert_eq(H.smoothed_count(), 0, "round_trip_drop_applied")

-- Scenario 8: Tunable rise hold (lower bound: 0 = no filter)
reset()
H.configure({ rise_hold_ms = 0, drop_hold_ms = 0 })
H.update(0, 0)
H.update(3, 0)
assert_eq(H.smoothed_count(), 3, "zero_rise_hold_immediate")
reset()
H.configure({ rise_hold_ms = 0, drop_hold_ms = 0 })

-- Scenario 9: Tunable rise hold (extended: 1500ms)
reset()
H.configure({ rise_hold_ms = 1500, drop_hold_ms = 2000 })
H.update(0, 0)
H.update(3, 0)
assert_eq(H.smoothed_count(), 0, "extended_rise_hold_pending")
H.update(3, 1000)
assert_eq(H.smoothed_count(), 0, "extended_rise_hold_still_pending")
H.update(3, 1700)
assert_eq(H.smoothed_count(), 3, "extended_rise_hold_applied")
reset()
H.configure({ rise_hold_ms = 500, drop_hold_ms = 2000 })

-- Scenario 10: Tunable drop hold (extended: 5000ms — high-latency player)
reset()
H.update(3, 0)
H.update(3, 600)
assert_eq(H.smoothed_count(), 3, "extended_drop_baseline")
H.configure({ rise_hold_ms = 500, drop_hold_ms = 5000 })
H.update(0, 1000)
assert_eq(H.smoothed_count(), 3, "extended_drop_hold_pending")
H.update(0, 5500)
assert_eq(H.smoothed_count(), 3, "extended_drop_hold_at_5500")
H.update(0, 6500)
assert_eq(H.smoothed_count(), 0, "extended_drop_hold_applied")
reset()
H.configure({ rise_hold_ms = 500, drop_hold_ms = 2000 })

-- Scenario 11: configure() is idempotent and clamps negative inputs
reset()
H.configure({ rise_hold_ms = -50, drop_hold_ms = -1 })
assert_eq(H.smoothed_count(), 0, "negative_clamped_immediate")
H.update(0, 0)
H.update(3, 0)
assert_eq(H.smoothed_count(), 3, "negative_rise_clamped_immediate")
H.update(3, 600)
H.update(0, 1000)
assert_eq(H.smoothed_count(), 0, "negative_drop_clamped_immediate")
reset()
H.configure({ rise_hold_ms = 500, drop_hold_ms = 2000 })

print("PASS enemy_count_hysteresis")
