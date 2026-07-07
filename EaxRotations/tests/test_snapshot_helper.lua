-- test_snapshot_helper.lua — Validates the shared DoT/finisher snapshot upgrade gating.
-- WHAT:  tests all decision paths of SnapshotHelper.should_upgrade: expired DoT,
--        pandemic refresh window, no-snapshot behavior (cat vs shadow), upgrade ratio,
--        extended window boundary, and nil-safety.
-- WHY:   the helper centralises snapshot logic used by feral cat (Rip/Rake AP snapshot)
--        and shadow priest (SW:P/VT/DP spell-damage snapshot) — a bug here affects both specs.

local _G = _G

-- Minimal NS mock so the module can set NS.SnapshotHelper
local NS = {}
_G.EaxRotations = NS

local function assert_true(v, msg)
    if not v then error("FAIL " .. tostring(msg), 2) end
end
local function assert_false(v, msg)
    if v then error("FAIL " .. tostring(msg) .. ": expected false", 2) end
end
local function assert_eq(a, b, msg)
    if a ~= b then
        error("FAIL " .. tostring(msg) .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
    end
end

-- Load the module under test
local mod_ok, mod_err = pcall(dofile, "EaxRotations/shared/snapshot_sylvanas.lua")
if not mod_ok then error("could not load snapshot_sylvanas: " .. tostring(mod_err)) end
local M = NS.SnapshotHelper
assert_true(M ~= nil, "NS.SnapshotHelper loaded")
assert_true(type(M.should_upgrade) == "function", "should_upgrade is a function")

-- Also verify _G export for dofile test pattern
assert_true(_G.SnapshotHelper ~= nil, "_G.SnapshotHelper exported")

-- Constants matching real usage
local REFRESH_WINDOW = 3.0   -- pandemic window (3s for most DoTs)
local UPGRADE_RATIO  = 1.05  -- 5% stronger
local EXTRA_WINDOW   = 1.5   -- cat default; shadow uses different value

-- ===========================================================================
-- Test 1: DoT expired (remains <= 0) → always refresh
-- ===========================================================================
assert_true(M.should_upgrade(1000, 1000, 0, REFRESH_WINDOW, UPGRADE_RATIO),
    "expired DoT (remains=0) should refresh")
assert_true(M.should_upgrade(1000, 1000, -1, REFRESH_WINDOW, UPGRADE_RATIO),
    "expired DoT (remains=-1) should refresh")
print("  [ PASS ] expired DoT always refreshes")

-- ===========================================================================
-- Test 2: DoT within pandemic refresh window → always refresh
-- ===========================================================================
assert_true(M.should_upgrade(500, 1000, 2.5, REFRESH_WINDOW, UPGRADE_RATIO),
    "remains < refresh_window should refresh even with weaker stat")
assert_true(M.should_upgrade(1000, 1000, 3.0, REFRESH_WINDOW, UPGRADE_RATIO),
    "remains == refresh_window boundary should refresh")
print("  [ PASS ] pandemic refresh window triggers refresh")

-- ===========================================================================
-- Test 3: No snapshot captured (snapshotted <= 0) — cat behavior (no_snapshot_refresh=false)
-- ===========================================================================
assert_false(M.should_upgrade(1000, 0, 5.0, REFRESH_WINDOW, UPGRADE_RATIO, { no_snapshot_refresh = false }),
    "cat: no snapshot + DoT healthy → do NOT refresh (wait for snapshot to beat)")
assert_false(M.should_upgrade(1000, 0, 5.0, REFRESH_WINDOW, UPGRADE_RATIO),
    "default (no opts) = cat behavior → no refresh without snapshot")
print("  [ PASS ] cat no-snapshot behavior (don't refresh without snapshot)")

-- ===========================================================================
-- Test 4: No snapshot captured — shadow behavior (no_snapshot_refresh=true)
-- ===========================================================================
assert_true(M.should_upgrade(1000, 0, 5.0, REFRESH_WINDOW, UPGRADE_RATIO, { no_snapshot_refresh = true }),
    "shadow: no snapshot + DoT healthy → refresh to establish snapshot")
print("  [ PASS ] shadow no-snapshot behavior (refresh to establish)")

-- ===========================================================================
-- Test 5: Upgrade ratio — current stat beats snapshot by ratio AND within extended window
-- ===========================================================================
-- current=1050, snapshotted=1000, ratio=1.05 → 1050 >= 1000*1.05=1050 → upgrade
-- remains=4.0, refresh_window=3.0, extra_window=1.5 → 4.0 <= 4.5 → within extended window
assert_true(M.should_upgrade(1050, 1000, 4.0, REFRESH_WINDOW, UPGRADE_RATIO, { extra_window = EXTRA_WINDOW }),
    "stat beats ratio AND within extended window → refresh")
print("  [ PASS ] upgrade ratio + extended window triggers refresh")

-- ===========================================================================
-- Test 6: Stat does NOT beat ratio → no refresh (outside pandemic window)
-- ===========================================================================
-- current=1049, snapshotted=1000, ratio=1.05 → 1049 < 1050 → not enough
assert_false(M.should_upgrade(1049, 1000, 4.0, REFRESH_WINDOW, UPGRADE_RATIO, { extra_window = EXTRA_WINDOW }),
    "stat below ratio threshold → no refresh")
print("  [ PASS ] below upgrade ratio → no refresh")

-- ===========================================================================
-- Test 7: Stat beats ratio but OUTSIDE extended window → no refresh
-- ===========================================================================
-- current=2000, snapshotted=1000, ratio=1.05 → beats ratio
-- remains=5.0, refresh_window=3.0, extra_window=1.5 → 5.0 > 4.5 → outside extended window
assert_false(M.should_upgrade(2000, 1000, 5.0, REFRESH_WINDOW, UPGRADE_RATIO, { extra_window = EXTRA_WINDOW }),
    "stat beats ratio but outside extended window → no refresh (wait)")
print("  [ PASS ] outside extended window → no refresh even with big upgrade")

-- ===========================================================================
-- Test 8: Extended window boundary (remains == refresh_window + extra_window)
-- ===========================================================================
-- remains=4.5 == 3.0 + 1.5 → boundary, should refresh (<=)
assert_true(M.should_upgrade(1100, 1000, 4.5, REFRESH_WINDOW, UPGRADE_RATIO, { extra_window = EXTRA_WINDOW }),
    "remains == refresh_window + extra_window boundary → refresh")
print("  [ PASS ] extended window boundary triggers refresh")

-- ===========================================================================
-- Test 9: Nil-safety — all nil numeric args don't crash
-- ===========================================================================
assert_true(M.should_upgrade(nil, nil, nil, REFRESH_WINDOW, UPGRADE_RATIO),
    "all nil args → refresh (remains defaults to 0)")
assert_true(M.should_upgrade(nil, nil, 0, nil, nil),
    "nil refresh_window + nil ratio + remains=0 → refresh")
-- nil snapshotted with healthy DoT → cat behavior (no_snapshot_refresh=false default)
assert_false(M.should_upgrade(1000, nil, 5.0, REFRESH_WINDOW, UPGRADE_RATIO),
    "nil snapshotted + healthy DoT → cat default (no refresh)")
-- nil snapshotted with shadow behavior
assert_true(M.should_upgrade(1000, nil, 5.0, REFRESH_WINDOW, UPGRADE_RATIO, { no_snapshot_refresh = true }),
    "nil snapshotted + healthy DoT + shadow → refresh")
print("  [ PASS ] nil-safety (no crashes, correct defaults)")

-- ===========================================================================
-- Test 10: Custom extra_window (shadow uses a different value)
-- ===========================================================================
-- Shadow: extra_window might be 2.0 instead of 1.5
-- remains=5.0, refresh_window=3.0, extra_window=2.0 → 5.0 <= 5.0 → within window
assert_true(M.should_upgrade(1100, 1000, 5.0, REFRESH_WINDOW, UPGRADE_RATIO, { extra_window = 2.0 }),
    "custom extra_window=2.0: remains=5.0 <= 5.0 → refresh")
-- remains=5.1, extra_window=2.0 → 5.1 > 5.0 → outside
assert_false(M.should_upgrade(1100, 1000, 5.1, REFRESH_WINDOW, UPGRADE_RATIO, { extra_window = 2.0 }),
    "custom extra_window=2.0: remains=5.1 > 5.0 → no refresh")
print("  [ PASS ] custom extra_window parameter respected")

-- ===========================================================================
-- Test 11: opts=nil (default behavior)
-- ===========================================================================
-- opts=nil should use defaults: no_snapshot_refresh=false, extra_window=1.5
assert_false(M.should_upgrade(1000, 0, 5.0, REFRESH_WINDOW, UPGRADE_RATIO, nil),
    "opts=nil → cat default (no refresh without snapshot)")
print("  [ PASS ] opts=nil uses safe defaults")

print("PASS test_snapshot_helper (11 sub-assertions: expired, pandemic, no-snapshot cat/shadow, ratio, extended window, nil-safety, custom extra_window)")
