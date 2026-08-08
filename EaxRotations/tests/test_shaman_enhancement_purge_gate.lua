-- test_shaman_enhancement_purge_gate.lua — regression for the enhancement
-- Purge dead-lane bug found by the behavioral battery audit (2026-08-07).
-- WHAT:  enhancement_sylvanas.lua Purge gated on NS.purge_should_cast (never
--        defined anywhere in the engine) AND on s.target (build_state never
--        sets a target field), so the strategy could never match in live play.
--        The lane now uses the OffensiveDispelDB priority scan + purge_manager
--        fallback, mirroring middleware_sylvanas.lua.
-- WHEN:  rotation suite execution.
-- WHY:   behavioral_audit.lua reported Purge never-firing across every
--        scenario including enemy-buffed PvP contexts.
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end

local result, err, ns = aud.load_spec("shaman", "enhancement")
assert_true(result ~= nil, "enhancement load failed: " .. tostring(err))

local purge = nil
for _, s in ipairs(result.strategies) do
    if s.name == "Purge" then purge = s break end
end
assert_true(purge ~= nil, "Purge strategy missing")

-- Purge should fire when the enemy has a high-priority buff, PvP enabled,
-- mana above the floor, and use_purge default on.
local ctx2 = aud.build_context_for("shaman", {
    name = "purge_buffed",
    overrides = { enemy_buffed = true, is_pvp = true },
})
assert_true(ctx2 ~= nil, "build_context_for failed")
aud.apply_battery_state(ns, ctx2, "shaman")
local ok, st = pcall(result.build_state, ctx2)
assert_true(ok, "build_state crashed: " .. tostring(st))
local state = ok and st or ctx2

local mok, m = pcall(purge.matches, ctx2, state)
assert_true(mok, "Purge matcher crashed: " .. tostring(m))
assert_true(m == true, "Purge must match when enemy is buffed and PvP is on")

-- And it must NOT match when the enemy has no buffs (no purge target).
local ctx3 = aud.build_context_for("shaman", {
    name = "standard",
    overrides = { is_pvp = true },
})
aud.apply_battery_state(ns, ctx3, "shaman")
local ok3, st3 = pcall(result.build_state, ctx3)
local state3 = ok3 and st3 or ctx3
local mok3, m3 = pcall(purge.matches, ctx3, state3)
assert_true(mok3, "Purge matcher crashed on clean target: " .. tostring(m3))
assert_true(m3 == false, "Purge must not match when the target has no purgeable buffs")

print("PASS: shaman/enhancement Purge gate regression (buffed=fire, clean=skip)")
