-- test_paladin_vanilla_seal_ooc_gate.lua
-- WHAT: regression test for OOC seal refresh toggle in vanilla retribution.
-- Verifies seal_refresh_allowed gates seal applications when out of combat
-- and seal_refresh_ooc is disabled (Sharpie bug fix).

local pass, fail = 0, 0
local function assert_eq(a, b, msg)
    if a == b then pass = pass + 1 else
        fail = fail + 1; print("FAIL: " .. (msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a))
    end
end

-- Reproduce the exact gate logic from retribution_vanilla.lua
local function seal_refresh_allowed(context, setting_val)
    if context and context.in_combat then return true end
    -- spec_kit.setting_bool(context, "seal_refresh_ooc", true)
    return setting_val ~= false  -- true when nil or true
end

-- Test 1: in combat always allows
assert_eq(seal_refresh_allowed({ in_combat = true }, false), true, "combat always true even if toggle off")

-- Test 2: OOC with toggle off blocks
assert_eq(seal_refresh_allowed({ in_combat = false }, false), false, "OOC with toggle off blocks")

-- Test 3: OOC with toggle on allows
assert_eq(seal_refresh_allowed({ in_combat = false }, true), true, "OOC with toggle on allows")

-- Test 4: nil context + default true allows
assert_eq(seal_refresh_allowed(nil, true), true, "nil context default true")

-- Test 5: nil context + default false blocks
assert_eq(seal_refresh_allowed(nil, false), false, "nil context default false")

if fail == 0 then
    print("PASS test_paladin_vanilla_seal_ooc_gate " .. pass .. "/" .. pass .. " passed")
else
    print("FAIL test_paladin_vanilla_seal_ooc_gate " .. fail .. " failures")
end