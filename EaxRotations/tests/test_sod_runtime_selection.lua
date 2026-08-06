-- test_sod_runtime_selection.lua -- Happy-path SoD runtime and context selection.
-- WHAT:  verifies SoD identity, exclusive module routing, phase, and rune context.
-- WHEN:  run standalone or from the rotation suite.
-- WHY:   prevents SoD clients from selecting legacy rotations or losing rune state.
-- SAFETY: fully mocked; no class rotation or external API is executed.

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local fixture = require("tests/sod_runtime_fixture")
local NS, context, ok = fixture.boot("Vanilla", { runtime_mode = "sod", sod_phase = 7 }, function()
    return { [409240] = true }
end)

assert_eq(ok, true, "SoD dispatcher context must build")
assert_eq(NS.is_sod(), true, "explicit SoD runtime identity")
assert_eq(NS.is_tbc(), false, "SoD is not TBC")
assert_eq(NS.is_vanilla(), false, "SoD is not Vanilla")
assert_eq(NS.is_wotlk(), false, "SoD is not WotLK")
assert_eq(NS.get_expansion_max_level(), 60, "SoD level cap")
assert_eq(context.sod_phase, 7, "configured SoD phase")
assert_eq(context.sod_runes[409240], true, "equipped rune state")

local original_require = require
local attempts = {}
local modules = { ["classes/rogue/combat_sod"] = "SOD_COMBAT" }
function require(path)
    if path == "shared/class_loader_sylvanas" then return original_require(path) end
    if path:match("^classes/rogue/") then
        attempts[#attempts + 1] = path
        if modules[path] then return modules[path] end
        error("module '" .. path .. "' not found", 0)
    end
    return original_require(path)
end

package.loaded["shared/class_loader_sylvanas"] = nil
local loader = require("shared/class_loader_sylvanas")
assert_eq(loader.create_expansion_loader("rogue", "Rogue")("combat", true), "SOD_COMBAT", "SoD module")
assert_eq(#attempts, 1, "SoD loader attempt count")
assert_eq(attempts[1], "classes/rogue/combat_sod", "SoD-only module path")
require = original_require

print("PASS test_sod_runtime_selection")
