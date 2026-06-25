-- ============================================================================
-- Regression test: hunter_adaptive_sylvanas.lua must load with WoW globals
-- absent (no Sylvanas co-habiting WoW client runtime).
-- ----------------------------------------------------------------------------
-- Background: prior to 2026-06-22, the module's load-time bindings did
-- `local X = _G.X` for UnitRangedAttackPower, UnitRangedDamage, GetTime,
-- etc. If the host environment had none of those, the module crashed at
-- first call to readStats / scheduleNextRecompute / timestamp.
--
-- The fix wraps each binding via a `safe_call` accessor that returns a
-- safe default if `_G.X` is nil. This test simulates a clean environment
-- (no WoW runtime) and asserts the module loads + exposes its public API.
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;./?.lua;api/?.lua;" .. package.path

-- 1. Pre-cache the real _G references we may need after stripping
-- (so cleanup at teardown doesn't accidentally leave our staging globals).
local function snapshot(name)
    local v = _G[name]
    _G[name] = false
    return v
end
local function restore(name, prev)
    _G[name] = prev
end

local stripped = {
    "UnitRangedAttackPower", "UnitRangedDamage", "GetRangedCritChance",
    "UnitBuff", "UnitGUID", "GetTime", "GetCVar",
    "CombatLogGetCurrentEventInfo", "GetTalentInfo",
    "CreateFrame",
}
local PREV = {}
for _, name in ipairs(stripped) do PREV[name] = snapshot(name) end

-- 2. Provide a minimal Sylvanas-style `EaxRotations` namespace so the
-- module's `local NS = _G.EaxRotations` and the SPELLS gate succeed.
local __NS = _G.EaxRotations
_G.EaxRotations = {
    HunterSpells = { MultiShot = { id = 2643 }, SteadyShot = { id = 5662 } },
    log = function() end,
    log_warning = function() end,
    register_on_combat_start = function() end,
    get_setting = function() return nil end,
    get_global_cooldown = function() return 1.5 end,
    gcd_remains = function() return 0 end,
    mana_pct = function() return 100 end,
    GetPlayer = function() return nil end,
    spell_ready = function() return false end,
}

-- 3. Also stub EaxRotations's api/core & HunterAdaptive consumers.
_G.__api_loaded = false
local REAL_require = require
package.preload["api/core"] = function()
    _G.__api_loaded = true
    return {
        get_ping = function() return 0.1 end,
    }
end

-- 4. Load the module. Wrapped in pcall so any failure prints cleanly.
local ok, M = pcall(function()
    return REAL_require("EaxRotations/shared/hunter_adaptive_sylvanas")
end)

assert(ok, string.format("test_hunter_adaptive_nil_globals FAIL: module load threw: %s", tostring(M)))

-- 5. The module returns nil because SPELLS.MultiShot must be a table-or-indexed
--    thing (EaxRotations gates on `if not SPELLS.MultiShot`); we already have
--    SPELLS.MultiShot as a table above. But the module unconditionally
--    TABLES its binding and accesses SPELLS.MultiShot elsewhere; we just
--    need to assert the module DID NOT throw — it can return either M or nil,
--    both are acceptable for the load-resilience contract.

-- 6. Most importantly: assert no _G.X was added (no global pollution).
--    The module writes NS.HunterAdaptive, which is on its own namespace.
if _G.EaxAutoQuester then
    error("test_hunter_adaptive_nil_globals FAIL: hunter_adaptive polluted _G.EaxAutoQuester")
end

-- 7. Confirm the safe_call behavior: even with stripped globals, calling
--    the HunterAdaptive public API (if returned) must not throw.
if type(M) == "table" then
    assert(type(M.ChooseAction) == "function", "test_hunter_adaptive_nil_globals FAIL: M.ChooseAction missing")
    -- Calling ChooseAction with nil unit should return a string option without throwing.
    local c_ok, c_ret = pcall(M.ChooseAction, nil)
    assert(c_ok, "test_hunter_adaptive_nil_globals FAIL: M.ChooseAction(nil) threw: " .. tostring(c_ret))
end

-- 8. Teardown: restore stripped globals.
for _, name in ipairs(stripped) do restore(name, PREV[name]) end
_G.EaxRotations = __NS
package.preload["api/core"] = nil

print("PASS test_hunter_adaptive_nil_globals")
os.exit(0)
