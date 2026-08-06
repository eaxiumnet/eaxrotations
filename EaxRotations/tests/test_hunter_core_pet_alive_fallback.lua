-- test_hunter_core_pet_alive_fallback.lua — pet_alive() fail-open regression.
-- WHAT:  hunter_core.pet_alive() must report the pet alive when the unit
--        exposes is_dead() but not is_alive() (PS unit variance). Previously
--        it pcall-failed and returned false, silently killing the whole BM
--        pet lane (Kill Command, Bestial Wrath, Mend Pet, Intimidation).
-- WHEN:  run as part of the rotation test suite.
-- WHY:   the live client's pet object lacks is_alive(); NS.unit_alive is the
--        project's fail-open chain (is_valid → is_alive → is_dead → is_ghost,
--        default alive). hunter_core was the outlier that failed closed.
-- SAFETY: fully mocked NS; no game API calls.

local _pass, _fail = 0, 0
local function assert_true(cond, msg)
    if cond then _pass = _pass + 1 else _fail = _fail + 1 print("  FAIL: " .. msg) end
end

-- ---------------------------------------------------------------------------
-- Mock NS (module captures NS at load; time advances per call so the 1s pet
-- cache in get_pet() expires between cases)
-- ---------------------------------------------------------------------------
local NS = {}
_G.EaxRotations = NS

local t = 0
NS.time_now = function()
    t = t + 2
    return t
end
NS.unit_alive = nil -- controlled per-case below

local current_pet = nil
NS.GetPet = function() return current_pet end

-- Load the REAL hunter_core module fresh
package.loaded["shared/hunter_core_sylvanas"] = nil
package.preload["shared/hunter_core_sylvanas"] = nil
local core = dofile("EaxRotations/shared/hunter_core_sylvanas.lua")
assert_true(type(core) == "table" and type(core.pet_alive) == "function", "hunter_core loads")

-- ---------------------------------------------------------------------------
-- Case 1: pet with is_alive() true → alive
-- ---------------------------------------------------------------------------
current_pet = { is_alive = function() return true end }
NS.unit_alive = nil
assert_true(core.pet_alive() == true, "pet with is_alive()=true is alive")

-- ---------------------------------------------------------------------------
-- Case 2: pet with is_alive() false → dead
-- ---------------------------------------------------------------------------
current_pet = { is_alive = function() return false end }
assert_true(core.pet_alive() == false, "pet with is_alive()=false is dead")

-- ---------------------------------------------------------------------------
-- Case 3 (REGRESSION): pet WITHOUT is_alive, is_dead()=false → alive
-- ---------------------------------------------------------------------------
current_pet = { is_dead = function() return false end }
assert_true(core.pet_alive() == true, "pet without is_alive() but not dead is alive")

-- ---------------------------------------------------------------------------
-- Case 4: pet WITHOUT is_alive, is_dead()=true → dead
-- ---------------------------------------------------------------------------
current_pet = { is_dead = function() return true end }
assert_true(core.pet_alive() == false, "pet without is_alive() and dead is dead")

-- ---------------------------------------------------------------------------
-- Case 5: no pet → dead
-- ---------------------------------------------------------------------------
current_pet = nil
assert_true(core.pet_alive() == false, "no pet is not alive")

-- ---------------------------------------------------------------------------
-- Case 6: NS.unit_alive present and authoritative (project-wide chain)
-- ---------------------------------------------------------------------------
local unit_alive_calls = 0
NS.unit_alive = function(unit)
    unit_alive_calls = unit_alive_calls + 1
    return unit ~= nil
end
current_pet = { } -- no is_alive, no is_dead
assert_true(core.pet_alive() == true, "NS.unit_alive path reports alive")
assert_true(unit_alive_calls > 0, "NS.unit_alive was consulted")
NS.unit_alive = nil

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------
print(string.format("test_hunter_core_pet_alive_fallback: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_hunter_core_pet_alive_fallback")
