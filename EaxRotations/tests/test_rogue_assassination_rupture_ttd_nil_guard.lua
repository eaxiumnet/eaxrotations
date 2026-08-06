-- test_rogue_assassination_rupture_ttd_nil_guard.lua — regression for the
-- RuptureBleed nil-vs-number crash found by the behavioral battery audit (2026-08-06).
-- WHAT:  RuptureBleed must not crash when context.ttd_known is true but
--        context.ttd is nil (out-of-combat / unknown-TTD contexts); it must
--        treat ttd as 0 and NOT gate the long-lived-target check on a crash.
-- WHEN:  rotation suite execution.
-- WHY:   behavioral_audit.lua surfaced "attempt to compare number with nil" at
--        assassination_sylvanas.lua:437 (RuptureBleed@out_of_combat).
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end

local result, err = aud.load_spec("rogue", "assassination")
assert_true(result ~= nil, "assassination load failed: " .. tostring(err))

local function find_strategy(name)
    for _, s in ipairs(result.strategies) do
        if s.name == name then return s end
    end
    return nil
end

local rupture = find_strategy("RuptureBleed")
assert_true(rupture ~= nil, "RuptureBleed strategy missing")

local ctx = {
    me = {},
    target = {},
    in_combat = true,
    is_moving = false,
    has_valid_enemy_target = true,
    settings = {},
}

-- Reproduce the audit crash: ttd_known reported but ttd absent.
-- Before the fix, `context.ttd > 0` compared nil with number and crashed.
local state_no_ttd = {
    combo = 5,
    rupture_remains = 0,
    energy_pool_finisher = false,
    target_bleed_immune = false,
}
ctx.ttd_known = true
ctx.ttd = nil

local ok, m = pcall(rupture.matches, ctx, state_no_ttd)
assert_true(ok, "RuptureBleed matcher must not crash when ttd_known=true and ttd=nil (nil-vs-number)")
assert_true(m == false or m == true, "RuptureBleed must return a boolean, not crash")

-- Sanity: with a short known TTD the matcher still gates correctly (no crash).
ctx.ttd = 6
local ok2, m2 = pcall(rupture.matches, ctx, state_no_ttd)
assert_true(ok2, "RuptureBleed matcher crashed with short TTD")
assert_true(m2 == false, "RuptureBleed must gate out on short TTD (< 12s)")

-- Sanity: with a long TTD the matcher proceeds past the TTD gate.
ctx.ttd = 30
local ok3, m3 = pcall(rupture.matches, ctx, state_no_ttd)
assert_true(ok3, "RuptureBleed matcher crashed with long TTD")
assert_true(m3 == true, "RuptureBleed should proceed when TTD is long and Rupture ready")

print("PASS: assassination RuptureBleed ttd-nil guard regression (3 asserts)")
