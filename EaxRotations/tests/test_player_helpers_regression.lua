-- test_player_helpers_regression.lua — pins shared/player_helpers_sylvanas.lua.
-- WHAT:  Exercises get_player / get_player_robust / install: the NS.GetPlayer
--        type+pcall guards, the core.object_manager.get_local_player fallback
--        (the aura_probe-heritage path), falsey-return handling, install
--        idempotency, and nil/non-table guard rails. Every spec reads the
--        player through these helpers and the module previously had ZERO test
--        references.
-- WHEN:  rotation suite execution.
-- WHY:   a future edit to the fallback chain could silently break specs that
--        rely on get_player_robust when the engine lacks a GetPlayer shim, or
--        let a throwing NS.GetPlayer propagate; this test pins the contract.
-- SAFETY: Pure unit test. The helpers read _G.EaxRotations / _G.core per call
--        (nothing cached at load), so the test mutates those tables directly;
--        the real SDK is never touched.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

_G.EaxRotations = nil
_G.core = nil
local ph = dofile("EaxRotations/shared/player_helpers_sylvanas.lua")
assert_true(type(ph) == "table", "player_helpers must load with no NS/core")

local me_unit = { name = "Me", guid = "player-guid" }
local fallback_unit = { name = "FallbackMe", guid = "fallback-guid" }
local fallback_calls = 0

-- ---------------------------------------------------------------------------
-- 1. No NS at all
-- ---------------------------------------------------------------------------
_G.EaxRotations = nil
assert_eq(ph.get_player(), nil, "get_player with nil NS returns nil")
assert_eq(ph.get_player_robust(), nil, "get_player_robust with nil NS and nil core returns nil")

-- ---------------------------------------------------------------------------
-- 2. NS without a GetPlayer function
-- ---------------------------------------------------------------------------
_G.EaxRotations = {}
assert_eq(ph.get_player(), nil, "get_player with NS lacking GetPlayer returns nil")

-- ---------------------------------------------------------------------------
-- 3. NS.GetPlayer returns the unit
-- ---------------------------------------------------------------------------
_G.EaxRotations = { GetPlayer = function() return me_unit end }
assert_eq(ph.get_player(), me_unit, "get_player returns the NS.GetPlayer unit")

-- ---------------------------------------------------------------------------
-- 4. Throwing NS.GetPlayer is pcall-isolated
-- ---------------------------------------------------------------------------
_G.EaxRotations = { GetPlayer = function() error("boom") end }
assert_eq(ph.get_player(), nil, "throwing NS.GetPlayer yields nil (pcall guard)")

-- ---------------------------------------------------------------------------
-- 5. get_player_robust fallback chain
-- ---------------------------------------------------------------------------
-- NS.GetPlayer returns nil -> get_player_robust falls back to core.
_G.EaxRotations = { GetPlayer = function() return nil end }
_G.core = {
    object_manager = {
        get_local_player = function() fallback_calls = fallback_calls + 1; return fallback_unit end,
    },
}
assert_eq(ph.get_player(), nil, "get_player stays nil when NS.GetPlayer returns nil")
assert_eq(ph.get_player_robust(), fallback_unit, "robust falls back to core.object_manager")
assert_eq(fallback_calls, 1, "fallback consulted exactly once")

-- robust PREFERS NS.GetPlayer over the fallback (fallback must not run).
_G.core = {
    object_manager = {
        get_local_player = function() error("should not be called") end,
    },
}
_G.EaxRotations = { GetPlayer = function() return me_unit end }
assert_eq(ph.get_player_robust(), me_unit, "robust prefers NS.GetPlayer when it returns a unit")

-- NS.GetPlayer returns false (falsey but not nil): robust falls through.
_G.EaxRotations = { GetPlayer = function() return false end }
_G.core = {
    object_manager = {
        get_local_player = function() return fallback_unit end,
    },
}
assert_eq(ph.get_player_robust(), fallback_unit, "robust falls back on a falsey player result")

-- core present but object_manager missing / get_local_player not a function.
_G.EaxRotations = { GetPlayer = function() return nil end }
_G.core = {}
assert_eq(ph.get_player_robust(), nil, "robust with no object_manager returns nil")
_G.core = { object_manager = {} }
assert_eq(ph.get_player_robust(), nil, "robust with no get_local_player returns nil")

-- Throwing fallback is also pcall-isolated.
_G.core = {
    object_manager = { get_local_player = function() error("boom") end },
}
_G.EaxRotations = { GetPlayer = function() return nil end }
assert_eq(ph.get_player_robust(), nil, "throwing fallback yields nil (pcall guard)")

-- ---------------------------------------------------------------------------
-- 6. install() installs both helpers onto an NS table (idempotent)
-- ---------------------------------------------------------------------------
_G.EaxRotations = nil
local target = {}
ph.install(target)
assert_eq(target.get_player, ph.get_player, "install sets NS.get_player")
assert_eq(target.get_player_robust, ph.get_player_robust, "install sets NS.get_player_robust")

ph.install(target)  -- idempotent: same functions, no churn
assert_eq(target.get_player, ph.get_player, "install is idempotent (get_player)")
assert_eq(target.get_player_robust, ph.get_player_robust, "install is idempotent (get_player_robust)")

-- Guard rails: non-table targets are ignored without raising.
local ok = pcall(ph.install, nil)
assert_true(ok, "install(nil) is a safe no-op")
ok = pcall(ph.install, "not-a-table")
assert_true(ok, "install(string) is a safe no-op")

print("PASS test_player_helpers_regression")
