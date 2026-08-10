-- test_middleware_mid_cast_skip.lua — pins the middleware mid-cast skip semantics.
-- WHAT:  main_sylvanas.lua's run_list skips middleware strategies while the
--        player is casting/channeling UNLESS the strategy is marked
--        mid_cast_safe = true (dispels, CC breaks, spellsteal/remove-curse —
--        the things that must fire to break the spell blocking the cast).
--        This test pins the guard helper M.middleware_mid_cast_skipped AND
--        proves end-to-end through the REAL dispatcher (on_rotation_update_unified
--        under the battery mock NS) that marked strategies still evaluate+fire
--        while casting while unmarked ones are skipped, and that OOC frames are
--        unaffected (unmarked still run when not casting).
-- WHEN:  rotation suite execution.
-- WHY:   a future edit could silently remove the guard or the mid_cast_safe
--        flags — this test fails if either the helper semantics change or the
--        real class middleware loses its marks (paladin Cleanse is the
--        canonical must-run-mid-cast lane).
-- SAFETY: Pure unit test with the behavioral_audit mock NS; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end
local function assert_false(v, label)
    if v then error(label or "assert_false failed", 2) end
end

-- Load the real dispatcher under the battery's mock NS so its exported helper
-- and run_list wiring are the actual production code (no logic copy in this test).
local saved_global = _G.EaxRotations
local ns = aud.build_ns("paladin")
-- The dispatcher resolves the active class via NS.rotation_registry.class_config;
-- give the mock a minimal registry so the middleware path is reachable.
ns.rotation_registry = {
    class_config = { class_key = "paladin", default_playstyle = "paladin" },
    playstyles = { paladin = {}, leveling = {} },
    options = {},
}
-- The unified dispatcher calls NS.run_unified_strategies after middleware and
-- NS.log_* on strategy errors — provide inert stubs so only the middleware
-- probe list's side effects are observable.
ns.run_unified_strategies = function() return false end
ns.log_warning = function() end
ns.log_success = function() end
-- _G.EaxRotations stays installed through all dispatcher exercises below (the
-- dispatcher's build_context reads live NS state on some paths); restored at
-- the end of the test.
_G.EaxRotations = ns
local ok_disp, dispatcher = pcall(dofile, "EaxRotations/main_sylvanas.lua")
assert_true(ok_disp, "main_sylvanas.lua must load under the battery mock NS: " .. tostring(dispatcher))
assert_true(type(dispatcher) == "table" and type(dispatcher.middleware_mid_cast_skipped) == "function",
    "dispatcher must export middleware_mid_cast_skipped")

local skip = dispatcher.middleware_mid_cast_skipped

-- ---------------------------------------------------------------------------
-- 1. Helper semantics (pure predicate)
-- ---------------------------------------------------------------------------
local marked   = { name = "Paladin_Cleanse", mid_cast_safe = true }
local unmarked = { name = "AutoConsumable" }

assert_true(skip("middleware", unmarked, { is_casting = true }),  "unmarked middleware skipped while casting")
assert_true(skip("middleware", unmarked, { is_channeling = true }), "unmarked middleware skipped while channeling")
assert_false(skip("middleware", marked, { is_casting = true }),     "mid-cast-safe strategy NOT skipped while casting")
assert_false(skip("middleware", marked, { is_channeling = true }),  "mid-cast-safe strategy NOT skipped while channeling")
assert_false(skip("middleware", unmarked, { is_casting = false }),  "unmarked middleware NOT skipped on a normal frame")
assert_false(skip("middleware", unmarked, {}),                      "unmarked middleware NOT skipped with no cast state")
assert_false(skip("playstyle", unmarked, { is_casting = true }),    "guard never applies to playstyle lists (skipped upstream)")
assert_true(skip("middleware", nil, { is_casting = true }),         "nil strategy skipped while casting (defensive — no mid_cast_safe on nil)")

-- ---------------------------------------------------------------------------
-- 2. End-to-end: the guard is wired into the REAL dispatcher's run_list.
--    The mock NS supplies class_middleware (what the unified dispatcher reads
--    at its middleware call site), and the mock player unit's
--    is_casting/is_channeling/is_in_combat drive the dispatcher's real
--    build_context. execute returns FALSE so run_list does not short-circuit
--    (it only returns early on execute == true), letting us observe BOTH
--    lanes' matches/execute side effects on the same frame.
-- ---------------------------------------------------------------------------
local evaluated, executed = {}, {}
ns.class_middleware = {
    paladin = {
        { name = "AutoConsumable",
          matches = function() evaluated[#evaluated + 1] = "AutoConsumable"; return true end,
          execute = function() executed[#executed + 1] = "AutoConsumable"; return false end },
        { name = "Paladin_Cleanse", mid_cast_safe = true,
          matches = function() evaluated[#evaluated + 1] = "Paladin_Cleanse"; return true end,
          execute = function() executed[#executed + 1] = "Paladin_Cleanse"; return false end },
    },
}
local me = ns.GetPlayer()
-- Pin the minted unit: build_context's _get_player() calls NS.GetPlayer(),
-- which mints a FRESH unit per call unless ns.me is set. Without the pin the
-- is_casting/is_in_combat patches below would land on a different table than
-- the one the dispatcher reads and the guard could never trigger.
ns.me = me

local function drive(casting, channeling, in_combat)
    evaluated, executed = {}, {}
    me.is_casting = function() return casting end
    me.is_channeling = function() return channeling end
    me.is_in_combat = function() return in_combat end
    local ok, err = pcall(dispatcher.on_rotation_update_unified)
    assert_true(ok, "dispatcher on_rotation_update_unified must not error: " .. tostring(err))
end

-- 2a. Casting, in combat: marked runs, unmarked skipped entirely.
drive(true, false, true)
assert_true(evaluated[1] == "Paladin_Cleanse" and evaluated[2] == nil,
    "while casting: Paladin_Cleanse evaluated, AutoConsumable must NOT be (got: " .. table.concat(evaluated, ",") .. ")")
assert_true(executed[1] == "Paladin_Cleanse",
    "while casting: Paladin_Cleanse must execute (got: " .. table.concat(executed, ",") .. ")")

-- 2b. Channeling, in combat: same semantics as casting (guard covers both).
drive(false, true, true)
assert_true(evaluated[1] == "Paladin_Cleanse" and evaluated[2] == nil,
    "while channeling: Paladin_Cleanse evaluated, AutoConsumable must NOT be (got: " .. table.concat(evaluated, ",") .. ")")

-- 2c. Same frame, NOT casting (in combat): both lanes evaluate and fire.
drive(false, false, true)
assert_true(evaluated[1] == "AutoConsumable" and evaluated[2] == "Paladin_Cleanse",
    "non-cast frame: both middleware strategies must evaluate (got: " .. table.concat(evaluated, ",") .. ")")
assert_true(executed[1] == "AutoConsumable" and executed[2] == "Paladin_Cleanse",
    "non-cast frame: both middleware strategies must execute (got: " .. table.concat(executed, ",") .. ")")

-- 2d. OOC frame (not in combat, not casting): unmarked middleware still runs.
drive(false, false, false)
assert_true(evaluated[1] == "AutoConsumable",
    "OOC frame: unmarked middleware must still evaluate (got: " .. table.concat(evaluated, ",") .. ")")

-- ---------------------------------------------------------------------------
-- 3. The real class middleware keeps its marks (flag can't silently vanish).
--    Paladin_Cleanse is the canonical must-run-mid-cast lane.
-- ---------------------------------------------------------------------------
local paladin_ok, paladin_mw = pcall(dofile, "EaxRotations/classes/paladin/middleware_sylvanas.lua")
assert_true(paladin_ok and type(paladin_mw) == "table", "paladin middleware must load")
local cleanse_found = false
for _, s in ipairs(paladin_mw) do
    if type(s) == "table" and s.name == "Paladin_Cleanse" then
        cleanse_found = true
        assert_true(s.mid_cast_safe == true, "Paladin_Cleanse must keep mid_cast_safe = true")
    end
end
assert_true(cleanse_found, "Paladin_Cleanse must exist in paladin middleware")
-- dispel-manager-built strategies forward the flag (opts.mid_cast_safe)
assert_false(skip("middleware", { name = "AutoDispel", mid_cast_safe = true }, { is_casting = true }),
    "dispel-manager strategy with mid_cast_safe forwarded must not be skipped while casting")

_G.EaxRotations = saved_global
print("PASS test_middleware_mid_cast_skip")
