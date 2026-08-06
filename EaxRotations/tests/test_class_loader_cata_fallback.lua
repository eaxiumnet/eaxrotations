-- test_class_loader_cata_fallback.lua -- Cata-aware class-loader precedence fixtures.
-- WHAT:  verifies explicit Cata selection, safe fallback, and unchanged legacy precedence.
-- WHEN:  run standalone, with --missing-cata-module for the manual failure-path fixture.
-- WHY:   prevents Cata clients from silently selecting an older expansion rotation.
-- SAFETY: fully mocked; restores require and globals before reporting success.

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local missing_cata_module = arg and arg[1] == "--missing-cata-module"
local original_require = require
local original_ns = _G.EaxRotations
local original_core = _G.core
local original_core_module = package.loaded["core_sylvanas"]
local attempts = {}

local modules = {
    ["classes/warrior/arms_cata"] = "CATA_ARMS",
    ["classes/warrior/arms_wotlk"] = "WOTLK_ARMS",
    ["classes/warrior/arms_sylvanas"] = "TBC_ARMS",
    ["classes/warrior/arms_vanilla"] = "VANILLA_ARMS",
}

local function mocked_require(path)
    if path == "shared/class_loader_sylvanas" then return original_require(path) end
    if modules[path] and not (missing_cata_module and path:match("_cata$")) then
        attempts[#attempts + 1] = path
        return modules[path]
    end
    if path:match("^classes/warrior/") then
        attempts[#attempts + 1] = path
        error("module '" .. path .. "' not found", 0)
    end
    return original_require(path)
end

local function set_mode(mode)
    _G.EaxRotations = {
        is_cata = mode == "missing-predicate" and nil or function() return mode == "cata" or mode == "cata-wotlk" end,
        is_wotlk = function() return mode == "wotlk" or mode == "cata-wotlk" end,
        is_vanilla = function() return mode == "vanilla" end,
        log_warning = function() end,
    }
end

local function reset_attempts()
    for i = #attempts, 1, -1 do attempts[i] = nil end
end

require = mocked_require
package.loaded["shared/class_loader_sylvanas"] = nil
set_mode("cata")
local loader = require("shared/class_loader_sylvanas")
local load_warrior = loader.create_expansion_loader("warrior", "Warrior")

local expected_cata_result = missing_cata_module and "TBC_ARMS" or "CATA_ARMS"
assert_eq(load_warrior("arms", true), expected_cata_result, "Cata selection")
assert_eq(attempts[1], "classes/warrior/arms_cata", "Cata must be attempted first")
if missing_cata_module then
    assert_eq(attempts[2], "classes/warrior/arms_sylvanas", "missing Cata module must fall back safely")
end

reset_attempts()
set_mode("cata-wotlk")
assert_eq(load_warrior("arms", true), missing_cata_module and "TBC_ARMS" or "CATA_ARMS", "Cata must take precedence over WotLK")
assert_eq(attempts[1], "classes/warrior/arms_cata", "Cata must win conflicting predicates")
if missing_cata_module then
    assert_eq(attempts[2], "classes/warrior/arms_sylvanas", "conflicting predicates must still fall back safely")
end

reset_attempts()
set_mode("wotlk")
assert_eq(load_warrior("arms", true), "WOTLK_ARMS", "WotLK precedence")
assert_eq(attempts[1], "classes/warrior/arms_wotlk", "WotLK must remain first")

reset_attempts()
set_mode("vanilla")
assert_eq(load_warrior("arms", true), "VANILLA_ARMS", "Vanilla precedence")
assert_eq(attempts[1], "classes/warrior/arms_vanilla", "Vanilla must remain first")

reset_attempts()
set_mode("missing-predicate")
assert_eq(load_warrior("arms", true), "TBC_ARMS", "missing Cata predicate")
assert_eq(attempts[1], "classes/warrior/arms_sylvanas", "missing predicate must retain default precedence")

require = original_require
_G.EaxRotations = original_ns
package.loaded["shared/class_loader_sylvanas"] = nil

_G.core = {
    time = function() return 0 end,
    log = function() end,
    get_game_version = function() return "Cataclysm Classic" end,
}
package.loaded["core_sylvanas"] = nil
_G.EaxRotations = nil
local cata_core = require("core_sylvanas")
assert_eq(cata_core.is_cata(), true, "Cata client identity")
assert_eq(cata_core.is_tbc(), false, "Cata must not be TBC")
assert_eq(cata_core.is_vanilla(), false, "Cata must not be Vanilla")
assert_eq(cata_core.is_wotlk(), false, "Cata must not be WotLK")
assert_eq(cata_core.get_expansion_max_level(), 85, "Cata maximum level")

_G.core = {
    time = function() return 0 end,
    log = function() end,
    get_game_version = function() return "4.3.4" end,
}
package.loaded["core_sylvanas"] = nil
_G.EaxRotations = nil
local cata_numeric_core = require("core_sylvanas")
assert_eq(cata_numeric_core.is_cata(), true, "Cata 4.3 client identity")
assert_eq(cata_numeric_core.get_expansion_max_level(), 85, "Cata 4.3 maximum level")

_G.core = original_core
_G.EaxRotations = original_ns
package.loaded["core_sylvanas"] = original_core_module

print("PASS class_loader_cata_fallback mode=" .. (missing_cata_module and "missing-cata-module" or "cata"))
