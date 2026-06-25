-- test_classic_warrior_spec.lua — Verify expansion loader picks correct warrior spec suffixes.
-- WHAT:  mocks require() to confirm _sylvanas vs _vanilla selection for Arms and Fury.
-- WHEN:  run as a standalone test or via test runner.
-- WHY:   warrior has stance/form complexity; warrants dedicated loader verification.
-- SAFETY: fully mocked; no real spec logic executed.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

-- Test that expansion loader selects correct suffix
local orig_require = require
function require(path)
    if path == "classes/warrior/fury_sylvanas" then return "TBC_FURY" end
    if path == "classes/warrior/fury_vanilla" then return "VANILLA_FURY" end
    if path == "classes/warrior/arms_sylvanas" then return "TBC_ARMS" end
    if path == "classes/warrior/arms_vanilla" then return "VANILLA_ARMS" end
    if path == "classes/warrior/protection_sylvanas" then return "TBC_PROT" end
    if path == "classes/warrior/protection_vanilla" then return "VANILLA_PROT" end
    if path == "classes/warrior/kebab_sylvanas" then return "TBC_KEBAB" end
    if path == "classes/warrior/kebab_vanilla" then return "VANILLA_KEBAB" end
    if path:match("^shared/class_loader_sylvanas") then return orig_require(path) end
    if path == "core_sylvanas" then return orig_require(path) end
    return orig_require(path)
end

-- Test 1: TBC expansion loads fury_sylvanas
_G.core = {
    time = function() return 0 end,
    log = function() end,
    get_game_version = function() return "Tbc" end,
}
package.loaded.core_sylvanas = nil; _G.EaxRotations = nil
local core_mod = require("core_sylvanas")
assert_true(core_mod.is_tbc(), "Should be TBC")

local loader = require("shared/class_loader_sylvanas")
local load_tbc = loader.create_expansion_loader("warrior", "Warrior")
assert_eq(load_tbc("fury", true), "TBC_FURY", "TBC fury should load _sylvanas")
assert_eq(load_tbc("arms", true), "TBC_ARMS", "TBC arms should load _sylvanas")
assert_eq(load_tbc("protection", true), "TBC_PROT", "TBC protection should load _sylvanas")
assert_eq(load_tbc("kebab", true), "TBC_KEBAB", "TBC kebab should load _sylvanas")

-- Test 2: Vanilla expansion loads _vanilla variants
_G.core.get_game_version = function() return "Vanilla" end
package.loaded.core_sylvanas = nil; _G.EaxRotations = nil
core_mod = require("core_sylvanas")
assert_true(core_mod.is_vanilla(), "Should be Vanilla")

loader = require("shared/class_loader_sylvanas")
local load_vanilla = loader.create_expansion_loader("warrior", "Warrior")
assert_eq(load_vanilla("fury", true), "VANILLA_FURY", "Vanilla fury should load _vanilla")
assert_eq(load_vanilla("arms", true), "VANILLA_ARMS", "Vanilla arms should load _vanilla")
assert_eq(load_vanilla("protection", true), "VANILLA_PROT", "Vanilla protection should load _vanilla")
assert_eq(load_vanilla("kebab", true), "VANILLA_KEBAB", "Vanilla kebab should load _vanilla")

require = orig_require

print("PASS classic_warrior_spec")
