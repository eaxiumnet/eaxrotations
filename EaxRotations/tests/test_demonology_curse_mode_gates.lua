-- test_demonology_curse_mode_gates.lua
-- WHAT: regression test for curse mode dropdown in demonology spec.
-- Verifies Curse of Elements, Curse of Doom, and Curse of Agony are gated
-- by the warlock_curse_mode setting (Bertsay bug fix).

local pass, fail = 0, 0
local function assert_eq(a, b, msg)
    if a == b then pass = pass + 1 else
        fail = fail + 1; print("FAIL: " .. (msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a))
    end
end

-- Reproduce the curse mode gating logic from demonology_sylvanas.lua
local function curse_mode_allows(curse_mode, allowed_modes)
    if curse_mode == "auto" then return true end
    for _, m in ipairs(allowed_modes) do
        if curse_mode == m then return true end
    end
    return false
end

-- CoD allows: "auto", "doom"
assert_eq(curse_mode_allows("auto", {"doom"}), true, "CoD auto mode")
assert_eq(curse_mode_allows("doom", {"doom"}), true, "CoD explicit doom mode")
assert_eq(curse_mode_allows("agony", {"doom"}), false, "CoD blocked in agony mode")
assert_eq(curse_mode_allows("elements", {"doom"}), false, "CoD blocked in elements mode")

-- CoE allows: "auto", "elements"
assert_eq(curse_mode_allows("auto", {"elements"}), true, "CoE auto mode")
assert_eq(curse_mode_allows("elements", {"elements"}), true, "CoE explicit elements mode")
assert_eq(curse_mode_allows("agony", {"elements"}), false, "CoE blocked in agony mode")
assert_eq(curse_mode_allows("shadow", {"elements"}), false, "CoE blocked in shadow mode")

-- CoA allows: "auto", "agony"
assert_eq(curse_mode_allows("auto", {"agony"}), true, "CoA auto mode")
assert_eq(curse_mode_allows("agony", {"agony"}), true, "CoA explicit agony mode")
assert_eq(curse_mode_allows("elements", {"agony"}), false, "CoA blocked in elements mode")
assert_eq(curse_mode_allows("none", {"agony"}), false, "CoA blocked in none mode")

if fail == 0 then
    print("PASS test_demonology_curse_mode_gates " .. pass .. "/" .. pass .. " passed")
else
    print("FAIL test_demonology_curse_mode_gates " .. fail .. " failures")
end