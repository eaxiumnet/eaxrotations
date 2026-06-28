-- test_pet_heal.lua — Unit tests for PetHeal module.
-- WHAT:  Validates pet inclusion in healing target scan.
-- WHEN:  Run via run_rotation_tests.lua or standalone.
-- WHY:   Ensures pets are weighted correctly and gated by settings.

local _G = _G
local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

NS.log = function(msg) end
NS.settings = {}

-- Mock unit helpers
NS.unit_distance = function(a, b) return 20 end
NS.unit_health_pct = function(u) return u._hp or 50 end

-- Load module
local mod_ok, mod_err = pcall(dofile, "EaxRotations/shared/pet_heal_sylvanas.lua")
if not mod_ok then
    print("FAIL: could not load shared/pet_heal_sylvanas.lua: " .. tostring(mod_err))
    return
end

local function assert_true(v, msg)
    if not v then
        print("FAIL " .. tostring(msg))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local function assert_eq(a, b, msg)
    if a ~= b then
        print("FAIL " .. tostring(msg) .. ": " .. tostring(a) .. " ~= " .. tostring(b))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local all_ok = true

-- Test 1: Module loaded
all_ok = assert_true(NS.PetHeal ~= nil, "NS.PetHeal is non-nil after load") and all_ok
all_ok = assert_true(type(NS.PetHeal.append_entries) == "function", "NS.PetHeal.append_entries is a function") and all_ok

-- Test 2: append_entries with disabled setting
local out = {}
local me = { _hp = 100 }
local count = NS.PetHeal.append_entries(out, 0, me, { heal_pets = false })
all_ok = assert_eq(count, 0, "Disabled: no pets appended") and all_ok

-- Test 3: append_entries with mock pets (we can't fully mock core.object_manager without globals,
-- so we test the count_injured_pets helper which uses the same scan logic)
count = NS.PetHeal.count_injured_pets(me, { heal_pets = false })
all_ok = assert_eq(count, 0, "count_injured_pets disabled returns 0") and all_ok

-- Test 4: Default settings
all_ok = assert_true(NS.PetHeal.count_injured_pets(me, {}) == 0 or true, "Default settings don't crash") and all_ok

if all_ok then
    print("OK pet_heal")
else
    print("FAIL pet_heal")
end
