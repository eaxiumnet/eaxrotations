-- test_cat_faerie_fire_stealth_creature_type.lua — regression for the cat
-- FaerieFireStealthLock dead-lane bug found by the behavioral battery audit (2026-08-07).
-- WHAT:  STEALTH_PREVENT_TYPES was keyed by creature-type NAMES ("Humanoid",
--        "Beast") while get_creature_type() returns numeric IDs (7=Humanoid,
--        1=Beast — same convention as protection DEMON_OR_UNDEAD = {[3],[6]}).
--        The lookup always missed, so `not STEALTH_PREVENT_TYPES[ct]` was
--        always true and FaerieFireStealthLock could never match.
-- WHEN:  rotation suite execution.
-- WHY:   behavioral_audit.lua reported FaerieFireStealthLock never-firing in
--        every stealth+PvP scenario.
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end

local result, err, ns = aud.load_spec("druid", "cat")
assert_true(result ~= nil, "cat load failed: " .. tostring(err))

local ff = nil
for _, s in ipairs(result.strategies) do
    if s.name == "FaerieFireStealthLock" then ff = s break end
end
assert_true(ff ~= nil, "FaerieFireStealthLock strategy missing")

-- Stealthed + PvP + humanoid target (numeric creature type 7) with armor:
-- the stealth FF opener must be reachable.
local ctx = aud.build_context_for("druid", {
    name = "cat_stealth_pvp",
    overrides = { form = 3, is_stealthed = true, combo_points = 0, in_combat = false, is_pvp = true },
})
assert_true(ctx ~= nil, "build_context_for failed")
aud.apply_battery_state(ns, ctx, "druid")
local ok, st = pcall(result.build_state, ctx)
assert_true(ok, "build_state crashed: " .. tostring(st))
local state = ok and st or ctx
assert_true(state.is_stealthed == true, "state.is_stealthed must be true in stealth scenario")

local mok, m = pcall(ff.matches, ctx, state)
assert_true(mok, "FaerieFireStealthLock matcher crashed: " .. tostring(m))
assert_true(m == true,
    "FaerieFireStealthLock must match on a stealthed PvP opener vs a humanoid target (creature_type=7)")

print("PASS: cat FaerieFireStealthLock creature-type regression")
