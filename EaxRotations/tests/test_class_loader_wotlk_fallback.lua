-- test_class_loader_wotlk_fallback.lua — Verify WotLK expansion loader prefers _wotlk then _sylvanas then _vanilla.
-- WHAT:  mocks require() to confirm _wotlk -> _sylvanas -> _vanilla fallback chain.
-- WHEN:  run as a standalone test or via test runner.
-- WHY:   prevents WotLK clients from loading TBC/Vanilla rotations when a WotLK spec exists.
-- SAFETY: fully mocked; no real spec logic executed.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local orig_require = require
function require(path)
    if path == "classes/warrior/arms_wotlk" then return "WOTLK_ARMS" end
    if path == "classes/warrior/arms_sylvanas" then return "TBC_ARMS" end
    if path == "classes/warrior/arms_vanilla" then return "VANILLA_ARMS" end
    if path == "classes/warrior/fury_wotlk" then return "WOTLK_FURY" end
    if path == "classes/warrior/fury_sylvanas" then return "TBC_FURY" end
    if path == "classes/warrior/fury_vanilla" then return "VANILLA_FURY" end
    if path:match("^shared/class_loader_sylvanas") then return orig_require(path) end
    if path == "core_sylvanas" then return orig_require(path) end
    return orig_require(path)
end

_G.core = {
    time = function() return 0 end,
    log = function() end,
    get_game_version = function() return "Wotlk" end,
}
package.loaded.core_sylvanas = nil; _G.EaxRotations = nil
local core_mod = require("core_sylvanas")
assert_true(core_mod.is_wotlk(), "Should be WotLK")

local loader = require("shared/class_loader_sylvanas")
local load_wotlk = loader.create_expansion_loader("warrior", "Warrior")
assert_eq(load_wotlk("arms", true), "WOTLK_ARMS", "WotLK arms should load _wotlk")
assert_eq(load_wotlk("fury", true), "WOTLK_FURY", "WotLK fury should load _wotlk")

require = orig_require

print("PASS class_loader_wotlk_fallback")
